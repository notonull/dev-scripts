#!/bin/bash
## 作者: aGeng
## 更新日期: 2025-09-15
## 版本: 1.4.0

version="1.4.0"
DEFAULT_ENV="dev"
DEFAULT_APP_LOG="./app-log"
DEFAULT_JVM_LOG="./jvm-log"
DEFAULT_APP_PORT=""  # 默认应用端口，如果设置则会覆盖其他端口配置
DEFAULT_APP_DEBUG_PORT=""  # 默认调试端口
source /etc/profile

cmd=$1        # 第一个参数：命令，如 start, stop, debug, print
env=$2        # 第二个参数：环境，如 dev 或 prod
appName=$3    # 第三个参数：应用名，可选

# 如果没有指定应用名，自动选择最新的 .jar 文件
if [ -z "$appName" ]; then
    appName=$(ls -t *.jar 2>/dev/null | head -n1)
    if [ -n "$appName" ]; then
        echo "自动选择JAR文件: $appName"
    else
        echo "错误: 当前目录没有找到JAR文件"
        exit 1
    fi
fi

# ----------------- 日志打印公共方法 -----------------
function log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

function log_warn() {
    echo -e "\033[33m[WARN]\033[0m $1"
}

function log_debug() {
    echo -e "\033[36m[DEBUG]\033[0m $1"
}

function log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

# 公共命令执行方法
function execute_cmd() {
    local cmd="$1"
    log_debug "执行: $cmd"
    eval "$cmd"
}

# 获取应用 PID
function getAppPid() {
    if [ -n "$DEFAULT_APP_PORT" ]; then
        # 有默认端口：先通过JAR名查找，再验证端口参数
        log_debug "查找运行 $appName 的进程..."
        local psCmd="ps -ef | grep java | grep '$appName' | grep -v grep"
        log_debug "执行: $psCmd"
        local psResult=$(eval "$psCmd")

        if [ -n "$psResult" ]; then
            # 检查进程是否包含指定端口参数
            while IFS= read -r line; do
                local pid=$(echo "$line" | awk '{print $2}')
                local cmdline=$(ps -p "$pid" -o args= 2>/dev/null)
                # 检查命令行是否包含指定端口参数
                if echo "$cmdline" | grep -q "\-Dserver\.port=$DEFAULT_APP_PORT"; then
                    appId="$pid"
                    return
                fi
            done <<< "$psResult"

            # 如果没找到端口参数匹配的，也检查是否有监听指定端口的
            while IFS= read -r line; do
                local pid=$(echo "$line" | awk '{print $2}')
                if netstat -tlnp 2>/dev/null | grep -q ":${DEFAULT_APP_PORT}.*${pid}/java" || \
                   ss -tlnp 2>/dev/null | grep -q ":${DEFAULT_APP_PORT}.*pid=${pid}"; then
                    appId="$pid"
                    return
                fi
            done <<< "$psResult"
        fi
    else
        # 没有默认端口：通过应用名查找进程（原始逻辑）
        local psCmd="ps -ef | grep java | grep '$appName' | grep -v grep"
        log_debug "执行: $psCmd"
        local psResult=$(eval "$psCmd")
        if [ -n "$psResult" ]; then
            appId=$(echo "$psResult" | awk '{print $2}')
        fi
    fi
}

# ----------------- 显示帮助 -----------------
function help() {
    log_info "应用启动管理脚本 v$version"
    log_info "命令: $0 {start|debug|stop|restart|status|log|print|info|help} [env] [appName]"
    log_info "start [env]  - 启动应用"
    log_info "debug        - 调试模式"
    log_info "stop         - 停止应用"
    log_info "restart [env]- 重启应用"
    log_info "status       - 查看状态"
    log_info "log          - 查看日志"
    log_info "print [env]  - 打印命令"
    log_info "info         - 显示应用信息"
    log_info "help         - 显示帮助信息"
    exit 0
}

# ----------------- 显示应用信息 -----------------
function info() {
    log_info "应用名称: $appName"
    if [ -z "$env" ]; then env=$DEFAULT_ENV; fi
    log_info "运行环境: $env"
    if [ -n "$DEFAULT_APP_PORT" ]; then
        log_info "配置端口: $DEFAULT_APP_PORT"
    fi
    log_info "调试端口: $DEFAULT_APP_DEBUG_PORT"

    # 显示启动命令
    local buildCmd=$(buildStartCmd)
    log_info "启动命令: $buildCmd"

    # 检查运行状态
    getAppPid
    if [ -z "$appId" ]; then
        log_info "运行状态: 未运行"
    else
        log_info "运行状态: 运行中 (PID: $appId)"
    fi
}

# ----------------- 构建启动命令 -----------------
function buildStartCmd() {
    if [ -z "$env" ]; then env=$DEFAULT_ENV; fi
    mkdir -p $DEFAULT_APP_LOG
    mkdir -p $DEFAULT_JVM_LOG

    # 构建端口参数（只有设置了 DEFAULT_APP_PORT 才添加）
    local portParam=""
    if [ -n "$DEFAULT_APP_PORT" ]; then
        portParam="-Dserver.port=$DEFAULT_APP_PORT"
    fi

    if [ "$env" == "dev" ]; then
        echo "nohup java -Xms1G -Xmx4G -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof $portParam -jar $appName > /dev/null 2>&1 &"
    elif [ "$env" == "prod" ]; then
        echo "nohup java -server -XX:+UnlockExperimentalVMOptions -Xms20G -Xmx20G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+ParallelRefProcEnabled -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -XX:+PrintGCApplicationConcurrentTime -Xloggc:$DEFAULT_JVM_LOG/gc-$(date +%Y%m%d_%H%M%S).log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=200M -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof $portParam -jar $appName > /dev/null 2>&1 &"
    else
        echo "nohup java -Xms1G -Xmx2G -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof $portParam -jar $appName > /dev/null 2>&1 &"
    fi
}

# ----------------- 构建调试命令 -----------------
function buildDebugCmd() {
    mkdir -p $DEFAULT_APP_LOG

    # 构建调试模式的端口参数（只有设置了 DEFAULT_APP_PORT 才添加）
    local portParam=""
    if [ -n "$DEFAULT_APP_PORT" ]; then
        portParam="-Dserver.port=$DEFAULT_APP_PORT"
    fi

    echo "nohup java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=$DEFAULT_APP_DEBUG_PORT -Xms1G -Xmx4G -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof $portParam -jar $appName > /dev/null 2>&1 &"
}

# ----------------- 启动应用 -----------------
function start() {
    getAppPid
    if [ -n "$appId" ]; then
        log_warn "应用已运行 (PID: $appId)"
        return
    fi
    local startCmd=$(buildStartCmd)
    execute_cmd "$startCmd"
    local startPid=$!
    log_info "启动成功 (PID: $startPid)"
}

# ----------------- 调试模式 -----------------
function debug() {
    getAppPid
    if [ -n "$appId" ]; then
        log_warn "应用已运行 (PID: $appId)"
        return
    fi
    local debugCmd=$(buildDebugCmd)
    execute_cmd "$debugCmd"
    local debugPid=$!
    log_info "调试启动成功 (PID: $debugPid, 调试端口: $DEFAULT_APP_DEBUG_PORT)"
}

# ----------------- 停止应用 -----------------
function stop() {
    getAppPid
    if [ -z "$appId" ]; then
        log_warn "应用未运行"
        return
    fi
    local killCmd="kill -9 $appId"
    execute_cmd "$killCmd"
    local killResult=$?
    if [ $killResult -eq 0 ]; then
        log_info "停止成功"
    else
        log_error "停止失败 (退出码: $killResult)"
    fi
}

# ----------------- 重启应用 -----------------
function restart() {
    stop
    start
}

# ----------------- 查看状态 -----------------
function status() {
    getAppPid
    if [ -z "$appId" ]; then
        log_warn "应用未运行"
    else
        if [ -n "$DEFAULT_APP_PORT" ]; then
            log_info "应用运行中 (PID: $appId, 端口: $DEFAULT_APP_PORT)"
            # 验证端口监听状态
            if netstat -tlnp 2>/dev/null | grep -q ":${DEFAULT_APP_PORT}.*${appId}/java" || \
               ss -tlnp 2>/dev/null | grep -q ":${DEFAULT_APP_PORT}.*pid=${appId}"; then
                log_info "端口监听正常"
            else
                log_warn "端口未监听"
            fi
        else
            log_info "应用运行中 (PID: $appId)"
        fi
    fi
}

# ----------------- 查看日志 -----------------
function log() {
    local tailCmd="tail -n 500 -f $DEFAULT_APP_LOG/log_total.log"
    execute_cmd "$tailCmd"
}

# ----------------- 打印启动命令 -----------------
function print() {
    local buildCmd=$(buildStartCmd)
    log_debug "启动命令: $buildCmd"
}

# ----------------- 命令解析 -----------------
case $cmd in
    start) start ;;
    debug) debug ;;
    stop) stop ;;
    restart) restart ;;
    status) status ;;
    log) log ;;
    print) print ;;
    info) info ;;
    help) help ;;
    *) help ;;
esac