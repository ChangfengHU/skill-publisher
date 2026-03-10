#!/usr/bin/env bash
# 一键安装 publish-skill 到本机
# 用法: bash <(curl -fsSL https://images-uii41p.vyibc.com/install-publish-skill.sh)
#       bash <(curl -fsSL ...) --target codex|cursor|claude|gemini|antigravity|copilot|all

set -euo pipefail
FILE_API="http://165.154.134.82:1002"
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
  echo "  3) Claude       (~/.claude/plugins/)"
  echo "  4) Gemini       (~/.gemini/skills/)"
  echo "  5) Antigravity  (~/.gemini/antigravity/knowledge/)"
  echo "  6) Copilot      (~/.copilot/skills/)"
  echo "  7) 全部安装"
  echo ""
  read -rp "请输入编号 [1-7]: " CHOICE
  case "$CHOICE" in
    1) TARGET="codex"       ;;
    2) TARGET="cursor"      ;;
    3) TARGET="claude"      ;;
    4) TARGET="gemini"      ;;
    5) TARGET="antigravity" ;;
    6) TARGET="copilot"     ;;
    7) TARGET="all"         ;;
    *) echo "❌ 无效选项"; exit 1 ;;
  esac
fi

# ── 各工具 skill 目录映射 ─────────────────────────────────
skill_dir() {
  case "$1" in
    codex)       echo "$HOME/.codex/skills/$SKILL_NAME" ;;
    cursor)      echo "$HOME/.cursor/skills/$SKILL_NAME" ;;
    claude)      echo "$HOME/.claude/plugins/$SKILL_NAME/skills/$SKILL_NAME" ;;
    gemini)      echo "$HOME/.gemini/skills/$SKILL_NAME" ;;
    antigravity) echo "$HOME/.gemini/antigravity/knowledge/$SKILL_NAME" ;;
    copilot)     echo "$HOME/.copilot/skills/$SKILL_NAME" ;;
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
      "$HOME/.claude/plugins/publish-skill/skills/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.gemini/skills/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.gemini/antigravity/knowledge/publish-skill/scripts/publish-skill.sh" \
      "$HOME/.copilot/skills/publish-skill/scripts/publish-skill.sh"; do
      [ -f "$p" ] && SCRIPT="$p" && break
    done
    ```

    ## Step 2: Resolve the skill name

    Run: ls ~/.codex/skills/ ~/.cursor/skills/ 2>/dev/null | sort -u

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
  curl -fsSL "https://images-uii41p.vyibc.com/publish-skill-core.sh" \
    -o "$dir/scripts/publish-skill.sh" 2>/dev/null \
    || { echo "  ⚠️  从文件服务器拉取失败"; exit 1; }
  chmod +x "$dir/scripts/publish-skill.sh"

  echo "  ✅ $tool → $dir"
}

# ── 执行安装 ──────────────────────────────────────────────
echo ""
echo "🚀 安装 publish-skill → $TARGET"
echo ""

if [[ "$TARGET" == "all" ]]; then
  for t in codex cursor claude gemini antigravity copilot; do
    install_to "$t"
  done
else
  install_to "$TARGET"
fi

echo ""
echo "✅ 安装完成！对 AI 说："
echo "   把我的 <skill名称> 发布出去，生成一键安装命令"
echo ""
