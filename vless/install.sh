#!/bin/bash
if pgrep singbox > /dev/null; then
  echo "singbox 进程存在，准备杀死..."
  echo
  pkill singbox
  sleep 2
  if pgrep singbox > /dev/null; then
    echo "singbox 进程未退出，强制杀死"
    echo
    pkill -9 singbox
  fi
fi

while true; do
  read -rp "请输入监听端口（1025~65535）: " PORT
  if [[ "$PORT" =~ ^[0-9]{1,5}$ ]] && [ "$PORT" -ge 1025 ] && [ "$PORT" -le 65535 ]; then
    break
  else
    echo "无效端口，请输入 1025~65535 范围内的数字。"
  fi
done

echo "请输入证书文件所在目录路径（包含 .crt 和 .key 文件）:"
read -r CERT_DIR

if [ ! -d "$CERT_DIR" ]; then
  echo "目录不存在：$CERT_DIR"
  exit 1
fi

CRT_FILE=$(find "$CERT_DIR" -maxdepth 1 -name "*.crt" | head -n 1)
KEY_FILE=$(find "$CERT_DIR" -maxdepth 1 -name "*.key" | head -n 1)
UUID=$(uuidgen)

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
echo "-----------------------------------"
echo
read -rp "确认以上信息无误？输入 y 继续，其他键退出: " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  exit 1
fi

cd /usr/local || exit
if [ -d anytls ]; then
  rm -rf anytls
fi

rm -f sing-box-1.12.0-beta.33-linux-amd64.tar.gz
wget https://github.com/SagerNet/sing-box/releases/download/v1.12.0-beta.33/sing-box-1.12.0-beta.33-linux-amd64.tar.gz
tar -xzvf sing-box-1.12.0-beta.33-linux-amd64.tar.gz && \
mv sing-box-1.12.0-beta.33-linux-amd64 anytls
cd anytls || exit
mv sing-box singbox
chmod +x singbox

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
      "listen_port": $PORT,
      "tag": "vless-tls-in",
      "users": [
        {
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "transport": {
        "type": "tls",
        "server_name": "$DOMAIN", 
        "certificate_path": "$CRT_FILE", 
        "key_path": "$KEY_FILE" 
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

echo "配置 systemd 服务..."
cat <<EOF | sudo tee /etc/systemd/system/singbox.service > /dev/null
[Unit]
Description=Sing-box Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/anytls/singbox run
WorkingDirectory=/usr/local/anytls
Restart=on-failure
StandardOutput=append:/var/log/singbox.log
StandardError=append:/var/log/singbox.log

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable singbox
sudo systemctl restart singbox

sleep 2
if systemctl is-active --quiet singbox; then
  echo "singbox 已通过 systemd 启动成功！"
  echo "日志文件位置：/var/log/singbox.log"
  echo "VlESS+TLS节点信息如下，粘贴导入使用"
  echo "================================================================="
  echo -n "vless://${UUID}@${DOMAIN}:${PORT}?encryption=none&flow=xtls-rprx-vision&type=tcp&security=tls#${DOMAIN}" | base64
  echo "================================================================="
else
  echo "singbox 启动失败，请使用 'journalctl -u singbox' 查看详细日志"
  exit 1
fi
