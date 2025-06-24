#!/bin/bash
clear
systemctl stop h-ui
RESTART_HUI="/usr/local/h-ui/restart-hui.sh"
echo "正在删除 crontab 中的定时任务..."
(crontab -l 2>/dev/null | grep -v "$RESTART_HUI") | crontab -
rm -rf /etc/systemd/system/h-ui.service /usr/local/h-ui/
echo "卸载成功!!!"
