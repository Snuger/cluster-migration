#!/bin/bash

# 处理参数
FILTER_KEYWORD="$1"
# 添加输出目录参数，默认为当前目录
OUTPUT_DIR="${2:-.}"
# 添加排除关键字参数，默认为空（不排除）
EXCLUDE_KEYWORD="$3"

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR/$FILTER_KEYWORD"

# 定义源命名空间
SOURCE_NS="lyra-production"

# 定义输出文件路径
DEPLOYMENT_FILE="$OUTPUT_DIR/$FILTER_KEYWORD/deployments.yaml"
SERVICE_FILE="$OUTPUT_DIR/$FILTER_KEYWORD/services.yaml"
VIRTUAL_SERVICE_FILE="$OUTPUT_DIR/$FILTER_KEYWORD/virtualservices.yaml"
DESTINATION_RULE_FILE="$OUTPUT_DIR/$FILTER_KEYWORD/destinationrules.yaml"

# 清空现有文件
> "$DEPLOYMENT_FILE"
> "$SERVICE_FILE"
> "$VIRTUAL_SERVICE_FILE"
> "$DESTINATION_RULE_FILE"

# 通用的资源过滤函数
# 参数1: 资源列表
# 返回: 过滤后的资源列表
t_filter_resources() {
    local resource_list="$1"
    local filtered_list=""
    
    # 首先应用包含过滤
    if [ -n "$FILTER_KEYWORD" ]; then
        filtered_list=$(echo "$resource_list" | grep -i "$FILTER_KEYWORD" | grep -v '^$')
    else
        filtered_list="$resource_list"
    fi
    
    # 然后应用排除过滤（如果设置了排除关键字）
    if [ -n "$EXCLUDE_KEYWORD" ]; then
        filtered_list=$(echo "$filtered_list" | grep -vi "$EXCLUDE_KEYWORD" | grep -v '^$')
    fi
    
    echo "$filtered_list"
}

# 处理Deployments
echo "开始处理 Deployments..."
# 显示过滤关键字信息
[ -n "$FILTER_KEYWORD" ] && echo "  使用包含过滤关键字: $FILTER_KEYWORD"
[ -n "$EXCLUDE_KEYWORD" ] && echo "  使用排除过滤关键字: $EXCLUDE_KEYWORD"

# 获取所有Deployment名称
all_deployments=$(kubectl get cm -n "$SOURCE_NS" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
# 应用过滤
deployments=$(t_filter_resources "$all_deployments")

# 显示找到的数量
deployment_count=$(echo "$deployments" | grep -c '^')
echo "  找到 $deployment_count 个符合条件的Deployment"

# 处理每个Deployment
for deployment in $deployments; do  
    if [ -n "$deployment" ]; then  # 确保不为空
        echo "  处理 Deployment: $deployment"
        # 获取Deployment YAML
        temp_yaml=$(kubectl get cm "$deployment" -n "$SOURCE_NS" -o yaml | \
        sed -e '/resourceVersion:/d' -e '/uid:/d' -e '/status:/,+30d')
        
        # 添加YAML文档分隔符（除了第一个资源外）
        if [ -s "$DEPLOYMENT_FILE" ]; then
            echo "---" >> "$DEPLOYMENT_FILE"
        fi
        echo "$temp_yaml" >> "$DEPLOYMENT_FILE"
    fi
done

echo "Deployments 已保存到 $DEPLOYMENT_FILE！"
echo "------------------------"

# 显示使用帮助
echo "\n使用说明："
echo "  1. 基本用法：bash back.sh [包含过滤关键字] [输出目录] [排除过滤关键字]"
echo "  2. 示例1：bash back.sh \"chanpin\" \"./2025111219\""  # 只使用包含关键字
 echo "  3. 示例2：bash back.sh \"chanpin\" \"./2025111219\" \"test\""  # 使用包含关键字并排除包含test的资源
 echo "  4. 如果不需要过滤，请将过滤关键字设为空字符串：bash back.sh \"\" \"./output\""  # 导出所有资源