# 订阅链接

## 功能概述

本 Worker 用于：

1. 通过访问 URL 获取 GitHub 仓库中的文件（支持 `.txt`, `.yaml`, `.json`）。
2. 阻止常见爬虫访问（通过 User-Agent 黑名单）。
3. 将每次成功访问的记录写入 **Cloudflare KV**。
4. KV 日志保留最近 200 条，每条日志独立存储，便于查看和管理。

---

## 安装与配置

### 1. 创建 KV 命名空间

1. 登录 Cloudflare 仪表盘 → Workers → KV → Create namespace  
2. 命名为`ACCESS_LOG`

---

### 2. 在 Worker 中绑定 KV

在 Worker 设置中：

- 找到 **Variables → KV Namespaces**  
- 添加命名空间  
  - **Variable name**: `ACCESS_LOG`  
  - **KV Namespace**: 选择你创建的 `ACCESS_LOG`  

---

### 3. 创建 Worker

粘贴 subscription_link.js 并部署

---

### 4. Worker环境变量设置

| 变量名         | 说明                             |
|----------------|----------------------------------|
| `GITHUB_OWNER` | 用户名           |
| `GITHUB_REPO`  | 仓库名                           |
| `GITHUB_TOKEN` | 需有读取仓库权限   |
| `PREFIX`(可选)       | 匹配请求路径的前缀(如 `/prefix`)|

---

### 5. 请求路径与 GitHub 文件映射表

| 请求 URL 路径         | 映射 GitHub 文件路径                          |
|----------------------|-----------------------------------------------|
| `/prefix/abc`        | `abc.txt` → `abc.yaml` → `abc.json`  |
| `/prefix/path/abc`  | `path/abc.txt` → `path/abc.yaml` → `path/abc.json` |
| `/abc`            | `abc.txt` → `abc.yaml` → `abc.json`  |

> 📌 注：同一目录下请不要有同名文件，否则扩展名会按 `.txt` → `.yaml` → `.json` 顺序依次尝试

---

### 6. 添加自定义域

禁用预览

---

###  7. 爬虫阻止规则

Worker 会检查请求的 User-Agent，如果匹配黑名单，则返回 404，不记录日志。  

---

##  8. 默认黑名单

以下 User-Agent 会被阻止访问:

Mozilla
Chrome
Safari
Opera
Edge
MSIE
Trident
Baiduspider
Yandex
Sogou
360SE
Qihoo
UCBrowser
WebKit
Bing
Googlebot
Yahoo
Bot
Crawler

---

### 9. 查看日志

请在 Workers KV 中选择 ACCESS_LOG 再选择 KV Pairs 查看访问文件成功日志

