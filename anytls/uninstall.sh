#!/bin/bash
clear
if pgrep singbox > /dev/null; then
  echo "正在停止 singbox 进程..."
  pkill singbox
  sleep 2
  if pgrep singbox > /dev/null; then
    echo "singbox 未正常退出，尝试强制结束..."
    pkill -9 singbox
  fi
else
  echo "未检测到 singbox 正在运行"
fi

if systemctl list-units --full -all | grep -q singbox.service; then
  echo "停止并禁用 systemd 服务..."
  sudo systemctl stop singbox
  sudo systemctl disable singbox
  sudo rm -f /etc/systemd/system/singbox.service
  sudo systemctl daemon-reload
fi

if [ -d /usr/local/anytls ]; then
  echo "删除安装目录 /usr/local/anytls..."
  sudo rm -rf /usr/local/anytls
fi

if [ -f /var/log/singbox.log ]; then
  echo "删除日志文件 /var/log/singbox.log..."
  sudo rm -f /var/log/singbox.log
fi

echo "singbox 卸载完成。"
