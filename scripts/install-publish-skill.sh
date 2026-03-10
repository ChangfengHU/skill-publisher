#!/usr/bin/env bash
# 一键安装 publish-skill 到本机
# 用法: bash <(curl -fsSL https://images-uii41p.vyibc.com/install-publish-skill.sh) [target]
# target: codex | cursor | claude | gemini | antigravity | copilot | all（默认 codex）

set -euo pipefail
FILE_API="http://165.154.134.82:1002"
SKILL_NAME="publish-skill"
TARGET="${1:-codex}"

declare -A DIRS
DIRS[codex]="$HOME/.codex/skills/$SKILL_NAME"
DIRS[cursor]="$HOME/.cursor/skills/$SKILL_NAME"
DIRS[claude]="$HOME/.claude/plugins/$SKILL_NAME/skills/$SKILL_NAME"
DIRS[gemini]="$HOME/.gemini/skills/$SKILL_NAME"
DIRS[antigravity]="$HOME/.gemini/antigravity/knowledge/$SKILL_NAME"
DIRS[copilot]="$HOME/.github-copilot/skills/$SKILL_NAME"

install_to() {
  local dir="$1"
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

  # agents/openai.yaml
  cat > "$dir/agents/openai.yaml" << 'AGENT_EOF'
interface:
  display_name: "Publish Skill"
  short_description: "一句话将本地 skill 打包发布，生成可在任意机器一键安装的 bash 命令。"
  default_prompt: |
    Goal: Package a local skill and publish it, returning a one-click install command.
    Steps:
    1. Parse SKILL_NAME from user message.
    2. Run: bash ~/.codex/skills/publish-skill/scripts/publish-skill.sh "<SKILL_NAME>"
    3. Show result:
       ✅ Skill 发布成功！
       🚀 bash <(curl -fsSL <raw_url>)
       📄 文档: <doc_url>
policy:
  allow_implicit_invocation: true
AGENT_EOF

  # scripts/publish-skill.sh — download from server
  curl -fsSL "${FILE_API}/admin/upload" 2>/dev/null || true
  curl -fsSL "https://images-uii41p.vyibc.com/publish-skill-core.sh" -o "$dir/scripts/publish-skill.sh" 2>/dev/null \
    || curl -fsSL "https://raw.githubusercontent.com/ChangfengHU/skill-publisher/main/skills/publish-skill/scripts/publish-skill.sh" \
         -o "$dir/scripts/publish-skill.sh"
  chmod +x "$dir/scripts/publish-skill.sh"
  echo "  📦 $TARGET → $dir"
}

echo ""
echo "🚀 安装 publish-skill..."
echo ""

if [[ "$TARGET" == "all" ]]; then
  for t in codex cursor claude gemini antigravity copilot; do
    install_to "${DIRS[$t]}"
  done
else
  install_to "${DIRS[$TARGET]:-$HOME/.codex/skills/$SKILL_NAME}"
fi

echo ""
echo "✅ 安装完成！对 AI 说："
echo "   把我的 <skill名称> 发布出去，生成一键安装命令"
echo ""
