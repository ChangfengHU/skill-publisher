---
name: local-sync-skill
description: >
  当用户说"同步 skill 到其他工具"、"广播 skill"、"sync skill to other tools"、
  "把我的 skill 同步给所有 AI 工具" 时自动触发。
  在多个 AI 工具的 skills 目录之间同步 skill，当某个工具的 skill 更新后，可快速同步到其他工具。
---

# 本地同步 Skill（Local Sync Skill）

**在多个 AI 工具的 skills 目录之间同步 skill，保持所有工具的 skill 版本一致。**

## 使用场景

- 在 Codex 中修改了某个 skill，想同步到 Cursor、Copilot 等其他工具
- 保持多个 AI 工具的 skill 库同步更新
- 快速将某个工具的最新 skill 广播给其他所有工具

## 用法示例

```
同步 skill 到其他工具

把我的 my-skill 广播给所有 AI 工具

sync my skills to other tools
```

## 交互流程

### 自动识别当前工具
```
用户: 同步 skill 到其他工具

AI: 检测到当前环境: Codex
    从 ~/.codex/skills/ 同步到其他工具
    
    发现以下 skills:
    1) my-awesome-skill
    2) data-analyzer
    3) code-reviewer
    
    请选择要同步的 skill (输入序号，如: 1 3):

用户: 1 2

AI: 选择同步到哪些工具：
    1) Cursor   2) Claude   3) Gemini   4) Antigravity
    5) Copilot   6) OpenClaw   7) Agents   8) 全部 (除 Codex 外)
    
用户: 8

AI: ✅ my-awesome-skill → Cursor, Claude, Gemini, ...
    ✅ data-analyzer → Cursor, Claude, Gemini, ...
    
    同步完成: 14/14 成功
```

## 支持的 AI 工具

| # | 工具 | Skills 目录 |
|---|------|---------|
| 1 | Codex | `~/.codex/skills/` |
| 2 | Cursor | `~/.cursor/skills/` |
| 3 | Claude | `~/.claude/skills/` |
| 4 | Gemini | `~/.gemini/skills/` |
| 5 | Antigravity | `~/.gemini/antigravity/skills/` |
| 6 | Copilot | `~/.copilot/skills/` |
| 7 | OpenClaw | `~/.openclaw/workspace/skills/` |
| 8 | Agents | `~/.agents/skills/` |

## 工作原理

1. **自动识别来源**：检测当前运行的 AI 工具环境
2. **列出 skills**：显示当前工具的所有 skills
3. **选择目标**：用户选择要同步到哪些工具
4. **执行同步**：复制 skill 到目标工具目录（同名覆盖）

## 与 local-publish-skill 的区别

| 功能 | local-publish-skill | local-sync-skill |
|------|-------------------|------------------|
| 来源 | 项目目录 | AI 工具目录 |
| 目标 | AI 工具目录 | AI 工具目录 |
| 场景 | 开发→部署 | 工具间同步 |
| 识别 | 查找项目根目录 | 识别当前工具 |

## 行为说明

- **同名覆盖**：目标位置存在同名 skill 会直接覆盖
- **一次性同步**：只执行一次复制，不监听变化
- **排除来源**：不会同步回来源工具自己
- **自动创建**：目标目录不存在会自动创建

## 环境要求

- `cp` 命令
- 具有目标目录的写入权限
