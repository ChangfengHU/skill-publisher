---
name: local-publish-skill
description: >
  当用户说"本地发布 skill"、"同步 skill 到本地"、"local publish skill"、
  "把项目的 skill 同步到所有工具" 时自动触发。
  将项目目录中的 skill 同步到本地多个 AI 工具的 skills 目录（Codex/Cursor/Claude/Gemini/Copilot等）。
---

# 本地发布 Skill（Local Publish Skill）

**将项目目录中的 skill 一键同步到本地多个 AI 工具的 skills 目录。**

## 使用场景

- 在项目中开发了 skill，想同步到本地所有 AI 工具使用
- 快速在本地多个工具间同步最新的 skill 版本
- 团队项目中的 skill 快速部署到本地开发环境

## 用法示例

```
本地发布 skill

把我的 my-awesome-skill 本地发布到所有工具

local publish my-skill to Cursor and Copilot
```

## 交互流程

### 场景 1：未指定 skill
```
用户: 本地发布 skill

AI: 检测到以下 skills：
    1) my-awesome-skill
    2) data-analyzer
    请选择 (输入序号，如: 1 2):

用户: 1

AI: 选择同步到哪些工具：
    1) Codex   2) Cursor   3) Claude   4) Gemini
    5) Antigravity   6) Copilot   7) OpenClaw   8) Agents
    9) 全部
    请输入序号 (如: 2 6 或输入 9):

用户: 9

AI: ✅ 已同步 my-awesome-skill 到所有 8 个工具目录
```

### 场景 2：已指定 skill
```
用户: 本地发布 my-awesome-skill

AI: 选择同步到哪些工具：
    1) Codex   2) Cursor   3) Claude   ...
    
用户: 2 6

AI: ✅ 已同步 my-awesome-skill → Cursor, Copilot
```

## 支持的 AI 工具

| # | 工具 | 目标路径 |
|---|------|---------|
| 1 | Codex | `~/.codex/skills/` |
| 2 | Cursor | `~/.cursor/skills/` |
| 3 | Claude | `~/.claude/skills/` |
| 4 | Gemini | `~/.gemini/skills/` |
| 5 | Antigravity | `~/.gemini/antigravity/skills/` |
| 6 | Copilot | `~/.copilot/skills/` |
| 7 | OpenClaw | `~/.openclaw/workspace/skills/` |
| 8 | Agents | `~/.agents/skills/` |
| 9 | 全部 | — |

## 行为说明

- **同名覆盖**：如果目标位置已存在同名 skill，会直接覆盖
- **一次性同步**：只执行一次复制操作，不会监听文件变化
- **目录创建**：如果目标工具的 skills 目录不存在，会自动创建

## 环境要求

- `cp` 或 `rsync` 命令
- 具有目标目录的写入权限
