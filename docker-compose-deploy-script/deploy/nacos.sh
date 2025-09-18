#!/bin/bash

# Nacos 部署脚本 - 子脚本
# 版本: 2.0
# 描述: Nacos 注册中心服务部署脚本

set -euo pipefail

# 脚本目录 - 使用主脚本传递的路径或自动检测
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
LIB_DIR="${LIB_DIR:-${SCRIPT_DIR}/lib}"

# 加载公共库
source "${LIB_DIR}/logger.sh"
source "${LIB_DIR}/docker_utils.sh"
source "${LIB_DIR}/system_utils.sh"
source "${LIB_DIR}/config_utils.sh"

# ============================================
# 服务配置定义
# ============================================

# 基础配置 (统一前缀: base_)
base_image_name="nacos/nacos-server:latest"
base_container_name="nacos"
base_install_path="/opt/server/nacos"
base_ip=$(get_local_ip)


# ============================================
# 命令实现
# ============================================

# 配置信息显示
config() {
    log_info "基础配置:"
    log_info "  ├─ 镜像名称: $base_image_name"
    log_info "  ├─ 容器名称: $base_container_name"
    log_info "  ├─ 安装路径: $base_install_path"
    log_info "  ├─ 服务器IP: $base_ip"
    log_info "  └─ yml路径: ${base_install_path}/docker-compose.yml"
}

# 拉取镜像
pull() {
    log_info "开始拉取 $base_container_name 镜像..."
    
    if ! check_docker; then
        return 1
    fi
    
    check_and_pull_image "$base_image_name"
}

# 安装之后操作
install_after() {
    log_info "无后续操作"
}

# 安装服务
install() {
    log_info "开始安装 $base_container_name 服务..."
    
    if ! check_docker; then
        return 1
    fi
    
    # 检查MySQL依赖
    if ! docker ps | grep -q "mysql.*Up"; then
        log_warn "未检测到运行中的MySQL容器，Nacos需要MySQL数据库支持"
        if ! confirm_action "是否继续安装Nacos"; then
            log_info "安装已取消"
            return 0
        fi
    fi
    
    # 检查并拉取镜像
    if ! check_and_pull_image "$base_image_name"; then
        return 1
    fi
    
    # 创建目录结构
    if [[ ! -d "${base_install_path}" ]]; then
        log_info "创建 $base_container_name 目录结构..."
        create_directory "${base_install_path}/data"
        create_directory "${base_install_path}/logs"
    fi
    
    # 创建yml文件
    local compose_file="${base_install_path}/docker-compose.yml"
    yml > "$compose_file"
    log_info "docker-compose.yml 文件生成完成"
    
    # 安装
    if execute_compose "up -d" "$base_install_path"; then
        log_info "$base_container_name 服务安装完成"
        
        # 安装后续
        install_after
        
        # 打印信息
        info
        return 0
    else
        log_error "$base_container_name 服务部署失败"
        return 1
    fi
}

# 卸载服务
uninstall() {
    log_info "开始卸载 $base_container_name 服务..."
    
    # 先执行 down 操作
    down
    
    # 再执行 rmi 操作
    rmi
    
    # 询问是否删除数据目录
    if confirm_action "是否删除 $base_container_name 数据目录 ${base_install_path}"; then
        safe_remove_directory "$base_install_path" true
    else
        log_info "保留 $base_container_name 数据目录"
    fi
    
    log_info "$base_container_name 服务卸载完成"
}

# 停止服务
down() {
    if [[ ! -d "$base_install_path" ]]; then
        log_warn "$base_container_name 安装目录不存在: $base_install_path"
        return 0
    fi
    
    execute_compose "down" "$base_install_path"
}

# 启动服务
up() {
    if [[ ! -d "$base_install_path" ]]; then
        log_error "$base_container_name 未安装，请先执行 install 命令"
        return 1
    fi
    
    execute_compose "up -d" "$base_install_path"
}

# 删除镜像
rmi() {
    remove_image_safe "$base_image_name"
}

# 查看日志
logs() {
    docker logs -f "$base_container_name"
}

# 生成docker-compose.yml
yml() {
    cat << EOF
version: "3.9"

services:
  ${base_container_name}:
    image: ${base_image_name}
    container_name: ${base_container_name}
    environment:
      - MODE=standalone
      - SPRING_DATASOURCE_PLATFORM=mysql
      - MYSQL_SERVICE_HOST=${base_ip}
      - MYSQL_SERVICE_DB_NAME=nacos
      - MYSQL_SERVICE_PORT=3306
      - MYSQL_SERVICE_USER=root
      - MYSQL_SERVICE_PASSWORD=123456
      - MYSQL_SERVICE_DB_PARAM=characterEncoding=utf8&connectTimeout=1000&socketTimeout=3000&autoReconnect=true&useUnicode=true&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true
      - NACOS_AUTH_TOKEN=WDdrUHFYOXZWMnJZOFRXOEZuTDZOQXhQd0I1Y0gxZFEyeEE5ZVI0dU04aUs3b1AzdyN2TjJsVjBqRzVmVA==
      - NACOS_AUTH_IDENTITY_KEY=nacos
      - NACOS_AUTH_IDENTITY_VALUE=nacos
    ports:
      - "9080:8080"
      - "8848:8848"
      - "9848:9848"
    volumes:
      - ${base_install_path}/data:/home/nacos/nacos-data
      - ${base_install_path}/logs:/home/nacos/logs
    restart: unless-stopped
EOF
}

# 显示信息
info() {
    # 打印配置
    config
    
    # 打印状态
    local status=$(get_container_status "$base_container_name")
    local status_display=$(get_status_display "$status")
    log_info "服务状态: $status_display"
    
    # 打印当前业务信息 如果启动成功的话 比如访问方式等
    if [[ "$status" == "running" ]]; then
        log_info "运行时信息:"
        log_info "  ├─ 控制台: http://${base_ip}:9080/nacos/"
        log_info "  ├─ 服务端口: ${base_ip}:8848"
        log_info "  ├─ 用户名: nacos"
        log_info "  ├─ 密码: nacos"
        log_info "  └─ 容器名称: $base_container_name"
    fi
}

# 显示帮助信息
help() {
    cat << EOF
Nacos 注册中心服务部署脚本

用法: $0 <命令>

命令:
  config       显示配置信息
  yml          查看docker-compose.yml文件
  pull         拉取Docker镜像
  install      安装服务
  uninstall    卸载服务
  down         停止服务
  up           启动服务
  rmi          删除镜像
  logs         查看服务日志
  info         显示服务信息
  help         显示此帮助信息

示例:
  $0 install   # 安装Nacos服务
  $0 yml       # 查看docker-compose.yml配置
  $0 logs      # 查看Nacos服务日志
  $0 info      # 显示Nacos服务信息

注意:
  Nacos依赖MySQL数据库，请先安装MySQL服务并创建nacos数据库

EOF
}

# 主函数
main() {
    if [[ $# -eq 0 ]]; then
        help
        exit 1
    fi
    
    local command="$1"
    
    case "$command" in
        "config")
            config
            ;;
        "yml")
            yml
            ;;
        "pull")
            pull
            ;;
        "install")
            install
            ;;
        "uninstall")
            uninstall
            ;;
        "down")
            down
            ;;
        "up")
            up
            ;;
        "rmi")
            rmi
            ;;
        "logs")
            logs
            ;;
        "info")
            info
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