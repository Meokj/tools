#!/bin/bash
clear
mkdir -p /usr/local/h-ui/
curl -fsSL https://github.com/jonssonyan/h-ui/releases/latest/download/h-ui-linux-amd64 -o /usr/local/h-ui/h-ui && chmod +x /usr/local/h-ui/h-ui
curl -fsSL https://raw.githubusercontent.com/jonssonyan/h-ui/main/h-ui.service -o /etc/systemd/system/h-ui.service
sed -i "s|^ExecStart=.*|ExecStart=/usr/local/h-ui/h-ui -p 6812|" "/etc/systemd/system/h-ui.service"
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
echo
echo "登录方式：IP:PORT"
echo "面板端口：6812"
echo "用户名：sysadmin"
echo "密码：sysadmin"
echo
