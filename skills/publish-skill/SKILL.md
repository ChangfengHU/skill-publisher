---
name: publish-skill
description: >
  当用户说"我想分享我的 skill"、"给我的 skill 生成安装脚本"、"publish skill"、
  "generate install command for my skill"、"把我的 skill 发布出去" 时自动触发。
  一句话为本地任意 skill 生成一键安装命令，对方机器只需执行一行 bash 命令即可安装。
---

# 发布 Skill（Publish Skill）

**一句话将本地 skill 打包发布，生成可在任意机器上一键安装的命令。**

## 使用场景

- 本地开发了一个 skill，想分享给团队成员
- 在新机器上快速复现自己的 skill 环境
- 将 skill 以 `bash <(curl ...)` 命令形式发布

## 用法示例

```
把我的 allocate-domain skill 发布出去，生成安装命令

publish my todo-helper skill

给 my-skill 生成一键安装脚本
```

## 返回结果

```
✅ Skill 发布成功！

📦 Skill: allocate-domain

🚀 一键安装命令：
bash <(curl -fsSL https://gist.githubusercontent.com/xxx/yyy/raw/install-allocate-domain.sh)

📄 文档页面（可分享给他人查看）：
https://skills.vyibc.com/abc123.html

💡 使用方式：
  复制上方命令，在任意机器上执行即可安装该 skill
```

## 工作流程

```
用户说：把我的 my-skill 发布出去
         ↓
1. 找到本地 skill 目录（~/.codex/skills/my-skill/）
2. 读取所有 skill 文件
3. 生成自包含安装脚本（内嵌所有文件内容）
4. 上传到 GitHub Gist → 获得 raw URL
5. 上传到 documents:toPage → 获得 HTML 文档 URL
6. 返回 bash <(curl -fsSL <raw-url>) 命令
```

## 环境要求

- `gh` CLI（GitHub CLI）或 `GITHUB_TOKEN` 环境变量
- `curl`
- 网络连接
