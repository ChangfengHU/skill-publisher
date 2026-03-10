# 🚀 Skill Publisher

**一句话将本地 AI skill 打包发布，生成可在任意机器一键安装的 bash 命令。**

就像 `npx` 之于 npm 包，`publish-skill` 让你的 AI skill 可以被任何人一键安装。

---

## ⚡ 一键安装 publish-skill

```bash
bash <(curl -fsSL https://skills.vyibc.com/install-publish-skill.sh)
```

安装完成后，直接对你的 AI 说：

```
把我的 my-skill 发布出去
```

AI 会自动打包、上传，返回一条安装命令：

```bash
bash <(curl -fsSL https://skills.vyibc.com/install-my-skill.sh)
```

把这条命令分享给任何人，他们就能在自己的机器上一键安装你的 skill。

---

## 工作原理

```
你说：把我的 my-skill 发布出去
         ↓
1. 在本机查找 skill 目录
   (~/.codex/skills/  ~/.cursor/skills/  ~/.copilot/skills/ 等)
2. 打包成 my-skill-<timestamp>.zip 上传到 skills.vyibc.com
3. 生成安装脚本 install-my-skill.sh 上传到 skills.vyibc.com
4. 输出一键安装命令
         ↓
bash <(curl -fsSL https://skills.vyibc.com/install-my-skill.sh)
```

安装脚本运行时：下载 zip → 解压 → 复制到目标 AI 工具的 skills 目录

---

## 支持的 AI 工具

安装时会弹出菜单，选择安装到哪个工具：

| # | 工具 | 安装路径 |
|---|------|---------|
| 1 | Codex | `~/.codex/skills/<name>/` |
| 2 | Cursor | `~/.cursor/skills/<name>/` |
| 3 | Claude | `~/.claude/plugins/<name>/skills/<name>/` |
| 4 | Gemini | `~/.gemini/skills/<name>/` |
| 5 | Antigravity | `~/.gemini/antigravity/knowledge/<name>/` |
| 6 | Copilot | `~/.copilot/skills/<name>/` |
| 7 | 全部安装 | — |

---

## 命令行直接使用

不依赖 AI，直接运行脚本：

```bash
# 发布指定 skill（自动在常见路径下查找）
bash ~/.codex/skills/publish-skill/scripts/publish-skill.sh <skill-name>

# 指定 skill 目录
bash ~/.codex/skills/publish-skill/scripts/publish-skill.sh <skill-name> /path/to/skill

# 自定义文件服务器
FILE_API_URL=http://your-server:1002 bash publish-skill.sh <skill-name>
```

---

## 兼容性

| 环境 | 支持 |
|------|------|
| macOS | ✅ |
| Linux | ✅ |
| Windows (Git Bash / WSL) | ✅ |
| Windows 原生 cmd/PowerShell | ❌ |

解压依赖：优先使用 `unzip`，自动回退到 `python3 -m zipfile`（无需额外安装）。

---

## 相关项目

- [auto-domain](https://github.com/ChangfengHU/auto-domain) — 自动分配域名 skill，本项目即用它发布
