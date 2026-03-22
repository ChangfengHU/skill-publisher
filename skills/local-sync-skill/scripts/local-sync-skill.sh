#!/bin/bash
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

get_tool_name() {
  case $1 in
    1) echo "Codex" ;;
    2) echo "Cursor" ;;
    3) echo "Claude" ;;
    4) echo "Gemini" ;;
    5) echo "Antigravity" ;;
    6) echo "Copilot" ;;
    7) echo "OpenClaw" ;;
    8) echo "Agents" ;;
    *) echo "Unknown" ;;
  esac
}

get_tool_path() {
  case $1 in
    1) echo "$HOME/.codex/skills" ;;
    2) echo "$HOME/.cursor/skills" ;;
    3) echo "$HOME/.claude/skills" ;;
    4) echo "$HOME/.gemini/skills" ;;
    5) echo "$HOME/.gemini/antigravity/skills" ;;
    6) echo "$HOME/.copilot/skills" ;;
    7) echo "$HOME/.openclaw/workspace/skills" ;;
    8) echo "$HOME/.agents/skills" ;;
    *) echo "" ;;
  esac
}

detect_current_tool() {
  local current_dir="$PWD"
  
  if [[ "$current_dir" == *"/.codex/skills"* ]]; then
    echo "1"; return 0
  elif [[ "$current_dir" == *"/.cursor/skills"* ]]; then
    echo "2"; return 0
  elif [[ "$current_dir" == *"/.claude/skills"* ]]; then
    echo "3"; return 0
  elif [[ "$current_dir" == *"/.gemini/skills"* ]]; then
    echo "4"; return 0
  elif [[ "$current_dir" == *"/.gemini/antigravity/skills"* ]]; then
    echo "5"; return 0
  elif [[ "$current_dir" == *"/.copilot/skills"* ]]; then
    echo "6"; return 0
  elif [[ "$current_dir" == *"/.openclaw/workspace/skills"* ]]; then
    echo "7"; return 0
  elif [[ "$current_dir" == *"/.agents/skills"* ]]; then
    echo "8"; return 0
  fi
  
  for i in {1..8}; do
    local tool_path=$(get_tool_path $i)
    if [ -d "$tool_path" ] && [ -n "$(ls -A "$tool_path" 2>/dev/null)" ]; then
      echo "$i"; return 0
    fi
  done
  
  return 1
}

sync_skill() {
  local skill_name="$1"
  local source_tool_index="$2"
  local target_tool_index="$3"
  
  local target_tool_name=$(get_tool_name "$target_tool_index")
  local source_path=$(get_tool_path "$source_tool_index")/$skill_name
  local target_path=$(get_tool_path "$target_tool_index")
  
  [ -z "$target_path" ] && return 1
  
  mkdir -p "$target_path" 2>/dev/null || true
  rm -rf "$target_path/$skill_name" 2>/dev/null || true
  
  if cp -r "$source_path" "$target_path/" 2>/dev/null; then
    echo -e "${GREEN}✅ $skill_name → $target_tool_name${NC}"
    return 0
  else
    echo -e "${RED}❌ $skill_name → $target_tool_name (失败)${NC}" >&2
    return 1
  fi
}

main() {
  echo -e "${BLUE}🔍 正在检测当前 AI 工具环境...${NC}"
  echo ""
  
  local source_tool_index=""
  
  if [ $# -gt 0 ] && [[ "$1" =~ ^[1-8]$ ]]; then
    source_tool_index="$1"
    shift
  else
    source_tool_index=$(detect_current_tool) || {
      echo -e "${YELLOW}无法自动识别当前工具，请手动选择来源:${NC}"
      echo "  1) Codex        2) Cursor       3) Claude       4) Gemini"
      echo "  5) Antigravity  6) Copilot      7) OpenClaw     8) Agents"
      echo ""
      read -p "请输入序号: " source_tool_index
      
      if ! [[ "$source_tool_index" =~ ^[1-8]$ ]]; then
        echo -e "${RED}错误: 无效的选择${NC}" >&2
        exit 1
      fi
    }
  fi
  
  local source_tool_name=$(get_tool_name "$source_tool_index")
  local source_path=$(get_tool_path "$source_tool_index")
  
  echo -e "${GREEN}✓ 检测到当前环境: $source_tool_name${NC}"
  echo -e "${GREEN}✓ 来源目录: $source_path${NC}"
  echo ""
  
  if [ ! -d "$source_path" ]; then
    echo -e "${RED}错误: $source_tool_name 的 skills 目录不存在${NC}" >&2
    exit 1
  fi
  
  local -a all_skills
  for skill_path in "$source_path"/*; do
    [ -d "$skill_path" ] && all_skills+=("$(basename "$skill_path")")
  done
  
  [ ${#all_skills[@]} -eq 0 ] && {
    echo -e "${RED}错误: $source_tool_name 的 skills 目录为空${NC}" >&2
    exit 1
  }
  
  local -a selected_skills
  
  if [ $# -gt 0 ]; then
    selected_skills=("$@")
    for skill_name in "${selected_skills[@]}"; do
      if [ ! -d "$source_path/$skill_name" ]; then
        echo -e "${RED}错误: skill '$skill_name' 在 $source_tool_name 中不存在${NC}" >&2
        exit 1
      fi
    done
  else
    echo -e "${YELLOW}发现以下 skills:${NC}"
    for i in "${!all_skills[@]}"; do
      echo "  $((i + 1))) ${all_skills[$i]}"
    done
    echo ""
    read -p "请选择要同步的 skill（输入序号，空格分隔，如: 1 3）: " selection
    
    for num in $selection; do
      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#all_skills[@]}" ]; then
        selected_skills+=("${all_skills[$((num - 1))]}")
      fi
    done
    
    [ ${#selected_skills[@]} -eq 0 ] && {
      echo -e "${RED}错误: 未选择有效的 skill${NC}" >&2
      exit 1
    }
  fi
  
  echo ""
  echo -e "${YELLOW}选择同步到哪些工具:${NC}"
  
  local -a available_targets
  local idx=1
  for i in {1..8}; do
    if [ "$i" != "$source_tool_index" ]; then
      echo "  $idx) $(get_tool_name $i)"
      available_targets+=("$i")
      idx=$((idx + 1))
    fi
  done
  echo "  $idx) 全部"
  echo ""
  read -p "请输入序号: " tool_selection
  
  local -a selected_tools
  
  if echo "$tool_selection" | grep -qw "$idx"; then
    selected_tools=("${available_targets[@]}")
  else
    for num in $tool_selection; do
      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$idx" ]; then
        selected_tools+=("${available_targets[$((num - 1))]}")
      fi
    done
  fi
  
  [ ${#selected_tools[@]} -eq 0 ] && {
    echo -e "${RED}错误: 未选择有效的目标工具${NC}" >&2
    exit 1
  }
  
  echo ""
  echo -e "${YELLOW}开始同步...${NC}"
  echo ""
  
  local success_count=0
  local total_count=$((${#selected_skills[@]} * ${#selected_tools[@]}))
  
  for skill_name in "${selected_skills[@]}"; do
    for target_tool_index in "${selected_tools[@]}"; do
      sync_skill "$skill_name" "$source_tool_index" "$target_tool_index" && ((success_count++)) || true
    done
  done
  
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}同步完成: $success_count/$total_count 成功${NC}"
  echo -e "${GREEN}来源: $source_tool_name${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

main "$@"

