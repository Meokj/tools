#!/bin/bash
if pgrep singbox-vless > /dev/null; then
  echo "singbox-vless 进程存在，准备杀死..."
  echo
  pkill singbox-vless
  sleep 2
  if pgrep singbox-vless > /dev/null; then
    echo "singbox-vless 进程未退出，强制杀死"
    echo
    pkill -9 singbox-vless
  fi
fi

while true; do
  read -rp "请输入监听端口（443 或 1025~65535）: " PORT
  if [[ "$PORT" =~ ^[0-9]{1,5}$ ]] && { [ "$PORT" -eq 443 ] || ( [ "$PORT" -ge 1025 ] && [ "$PORT" -le 65535 ] ); }; then
    break
  else
    echo "无效端口，请输入 443 或 1025~65535 范围内的数字。"
  fi
done

echo "请输入证书文件所在目录路径（包含 .crt 和 .key 文件）:"
read -r CERT_DIR

if [ ! -d "$CERT_DIR" ]; then
  echo "目录不存在：$CERT_DIR"
  exit 1
fi

VLESS_PATH="/abcdefg"
ENCODED_PATH="${VLESS_PATH/\//%2F}"
CRT_FILE=$(find "$CERT_DIR" -maxdepth 1 -name "*.crt" | head -n 1)
KEY_FILE=$(find "$CERT_DIR" -maxdepth 1 -name "*.key" | head -n 1)
UUID=$(cat /proc/sys/kernel/random/uuid)

if [ -z "$CRT_FILE" ] || [ -z "$KEY_FILE" ]; then
  echo "在目录中未找到 .crt 或 .key 文件"
  exit 1
fi

DOMAIN=$(basename "$CRT_FILE" .crt)

echo
echo "-----------------------------------"
echo "📌 监听端口     : $PORT"
echo "📄 证书文件     : $CRT_FILE"
echo "🔐 密钥文件     : $KEY_FILE"
echo "🌐 域名         : $DOMAIN"
echo "🛣️ 路径         : $VLESS_PATH"
echo "-----------------------------------"
echo
read -rp "确认以上信息无误？输入 y 继续，其他键退出: " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  exit 1
fi

cd /usr/local || exit
if [ -d vless ]; then
  rm -rf vless
fi

rm -f sing-box-1.12.0-beta.33-linux-amd64.tar.gz
wget https://github.com/SagerNet/sing-box/releases/download/v1.12.0-beta.33/sing-box-1.12.0-beta.33-linux-amd64.tar.gz
tar -xzvf sing-box-1.12.0-beta.33-linux-amd64.tar.gz && \
mv sing-box-1.12.0-beta.33-linux-amd64 vless
cd vless || exit
mv sing-box singbox-vless
chmod +x singbox-vless

if [ "$PORT" = "443" ]; then
cat <<- EOF > config.json
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": 443,
      "tag": "vless-ws-tls-in",
      "users": [
        {
          "uuid": "$UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN",
        "certificate_path": "$CRT_FILE",
        "key_path": "$KEY_FILE",
        "alpn": ["h2", "http/1.1"]
      },
      "transport": {
        "type": "ws",
        "path": "$VLESS_PATH"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

else

cat <<- EOF > config.json
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "127.0.0.1",
      "listen_port": $PORT,
      "tag": "vless-ws-tls-in",
      "users": [
        {
          "uuid": "$UUID"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$VLESS_PATH"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

fi

echo "配置 systemd 服务..."
cat <<EOF | sudo tee /etc/systemd/system/singbox-vless.service > /dev/null
[Unit]
Description=Sing-box Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/vless/singbox-vless run
WorkingDirectory=/usr/local/vless
Restart=on-failure
StandardOutput=append:/var/log/singbox-vless.log
StandardError=append:/var/log/singbox-vless.log

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable singbox-vless
sudo systemctl restart singbox-vless

sleep 2
if systemctl is-active --quiet singbox-vless; then
  echo "singbox-vless 已通过 systemd 启动成功！"
  echo "日志文件位置：/var/log/singbox-vless.log"
  echo "如果未监听非标端口443，请配置NGINX进行转发"
  echo "VLESS+WS+TLS节点信息如下，粘贴导入使用"
  echo "================================================================="
  echo "vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&sni=${DOMAIN}&alpn=h2,http/1.1&type=ws&host=${DOMAIN}&path=${ENCODED_PATH}#VLESS"
  echo "================================================================="
else
  echo "singbox-vless 启动失败，请使用 'journalctl -u singbox-vless' 查看详细日志"
  exit 1
fi
