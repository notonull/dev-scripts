#!/bin/bash
## 作者: aGeng
## 更新日期: 2025-09-15
## 版本: 1.4.0

version="1.4.0"
DEFAULT_ENV="dev"
DEFAULT_APP_LOG="./app-log"
DEFAULT_JVM_LOG="./jvm-log"
debugPort=58802

cmd=$1        # 第一个参数：命令，如 start, stop, debug, print
env=$2        # 第二个参数：环境，如 dev 或 prod
appName=$3    # 第三个参数：应用名，可选

# 如果没有指定应用名，自动选择最新的 .jar 文件
if [ -z "$appName" ]; then
    appName=$(ls -t | grep .jar$ | head -n1)
fi

# 获取应用 PID
function getAppPid() {
    appId=$(ps -ef | grep java | grep "$appName" | grep -v grep | awk '{print $2}')
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
    echo " debug : 启动调试模式，JDWP 调试端口 $debugPort"
    echo " stop : 停止应用"
    echo " restart [env] : 重启应用，默认环境: $DEFAULT_ENV"
    echo " status : 查看应用状态及 PID"
    echo " log : 查看日志（tail -f $DEFAULT_APP_LOG/log_total.log）"
    echo " print [env] : 打印启动命令（不执行）"
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

    if [ "$env" == "dev" ]; then
        echo "java -Xms1G -Xmx4G -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof -jar $appName"
    elif [ "$env" == "prod" ]; then
        echo "java -server -XX:+UnlockExperimentalVMOptions -Xms20G -Xmx20G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+ParallelRefProcEnabled -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -XX:+PrintGCApplicationConcurrentTime -Xloggc:$DEFAULT_JVM_LOG/gc-$(date +%Y%m%d_%H%M%S).log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=200M -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=1808 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=127.0.0.1 -jar $appName"
    else
        echo "未知环境: $env"
    fi
}

# ----------------- 启动应用 -----------------
function start() {
    getAppPid
    if [ -n "$appId" ]; then
        echo "应用 $appName 已经运行 (PID: $appId)，请检查。"
        return
    fi
    cmdStr=$(buildStartCmd)
    echo "启动应用命令: $cmdStr"
    nohup $cmdStr > /dev/null 2>&1 &
    echo "$env 环境启动完成"
}

# ----------------- 调试模式 -----------------
function debug() {
    getAppPid
    if [ -n "$appId" ]; then
        echo "应用 $appName 已经运行 (PID: $appId)，请检查。"
        return
    fi
    mkdir -p $DEFAULT_APP_LOG
    echo "调试模式启动命令:"
    echo "java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=$debugPort -Xms1G -Xmx4G -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof -jar $appName"
    nohup java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=$debugPort -Xms1G -Xmx4G -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$DEFAULT_APP_LOG/heapdump-$(date +%Y%m%d_%H%M%S).hprof -jar $appName > /dev/null 2>&1 &
    echo "调试模式启动完成"
}

# ----------------- 停止应用 -----------------
function stop() {
    getAppPid
    if [ -z "$appId" ]; then
        echo "$appName 未运行"
        return
    fi
    echo "停止应用 $appName (PID: $appId)..."
    kill -9 $appId
    echo "已停止"
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
        echo -e "\033[31m $appName 未运行 \033[0m"
    else
        echo -e "\033[32m $appName 正在运行 (PID: $appId) \033[0m"
    fi
}

# ----------------- 查看日志 -----------------
function log() {
    echo "查看日志 $DEFAULT_APP_LOG/log_total.log..."
    tail -f $DEFAULT_APP_LOG/log_total.log
}

# ----------------- 打印启动命令 -----------------
function print() {
    echo "打印 $env 环境启动命令:"
    buildStartCmd
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