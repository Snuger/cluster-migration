#!/bin/bash

# 获取当前时间，格式为年月日小时（24小时制）
TIMESTAMP=$(date +"%Y%m%d%H")

# 设置脚本路径和工作目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 执行back.sh脚本，使用当前时间作为输出目录
bash back.sh "cyan" "./$TIMESTAMP"
bash back.sh "lyra" "./$TIMESTAMP"
bash back.sh "vela" "./$TIMESTAMP" "jiaohu"
bash back.sh "biaozhun" "./$TIMESTAMP" 
bash back.sh "jiaohu" "./$TIMESTAMP" "biaozhun"
bash back.sh "mars" "./$TIMESTAMP" 
bash back.sh "merc" "./$TIMESTAMP" 
bash back.sh "nova" "./$TIMESTAMP" 
bash back.sh "grus" "./$TIMESTAMP" 

# 可选：记录执行日志
LOG_FILE="$SCRIPT_DIR/cron_backup.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行备份任务，输出目录: ./$TIMESTAMP" >> "$LOG_FILE"