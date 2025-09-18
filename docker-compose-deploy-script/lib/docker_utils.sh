#!/bin/bash

# Docker 工具库
# 版本: 1.0
# 描述: 提供Docker相关的通用功能

# 加载日志库
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "${SCRIPT_DIR}/lib/logger.sh"

# 检查Docker和Docker Compose是否安装
check_docker() {
    log_debug "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装或不在PATH中"
        return 1
    fi
    
    if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null; then
        log_error "Docker Compose 未安装或不在PATH中"
        return 1
    fi
    
    log_debug "Docker环境检查通过"
    return 0
}

# 检查并拉取镜像
check_and_pull_image() {
    local image="$1"
    
    log_debug "检查镜像: $image"
    
    if docker image inspect "$image" &> /dev/null; then
        log_info "镜像已存在: $image"
        return 0
    fi
    
    log_info "正在拉取镜像: $image"
    if docker pull "$image"; then
        log_info "镜像拉取成功: $image"
        return 0
    else
        log_error "镜像拉取失败: $image"
        return 1
    fi
}

# 获取容器状态
get_container_status() {
    local container_name="$1"
    local docker_output=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" 2>/dev/null)
    local docker_exit_code=$?
    if [[ $docker_exit_code -ne 0 ]]; then
        set -e
        echo "docker_error"
        return 0
    fi
    # 直接获取容器状态，不依赖table格式的输出
    local status=$(docker ps -a --format "{{.Status}}" --filter "name=${container_name}" 2>/dev/null)
    if [[ -n "$status" ]]; then
        # 容器存在，检查状态
        if [[ "$status" =~ ^Up ]]; then
            echo "running"
        elif [[ "$status" =~ ^Exited ]]; then
            echo "stopped"
        else
            echo "unknown"
        fi
    else
        echo "not_installed"
    fi
}

# 获取状态显示文本（带颜色）
get_status_display() {
    local status="$1"
    case "$status" in
        "running") echo -e "${GREEN}运行中${NC}" ;;
        "stopped") echo -e "${YELLOW}已停止${NC}" ;;
        "not_installed") echo -e "${GRAY}未安装${NC}" ;;
        "docker_error") echo -e "${RED}Docker服务异常${NC}" ;;
        *) echo -e "${RED}状态异常${NC}" ;;
    esac
}

# 检查镜像是否存在
check_image_exists() {
    local image="$1"
    docker image inspect "$image" &> /dev/null
}

# 检查容器是否运行
is_container_running() {
    local container_name="$1"
    docker ps -q --filter "name=${container_name}" | grep -q .
}

# 停止并删除容器
stop_and_remove_container() {
    local container_name="$1"
    
    if docker ps -q --filter "name=${container_name}" | grep -q .; then
        log_info "停止容器: $container_name"
        docker stop "$container_name"
    fi
    
    if docker ps -aq --filter "name=${container_name}" | grep -q .; then
        log_info "删除容器: $container_name"
        docker rm "$container_name"
    fi
}

# 删除镜像（包括依赖检查）
remove_image_safe() {
    local image="$1"
    
    if ! check_image_exists "$image"; then
        log_warn "镜像不存在: $image"
        return 0
    fi
    
    # 检查是否有容器在使用该镜像
    local containers=$(docker ps -aq --filter "ancestor=${image}")
    if [[ -n "$containers" ]]; then
        log_warn "发现使用该镜像的容器，正在停止和删除..."
        echo "$containers" | xargs docker stop 2>/dev/null || true
        echo "$containers" | xargs docker rm 2>/dev/null || true
    fi
    
    if docker rmi "$image"; then
        log_info "镜像删除成功: $image"
        return 0
    else
        log_error "镜像删除失败: $image"
        return 1
    fi
}

# 执行docker-compose命令
execute_compose() {
    local action="$1"
    local compose_dir="$2"
    local compose_file="${compose_dir}/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        log_error "docker-compose.yml 文件不存在: $compose_file"
        return 1
    fi
    
    cd "$compose_dir"
    
    # 优先使用新版 docker compose，如果失败则尝试旧版 docker-compose
    if docker compose version &> /dev/null; then
        log_debug "使用 docker compose 命令"
        if docker compose $action; then
            log_info "Docker Compose $action 执行成功"
            return 0
        else
            log_error "Docker Compose $action 执行失败"
            return 1
        fi
    elif docker-compose version &> /dev/null; then
        log_debug "使用 docker-compose 命令"
        if docker-compose $action; then
            log_info "Docker Compose $action 执行成功"
            return 0
        else
            log_error "Docker Compose $action 执行失败"
            return 1
        fi
    else
        log_error "Docker Compose 未安装或不可用"
        return 1
    fi
}

# 显示容器信息表格
show_container_info() {
    local container_name="$1"
    
    if is_container_running "$container_name"; then
        log_info "容器运行信息:"
        docker ps --filter "name=${container_name}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        log_info "容器未运行"
    fi
}