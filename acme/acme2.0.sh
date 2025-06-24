#!/bin/bash
# Author: Content sourced from the internet

# 确保脚本在遇到错误时退出
set -e
clear

# 检查系统是否安装 ufw
check_ufw() {
    if ! command -v ufw >/dev/null 2>&1; then
        echo "警告: 未检测到 ufw 防火墙工具，无法执行 ufw 相关命令。"
        return 1  # 返回1表示没有安装 ufw
    fi
    return 0  # 返回0表示 ufw 存在
}

# 检查系统类型
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

# 提示用户输入二级域名和电子邮件地址
get_user_input() {
    read -p "请输入二级域名: " DOMAIN
    read -p "请输入电子邮件地址: " EMAIL
}

# 显示证书颁发机构选择菜单
choose_ca() {
    echo "请选择要使用的证书颁发机构 (CA):"
    echo "1) Let's Encrypt"
    echo "2) Buypass"
    echo "3) ZeroSSL"
    read -p "输入选项 (1, 2, or 3): " CA_OPTION

    # 根据用户选择设置CA参数
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

# 提示用户防火墙配置
firewall_setup() {
    echo "是否关闭防火墙？"
    echo "1) 是"
    echo "2) 否"
    read -p "输入选项 (1 或 2): " FIREWALL_OPTION

    # 如果用户选择不关闭防火墙，提示用户是否放行端口
    if [ "$FIREWALL_OPTION" -eq 2 ]; then
        echo "是否放行特定端口？"
        echo "1) 是"
        echo "2) 否"
        read -p "输入选项 (1 或 2): " PORT_OPTION

        # 如果用户选择放行端口，提示用户输入端口号
        if [ "$PORT_OPTION" -eq 1 ]; then
            read -p "请输入要放行的端口号: " PORT
        fi
    fi
}

# 安装依赖项并配置防火墙
install_dependencies() {
    case $OS in
        ubuntu|debian)
            sudo apt update
            sudo apt upgrade -y
            sudo apt install -y curl socat git
            if [ "$FIREWALL_OPTION" -eq 1 ]; then
                check_ufw && sudo ufw disable
            elif [ "$PORT_OPTION" -eq 1 ]; then
                check_ufw && sudo ufw allow $PORT
            fi
            ;;
        centos)
            sudo yum update -y
            sudo yum install -y curl socat git
            if [ "$FIREWALL_OPTION" -eq 1 ]; then
                sudo systemctl stop firewalld
                sudo systemctl disable firewalld
            elif [ "$PORT_OPTION" -eq 1 ]; then
                sudo firewall-cmd --permanent --add-port=${PORT}/tcp
                sudo firewall-cmd --reload
            fi
            ;;
        *)
            echo "不支持的操作系统：$OS"
            exit 1
            ;;
    esac
}

# 安装 acme.sh 脚本
install_acme() {
    curl https://get.acme.sh | sh

    # 使 acme.sh 脚本可用
    export PATH="$HOME/.acme.sh:$PATH"

    # 添加执行权限
    chmod +x "$HOME/.acme.sh/acme.sh"
}

# 注册帐户
register_account() {
    acme.sh --register-account -m $EMAIL --server $CA_SERVER
}

# 申请 SSL 证书
issue_certificate() {
    acme.sh --issue --standalone -d $DOMAIN --server $CA_SERVER
}

# 安装 SSL 证书
install_certificate() {
    ~/.acme.sh/acme.sh --installcert -d $DOMAIN \
        --key-file       /root/${DOMAIN}.key \
        --fullchain-file /root/${DOMAIN}.crt

    # 提示用户证书已生成
    echo "SSL证书和私钥已生成:"
    echo "证书: /root/${DOMAIN}.crt"
    echo "私钥: /root/${DOMAIN}.key"
}

# 创建自动续期脚本
create_renew_script() {
    cat << EOF > /root/renew_cert.sh
#!/bin/bash
export PATH="\$HOME/.acme.sh:\$PATH"
acme.sh --renew -d $DOMAIN --server $CA_SERVER
EOF
    chmod +x /root/renew_cert.sh
}

# 创建自动续期的 cron 任务
create_cron_job() {
    (crontab -l 2>/dev/null; echo "0 0 * * * /root/renew_cert.sh > /dev/null") | crontab -
}

# 主函数调用顺序
main() {
    check_os
    get_user_input
    choose_ca
    firewall_setup
    install_dependencies
    install_acme
    register_account
    issue_certificate
    install_certificate
    create_renew_script
    create_cron_job
}

# 执行主函数
main
