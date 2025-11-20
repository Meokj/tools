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

while true; do
    PORT=$((RANDOM % 64512 + 1024))
    if ! netstat -tuln | grep -q ":$PORT\b"; then
        break
    fi
done

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
echo "在powershell中执行如下这条命令，输入服务器密码，通过SSH本地端口转发登录面板，防止信息泄露，面板进行证书和端口设置后请记得防火墙开启该端口"
echo "ssh -v -p $SSH_PORT -L 60000:127.0.0.1:$PORT $USER_NAME@$IP"
echo "登录地址：http://localhost:6000"
echo "用户名：sysadmin"
echo "密码：sysadmin"
echo "================================"
