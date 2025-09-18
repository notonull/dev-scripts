#!/bin/bash

# 系统工具库
# 版本: 1.0
# 描述: 提供系统相关的通用功能

# 获取本地IP地址
get_local_ip() {
    # 优先获取内网IP
    local ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    if [[ -z "$ip" ]]; then
        # 备用方案：通过hostname获取
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [[ -z "$ip" ]]; then
        # 最后备用方案
        ip="127.0.0.1"
    fi
    echo "$ip"
}

# 确保目录存在
ensure_directory() {
    local dir_path="$1"
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path"
    fi
}

# 创建目录
create_directory() {
    local dir_path="$1"
    ensure_directory "$dir_path"
}

# 检查文件是否可读
check_file_readable() {
    local file_path="$1"
    [[ -f "$file_path" && -r "$file_path" ]]
}

# 确认操作
confirm_action() {
    local message="$1"
    echo -n "$message (y/N): "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# 安全删除目录
safe_remove_directory() {
    local dir_path="$1"
    local force="${2:-false}"
    
    if [[ -d "$dir_path" ]]; then
        if [[ "$force" == "true" ]] || confirm_action "确认删除目录 $dir_path"; then
            rm -rf "$dir_path"
            return 0
        fi
    fi
    return 1
}

# 等待服务启动
wait_for_service() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    
    local count=0
    while [[ $count -lt $timeout ]]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            return 0
        fi
        sleep 1
        ((count++))
    done
    return 1
}