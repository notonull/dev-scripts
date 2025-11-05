#!/bin/bash
## 作者: aGeng
## 更新日期: 2025-09-15
## 版本: 1.4.0

version="1.4.0"
DEFAULT_ENV="dev"
DEFAULT_APP_LOG="./app-log"
DEFAULT_JVM_LOG="./jvm-log"
DEFAULT_APP_PORT=""  # 默认应用端口，如果设置则会覆盖其他端口配置
DEFAULT_APP_DEBUG_PORT="58999"  # 默认调试端口

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

# 获取应用 PID
function getAppPid() {
    if [ -n "$DEFAULT_APP_PORT" ]; then
        # 有默认端口：先通过JAR名查找，再验证端口参数
        echo "查找运行 $appName 的进程..."
        echo "执行: ps -ef | grep java | grep \"$appName\" | grep -v grep"
        local psResult=$(ps -ef | grep java | grep "$appName" | grep -v grep)
        
        if [ -n "$psResult" ]; then
            echo "找到进程: $psResult"
            # 检查进程是否包含指定端口参数
            while IFS= read -r line; do
                local pid=$(echo "$line" | awk '{print $2}')
                local cmdline=$(ps -p "$pid" -o args= 2>/dev/null)
                # 检查命令行是否包含指定端口参数
                if echo "$cmdline" | grep -q "\-Dserver\.port=$DEFAULT_APP_PORT"; then
                    appId="$pid"
                    echo "找到匹配进程: PID=$pid (端口参数: $DEFAULT_APP_PORT)"
                    return
                fi
            done <<< "$psResult"
            
            # 如果没找到端口参数匹配的，也检查是否有监听指定端口的
            echo "检查是否有进程监听端口 $DEFAULT_APP_PORT..."
            while IFS= read -r line; do
                local pid=$(echo "$line" | awk '{print $2}')
                if netstat -tlnp 2>/dev/null | grep -q ":${DEFAULT_APP_PORT}.*${pid}/java" || \
                   ss -tlnp 2>/dev/null | grep -q ":${DEFAULT_APP_PORT}.*pid=${pid}"; then
                    appId="$pid"
                    echo "找到匹配进程: PID=$pid (监听端口: $DEFAULT_APP_PORT)"
                    return
                fi
            done <<< "$psResult"
        fi
        echo "未找到使用端口 $DEFAULT_APP_PORT 的 $appName 进程"
    else
        # 没有默认端口：通过应用名查找进程（原始逻辑）
        echo "查找命令: ps -ef | grep java | grep \"$appName\" | grep -v grep"
        local psResult=$(ps -ef | grep java | grep "$appName" | grep -v grep)
        if [ -n "$psResult" ]; then
            echo "找到进程: $psResult"
            appId=$(echo "$psResult" | awk '{print $2}')
        else
            echo "未找到 $appName 进程"
        fi
    fi
}

# ----------------- 显示信息 -----------------
function info() {
    echo "===================================================="
    echo "应用启动管理脚本"
    echo "作者: aGeng"
    echo "版本: $version"
    echo "更新日期: 2024-08-23"
    echo "===================================================="
    echo ""
    echo "命令格式：$0 {start|debug|stop|restart|status|log|print} [env] [appName]"
    echo ""
    echo "参数说明："
    echo " start [env] : 启动应用，默认环境: $DEFAULT_ENV"
    echo " debug : 启动调试模式，JDWP 调试端口 $DEFAULT_APP_DEBUG_PORT"
    echo " stop : 停止应用"
    echo " restart [env] : 重启应用，默认环境: $DEFAULT_ENV"
    echo " status : 查看应用状态及 PID"
    echo " log : 查看日志（tail -f $DEFAULT_APP_LOG/log_total.log）"
    echo " print [env] : 打印启动命令（不执行）"
    echo ""
    echo "🔧 DEFAULT_APP_PORT 变量说明："
    echo " - 如果设置了 DEFAULT_APP_PORT，会用该端口查找进程并在启动时添加端口参数"
    echo " - 如果未设置，则使用应用名查找进程，启动时不添加端口参数"
    echo " - 设置方式：DEFAULT_APP_PORT=\"8081\" ./app.sh start"
    echo ""
    echo "使用示例："
    echo " $0 start # 启动默认环境 ($DEFAULT_ENV)"
    echo " $0 start prod # 启动生产环境"
    echo " $0 debug # 调试模式"
    echo " $0 stop # 停止应用"
    echo " $0 restart # 重启默认环境 ($DEFAULT_ENV)"
    echo " $0 print dev # 打印开发环境启动命令"
    echo "===================================================="
    exit 0
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
        echo "java -Xms1G -Xmx4G -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof $portParam -jar $appName"
    elif [ "$env" == "prod" ]; then
        echo "java -server -XX:+UnlockExperimentalVMOptions -Xms20G -Xmx20G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+ParallelRefProcEnabled -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -XX:+PrintGCApplicationConcurrentTime -Xloggc:$DEFAULT_JVM_LOG/gc-$(date +%Y%m%d_%H%M%S).log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=200M -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof $portParam -jar $appName"
    else
        echo "java -Xms1G -Xmx2G -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof $portParam -jar $appName"
    fi
}

# ----------------- 启动应用 -----------------
function start() {
    getAppPid
    if [ -n "$appId" ]; then
        if [ -n "$DEFAULT_APP_PORT" ]; then
            echo "应用 $appName 已经运行 (PID: $appId, 端口: $DEFAULT_APP_PORT)，请检查。"
        else
            echo "应用 $appName 已经运行 (PID: $appId)，请检查。"
        fi
        return
    fi
    cmdStr=$(buildStartCmd)
    echo "启动命令: $cmdStr"
    echo "执行: nohup $cmdStr > /dev/null 2>&1 &"
    nohup $cmdStr > /dev/null 2>&1 &
    local startPid=$!
    echo "启动进程PID: $startPid"
    if [ -n "$DEFAULT_APP_PORT" ]; then
        echo "$env 环境启动完成，端口: $DEFAULT_APP_PORT"
    else
        echo "$env 环境启动完成"
    fi
}

# ----------------- 调试模式 -----------------
function debug() {
    getAppPid
    if [ -n "$appId" ]; then
        if [ -n "$DEFAULT_APP_PORT" ]; then
            echo "应用 $appName 已经运行 (PID: $appId, 端口: $DEFAULT_APP_PORT)，请检查。"
        else
            echo "应用 $appName 已经运行 (PID: $appId)，请检查。"
        fi
        return
    fi
    mkdir -p $DEFAULT_APP_LOG
    
    # 构建调试模式的端口参数（只有设置了 DEFAULT_APP_PORT 才添加）
    local portParam=""
    if [ -n "$DEFAULT_APP_PORT" ]; then
        portParam="-Dserver.port=$DEFAULT_APP_PORT"
    fi
    
    local debugCmd="java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=$DEFAULT_APP_DEBUG_PORT -Xms1G -Xmx4G -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof $portParam -jar $appName"
    
    echo "调试命令: $debugCmd"
    if [ -n "$DEFAULT_APP_PORT" ]; then
        echo "应用端口: $DEFAULT_APP_PORT, 调试端口: $DEFAULT_APP_DEBUG_PORT"
    else
        echo "调试端口: $DEFAULT_APP_DEBUG_PORT"
    fi
    echo "执行: nohup $debugCmd > /dev/null 2>&1 &"
    nohup $debugCmd > /dev/null 2>&1 &
    local debugPid=$!
    echo "调试进程PID: $debugPid"
    if [ -n "$DEFAULT_APP_PORT" ]; then
        echo "调试模式启动完成，应用端口: $DEFAULT_APP_PORT, 调试端口: $DEFAULT_APP_DEBUG_PORT"
    else
        echo "调试模式启动完成，调试端口: $DEFAULT_APP_DEBUG_PORT"
    fi
}

# ----------------- 停止应用 -----------------
function stop() {
    getAppPid
    if [ -z "$appId" ]; then
        if [ -n "$DEFAULT_APP_PORT" ]; then
            echo "$appName (端口: $DEFAULT_APP_PORT) 未运行"
        else
            echo "$appName 未运行"
        fi
        return
    fi
    if [ -n "$DEFAULT_APP_PORT" ]; then
        echo "停止应用 $appName (PID: $appId, 端口: $DEFAULT_APP_PORT)..."
    else
        echo "停止应用 $appName (PID: $appId)..."
    fi
    echo "执行: kill -9 $appId"
    kill -9 $appId
    local killResult=$?
    if [ $killResult -eq 0 ]; then
        echo "已停止"
    else
        echo "停止失败，退出码: $killResult"
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
        if [ -n "$DEFAULT_APP_PORT" ]; then
            echo -e "\033[31m $appName (端口: $DEFAULT_APP_PORT) 未运行 \033[0m"
        else
            echo -e "\033[31m $appName 未运行 \033[0m"
        fi
    else
        if [ -n "$DEFAULT_APP_PORT" ]; then
            echo -e "\033[32m $appName 正在运行 (PID: $appId, 端口: $DEFAULT_APP_PORT) \033[0m"
            # 验证端口监听状态
            if netstat -tlnp 2>/dev/null | grep -q ":${DEFAULT_APP_PORT}.*${appId}/java" || \
               ss -tlnp 2>/dev/null | grep -q ":${DEFAULT_APP_PORT}.*pid=${appId}"; then
                echo -e "\033[32m 端口 $DEFAULT_APP_PORT 正在监听中 ✓ \033[0m"
            else
                echo -e "\033[33m 警告: 端口 $DEFAULT_APP_PORT 未监听，应用可能正在启动中 \033[0m"
            fi
        else
            echo -e "\033[32m $appName 正在运行 (PID: $appId) \033[0m"
        fi
    fi
}

# ----------------- 查看日志 -----------------
function log() {
    echo "查看日志 $DEFAULT_APP_LOG/log_total.log..."
    echo "执行: tail -f $DEFAULT_APP_LOG/log_total.log"
    tail -f $DEFAULT_APP_LOG/log_total.log
}

# ----------------- 打印启动命令 -----------------
function print() {
    local printCmd=$(buildStartCmd)
    echo "$env 环境启动命令:"
    echo "$printCmd"
    if [ -n "$DEFAULT_APP_PORT" ]; then
        echo "端口: $DEFAULT_APP_PORT"
    fi
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
    *) info ;;
esac