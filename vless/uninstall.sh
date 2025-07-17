#!/bin/bash
clear
if pgrep -x singbox > /dev/null; then
  echo "正在停止 singbox-vless 进程..."
  pkill -x singbox-vless
  sleep 2
  if pgrep singbox-vless> /dev/null; then
    echo "singbox-vless未正常退出，尝试强制结束..."
    pkill -9 -x singbox-vless
  fi
else
  echo "未检测到 singbox-vless正在运行"
fi

if systemctl list-units --full -all | grep -q singbox-vless.service; then
  echo "停止并禁用 systemd 服务..."
  sudo systemctl stop singbox-vless
  sudo systemctl disable singbox-vless
  sudo rm -f /etc/systemd/system/singbox-vless.service
  sudo systemctl daemon-reload
fi

if [ -d /usr/local/vless ]; then
  echo "删除安装目录 /usr/local/vless..."
  sudo rm -rf /usr/local/vless
fi

if [ -f /var/log/singbox-vless.log ]; then
  echo "删除日志文件 /var/log/singbox-vless.log..."
  sudo rm -f /var/log/singbox-vless.log
fi

echo "singbox-vless卸载完成。"
