#!/bin/bash

# Nginx 部署脚本 - 子脚本
# 版本: 2.0
# 描述: Nginx Web服务器部署脚本

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
base_image_name="nginx:latest"
base_container_name="nginx"
base_install_path="/opt/server/nginx"
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

# 创建配置文件
create_config_files() {
    local config_dir="${base_install_path}/conf"
    local conf_d_dir="${config_dir}/conf.d"
    
    create_directory "$config_dir"
    create_directory "$conf_d_dir"
    create_directory "${base_install_path}/html"
    
    # 创建主配置文件
    cat > "${config_dir}/nginx.conf" << 'EOF'
# 启动 8 个工作进程，通常为 CPU 核心数的倍数，能够提高并发处理能力。
worker_processes  8;

events {
    # 每个工作进程最多处理 102400 个连接，设置更高的值有助于提升并发性能。
    worker_connections  102400;
    
    # 启用多连接接受模式，每次工作进程可以接受多个连接，提升性能。
    multi_accept on;
}

http {
    # 引入 mime.types 文件，它包含文件扩展名与 MIME 类型的映射。
    include       mime.types;

    # 默认文件类型为 `application/octet-stream`，用于无法识别的文件类型。
    default_type  application/octet-stream;

    # 定义日志格式，记录请求的详细信息
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    '$status $body_bytes_sent "$http_referer" '
    '"$http_user_agent" "$http_x_forwarded_for"';

    # 启用 `sendfile` 系统调用来高效地发送文件
    sendfile     on;

    # 启用 TCP_NOPUSH，配合 sendfile 可以减少系统调用次数，提高文件传输性能。
    tcp_nopush     on;

    # 设置 HTTP Keep-Alive 超时时间为 1800 秒，减少新连接的开销。
    keepalive_timeout  1800s;

    # 设置最大可保持的请求次数为 2000，超过后关闭连接。
    keepalive_requests 2000;

    # 设置字符编码为 utf-8。
    charset utf-8;

    # 配置 server_names_hash 的桶大小，避免服务器名称冲突。
    server_names_hash_bucket_size 128;

    # 设置客户端请求头缓冲区大小，较大的头部可能需要增大该值。
    client_header_buffer_size 2k;

    # 设置最大客户端请求头的缓冲区，默认 4KB，增加此值来支持更大的请求头。
    large_client_header_buffers 4 4k;

    # 设置允许客户端上传的最大请求体大小，默认 1MB，设置为 1024MB。
    client_max_body_size  1024m;

    # 启用文件打开缓存，提高文件访问速度。
    open_file_cache max=102400 inactive=20s;

    # 启用 gzip 压缩，压缩传输内容以节省带宽。
    gzip  on;

    # 设置最小压缩文件大小为 1KB，小于该值的文件不进行压缩。
    gzip_min_length 1k;

    # 设置 gzip 使用的缓冲区大小。
    gzip_buffers 4 16k;

    # 启用 gzip 压缩，并且指定支持的最低 HTTP 协议版本。
    gzip_http_version 1.0;

    # 设置 gzip 压缩级别为 2，压缩和性能之间的平衡。
    gzip_comp_level 2;

    # 指定 gzip 压缩的 MIME 类型。
    gzip_types text/plain application/x-javascript text/css application/xml;

    # 启用 gzip 变体缓存，对于不同的用户代理发送不同的内容。
    gzip_vary on;

    # 设置代理连接超时时间为 75 秒。
    proxy_connect_timeout 75s;

    # 设置代理发送数据的超时时间为 75 秒。
    proxy_send_timeout 75s;

    # 设置代理接收数据的超时时间为 75 秒。
    proxy_read_timeout 75s;

    # 设置 FastCGI 连接的超时时间为 75 秒。
    fastcgi_connect_timeout 75s;

    # 设置 FastCGI 发送数据的超时时间为 75 秒。
    fastcgi_send_timeout 75s;

    # 设置 FastCGI 接收数据的超时时间为 75 秒。
    fastcgi_read_timeout 75s;

    # 引入所有位于 /etc/nginx/conf.d/ 目录下的配置文件。
    include /etc/nginx/conf.d/*.conf;
}
EOF

    # 创建示例配置文件
    cat > "${conf_d_dir}/demo.conf" << 'EOF'
server {
    listen               80;
    server_name          demo.server;
    # server_name          www.server.com;
    add_header Access-Control-Allow-Methods 'GET,POST,OPTIONS';
    add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,token';

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
}
EOF

    # 创建默认首页
    cat > "${base_install_path}/html/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to nginx!</title>
    <style>
        body {
            width: 35em;
            margin: 0 auto;
            font-family: Tahoma, Verdana, Arial, sans-serif;
        }
    </style>
</head>
<body>
    <h1>Welcome to nginx!</h1>
    <p>If you see this page, the nginx web server is successfully installed and
    working. Further configuration is required.</p>

    <p>For online documentation and support please refer to
    <a href="http://nginx.org/">nginx.org</a>.<br/>
    Commercial support is available at
    <a href="http://nginx.com/">nginx.com</a>.</p>

    <p><em>Thank you for using nginx.</em></p>
</body>
</html>
EOF

    log_info "Nginx 配置文件创建完成"
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
    
    # 检查并拉取镜像
    if ! check_and_pull_image "$base_image_name"; then
        return 1
    fi
    
    # 创建目录结构
    if [[ ! -d "${base_install_path}" ]]; then
        log_info "创建 $base_container_name 目录结构..."
        create_directory "${base_install_path}/logs"
    fi
    
    # 创建配置文件
    create_config_files
    
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
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ${base_install_path}/conf/nginx.conf:/etc/nginx/nginx.conf
      - ${base_install_path}/conf/conf.d:/etc/nginx/conf.d
      - ${base_install_path}/logs:/var/log/nginx
      - ${base_install_path}/html:/usr/share/nginx/html
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
        log_info "  ├─ HTTP访问: http://${base_ip}/"
        log_info "  ├─ HTTPS访问: https://${base_ip}/ (需要配置SSL证书)"
        log_info "  ├─ 配置目录: ${base_install_path}/conf/"
        log_info "  ├─ 网站目录: ${base_install_path}/html/"
        log_info "  └─ 容器名称: $base_container_name"
    fi
}

# 显示帮助信息
help() {
    cat << EOF
Nginx Web服务器部署脚本

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
  $0 install   # 安装Nginx服务
  $0 yml       # 查看docker-compose.yml配置
  $0 logs      # 查看Nginx服务日志
  $0 info      # 显示Nginx服务信息

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