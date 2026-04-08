#!/bin/bash
# NATMap 更新脚本 - Bash 版本
# 用法: ./update.sh <public_ip> <public_port> <ipv6> <out_port> <protocol> <local_ip>

API="https://nm.kszhc.top/api/update"
API_KEY="abc123apikey"
APP="vpn"

PUB_IP=$1
PUB_PORT=$2
IPV6=$3
OUT_PORT=$4
PROTO=$5
LOCAL_IP=$6

if [ -z "$PUB_IP" ] || [ -z "$PUB_PORT" ] || [ -z "$LOCAL_IP" ]; then
    echo "用法: $0 <public_ip> <public_port> <ipv6> <out_port> <protocol> <local_ip>"
    echo "示例: $0 1.2.3.4 12345 :: 0 tcp 192.168.1.100"
    exit 1
fi

curl -s -X POST "$API" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -d "{
        \"app\":\"$APP\",
        \"ip\":\"$PUB_IP\",
        \"port\":$PUB_PORT,
        \"proto\":\"$PROTO\",
        \"local_ip\":\"$LOCAL_IP\",
        \"local_port\":9001
    }"
