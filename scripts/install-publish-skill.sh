#!/usr/bin/env bash
# 一键安装 publish-skill 到本机
# 用法: bash <(curl -fsSL https://skill.vyibc.com/install-publish-skill.sh)
#       bash <(curl -fsSL ...) --target codex|cursor|claude|gemini|antigravity|copilot|openclaw|agents|hermes|all

set -euo pipefail
FILE_API="https://upload.vyibc.com"
SKILL_NAME="publish-skill"
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

# ── 交互菜单（未指定 --target 时显示）────────────────────
if [[ -z "$TARGET" ]]; then
  echo ""
  echo "🛠  选择安装 publish-skill 到哪个 AI 工具："
  echo ""
  echo "  1) Codex        (~/.codex/skills/)"
  echo "  2) Cursor       (~/.cursor/skills/)"
  echo "  3) Claude       (~/.claude/skills/)"
  echo "  4) Gemini       (~/.gemini/skills/)"
  echo "  5) Antigravity  (~/.gemini/antigravity/skills/)"
  echo "  6) Copilot      (~/.copilot/skills/)"
  echo "  7) OpenClaw     (~/.openclaw/workspace/skills/)"
  echo "  8) Agents       (~/.agents/skills/)"
  echo "  9) Hermes       (~/.hermes/skills/devops/)"
  echo " 10) 全部安装"
  echo ""
  read -rp "请输入编号 [1-10]: " CHOICE
  case "$CHOICE" in
    1) TARGET="codex"       ;;
    2) TARGET="cursor"      ;;
    3) TARGET="claude"      ;;
    4) TARGET="gemini"      ;;
    5) TARGET="antigravity" ;;
    6) TARGET="copilot"     ;;
    7) TARGET="openclaw"    ;;
    8) TARGET="agents"      ;;
    9) TARGET="hermes"      ;;
   10) TARGET="all"         ;;
    *) echo "❌ 无效选项"; exit 1 ;;
  esac
fi

# ── 各工具 skill 目录映射 ─────────────────────────────────
skill_dir() {
  case "$1" in
    codex)       echo "$HOME/.codex/skills/$SKILL_NAME" ;;
    cursor)      echo "$HOME/.cursor/skills/$SKILL_NAME" ;;
    claude)      echo "$HOME/.claude/skills/$SKILL_NAME" ;;
    gemini)      echo "$HOME/.gemini/skills/$SKILL_NAME" ;;
    antigravity) echo "$HOME/.gemini/antigravity/skills/$SKILL_NAME" ;;
    copilot)     echo "$HOME/.copilot/skills/$SKILL_NAME" ;;
    openclaw)    echo "$HOME/.openclaw/workspace/skills/$SKILL_NAME" ;;
    agents)      echo "$HOME/.agents/skills/$SKILL_NAME" ;;
    hermes)      echo "$HOME/.hermes/skills/devops/$SKILL_NAME" ;;
  esac
}

install_to() {
  local tool="$1"
  local dir
  dir=$(skill_dir "$tool")
  mkdir -p "$dir/agents" "$dir/scripts"

  # SKILL.md
  cat > "$dir/SKILL.md" << 'SKILL_EOF'
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
bash <(curl -fsSL https://skill.vyibc.com/install-allocate-domain.sh)

📄 文档页面（可分享给他人查看）：
https://skill.vyibc.com/abc123.html

💡 使用方式：
  复制上方命令，在任意机器上执行即可安装该 skill
```

## 工作流程

```
用户说：把我的 my-skill 发布出去
         ↓
1. 找到本地 skill 目录（~/.codex/skills/my-skill/）
2. 生成/校验 sop-skill-contract.json sidecar（不改变 skill 本身执行）
3. 打包成 zip 文件并上传到 skill.vyibc.com
4. 生成安装脚本（下载 zip -> 解压 -> 安装到目标工具）并上传
5. 调用 documents:toPage 生成可分享的文档页
6. 返回 bash <(curl -fsSL https://skill.vyibc.com/install-my-skill.sh) 命令
```

## SOP Skill Contract

发布脚本会默认在打包副本中生成 `sop-skill-contract.json`。这个文件是
SOP Node Builder / A2A Runtime 的旁路元数据，普通 agent 可以忽略它。

核心约束：

- Node 公开入参固定为 `instruction + materials`。
- CLI 参数、URL、token、输出目录等只作为内部 adapter hints。
- 输出统一按 `SOP_OUTPUT_DIR` + `manifest.json` / artifacts 发现。
- 不把任何密钥值写进 contract。

## 环境要求

- `zip`
- `python3`
- `curl`
- 网络连接

## 路径限制

- 默认只会从受支持工具的 skill 目录中查找和发布
- 如果手动传入第二个参数，路径也必须落在这些目录内
- 只有显式设置 `ALLOW_EXTERNAL_SKILL_DIR=1` 时，才允许从仓库目录等外部路径发布
SKILL_EOF

  # agents/openai.yaml — 脚本路径自适应，搜索所有工具目录
  cat > "$dir/agents/openai.yaml" << 'AGENT_EOF'
interface:
  display_name: "Publish Skill"
  short_description: "一句话将本地 skill 打包发布，生成可在任意机器一键安装的 bash 命令。"
  default_prompt: |
    Goal: Package a local skill and publish it, returning a one-click install command.

    ## Step 1: Find the publish-skill script

    Search for the script in all possible install locations:
    ```
    for p in \
      "$HOME/.codex/skills/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.cursor/skills/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.claude/skills/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.gemini/skills/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.gemini/antigravity/skills/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.copilot/skills/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.openclaw/workspace/skills/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.agents/skills/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.hermes/skills/devops/publish-skill/scripts/publish-skill.sh"; do
      [ -f "$p" ] && SCRIPT="$p" && break
    done
    ```

    ## Step 2: Resolve the skill name

    Run: ls ~/.codex/skills/ ~/.cursor/skills/ ~/.copilot/skills/ ~/.gemini/skills/ ~/.gemini/antigravity/skills/ ~/.claude/skills/ ~/.openclaw/workspace/skills/ ~/.agents/skills/ ~/.hermes/skills/devops/ 2>/dev/null | sort -u
    (Only check these specific directories. DO NOT package the current working directory unless it is inside one of these paths.)

    Matching rules:
    - Exact match → proceed directly
    - One fuzzy match → proceed directly (e.g. "allocate" → "allocate-domain")
    - Multiple matches → list and ask: "找到多个匹配，你要发布哪个？"
    - No match / no name given → list all and ask which one

    ## Step 3: Publish

    Run: bash "$SCRIPT" "<SKILL_NAME>"

    ## Step 4: Show result

    ✅ Skill 发布成功！

    📦 Skill: <SKILL_NAME>

    🚀 一键安装命令：
    ```bash
    bash <(curl -fsSL <INSTALL_URL>)
    ```

    📄 文档页面：<DOC_URL>

    💡 把上方命令发给任何人，在他们的机器上执行即可安装该 skill。

policy:
  allow_implicit_invocation: true
AGENT_EOF

  # scripts/publish-skill.sh — 从文件服务器拉取
  curl -fsSL "https://skill.vyibc.com/publish-skill-core.sh" \
    -o "$dir/scripts/publish-skill.sh" 2>/dev/null \
    || { echo "  ⚠️  从文件服务器拉取失败"; exit 1; }
  chmod +x "$dir/scripts/publish-skill.sh"

  curl -fsSL "https://skill.vyibc.com/generate-sop-skill-contract.py" \
    -o "$dir/scripts/generate-sop-skill-contract.py" 2>/dev/null \
    || echo "  ⚠️  contract 生成器拉取失败，发布时会跳过 sop-skill-contract.json"
  chmod +x "$dir/scripts/generate-sop-skill-contract.py" 2>/dev/null || true

  echo "  ✅ $tool → $dir"
}

# ── 执行安装 ──────────────────────────────────────────────
echo ""
echo "🚀 安装 publish-skill → $TARGET"
echo ""

if [[ "$TARGET" == "all" ]]; then
  for t in codex cursor claude gemini antigravity copilot openclaw agents hermes; do
    install_to "$t"
  done
else
  install_to "$TARGET"
fi

echo ""
echo "✅ 安装完成！对 AI 说："
echo "   把我的 <skill名称> 发布出去，生成一键安装命令"
echo ""
