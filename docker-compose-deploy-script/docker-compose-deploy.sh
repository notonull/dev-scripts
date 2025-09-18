#!/bin/bash

# Docker Compose 部署脚本 - 主脚本
# 版本: 2.0
# 描述: 统一管理多个Docker服务的部署脚本

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 发布目录
DEPLOY_DIR="${SCRIPT_DIR}/deploy"
# 工具包目录
LIB_DIR="${SCRIPT_DIR}/lib"

# 加载公共库
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/system_utils.sh"

# 注册脚本列表
declare -A REGISTERED_SCRIPTS
REGISTERED_SCRIPTS["jenkins"]="deploy/jenkins.sh"
REGISTERED_SCRIPTS["mysql"]="deploy/mysql.sh"
REGISTERED_SCRIPTS["redis"]="deploy/redis.sh"
REGISTERED_SCRIPTS["mongodb"]="deploy/mongodb.sh"
REGISTERED_SCRIPTS["minio"]="deploy/minio.sh"
REGISTERED_SCRIPTS["nacos"]="deploy/nacos.sh"
REGISTERED_SCRIPTS["nexus"]="deploy/nexus.sh"
REGISTERED_SCRIPTS["yapi"]="deploy/yapi.sh"
REGISTERED_SCRIPTS["nginx"]="deploy/nginx.sh"

# 安装顺序列表 - 从注册脚本列表中选择需要操作的服务
declare -a INSTALL_ORDER=(
    "mysql"     
    "redis"     
    "mongodb"   
    "jenkins"   
    "minio"     
    "nacos"
    "nexus"
    "yapi"
    "nginx"
)

# 获取所有可用服务代码列表
list() {
    echo "${INSTALL_ORDER[@]}"
}

# 获取指定服务代码的脚本路径
get() {
    local code="$1"
    local registered_path="${REGISTERED_SCRIPTS[$code]}"
    
    # 如果是绝对路径，直接返回
    if [[ "$registered_path" = /* ]]; then
        echo "$registered_path"
    else
        # 相对路径，基于SCRIPT_DIR解析
        echo "${SCRIPT_DIR}/${registered_path}"
    fi
}

# 检查脚本是否存在
check() {
    local code="$1"
    local script_path="$(get "$code")"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "脚本不存在: $script_path"
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        chmod +x "$script_path" 2>/dev/null || true
    fi
    
    return 0
}

# 执行子脚本命令
execute() {
    local command="$1"
    local code="${2:-}"
    
    # 如果没有指定服务代码，执行所有服务
    if [[ -z "$code" ]]; then
        local codes
        
        # 获取启用的服务列表
        codes=($(list))
        
        if [[ ${#codes[@]} -eq 0 ]]; then
            log_warn "没有启用的服务"
            return 0
        fi
        
        # 根据命令类型决定是否需要确认
        case "$command" in
            "config"|"yml"|"info")
                # 查看类命令：不需要确认
                ;;
            "pull"|"install"|"uninstall"|"down"|"up"|"rmi")
                # 操作类命令：需要确认
                log_warn "即将对所有启用的服务执行 '$command' 操作:"
                for code_item in "${codes[@]}"; do
                    log_info "  - $code_item"
                done
                
                if ! confirm_action "确认执行"; then
                    log_info "操作已取消"
                    return 0
                fi
                ;;
            *)
                log_error "不支持的批量命令: $command"
                return 1
                ;;
        esac
        
        local success_count=0
        local total_count=${#codes[@]}
        
        # 批量执行
        for code_item in "${codes[@]}"; do
            log_info "执行 $code_item 的 $command 操作..."
            # 临时禁用 set -e，允许单个服务失败而不退出整个脚本
            set +e
            
            # 直接执行单个服务，不使用递归调用
            if [[ ! -v REGISTERED_SCRIPTS[$code_item] ]]; then
                log_error "未注册的脚本代码: $code_item"
                exit_code=1
            else
                # 检查服务是否在启用列表中（操作类命令需要检查）
                case "$command" in
                    "pull"|"install"|"uninstall"|"down"|"up"|"rmi"|"logs")
                        local is_enabled=false
                        for enabled_code in "${INSTALL_ORDER[@]}"; do
                            if [[ "$enabled_code" == "$code_item" ]]; then
                                is_enabled=true
                                break
                            fi
                        done
                        
                        if [[ "$is_enabled" == false ]]; then
                            log_error "服务未启用: $code_item"
                            exit_code=1
                        else
                            # 执行单个服务
                            if check "$code_item"; then
                                local script_path="$(get "$code_item")"
                                export SCRIPT_DIR="${SCRIPT_DIR}"
                                export LIB_DIR="${LIB_DIR}"
                                bash "$script_path" "$command" "${@:3}"
                                exit_code=$?
                            else
                                exit_code=1
                            fi
                        fi
                        ;;
                    *)
                        # 查看类命令，直接执行
                        if check "$code_item"; then
                            local script_path="$(get "$code_item")"
                            export SCRIPT_DIR="${SCRIPT_DIR}"
                            export LIB_DIR="${LIB_DIR}"
                            bash "$script_path" "$command" "${@:3}"
                            exit_code=$?
                        else
                            exit_code=1
                        fi
                        ;;
                esac
            fi
            
            set -e
            
            if [[ $exit_code -eq 0 ]]; then
                success_count=$((success_count + 1))
                log_info "$code_item 的 $command 操作成功"
            else
                log_error "$code_item 的 $command 操作失败"
            fi
            log_info "----------------------------------------"
        done
        log_info "批量操作完成: $success_count/$total_count 成功"
        return 0
    fi
    
    # 执行单个服务
    if [[ ! -v REGISTERED_SCRIPTS[$code] ]]; then
        log_error "未注册的脚本代码: $code"
        log_info "可用的脚本代码: $(list)"
        return 1
    fi
    
    # 检查服务是否在启用列表中（操作类命令需要检查）
    case "$command" in
        "pull"|"install"|"uninstall"|"down"|"up"|"rmi"|"logs")
            local is_enabled=false
            for enabled_code in "${INSTALL_ORDER[@]}"; do
                if [[ "$enabled_code" == "$code" ]]; then
                    is_enabled=true
                    break
                fi
            done
            
            if [[ "$is_enabled" == false ]]; then
                log_error "服务未启用: $code"
                log_info "启用的服务代码: $(list)"
                return 1
            fi
            ;;
    esac
    
    if ! check "$code"; then
        return 1
    fi
    
    local script_path="$(get "$code")"
    log_info "执行 $code 的 $command 操作..."
    
    # 导出路径供子脚本使用
    export SCRIPT_DIR="${SCRIPT_DIR}"
    export LIB_DIR="${LIB_DIR}"
    
    # 传递额外参数给子脚本
    local script_args=("$@")
    
    # 执行子脚本时禁用 set -e，防止子脚本的失败影响主脚本
    set +e
    bash "$script_path" "$command" "${script_args[@]:3}"
    local exit_code=$?
    set -e
    
    return $exit_code
}



# 显示帮助信息
help() {
    cat << EOF
Docker Compose 部署脚本

用法: $0 <命令> [服务代码]

命令:
  list                 查询所有注册的脚本
  get [<code>]         定位脚本路径 (显示所有或指定脚本的绝对路径)
  config [<code>]      显示配置信息
  yml [<code>]         查看docker-compose.yml (显示所有或指定服务)
  pull [<code>]        拉取Docker镜像 (需要确认)
  install [<code>]     安装服务 (需要确认)
  uninstall [<code>]   卸载服务 (需要确认)
  down [<code>]        停止服务 (需要确认)
  up [<code>]          启动服务 (需要确认)
  rmi [<code>]         删除镜像 (需要确认)
  logs <code>          查看服务日志 (必须指定服务代码)
  info [<code>]        显示服务信息
  help                 显示此帮助信息

可用的服务代码 (按推荐执行顺序):
$(for code in $(list); do echo "  $code"; done)

示例:
  $0 install jenkins    # 安装Jenkins服务
  $0 install           # 安装所有服务 (需要确认)
  $0 yml jenkins       # 查看Jenkins的docker-compose.yml
  $0 yml               # 查看所有服务的docker-compose.yml
  $0 logs jenkins      # 查看Jenkins服务日志
  $0 info              # 显示所有服务信息

EOF
}

# 主函数
main() {
    if [[ $# -eq 0 ]]; then
        help
        exit 1
    fi
    
    local command="$1"
    local code="${2:-}"
    
    case "$command" in
        "list")
            log_info "注册的脚本列表:"
            for reg_code in "${!REGISTERED_SCRIPTS[@]}"; do
                # 检查文件是否存在
                script_path="$(get "$reg_code")"
                file_status="存在"
                if [[ ! -f "$script_path" ]]; then
                    file_status="不存在"
                fi
                
                # 检查是否在安装顺序中
                install_status="禁用"
                for install_code in "${INSTALL_ORDER[@]}"; do
                    if [[ "$install_code" == "$reg_code" ]]; then
                        install_status="启用"
                        break
                    fi
                done
                
                log_info "  $reg_code -> ${REGISTERED_SCRIPTS[$reg_code]} [$file_status] [$install_status]"
            done
            ;;
        "get")
            if [[ -n "$code" ]]; then
                if [[ ! -v REGISTERED_SCRIPTS[$code] ]]; then
                    log_error "未注册的脚本代码: $code"
                    log_info "可用的脚本代码: $(list)"
                    exit 1
                fi
                script_path="$(get "$code")"
                log_info "$code -> $script_path"
                
                # 检查文件是否存在
                file_status="存在"
                if [[ ! -f "$script_path" ]]; then
                    file_status="不存在"
                fi
                
                # 检查是否在安装顺序中
                install_status="禁用"
                for install_code in "${INSTALL_ORDER[@]}"; do
                    if [[ "$install_code" == "$code" ]]; then
                        install_status="启用"
                        break
                    fi
                done
                
                log_info "文件状态: $file_status"
                log_info "安装状态: $install_status"
            else
                log_info "所有脚本的绝对路径:"
                for reg_code in "${!REGISTERED_SCRIPTS[@]}"; do
                    script_path="$(get "$reg_code")"
                    
                    # 检查文件是否存在
                    file_status="存在"
                    if [[ ! -f "$script_path" ]]; then
                        file_status="不存在"
                    fi
                    
                    # 检查是否在安装顺序中
                    install_status="禁用"
                    for install_code in "${INSTALL_ORDER[@]}"; do
                        if [[ "$install_code" == "$reg_code" ]]; then
                            install_status="启用"
                            break
                        fi
                    done
                    
                    log_info "  $reg_code -> $script_path [$file_status] [$install_status]"
                done
            fi
            ;;
        "config")
            execute "config" "$code" "${@:3}"
            ;;
        "yml")
            execute "yml" "$code" "${@:3}"
            ;;
        "pull")
            execute "pull" "$code" "${@:3}"
            ;;
        "install")
            execute "install" "$code" "${@:3}"
            ;;
        "uninstall")
            execute "uninstall" "$code" "${@:3}"
            ;;
        "down")
            execute "down" "$code" "${@:3}"
            ;;
        "up")
            execute "up" "$code" "${@:3}"
            ;;
        "rmi")
            execute "rmi" "$code" "${@:3}"
            ;;
        "logs")
            if [[ -z "$code" ]]; then
                log_error "logs 命令必须指定服务代码"
                log_info "可用的服务代码: $(list)"
                exit 1
            fi
            execute "logs" "$code" "${@:3}"
            ;;
        "info")
            execute "info" "$code" "${@:3}"
            ;;
        "help"|"-h"|"--help")
            help
            ;;
        *)
            log_error "未知命令: $command"
            help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
