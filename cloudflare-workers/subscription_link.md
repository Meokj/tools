# 使用教程

## 功能概述

本 Worker 用于：

1. 通过访问 URL 获取 GitHub 仓库中的文件（支持 `.txt`, `.yaml`, `.json`）。
2. 阻止常见爬虫访问（通过 User-Agent 黑名单）。
3. 将每次成功访问的记录写入 **Cloudflare KV**。
4. KV 日志保留最近 200 条，每条日志独立存储，便于查看和管理。

---

## 安装与配置

### 1. KV 命名空间

在 Cloudflare Worker 中创建一个 KV 命名空间，命名为 `ACCESS_LOG`。

### 2. Worker 环境变量

| 变量名           | 说明                                      |
| ---------------- | ----------------------------------------- |
| `PREFIX`         | 可选路径前缀，用于 URL 路由               |
| `GITHUB_OWNER`   | GitHub 仓库所有者                          |
| `GITHUB_REPO`    | GitHub 仓库名                               |
| `GITHUB_TOKEN`   | GitHub Personal Access Token（需要权限访问仓库内容） |

---

## URL 使用规则

假设 Worker 部署在 `https://example.com/`：

- 用户访问 `https://example.com/config`  
- Worker 会依次尝试获取：
  - `config.txt`
  - `config.yaml`
  - `config.json`

- 返回第一个存在的文件内容。  

---

## 爬虫阻止规则

Worker 会检查请求的 User-Agent，如果匹配黑名单，则返回 404，不记录日志。  

### 默认黑名单示例

以下 User-Agent 会被阻止访问：
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

