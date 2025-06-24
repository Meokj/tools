## 📖 说明
根据请求路径从 GitHub 私有仓库中返回 `.txt`、`.yaml` 或 `.json` 文件内容，屏蔽常见浏览器和爬虫访问

---

## 📦 部署方式

1. 登录 Cloudflare
2. 创建一个新的 Worker
3. 将代码粘贴进去
4. 配置环境变量（Settings > Variables > Type > Secret）
6. 保存并部署
7. 设置自定义域

## 🛠 环境变量设置

| 变量名         | 说明                             |
|----------------|----------------------------------|
| `GITHUB_OWNER` | 用户名           |
| `GITHUB_REPO`  | 仓库名                           |
| `GITHUB_TOKEN` | 需有读取仓库权限   |
| `PREFIX`(可选)       | 匹配请求路径的前缀(如 `/prefix`)|

## 🌐 请求路径与 GitHub 文件映射表

| 请求 URL 路径         | 映射 GitHub 文件路径                          |
|----------------------|-----------------------------------------------|
| `/prefix/abc`        | `abc.txt` → `abc.yaml` → `abc.json`  |
| `/prefix/path/abc`  | `path/abc.txt` → `path/abc.yaml` → `path/abc.json` |
| `/abc`            | `abc.txt` → `abc.yaml` → `abc.json`  |

> 📌 注：同一目录下请不要有同名文件，否则扩展名会按 `.txt` → `.yaml` → `.json` 顺序依次尝试
