#!/bin/bash
clear
echo "开始卸载 singbox..."

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

if [ -d /usr/local/anytls ]; then
  echo "删除安装目录 /usr/local/anytls..."
  rm -rf /usr/local/anytls
fi

echo "singbox 卸载完成。"
