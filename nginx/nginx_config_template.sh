#!/bin/bash

GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[0;34m'
RESET='\033[0m'

green() {
	echo -e "${GREEN}${1}${RESET}"
}

red() {
	echo -e "${RED}${1}${RESET}"
}

yellow() {
	echo -e "${YELLOW}${1}${RESET}"
}

blue() {
	echo -e "${BLUE}${1}${RESET}"
}

check_domain() {
	local DOMAIN=$1

	IP_RESULT=$(dig +short $DOMAIN A)

	if [ -z "$IP_RESULT" ]; then
		IP_RESULT=$(dig +short $DOMAIN AAAA)
	fi

	SERVER_IP=$(hostname -I)

	if [ -z "$IP_RESULT" ]; then
		echo
		red "域名输入有误"
		echo
		return 1
	fi

	if ! echo "$SERVER_IP" | grep -q "$IP_RESULT"; then
		echo
		red "该域名未解析到此服务器"
		echo
		return 1
	fi

	return 0
}

clear

check_url() {
	local url="$1"
	local token="$2"
	local status_code
	status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: $token" "$url")
	echo "$status_code"
}

if ! which nginx >/dev/null 2>&1; then
	red "还未安装nginx！"
	exit 1
fi

if ! pgrep nginx >/dev/null 2>&1; then
	yellow "nginx没有启动，正在启动..."
	sudo nginx
fi

while true; do
	read -p "$(yellow '请输入你的二级域名：') " DOMAIN
	check_domain "$DOMAIN"
	if [ $? -ne 0 ]; then
		continue
	fi
	CRT="$DOMAIN.crt"
	KEY="$DOMAIN.key"

	CRT_PATHS=($(find / -name "$CRT" 2>/dev/null))
	KEY_PATHS=($(find / -name "$KEY" 2>/dev/null))
	CA_PATHS=($(find / -name "ca-certificates.crt" 2>/dev/null))

	while true; do
		if [ ${#CRT_PATHS[@]} -eq 0 ]; then
			echo
			red "CRT证书不存在。"
			exit 1
		elif [ ${#CRT_PATHS[@]} -eq 1 ]; then
			CRT_PATH="${CRT_PATHS[0]}"
			echo
			green "找到的CRT证书路径是: $CRT_PATH"
			break
		else
			echo
			yellow "找到以下CRT证书路径："
			for i in "${!CRT_PATHS[@]}"; do
				yellow "$((i + 1)). ${CRT_PATHS[i]}"
			done

			read -p "$(yellow '请选择CRT证书路径:')" your_choice

			if [[ $your_choice -ge 1 && $your_choice -le ${#CRT_PATHS[@]} ]]; then
				CRT_PATH="${CRT_PATHS[$((your_choice - 1))]}"
				echo
				green "已选择的CRT证书路径是: $CRT_PATH"
				echo
				break
			else
				echo
				red "无效选择，请重新选择"
				echo
			fi
		fi
	done

	while true; do
		if [ ${#KEY_PATHS[@]} -eq 0 ]; then
			echo
			red "KEY证书不存在。"
			exit 1
		elif [ ${#KEY_PATHS[@]} -eq 1 ]; then
			KEY_PATH="${KEY_PATHS[0]}"
			echo
			green "找到的KEY证书路径是: $KEY_PATH"
			break
		else
			echo
			yellow "找到以下KEY证书路径："
			for i in "${!KEY_PATHS[@]}"; do
				yellow "$((i + 1)). ${KEY_PATHS[i]}"
			done

			read -p "$(yellow '请选择KEY证书路径:')" your_choices

			if [[ $your_choices -ge 1 && $your_choices -le ${#KEY_PATHS[@]} ]]; then
				KEY_PATH="${KEY_PATHS[$((your_choices - 1))]}"
				echo
				green "已选择的KEY证书路径是: $KEY_PATH"
				echo
				break
			else
				echo
				red "无效选择，请重新选择"
				echo
			fi
		fi
	done

	while true; do
		if [ ${#CA_PATHS[@]} -eq 0 ]; then
			echo
			red "CA证书不存在"
			exit 1
		elif [ ${#CA_PATHS[@]} -eq 1 ]; then
			CA_PATH="${CA_PATHS[0]}"
			echo
			green "找到的CA证书路径是: $CA_PATH"
			echo
			break
		else
			echo
			yellow "找到以下CA证书路径："
			for i in "${!CA_PATHS[@]}"; do
				yellow "$((i + 1)). ${CA_PATHS[i]}"
			done

			read -p "$(yellow '请选择CA证书路径:')" your_choices_ca

			if [[ $your_choices_ca -ge 1 && $your_choices_ca -le ${#CA_PATHS[@]} ]]; then
				CA_PATH="${CA_PATHS[$((your_choices_ca - 1))]}"
				echo
				green "已选择的CA证书路径是: $CA_PATH"
				echo
				break
			else
				echo
				red "无效选择，请重新选择"
				echo
			fi
		fi
	done

	break

done

TEMP_FILE=$(mktemp)

nginx_config=$(
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
)

rm -f "$TEMP_FILE"

sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak

echo "$nginx_config" | sudo tee /etc/nginx/sites-available/default >/dev/null

echo

sudo nginx -t

if [ $? -eq 0 ]; then
	sudo nginx -s reload
	echo
	green "配置正确,nginx已重新加载并应用新的配置!"
	echo
else
	sudo cp /etc/nginx/sites-available/default.bak /etc/nginx/sites-available/default
	sudo nginx -s reload
	echo
	red "Nginx 配置有错误，请检查后重试，已恢复原有配置并应用!"
	echo
fi
