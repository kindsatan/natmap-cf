#!/bin/bash
# NATMap 客户端连接脚本 - Bash 版本
# 用法: ./connect.sh

API="https://nm.kszhc.top/api/get?tenant=companyA&app=vpn"

echo "正在获取最新的公网地址..."

DATA=$(curl -s "$API")

if [ -z "$DATA" ] || [ "$DATA" = "not found" ]; then
    echo "错误: 未找到映射数据"
    exit 1
fi

IP=$(echo "$DATA" | jq -r .public_ip)
PORT=$(echo "$DATA" | jq -r .public_port)

if [ "$IP" = "null" ] || [ -z "$IP" ]; then
    echo "错误: 无法解析响应数据"
    echo "原始响应: $DATA"
    exit 1
fi

echo "连接到: $IP:$PORT"

# 使用 nc 连接，如果不存在则提示安装
if command -v nc &> /dev/null; then
    nc "$IP" "$PORT"
else
    echo "提示: 未找到 nc 命令，请手动连接: $IP:$PORT"
fi
