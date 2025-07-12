#!/bin/bash
set -e

read -p "你是否熟悉 nftables 防火墙配置？(y/n) " answer
case "$answer" in
    y|Y|yes|YES)
        echo "继续执行脚本。。。"
        ;;
    *)
        echo "退出脚本，请先了解 nftables 防火墙相关知识。"
        exit 1
        ;;
esac

if ! command -v nft >/dev/null 2>&1; then
    echo "nft 命令未找到，尝试安装 nftables ..."
    apt update
    apt install -y nftables
fi

cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f

table inet filter {
    chain INPUT {
        type filter hook input priority filter; policy drop;

        iif "lo" accept
        ct state established,related accept
        tcp dport 22 accept         # SSH默认
        tcp dport 2022 accept       # SSH
        tcp dport 80 accept         # HTTP
        tcp dport 443 accept        # HTTPS

        ip protocol icmp accept     # ICMPv4
        ip6 nexthdr ipv6-icmp accept # ICMPv6

        tcp dport 53 accept         # DNS TCP
        udp dport 53 accept         # DNS UDP

        udp dport 10000-20000 accept  # 端口跳跃范围 UDP

        tcp dport 6812 accept       # 其它自定义端口 
        udp dport 8443 accept      
    }

    chain FORWARD {
        type filter hook forward priority filter; policy drop;
    }

    chain OUTPUT {
        type filter hook output priority filter; policy accept;
    }
}

table ip nat {
    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;

        udp dport 10000-20000 dnat to :8443
    }
}

table ip6 nat {
    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;

        udp dport 10000-20000 dnat to :8443
    }
}
EOF

echo "已写入 /etc/nftables.conf"

nft -f /etc/nftables.conf
echo
echo "注意：nftables 配置已加载，已放行SSH默认端口22"
echo

systemctl enable nftables
systemctl restart nftables
echo "nftables 服务已启用并设置为开机自启"

echo "=============================================="
echo "停用防火墙命令（使规则不生效）:"
echo "    systemctl stop nftables && nft flush ruleset"
echo "启用防火墙命令（加载规则并开机自启）:"
echo "    systemctl enable nftables && systemctl start nftables"
echo "=============================================="

echo
echo "已有规则如下"
nft list ruleset
