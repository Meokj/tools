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
  read -rp "请输入监听端口（443 或 1025~65535）: " PORT
  if [[ "$PORT" =~ ^[0-9]{1,5}$ ]] && { [ "$PORT" -eq 443 ] || ( [ "$PORT" -ge 1025 ] && [ "$PORT" -le 65535 ] ); }; then
    break
  else
    echo "无效端口，请输入 443 或 1025~65535 范围内的数字。"
  fi
done

while true; do
  read -r -p "请输入密码: " PASSWORD
  if [[ -z "$PASSWORD" ]]; then
    echo "密码不能为空，请重新输入。"
  elif [[ "$PASSWORD" =~ [[:space:]] ]]; then
    echo "密码不能包含空格，请重新输入。"
  else
    break
  fi
done

cd /usr/local || exit
if [ -d anytls ]; then
  rm -rf anytls
fi

rm -f sing-box-1.12.0-beta.30-linux-amd64.tar.gz
wget https://github.com/SagerNet/sing-box/releases/download/v1.12.0-beta.30/sing-box-1.12.0-beta.30-linux-amd64.tar.gz
tar -xzvf sing-box-1.12.0-beta.30-linux-amd64.tar.gz && \
mv sing-box-1.12.0-beta.30-linux-amd64 anytls
cd anytls || exit
mv sing-box singbox
chmod +x singbox

REALITY_KEYS=$(./singbox generate reality-keypair)
PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep 'PrivateKey:' | awk '{print $2}')
PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep 'PublicKey:' | awk '{print $2}')
SHORT_ID=$(openssl rand -hex 8)

cat <<- EOF > config.json
{
	"dns": {
		"servers": [{
				"tag": "google",
				"type": "udp",
				"server": "8.8.8.8"
			},
			{
				"tag": "cloudflare",
				"type": "udp",
				"server": "1.1.1.1"
			}
		],
		"rules": [{
				"query_type": "HTTPS",
				"action": "reject"
			},
			{
				"query_type": [
					"A",
					"AAAA"
				],
				"server": "cloudflare"
			}
		],
		"final": "cloudflare",
		"strategy": "ipv4_only"
	},
	"inbounds": [{
		"type": "anytls",
		"listen": "::",
		"listen_port": $PORT,
		"users": [{
			"name": "user",
			"password": "$PASSWORD"
		}],
		"padding_scheme": [
			"stop=8",
			"0=30-30",
			"1=100-400",
			"2=400-500,c,500-1000,c,500-1000,c,500-1000,c,500-1000",
			"3=9-9,500-1000",
			"4=500-1000",
			"5=500-1000",
			"6=500-1000",
			"7=500-1000"
		],
		"tls": {
			"enabled": true,
			"server_name": "yahoo.com",
			"reality": {
				"enabled": true,
				"handshake": {
					"server": "yahoo.com",
					"server_port": 443
				},
				"private_key": "$PRIVATE_KEY",
				"short_id": "$SHORT_ID"
			}
		}
	}],
	"outbounds": [{
			"tag": "代理出站",
			"type": "selector",
			"outbounds": [
				"直接出站"
			]
		},
		{
			"tag": "直接出站",
			"type": "direct"
		}
	],
	"route": {
		"rules": [{
				"action": "sniff",
				"sniffer": [
					"http",
					"tls",
					"quic",
					"dns"
				]
			},
			{
				"type": "logical",
				"mode": "or",
				"rules": [{
						"port": 53
					},
					{
						"protocol": "dns"
					}
				],
				"action": "hijack-dns"
			},
			{
				"ip_is_private": true,
				"outbound": "直接出站"
			},
			{
				"rule_set": "geosite-ai",
				"outbound": "代理出站"
			}
		],
		"rule_set": [{
			"tag": "geosite-ai",
			"type": "remote",
			"format": "binary",
			"url": "https://github.com/qljsyph/ruleset-icon/raw/refs/heads/main/sing-box/geosite/ai-domain.srs",
			"download_detour": "直接出站"
		}],
		"final": "直接出站",
		"auto_detect_interface": true,
		"default_domain_resolver": {
			"server": "cloudflare"
		}
	},
	"experimental": {
		"cache_file": {
			"enabled": true,
			"path": "/usr/local/anytls/cache.db"
		}
	},
	"log": {
		"disabled": false,
		"level": "info",
		"timestamp": true
	}
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
  echo
  echo "-----------------------------------"
  echo "📌 监听端口     : $PORT"
  echo "🔑 密码         : $PASSWORD"
  echo "🔐 Reality 公钥  : $PUBLIC_KEY"
  echo "🔐 Short ID   : $SHORT_ID"
  echo "-----------------------------------"
  echo
else
  echo "singbox 启动失败，请使用 'journalctl -u singbox' 查看详细日志"
  exit 1
fi
