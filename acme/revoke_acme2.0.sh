#!/bin/bash
set -e

read -p "请输入你想撤销证书的二级域名: " DOMAIN

CA_FILE="$HOME/.acme.sh/${DOMAIN}/ca"

if [ ! -f "$CA_FILE" ]; then
    echo "找不到 $DOMAIN 的证书CA信息文件: $CA_FILE"
    exit 1
fi

CA_URL=$(cat "$CA_FILE")

if [[ "$CA_URL" == *"letsencrypt"* ]]; then
    CA_SERVER="letsencrypt"
elif [[ "$CA_URL" == *"buypass"* ]]; then
    CA_SERVER="buypass"
elif [[ "$CA_URL" == *"zerossl"* ]]; then
    CA_SERVER="zerossl"
else
    echo "无法识别CA服务器: $CA_URL"
    exit 1
fi

echo "检测到证书颁发机构为: $CA_SERVER"

~/.acme.sh/acme.sh --revoke -d "$DOMAIN" --server "$CA_SERVER"

if [ $? -eq 0 ]; then
    echo "证书已成功撤销: $DOMAIN"

    rm -f /root/${DOMAIN}.key /root/${DOMAIN}.crt

    RENEW_SCRIPT="/root/renew_cert.sh"
    if [ -f "$RENEW_SCRIPT" ]; then
        rm -f "$RENEW_SCRIPT"
        echo "已删除自动续期脚本：$RENEW_SCRIPT"
    fi

    crontab -l | grep -v "$RENEW_SCRIPT" | crontab -
    echo "已从crontab中删除自动续期任务。"
else
    echo "证书撤销失败: $DOMAIN"
fi
