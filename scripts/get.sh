#!/bin/bash
# NATMap 查询脚本 - Bash 版本
# 用法: ./get.sh

API="https://nm.kszhc.top/api/get?tenant=companyA&app=vpn"

DATA=$(curl -s "$API")

if [ -z "$DATA" ] || [ "$DATA" = "not found" ]; then
    echo "错误: 未找到映射数据"
    exit 1
fi

IP=$(echo "$DATA" | jq -r .public_ip)
PORT=$(echo "$DATA" | jq -r .public_port)
UPDATED_AT=$(echo "$DATA" | jq -r .updated_at)

if [ "$IP" = "null" ] || [ -z "$IP" ]; then
    echo "错误: 无法解析响应数据"
    echo "原始响应: $DATA"
    exit 1
fi

echo "公网地址: $IP:$PORT"
echo "更新时间: $UPDATED_AT"
