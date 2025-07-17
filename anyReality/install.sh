#!/bin/bash
if pgrep -x singbox > /dev/null; then
  echo "singbox 进程存在，准备杀死..."
  echo
  pkill -x singbox
  sleep 2
  if pgrep -x singbox > /dev/null; then
    echo "singbox 进程未退出，强制杀死"
    echo
    pkill -9 -x singbox
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

rm -f sing-box-1.12.0-beta.33-linux-amd64.tar.gz
wget https://github.com/SagerNet/sing-box/releases/download/v1.12.0-beta.33/sing-box-1.12.0-beta.33-linux-amd64.tar.gz
tar -xzvf sing-box-1.12.0-beta.33-linux-amd64.tar.gz && \
mv sing-box-1.12.0-beta.33-linux-amd64 anytls
cd anytls || exit
mv sing-box singbox
chmod +x singbox

REALITY_KEYS=$(./singbox generate reality-keypair)
PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep 'PrivateKey:' | awk '{print $2}')
PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep 'PublicKey:' | awk '{print $2}')
SHORT_ID=$(openssl rand -hex 8)
IP=$(hostname -I | awk '{print $1}')

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
		"listen": "0.0.0.0",
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
	"log": {
		"disabled": false,
		"level": "info",
		"timestamp": true
	}
}
EOF

cat <<- EOF > client.json
{
	"dns": {
		"servers": [{
				"tag": "local",
				"type": "udp",
				"server": "119.29.29.29"
			},
			{
				"tag": "public",
				"type": "https",
				"server": "dns.alidns.com",
				"domain_resolver": "local"
			},
			{
				"tag": "foreign",
				"type": "https",
				"server": "dns.google",
				"domain_resolver": "local"
			},
			{
				"tag": "fakeip",
				"type": "fakeip",
				"inet4_range": "198.18.0.0/15",
				"inet6_range": "fc00::/18"
			}
		],
		"rules": [{
				"clash_mode": "direct",
				"server": "local"
			},
			{
				"clash_mode": "global",
				"server": "fakeip"
			},
			{
				"query_type": "HTTPS",
				"action": "reject"
			},
			{
				"rule_set": [
					"geosite-cn",
					"geosite-steamcn",
					"geosite-apple"
				],
				"server": "local"
			},
			{
				"query_type": [
					"A",
					"AAAA"
				],
				"server": "fakeip",
				"rewrite_ttl": 1
			}
		],
		"final": "foreign",
		"strategy": "ipv4_only",
		"independent_cache": true
	},
	"outbounds": [{
			"tag": "🚀 默认代理",
			"type": "selector",
			"outbounds": [
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "🧠 AI",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "📹 YouTube",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "🍀 Google",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "👨‍💻 Github",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "📲 Telegram",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "🎵 TikTok",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "🎥 Netflix",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "💶 PayPal",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "🎮 Steam",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "🪟 Microsoft",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "🐬 OneDrive",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "🍏 Apple",
			"type": "selector",
			"outbounds": [
				"🎯 全球直连",
				"🚀 默认代理",
				"🐸 手动选择",
				"♻️ 自动选择"
			]
		},
		{
			"tag": "🐠 漏网之鱼",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🎯 全球直连"
			]
		},
		{
			"tag": "🐸 手动选择",
			"type": "selector",
			"outbounds": [
				"anytls-out"
			]
		},
		{
			"tag": "♻️ 自动选择",
			"type": "urltest",
			"outbounds": [
				"anytls-out"
			],
			"interval": "10m",
			"tolerance": 100
		},
		{
			"tag": "🍃 延迟辅助",
			"type": "urltest",
			"outbounds": [
				"🚀 默认代理",
				"🎯 全球直连"
			]
		},
		{
			"tag": "GLOBAL",
			"type": "selector",
			"outbounds": [
				"🚀 默认代理",
				"🧠 AI",
				"📹 YouTube",
				"🍀 Google",
				"👨‍💻 Github",
				"📲 Telegram",
				"🎵 TikTok",
				"🎥 Netflix",
				"💶 PayPal",
				"🎮 Steam",
				"🪟 Microsoft",
				"🐬 OneDrive",
				"🍏 Apple",
				"🐠 漏网之鱼",
				"🐸 手动选择",
				"♻️ 自动选择",
				"🍃 延迟辅助",
				"🎯 全球直连"
			]
		},
		{
			"tag": "🎯 全球直连",
			"type": "direct"
		},
		{
			"type": "anytls",
			"tag": "anytls-out",
			"server": "$IP",
			"server_port": $PORT,
			"password": "$PASSWORD",
			"idle_session_check_interval": "30s",
			"idle_session_timeout": "30s",
			"min_idle_session": 5,
			"tls": {
				"enabled": true,
				"disable_sni": false,
				"server_name": "yahoo.com",
				"insecure": false,
				"utls": {
					"enabled": true,
					"fingerprint": "chrome"
				},
				"reality": {
					"enabled": true,
					"public_key": "$PUBLIC_KEY",
					"short_id": "$SHORT_ID"
				}
			}
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
				"outbound": "🎯 全球直连"
			},
			{
				"clash_mode": "direct",
				"outbound": "🎯 全球直连"
			},
			{
				"clash_mode": "global",
				"outbound": "GLOBAL"
			},
			{
				"rule_set": "geosite-adobe",
				"action": "reject"
			},
			{
				"rule_set": "geosite-ai",
				"outbound": "🧠 AI"
			},
			{
				"rule_set": "geosite-youtube",
				"outbound": "📹 YouTube"
			},
			{
				"rule_set": "geosite-google",
				"outbound": "🍀 Google"
			},
			{
				"rule_set": "geosite-github",
				"outbound": "👨‍💻 Github"
			},
			{
				"rule_set": "geosite-onedrive",
				"outbound": "🐬 OneDrive"
			},
			{
				"rule_set": "geosite-microsoft",
				"outbound": "🪟 Microsoft"
			},
			{
				"rule_set": "geosite-apple",
				"outbound": "🍏 Apple"
			},
			{
				"rule_set": "geosite-telegram",
				"outbound": "📲 Telegram"
			},
			{
				"rule_set": "geosite-tiktok",
				"outbound": "🎵 TikTok"
			},
			{
				"rule_set": "geosite-netflix",
				"outbound": "🎥 Netflix"
			},
			{
				"rule_set": "geosite-paypal",
				"outbound": "💶 PayPal"
			},
			{
				"rule_set": "geosite-steamcn",
				"outbound": "🎯 全球直连"
			},
			{
				"rule_set": "geosite-steam",
				"outbound": "🎮 Steam"
			},
			{
				"rule_set": "geosite-!cn",
				"outbound": "🚀 默认代理"
			},
			{
				"rule_set": "geosite-cn",
				"outbound": "🎯 全球直连"
			},
			{
				"rule_set": "geoip-google",
				"outbound": "🍀 Google"
			},
			{
				"rule_set": "geoip-apple",
				"outbound": "🍏 Apple"
			},
			{
				"rule_set": "geoip-telegram",
				"outbound": "📲 Telegram"
			},
			{
				"rule_set": "geoip-netflix",
				"outbound": "🎥 Netflix"
			},
			{
				"rule_set": "geoip-cn",
				"outbound": "🎯 全球直连"
			}
		],
		"rule_set": [{
				"tag": "geosite-adobe",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://github.com/qljsyph/ruleset-icon/raw/refs/heads/main/sing-box/geosite/adobe.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-ai",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://github.com/qljsyph/ruleset-icon/raw/refs/heads/main/sing-box/geosite/ai-domain.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-youtube",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/youtube.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-google",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/google.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-github",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/github.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-onedrive",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/onedrive.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-microsoft",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/microsoft.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-apple",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/apple.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-telegram",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/telegram.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-tiktok",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/tiktok.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-netflix",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/netflix.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-paypal",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/paypal.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-steamcn",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/steam@cn.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-steam",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/steam.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-!cn",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/geolocation-!cn.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geosite-cn",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/cn.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geoip-google",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geoip/google.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geoip-apple",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geoip/apple.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geoip-telegram",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geoip/telegram.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geoip-netflix",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geoip/netflix.srs",
				"download_detour": "🎯 全球直连"
			},
			{
				"tag": "geoip-cn",
				"type": "remote",
				"format": "binary",
				"url": "https://gh-proxy.com/https://github.com/qljsyph/ruleset-icon/raw/refs/heads/main/sing-box/geoip/China-ASN-combined-ip.srs",
				"download_detour": "🎯 全球直连"
			}
		],
		"final": "🐠 漏网之鱼",
		"auto_detect_interface": true,
		"default_domain_resolver": {
			"server": "public"
		}
	},
	"inbounds": [{
			"tag": "tun-in",
			"type": "tun",
			"address": [
				"172.19.0.1/30",
				"fdfe:dcba:9876::1/126"
			],
			"mtu": 9000,
			"auto_route": true,
			"auto_redirect": false,
			"strict_route": true
		},
		{
			"tag": "mixed-in",
			"type": "mixed",
			"listen": "0.0.0.0",
			"listen_port": 7893
		}
	],
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
  echo "客户端配置文件路径： /usr/local/anytls/client.json"
  echo
else
  echo "singbox 启动失败，请使用 'journalctl -u singbox' 查看详细日志"
  exit 1
fi
