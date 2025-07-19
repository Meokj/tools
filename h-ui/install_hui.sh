#!/bin/bash
clear
IP=$(hostname -I | awk '{print $1}')
USER_NAME=$(whoami)
SSH_PORT=$(awk '/^Port/ {print $2}' /etc/ssh/sshd_config)

if ! command -v netstat &> /dev/null; then
    echo "netstat 未安装，正在安装..."
    
    if [ -f /etc/debian_version ]; then
        sudo apt update
        sudo apt install -y net-tools
    else
        echo "不支持的操作系统，无法安装 netstat"
        exit 1
    fi
fi

read -p "请输入自定义面板端口号（1024-65535）：" PORT
if [[ "$PORT" -ge 1024 && "$PORT" -le 65535 ]]; then
    if netstat -tuln | grep -q ":$PORT"; then
        echo "端口 $PORT 已被占用"
        exit 1
    fi
else
    echo "无效的端口号，请输入范围在1024到65535之间的数字"
    exit 1
fi

mkdir -p /usr/local/h-ui/
curl -fsSL https://github.com/jonssonyan/h-ui/releases/latest/download/h-ui-linux-amd64 -o /usr/local/h-ui/h-ui && chmod +x /usr/local/h-ui/h-ui
curl -fsSL https://raw.githubusercontent.com/jonssonyan/h-ui/main/h-ui.service -o /etc/systemd/system/h-ui.service
sed -i "s|^ExecStart=.*|ExecStart=/usr/local/h-ui/h-ui -p $PORT|" "/etc/systemd/system/h-ui.service"
systemctl daemon-reload
systemctl enable h-ui
systemctl restart h-ui
if ! command -v crontab &> /dev/null; then
  echo "cron 未安装，正在安装 cron..."
  sudo apt update > /dev/null 2>&1
  sudo apt install -y cron > /dev/null 2>&1
  sudo systemctl enable cron
  sudo systemctl start cron
fi
RESTART_HUI="/usr/local/h-ui/restart-hui.sh"
cat <<EOF | sudo tee $RESTART_HUI > /dev/null
#!/bin/bash
sudo systemctl restart h-ui
EOF
sudo chmod +x $RESTART_HUI
sudo timedatectl set-timezone Asia/Shanghai
(crontab -l 2>/dev/null; echo "0 4 * * * $RESTART_HUI") | crontab -
echo "h-ui服务安装完成，定时任务已设置为每天凌晨4点重启服务!!!"
echo "================================"
echo "确保防火墙放行了$PORT，在本地终端执行如下这条命令，输入服务器密码，通过SSH本地端口转发登录面板，防止信息泄露"
echo
echo "ssh -p $SSH_PORT -L $PORT:127.0.0.1:$PORT $USER_NAME@$IP"
echo
echo "登录地址：http://localhost:$PORT"
echo "用户名：sysadmin"
echo "密码：sysadmin"
echo "================================"
