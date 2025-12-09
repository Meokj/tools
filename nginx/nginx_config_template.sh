#!/bin/bash

GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[0;34m'
RESET='\033[0m'

green() { echo -e "${GREEN}${1}${RESET}"; }
red() { echo -e "${RED}${1}${RESET}"; }
yellow() { echo -e "${YELLOW}${1}${RESET}"; }
blue() { echo -e "${BLUE}${1}${RESET}"; }

check_nginx() {
    if ! which nginx >/dev/null 2>&1; then
        red "还未安装 nginx！"
        exit 1
    fi

    if ! pgrep nginx >/dev/null 2>&1; then
        yellow "nginx 没有启动，正在启动..."
        sudo nginx
    fi
}

backup_default_config() {
    if [[ -f /etc/nginx/sites-available/default ]]; then
        sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
        green "已备份默认配置为 default.bak"
    fi
}

generate_nginx_config() {
    cat <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    root /var/www/html;

    ssl_certificate $CRT_PATH;
    ssl_certificate_key $KEY_PATH;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
}
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _; 
    return 444;
}
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;
    ssl_certificate $CRT_PATH;
    ssl_certificate_key $KEY_PATH;
    return 444;
}
EOF
}

reload_nginx() {
    sudo nginx -t
    if [ $? -eq 0 ]; then
        sudo nginx -s reload
        green "配置正确，nginx 已重新加载!"
    else
        sudo cp /etc/nginx/sites-available/default.bak /etc/nginx/sites-available/default
        sudo nginx -s reload
        red "Nginx 配置有错误，已恢复原配置! 请查看 /var/log/nginx/error.log"
    fi
}

main() {
    check_nginx

    read -p "请输入二级域名: " DOMAIN
    read -p "请输入证书路径 (绝对路径): " CRT_PATH
    read -p "请输入私钥路径 (绝对路径): " KEY_PATH

    regex='^[A-Za-z0-9-]{1,63}\.[A-Za-z]{2,63}$'
    
    if [[ -z "$DOMAIN" ]]; then red "域名不能为空"; exit 1; fi
    if ! [[ $DOMAIN =~ $regex ]]; then
        echo "$DOMAIN 不是二级域名"
        exit 1
    fi
    if [[ ! -f "$CRT_PATH" ]]; then red "证书文件不存在: $CRT_PATH"; exit 1; fi
    if [[ ! -f "$KEY_PATH" ]]; then red "私钥文件不存在: $KEY_PATH"; exit 1; fi
    if [[ "$CRT_PATH" != /* || "$KEY_PATH" != /* ]]; then red "路径必须是绝对路径!"; exit 1; fi

    backup_default_config
    generate_nginx_config | sudo tee /etc/nginx/sites-available/default >/dev/null
    reload_nginx
}

main
