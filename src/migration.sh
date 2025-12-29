#!/bin/bash

# 处理参数
FILTER_KEYWORD="$1"

# 资源过滤函数
filter_resources() {
  if [ -n "$FILTER_KEYWORD" ]; then
    grep -i "$FILTER_KEYWORD"
  else
    cat
  fi
}

# 定义源命名空间和目标命名空间
SOURCE_NS="mcrp-java-dev"
TARGET_NS="lyra-alpha"

# 创建目标命名空间（如果不存在）
kubectl create namespace "$TARGET_NS" --dry-run=client -o yaml | kubectl apply -f -

# 处理Deployments
echo "开始处理 Deployments..."
deployments=$(kubectl get deploy -n "$SOURCE_NS" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | filter_resources)

for deployment in $deployments; do
  echo "处理 Deployment: $deployment"
  
  # 检查目标命名空间是否已存在同名Deployment
  if kubectl get deploy "$deployment" -n "$TARGET_NS" &>/dev/null; then
    
    # 获取源和目标Deployment的镜像列表
    source_images=$(kubectl get deploy "$deployment" -n "$SOURCE_NS" -o=jsonpath='{.spec.template.spec.containers[*].image}')
    target_images=$(kubectl get deploy "$deployment" -n "$TARGET_NS" -o=jsonpath='{.spec.template.spec.containers[*].image}')
    
    # 比较镜像列表
    if [ "$source_images" == "$target_images" ]; then
      echo "  源和目标镜像相同，放弃更新..."
      continue
    else
      echo "  镜像不同，准备更新: $source_images → $target_images"
      kubectl get deploy "$deployment" -n "$SOURCE_NS" -o yaml | \
        sed "s/namespace: $SOURCE_NS/namespace: $TARGET_NS/g" | \
        kubectl replace --force -f -
    fi
  else
    # 目标命名空间不存在该Deployment，直接创建
    echo "  创建新 Deployment: $deployment"
    kubectl get deploy "$deployment" -n "$SOURCE_NS" -o yaml | \
      sed "s/namespace: $SOURCE_NS/namespace: $TARGET_NS/g" | \
      kubectl apply -f -
  fi
done

echo "Deploy 处理完成！"
echo "------------------------"


# 处理Services（优化对比效率）
echo "开始处理 Services..."
# 获取源和目标命名空间的Service列表，排除kubernetes服务
source_services=$(kubectl get svc -n "$SOURCE_NS" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -v '^kubernetes$' | filter_resources)
target_services=$(kubectl get svc -n "$TARGET_NS" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -v '^kubernetes$')

# 计算需要创建的Service（在源中但不在目标中）
services_to_create=$(comm -23 <(echo "$source_services" | tr ' ' '\n' | sort) <(echo "$target_services" | tr ' ' '\n' | sort))

if [ -z "$services_to_create" ]; then
  echo "没有需要补充的Service"
fi

for service in $services_to_create; do
  echo "处理 Service: $service"
  
  # 获取Service YAML并一次性处理所有修改
  kubectl get svc "$service" -n "$SOURCE_NS" -o yaml | \
  # 移除clusterIP字段(仅删除当前行)和clusterIPs相关配置块(删除6行)
  sed -e '/clusterIP:/d' -e '/clusterIPs:/,+4d' | \
  # 修改命名空间
  sed "s/namespace: $SOURCE_NS/namespace: $TARGET_NS/g" | \
  (
    # 临时保存处理后的YAML
    temp_yaml=$(cat)
    
    # 检查是否为NodePort类型，如果是则转换为ClusterIP
    if echo "$temp_yaml" | grep -q "type: NodePort\|type: LoadBalancer"; then
      echo "  检测到NodePort类型Service，将转换为ClusterIP类型..."
      # 移除nodePort字段
      temp_yaml=$(echo "$temp_yaml" | sed '/nodePort:/d')

      # 将type从NodePort改为ClusterIP
      temp_yaml=$(echo "$temp_yaml" | sed 's/type: NodePort/type: ClusterIP/g')
      temp_yaml=$(echo "$temp_yaml" | sed 's/type: LoadBalancer/type: ClusterIP/g')
      
      echo "  已将Service类型从NodePort转换为ClusterIP"
    fi
    
    # 应用处理后的Service
    #echo "$temp_yaml"
    echo "$temp_yaml" | kubectl apply -f -
  )
  
  echo "---"
done

echo "Services 处理完成！"
echo "------------------------"

# 处理VirtualServices（优化对比效率）
echo "开始处理 VirtualServices..."
# 获取源和目标命名空间的VirtualService列表
# 使用range语法确保每个名称单独成行
source_vs=$(kubectl get virtualservices.networking.istio.io -n "$SOURCE_NS" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'|| true | filter_resources)
target_vs=$(kubectl get virtualservices.networking.istio.io -n "$TARGET_NS" -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'|| true)

# 计算需要创建的VirtualService（在源中但不在目标中）
vs_to_create=$(comm -23 <(echo "$source_vs" | tr ' ' '\n' | sort) <(echo "$target_vs" | tr ' ' '\n' | sort))

if [ -z "$vs_to_create" ]; then
  echo "没有需要补充的VirtualService"
fi

for vs in $vs_to_create; do
  echo "处理 VirtualService: $vs"
  
  # 获取VirtualService YAML并修改命名空间和网关引用
  kubectl get virtualservices.networking.istio.io "$vs" -n "$SOURCE_NS" -o yaml | \
  sed "s/$SOURCE_NS/$TARGET_NS/g" | \
  kubectl apply -f -
done

echo "VirtualServices 处理完成！"
echo "------------------------"

# 处理Gateway资源
echo "开始处理 Gateways..."

# 构建目标命名空间的Gateway名称
TARGET_GW_NAME="${TARGET_NS}-gateway"

# 检查目标命名空间是否已存在目标Gateway
if kubectl get gateways.networking.istio.io "$TARGET_GW_NAME" -n "$TARGET_NS" &>/dev/null; then
  echo "目标命名空间中已存在 Gateway: $TARGET_GW_NAME，放弃操作..."
else
  # 获取源命名空间的Gateway列表
  SOURCE_GWS=$(kubectl get gateways.networking.istio.io -n "$SOURCE_NS" -o=jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
  
  # 如果源命名空间中没有Gateway，则跳过
  if [ -z "$SOURCE_GWS" ]; then
    echo "源命名空间中没有找到 Gateways，放弃操作..."
  else
    # 默认使用第一个Gateway进行导出和转换
    SOURCE_GW=$(echo "$SOURCE_GWS" | awk '{print $1}')
    echo "处理 Gateway: $SOURCE_GW (将转换为 $TARGET_GW_NAME)"
    
    # 获取源Gateway YAML并修改命名空间和名称
    kubectl get gateways.networking.istio.io "$SOURCE_GW" -n "$SOURCE_NS" -o yaml | \
    sed "s/namespace: $SOURCE_NS/namespace: $TARGET_NS/g" | \
    sed "s/name: $SOURCE_GW/name: $TARGET_GW_NAME/g" | \
    # 替换网关名称中的命名空间引用
    sed "s/${SOURCE_NS}-gateway/${TARGET_NS}-gateway/g" | \
    kubectl apply -f -
    
    echo "---"
  fi
fi

echo "所有资源已从 $SOURCE_NS 命名空间迁移至 $TARGET_NS 命名空间"