#!/bin/bash
set -e
clear
echo "如果安装的有防火墙，请先放行80端口，并且保证80端口未被占用"

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif command -v lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    else
        echo "无法确定操作系统类型，请手动安装依赖项。"
        exit 1
    fi
}

get_user_input() {
    read -p "请输入二级域名: " DOMAIN
    read -p "请输入电子邮件地址: " EMAIL
}

choose_ca() {
    echo "请选择要使用的证书颁发机构 (CA):"
    echo "1) Let's Encrypt"
    echo "2) Buypass"
    echo "3) ZeroSSL"
    read -p "输入选项 (1, 2, or 3): " CA_OPTION

    case $CA_OPTION in
        1)
            CA_SERVER="letsencrypt"
            ;;
        2)
            CA_SERVER="buypass"
            ;;
        3)
            CA_SERVER="zerossl"
            ;;
        *)
            echo "无效选项"
            exit 1
            ;;
    esac
}

install_dependencies() {
    case $OS in
        ubuntu|debian)
            sudo apt update
            sudo apt upgrade -y
            sudo apt install -y curl socat git
            ;;
        centos)
            sudo yum update -y
            sudo yum install -y curl socat git
            ;;
        *)
            echo "不支持的操作系统：$OS"
            exit 1
            ;;
    esac
}

install_acme() {
    curl https://get.acme.sh | sh
    export PATH="$HOME/.acme.sh:$PATH"
    chmod +x "$HOME/.acme.sh/acme.sh"
}

register_account() {
    acme.sh --register-account -m $EMAIL --server $CA_SERVER
}

issue_certificate() {
    acme.sh --issue --standalone -d $DOMAIN --server $CA_SERVER
}

install_certificate() {
    ~/.acme.sh/acme.sh --installcert -d $DOMAIN \
        --key-file       /root/${DOMAIN}.key \
        --fullchain-file /root/${DOMAIN}.crt
    echo "SSL证书和私钥已生成:"
    echo "证书: /root/${DOMAIN}.crt"
    echo "私钥: /root/${DOMAIN}.key"
}

create_renew_script() {
    cat << EOF > /root/renew_cert.sh
#!/bin/bash
export PATH="\$HOME/.acme.sh:\$PATH"
acme.sh --renew -d $DOMAIN --server $CA_SERVER
EOF
    chmod +x /root/renew_cert.sh
}

create_cron_job() {
    (crontab -l 2>/dev/null; echo "0 0 * * * /root/renew_cert.sh > /dev/null") | crontab -
}

main() {
    check_os
    get_user_input
    choose_ca
    install_dependencies
    install_acme
    register_account
    issue_certificate
    install_certificate
    create_renew_script
    create_cron_job
}

main
