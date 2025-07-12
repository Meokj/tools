#!/bin/bash
set -e
cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f

table inet filter {
    chain INPUT {
        type filter hook input priority filter; policy drop;

        iif "lo" accept
        ct state established,related accept

        tcp dport 2022 accept       # SSH
        tcp dport 80 accept         # HTTP
        tcp dport 443 accept        # HTTPS

        ip protocol icmp accept     # ICMPv4
        ip6 nexthdr ipv6-icmp accept # ICMPv6

        tcp dport 53 accept         # DNS TCP
        udp dport 53 accept         # DNS UDP

        tcp dport 10000-20000 accept  # 端口跳跃范围 TCP
        udp dport 10000-20000 accept  # 端口跳跃范围 UDP

        tcp dport 6812 accept       # 其它自定义端口

        tcp dport 8443 accept       
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

        tcp dport 10000-20000 dnat to :8443
        udp dport 10000-20000 dnat to :8443
    }
}

table ip6 nat {
    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;

        tcp dport 10000-20000 dnat to :8443
        udp dport 10000-20000 dnat to :8443
    }
}
EOF

echo "已写入 /etc/nftables.conf"

nft -f /etc/nftables.conf
echo "nftables 配置已加载"

systemctl enable nftables
systemctl restart nftables
echo "nftables 服务已启用并设置为开机自启"

echo "=============================================="
echo "停用防火墙命令（使规则不生效）:"
echo "    sudo systemctl stop nftables && sudo nft flush ruleset"
echo "启用防火墙命令（加载规则并开机自启）:"
echo "    sudo systemctl enable nftables && sudo systemctl start nftables"
echo "=============================================="
