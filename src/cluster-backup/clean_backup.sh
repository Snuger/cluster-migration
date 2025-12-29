#!/bin/bash

SCRIPT_DIR=$(dirname $(readlink -f "$0"))
cd "$SCRIPT_DIR"
KEEP_DAYS=3

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始清理超过$KEEP_DAYS天的备份文件夹..."

# 获取当前时间的时间戳（以秒为单位）
current_timestamp=$(date +%s)
# 计算3天的秒数
keep_seconds=$((KEEP_DAYS * 24 * 60 * 60))

# 查找所有符合YYYYMMDDHH格式的文件夹（更严格的正则表达式）
backup_folders=$(find "$SCRIPT_DIR" -maxdepth 1 -type d -name "20[0-9][0-9][01][0-9][0-3][0-9][0-2][0-9]" 2>/dev/null)

# 准备删除的文件夹列表
folders_to_delete=()

# 遍历所有备份文件夹
for folder in $backup_folders; do
    # 提取文件夹名称（去除路径）
    folder_name=$(basename "$folder")
    
    # 严格验证文件夹名称格式（YYYYMMDDHH）
    if ! [[ "$folder_name" =~ ^20[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])([01][0-9]|2[0-3])$ ]]; then
        echo "  跳过非标准格式文件夹: $folder_name"
        continue
    fi
    
    # 从文件夹名称中提取日期和时间
    year="${folder_name:0:4}"
    month="${folder_name:4:2}"
    day="${folder_name:6:2}"
    hour="${folder_name:8:2}"
    
    # 将文件夹名称转换为时间戳
    folder_timestamp=$(date -d "$year-$month-$day $hour:00:00" +%s 2>/dev/null)
    
    if [ -z "$folder_timestamp" ]; then
        echo "  跳过无效日期格式文件夹: $folder_name"
        continue
    fi
    
    # 计算时间差（秒）
    time_diff=$((current_timestamp - folder_timestamp))
    
    # 如果超过保留时间，添加到删除列表
    if [ "$time_diff" -gt "$keep_seconds" ]; then
        folders_to_delete+=("$folder")
    fi
done

# 显示要删除的文件夹
if [ ${#folders_to_delete[@]} -gt 0 ]; then
    echo "准备删除以下旧备份文件夹："
    for folder in "${folders_to_delete[@]}"; do
        echo "  $folder"
    done
    
    # 删除这些文件夹
    for folder in "${folders_to_delete[@]}"; do
        echo "  删除文件夹: $folder"
        rm -rf "$folder" 2>/dev/null
    done
    
    # 记录删除的文件夹数量
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理完成，已删除 ${#folders_to_delete[@]} 个超过$KEEP_DAYS天的备份文件夹"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理完成，已删除 ${#folders_to_delete[@]} 个超过$KEEP_DAYS天的备份文件夹" >> "$SCRIPT_DIR/cron_cleanup.log"
else
    echo "没有需要删除的旧备份文件夹。"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理完成，没有需要删除的旧备份文件夹" >> "$SCRIPT_DIR/cron_cleanup.log"
fi