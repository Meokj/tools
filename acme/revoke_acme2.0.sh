#!/bin/bash
# 注意：请确保你已经成功申请过 SSL 证书，否则撤销操作会失败

set -e

read -p "请输入你要撤销 SSL 证书的二级域名: " DOMAIN

echo "请选择你申请 SSL 证书时使用的证书颁发机构 (CA):"
echo "1) Let's Encrypt"
echo "2) Buypass"
echo "3) ZeroSSL"
read -p "输入选项 (1, 2, or 3): " CA_OPTION

case $CA_OPTION in
    1) CA_SERVER="letsencrypt" ;;
    2) CA_SERVER="buypass" ;;
    3) CA_SERVER="zerossl" ;;
    *) echo "无效选项"; exit 1 ;;
esac

if [ ! -d "$HOME/.acme.sh" ]; then
    echo "未检测到 acme.sh，请检查是否已经安装。"
    exit 1
fi

export PATH="$HOME/.acme.sh:$PATH"

echo "正在撤销 SSL 证书..."
~/.acme.sh/acme.sh --revoke -d "$DOMAIN" --server "$CA_SERVER"

echo "正在删除证书文件..."
rm -f /root/"$DOMAIN".crt /root/"$DOMAIN".key
rm -rf ~/.acme.sh/"$DOMAIN"

echo "正在取消自动续期计划..."
~/.acme.sh/acme.sh --remove -d "$DOMAIN"

if [ -f /root/renew_cert.sh ]; then
    rm -f /root/renew_cert.sh
fi

echo "正在删除自动续期的 crontab 任务..."
crontab -l | grep -v "/root/renew_cert.sh" | crontab -

read -p "是否卸载 acme.sh？(y/n): " REMOVE_ACME
if [[ "$REMOVE_ACME" == "y" || "$REMOVE_ACME" == "Y" ]]; then
    echo "正在卸载 acme.sh..."
    ~/.acme.sh/acme.sh --uninstall
    rm -rf ~/.acme.sh
    echo "acme.sh 已卸载。"
fi

echo "SSL 证书已成功撤销，相关文件和续期任务已清理完毕。"
