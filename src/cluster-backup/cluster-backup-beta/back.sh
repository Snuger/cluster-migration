#!/bin/bash

export KUBECONFIG=/root/.kube/config   
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
all_deployments=$(/usr/local/bin/kubectl get deploy -n "$SOURCE_NS" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
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
        temp_yaml=$(/usr/local/bin/kubectl get deploy "$deployment" -n "$SOURCE_NS" -o yaml | \
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


# 处理Services
echo "开始处理 Services..."
# 显示过滤关键字信息
[ -n "$FILTER_KEYWORD" ] && echo "  使用包含过滤关键字: $FILTER_KEYWORD"
[ -n "$EXCLUDE_KEYWORD" ] && echo "  使用排除过滤关键字: $EXCLUDE_KEYWORD"

# 获取所有Service名称，排除kubernetes服务
all_services=$(/usr/local/bin/kubectl get svc -n "$SOURCE_NS" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -v '^kubernetes$')
# 应用过滤
source_services=$(t_filter_resources "$all_services")

# 显示找到的数量
service_count=$(echo "$source_services" | grep -c '^')
echo "  找到 $service_count 个需要处理的Service"

# 处理每个Service
for service in $source_services; do
    if [ -n "$service" ]; then  # 确保不为空
        echo "  处理 Service: $service"
        
        # 获取Service YAML并处理
        /usr/local/bin/kubectl get svc "$service" -n "$SOURCE_NS" -o yaml | \
        sed -e '/resourceVersion:/d' -e '/uid:/d' | \
        # 移除clusterIP字段和clusterIPs相关配置块
        sed -e '/clusterIP:/d' -e '/clusterIPs:/,+4d' | \
        (
            # 临时保存处理后的YAML
            temp_yaml=$(cat)
            
            # 检查是否为NodePort类型，如果是则转换为ClusterIP
            if echo "$temp_yaml" | grep -q "type: NodePort\|type: LoadBalancer"; then
                echo "    检测到NodePort类型Service，将转换为ClusterIP类型..."
                # 移除nodePort字段
                temp_yaml=$(echo "$temp_yaml" | sed '/nodePort:/d') 
                echo "    已将Service类型从NodePort转换为ClusterIP"
            fi
            
            # 添加YAML文档分隔符（除了第一个资源外）
            if [ -s "$SERVICE_FILE" ]; then echo "---" >> "$SERVICE_FILE"; fi
            echo "$temp_yaml" >> "$SERVICE_FILE"
        )
    fi
done

echo "Services 已保存到 $SERVICE_FILE！"
echo "------------------------"

# 处理VirtualServices
echo "开始处理 VirtualServices..."
# 显示过滤关键字信息
[ -n "$FILTER_KEYWORD" ] && echo "  使用包含过滤关键字: $FILTER_KEYWORD"
[ -n "$EXCLUDE_KEYWORD" ] && echo "  使用排除过滤关键字: $EXCLUDE_KEYWORD"

# 获取所有VirtualService名称
all_vs=$(/usr/local/bin/kubectl get virtualservices.networking.istio.io -n "$SOURCE_NS" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
# 应用过滤
source_vs=$(t_filter_resources "$all_vs")

# 显示找到的数量
vs_count=$(echo "$source_vs" | grep -c '^')
echo "  找到 $vs_count 个符合条件的VirtualService"

# 处理每个VirtualService
for vs in $source_vs; do
    if [ -n "$vs" ]; then  # 确保不为空
        echo "  处理 VirtualService: $vs"
        
        # 获取VirtualService YAML
        temp_yaml=$(/usr/local/bin/kubectl get virtualservices.networking.istio.io "$vs" -n "$SOURCE_NS" -o yaml | \
        sed -e '/resourceVersion:/d' -e '/uid:/d')
          
        # 添加YAML文档分隔符（除了第一个资源外）
        if [ -s "$VIRTUAL_SERVICE_FILE" ]; then
            echo "---" >> "$VIRTUAL_SERVICE_FILE"
        fi
        echo "$temp_yaml" >> "$VIRTUAL_SERVICE_FILE"
    fi
done
echo "VirtualServices 已保存到 $VIRTUAL_SERVICE_FILE！"


# 处理DestinationRules
echo "开始处理 DestinationRules..."
# 显示过滤关键字信息
[ -n "$FILTER_KEYWORD" ] && echo "  使用包含过滤关键字: $FILTER_KEYWORD"
[ -n "$EXCLUDE_KEYWORD" ] && echo "  使用排除过滤关键字: $EXCLUDE_KEYWORD"

# 获取所有DestinationRule名称
all_dr=$(/usr/local/bin/kubectl get destinationrules.networking.istio.io -n "$SOURCE_NS" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
# 应用过滤
source_dr=$(t_filter_resources "$all_dr")

# 显示找到的数量
dr_count=$(echo "$source_dr" | grep -c '^')
echo "  找到 $dr_count 个符合条件的DestinationRule"

# 处理每个DestinationRule
for dr in $source_dr; do
    if [ -n "$dr" ]; then  # 确保不为空
        echo "  处理 DestinationRule: $dr"
        
        # 获取DestinationRule YAML
        temp_yaml=$(/usr/local/bin/kubectl get destinationrules.networking.istio.io "$dr" -n "$SOURCE_NS" -o yaml | \
        sed -e '/resourceVersion:/d' -e '/uid:/d')
          
        # 添加YAML文档分隔符（除了第一个资源外）
        if [ -s "$DESTINATION_RULE_FILE" ]; then
            echo "---" >> "$DESTINATION_RULE_FILE"
        fi
        echo "$temp_yaml" >> "$DESTINATION_RULE_FILE"
    fi
done
echo "DestinationRules 已保存到 $DESTINATION_RULE_FILE！"



echo "------------------------"
echo "所有资源已导出并保存到文件："
echo "- Deployments: $DEPLOYMENT_FILE"
echo "- Services: $SERVICE_FILE"
echo "- VirtualServices: $VIRTUAL_SERVICE_FILE"
echo "- DestinationRules: $DESTINATION_RULE_FILE"
echo "------------------------"
echo "使用方式：kubectl apply -f $DEPLOYMENT_FILE"
echo "          kubectl apply -f $SERVICE_FILE"
echo "          kubectl apply -f $VIRTUAL_SERVICE_FILE"
echo "          kubectl apply -f $DESTINATION_RULE_FILE"

# 显示使用帮助
echo "\n使用说明："
echo "  1. 基本用法：bash back.sh [包含过滤关键字] [输出目录] [排除过滤关键字]"
echo "  2. 示例1：bash back.sh \"chanpin\" \"./2025111219\""  # 只使用包含关键字
 echo "  3. 示例2：bash back.sh \"chanpin\" \"./2025111219\" \"test\""  # 使用包含关键字并排除包含test的资源
 echo "  4. 如果不需要过滤，请将过滤关键字设为空字符串：bash back.sh \"\" \"./output\""  # 导出所有资源