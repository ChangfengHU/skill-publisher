# 🚀 Skill Publisher

**一句话将本地 skill 打包发布，生成可在任意机器上一键安装的 bash 命令。**

---

## ⚡ 安装 publish-skill

```bash
bash <(curl -fsSL https://images-uii41p.vyibc.com/install-publish-skill.sh)
```

安装后，对 AI 说：
```
把我的 allocate-domain skill 发布出去
```

---

## 工作原理

```
用户说：把我的 my-skill 发布出去
         ↓
1. 找到 ~/.codex/skills/my-skill/ 下所有文件
2. 生成自包含安装脚本（base64 内嵌所有文件）
3. 上传到 https://images-uii41p.vyibc.com/ → 得到 raw URL
4. 同时生成 HTML 文档页面
5. 返回一键安装命令
         ↓
bash <(curl -fsSL https://images-uii41p.vyibc.com/install-my-skill.sh)
```

---

## 命令行直接使用

```bash
# 安装 publish-skill
bash <(curl -fsSL https://images-uii41p.vyibc.com/install-publish-skill.sh)

# 发布任意 skill
bash ~/.codex/skills/publish-skill/scripts/publish-skill.sh <skill-name>

# 环境变量
FILE_API_URL=http://165.154.134.82:1002  # 文件托管服务
DOCS_API_URL=http://165.154.134.82:1002  # 文档页面服务
```

---

## 安装的 skill 支持哪些工具

生成的安装命令支持选择安装到：

| 工具 | 路径 |
|------|------|
| Codex | `~/.codex/skills/` |
| Cursor | `~/.cursor/skills/` |
| Claude | `~/.claude/plugins/` |
| Gemini | `~/.gemini/skills/` |
| Antigravity | `~/.gemini/antigravity/knowledge/` |
| Copilot | `~/.github-copilot/skills/` |
