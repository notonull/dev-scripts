#!/bin/bash

# 日志工具库
# 版本: 1.0
# 描述: 提供统一的彩色日志输出功能

# 日志颜色定义
if [[ -z "${RED:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    GRAY='\033[0;37m'
    NC='\033[0m' # No Color
fi

# 获取当前时间戳
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 信息日志 - 绿色
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(get_timestamp) - $1"
}

# 警告日志 - 黄色  
log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(get_timestamp) - $1"
}

# 错误日志 - 红色
log_error() {
    echo -e "${RED}[ERROR]${NC} $(get_timestamp) - $1"
}


# 调试日志 - 紫色
log_debug() {
    # 临时启用debug以诊断路径问题
    echo -e "${PURPLE}[DEBUG]${NC} $(get_timestamp) - $1"
}

# 分隔线
log_separator() {
    log_info "=========================================="
}

# 小分隔线
log_line() {
    log_info "----------------------------------------"
}

# 标题日志
log_title() {
    log_separator
    echo -e "${GREEN}[INFO]${NC} $(get_timestamp) - ${WHITE}$1${NC}"
    log_separator
}

# 子标题日志
log_subtitle() {
    echo -e "${GREEN}[INFO]${NC} $(get_timestamp) - ${CYAN}$1${NC}"
    log_line
}