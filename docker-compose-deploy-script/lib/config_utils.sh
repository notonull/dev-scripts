#!/bin/bash

# 配置工具库
# 版本: 1.0
# 描述: 提供配置文件生成和管理功能

# 加载日志库
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "${SCRIPT_DIR}/lib/logger.sh"

# 生成 docker-compose.yml 文件
generate_docker_compose() {
    local service_name="$1"
    local image_name="$2"
    local container_name="$3"
    local install_path="$4"
    local ports_array_name="$5"
    local volumes_array_name="$6"
    local environment_array_name="$7"
    local extra_config="${8:-}"
    
    local compose_file="${install_path}/docker-compose.yml"
    
    log_info "生成 docker-compose.yml 文件: $compose_file"
    
    # 创建基础结构
    cat > "$compose_file" << EOF
version: "3.9"

services:
  ${service_name}:
    image: ${image_name}
    container_name: ${container_name}
EOF

    # 添加额外配置（如privileged等）
    if [[ -n "$extra_config" ]]; then
        echo "$extra_config" >> "$compose_file"
    fi

    # 添加端口映射
    local -n ports_ref=$ports_array_name
    if [[ ${#ports_ref[@]} -gt 0 ]]; then
        echo "    ports:" >> "$compose_file"
        for port in "${ports_ref[@]}"; do
            echo "      - \"$port\"" >> "$compose_file"
        done
    fi
    
    # 添加环境变量
    local -n env_ref=$environment_array_name
    if [[ ${#env_ref[@]} -gt 0 ]]; then
        echo "    environment:" >> "$compose_file"
        for env_var in "${env_ref[@]}"; do
            echo "      $env_var" >> "$compose_file"
        done
    fi
    
    # 添加卷挂载
    local -n volumes_ref=$volumes_array_name
    if [[ ${#volumes_ref[@]} -gt 0 ]]; then
        echo "    volumes:" >> "$compose_file"
        for volume in "${volumes_ref[@]}"; do
            echo "      - $volume" >> "$compose_file"
        done
    fi
    
    # 添加重启策略
    echo "    restart: unless-stopped" >> "$compose_file"
    
    log_info "docker-compose.yml 文件生成完成"
}

# 验证配置数组
validate_config_arrays() {
    local service_name="$1"
    local ports_array_name="$2"
    local volumes_array_name="$3"
    local environment_array_name="$4"
    
    log_debug "验证 $service_name 配置数组..."
    
    # 验证端口配置
    local -n ports_ref=$ports_array_name
    for port in "${ports_ref[@]}"; do
        if [[ ! "$port" =~ ^[0-9]+:[0-9]+$ ]]; then
            log_error "无效的端口映射格式: $port (应为 宿主机端口:容器端口)"
            return 1
        fi
    done
    
    # 验证卷挂载配置
    local -n volumes_ref=$volumes_array_name
    for volume in "${volumes_ref[@]}"; do
        if [[ ! "$volume" =~ ^.+:.+$ ]]; then
            log_error "无效的卷挂载格式: $volume (应为 宿主机路径:容器路径)"
            return 1
        fi
    done
    
    # 验证环境变量配置
    local -n env_ref=$environment_array_name
    for env_var in "${env_ref[@]}"; do
        if [[ ! "$env_var" =~ ^[A-Za-z_][A-Za-z0-9_]*=.* ]]; then
            log_error "无效的环境变量格式: $env_var (应为 变量名=值)"
            return 1
        fi
    done
    
    log_debug "$service_name 配置验证通过"
    return 0
}

# 显示配置摘要
show_config_summary() {
    local service_name="$1"
    local image_name="$2"
    local container_name="$3"
    local install_path="$4"
    local server_ip="$5"
    local ports_array_name="$6"
    local volumes_array_name="$7"
    local environment_array_name="$8"
    
    log_info "配置摘要 - $service_name:"
    log_info "  镜像: $image_name"
    log_info "  容器: $container_name"
    log_info "  路径: $install_path"
    log_info "  IP: $server_ip"
    
    local -n ports_ref=$ports_array_name
    log_info "  端口: ${#ports_ref[@]} 个"
    
    local -n volumes_ref=$volumes_array_name
    log_info "  卷: ${#volumes_ref[@]} 个"
    
    local -n env_ref=$environment_array_name
    log_info "  环境变量: ${#env_ref[@]} 个"
}