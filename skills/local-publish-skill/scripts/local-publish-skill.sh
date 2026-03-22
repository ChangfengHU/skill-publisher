#!/bin/bash
set -uo pipefail

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 获取工具名称
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

# 获取工具路径
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

# 查找项目根目录（包含 skills 目录的位置）
find_project_root() {
  local current_dir="$PWD"
  
  # 先检查当前目录
  if [ -d "$current_dir/skills" ]; then
    echo "$current_dir"
    return 0
  fi
  
  # 向上查找最多 5 层
  for i in {1..5}; do
    current_dir="$(dirname "$current_dir")"
    if [ -d "$current_dir/skills" ]; then
      echo "$current_dir"
      return 0
    fi
    [ "$current_dir" = "/" ] && break
  done
  
  return 1
}

# 同步 skill 到指定工具
sync_skill() {
  local skill_name="$1"
  local tool_index="$2"
  local project_root="$3"
  
  local tool_name=$(get_tool_name "$tool_index")
  local tool_path=$(get_tool_path "$tool_index")
  
  [ -z "$tool_path" ] && return 1
  
  local source_path="$project_root/skills/$skill_name"
  
  # 创建目标目录
  mkdir -p "$tool_path" 2>/dev/null || true
  
  # 删除旧版本（如果存在）
  rm -rf "$tool_path/$skill_name" 2>/dev/null || true
  
  # 复制新版本
  if cp -r "$source_path" "$tool_path/" 2>/dev/null; then
    echo -e "${GREEN}✅ $skill_name → $tool_name${NC}"
    return 0
  else
    echo -e "${RED}❌ $skill_name → $tool_name (失败)${NC}" >&2
    return 1
  fi
}

# 主函数
main() {
  # 查找项目根目录
  local project_root
  project_root=$(find_project_root) || {
    echo -e "${RED}错误: 未找到包含 skills 目录的项目根目录${NC}" >&2
    echo "请在项目目录或其子目录中运行此脚本" >&2
    exit 1
  }
  
  echo -e "${GREEN}项目根目录: $project_root${NC}"
  echo ""
  
  # 收集所有可用的 skills
  local -a all_skills
  for skill_path in "$project_root/skills"/*; do
    [ -d "$skill_path" ] && all_skills+=("$(basename "$skill_path")")
  done
  
  [ ${#all_skills[@]} -eq 0 ] && {
    echo -e "${RED}错误: skills 目录为空${NC}" >&2
    exit 1
  }
  
  # 第一步: 选择要发布的 skills
  local -a selected_skills
  
  if [ $# -gt 0 ]; then
    # 指定了 skill 名称
    local skill_name="$1"
    if [ ! -d "$project_root/skills/$skill_name" ]; then
      echo -e "${RED}错误: skill '$skill_name' 不存在${NC}" >&2
      exit 1
    fi
    selected_skills=("$skill_name")
  else
    # 显示菜单
    echo -e "${YELLOW}检测到以下 skills:${NC}"
    for i in "${!all_skills[@]}"; do
      echo "  $((i + 1))) ${all_skills[$i]}"
    done
    echo ""
    echo -n "请选择要发布的 skill（输入序号，空格分隔，如: 1 3）: "
    read -r selection
    
    # 解析用户输入
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
  
  # 第二步: 选择目标工具
  echo ""
  echo -e "${YELLOW}选择同步到哪些 AI 工具:${NC}"
  echo "  1) Codex        (~/.codex/skills/)"
  echo "  2) Cursor       (~/.cursor/skills/)"
  echo "  3) Claude       (~/.claude/skills/)"
  echo "  4) Gemini       (~/.gemini/skills/)"
  echo "  5) Antigravity  (~/.gemini/antigravity/skills/)"
  echo "  6) Copilot      (~/.copilot/skills/)"
  echo "  7) OpenClaw     (~/.openclaw/workspace/skills/)"
  echo "  8) Agents       (~/.agents/skills/)"
  echo "  9) 全部"
  echo ""
  echo -n "请输入序号（空格分隔，如: 2 6 或输入 9）: "
  read -r tool_selection
  
  local -a selected_tools
  
  # 如果选择全部
  if echo "$tool_selection" | grep -qw "9"; then
    selected_tools=(1 2 3 4 5 6 7 8)
  else
    # 解析用户输入
    for num in $tool_selection; do
      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le 8 ]; then
        selected_tools+=("$num")
      fi
    done
  fi
  
  [ ${#selected_tools[@]} -eq 0 ] && {
    echo -e "${RED}错误: 未选择有效的工具${NC}" >&2
    exit 1
  }
  
  # 第三步: 执行同步
  echo ""
  echo -e "${YELLOW}开始同步...${NC}"
  echo ""
  
  local success_count=0
  local total_count=$((${#selected_skills[@]} * ${#selected_tools[@]}))
  
  for skill_name in "${selected_skills[@]}"; do
    for tool_id in "${selected_tools[@]}"; do
      sync_skill "$skill_name" "$tool_id" "$project_root" && ((success_count++)) || true
    done
  done
  
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}同步完成: $success_count/$total_count 成功${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 执行主函数
main "$@"

