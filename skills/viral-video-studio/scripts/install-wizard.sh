#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR=""
PROJECT_DIR="$PWD"
INSTALL_TARGET=""
CONFIGURE_TTS=0
SKIP_TTS="${VIRAL_VIDEO_STUDIO_SKIP_TTS:-0}"

resolve_path() {
  local input="$1"
  if [[ "$input" == "~" ]]; then
    echo "$HOME"
  elif [[ "$input" == ~/* ]]; then
    echo "$HOME/${input#~/}"
  elif [[ "$input" = /* ]]; then
    echo "$input"
  else
    echo "$PWD/$input"
  fi
}

for arg in "$@"; do
  case "$arg" in
    --skill-dir=*) SKILL_DIR="${arg#*=}" ;;
    --project-dir=*) PROJECT_DIR="${arg#*=}" ;;
    --install-target=*) INSTALL_TARGET="${arg#*=}" ;;
    --configure-tts) CONFIGURE_TTS=1 ;;
    --skip-tts) SKIP_TTS=1 ;;
  esac
done

if [[ -z "$SKILL_DIR" ]]; then
  SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi
PROJECT_DIR="$(resolve_path "$PROJECT_DIR")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 viral-video-studio 初始化"
echo ""
echo "第 1 步：skill 已安装到 ${INSTALL_TARGET:-当前目标}。"
echo "第 2 步：可选配置百炼/千问 TTS。配置后该视频项目默认使用 qwen-tts；不配置则使用免 key 的 edge-tts。"
echo ""

if [[ "$SKIP_TTS" == "1" ]]; then
  echo "已跳过 TTS 配置。"
  exit 0
fi

if [[ "$CONFIGURE_TTS" != "1" && ! -t 0 ]]; then
  echo "当前是非交互安装，已跳过 TTS 配置。"
  echo "稍后可手动运行："
  echo "  bash \"$SKILL_DIR/scripts/install-wizard.sh\" --skill-dir=\"$SKILL_DIR\" --project-dir=\"<视频项目目录>\" --configure-tts"
  exit 0
fi

if [[ "$CONFIGURE_TTS" != "1" ]]; then
  read -rp "是否现在配置百炼/千问 TTS appkey？[y/N]: " SHOULD_CONFIGURE
  case "$SHOULD_CONFIGURE" in
    y|Y|yes|YES) CONFIGURE_TTS=1 ;;
    *) echo "已跳过。之后默认使用 edge-tts。"; exit 0 ;;
  esac
fi

if [[ "$CONFIGURE_TTS" == "1" && -t 0 ]]; then
  read -rp "视频项目目录 [${PROJECT_DIR}]: " INPUT_PROJECT_DIR
  if [[ -n "$INPUT_PROJECT_DIR" ]]; then
    PROJECT_DIR="$(resolve_path "$INPUT_PROJECT_DIR")"
  fi
fi

mkdir -p "$PROJECT_DIR"

CHECK_JSON="$(node "$SKILL_DIR/scripts/tts-credential-check.mjs" --project-dir="$PROJECT_DIR" 2>/dev/null || true)"
QWEN_USABLE="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.qwenTts?.usable?"1":"0")}catch{process.stdout.write("0")}});')"
ACTIVE_PROVIDER="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.activeProvider||"")}catch{}});')"
KEY_FILE_REL="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);const src=(j.qwenTts?.keySources||[]).find(x=>x.startsWith("file:"));process.stdout.write(src?src.slice(5):"")}catch{}});')"

if [[ "$QWEN_USABLE" == "1" && "$ACTIVE_PROVIDER" == "qwen-tts" ]]; then
  echo "检测到该项目已经启用 qwen-tts。无需重复配置。"
  exit 0
fi

if [[ "$QWEN_USABLE" == "1" && -n "$KEY_FILE_REL" ]]; then
  KEY_FILE="$KEY_FILE_REL"
  [[ "$KEY_FILE" = /* ]] || KEY_FILE="$PROJECT_DIR/$KEY_FILE"
  if [[ -f "$KEY_FILE" ]]; then
    echo "检测到已有 DashScope key 文件，将启用 qwen-tts。"
    node "$SKILL_DIR/scripts/configure-dashscope-tts.mjs" --project-dir="$PROJECT_DIR" < "$KEY_FILE" >/dev/null
    echo "✅ 已启用 qwen-tts：$PROJECT_DIR/.env.local"
    exit 0
  fi
fi

echo ""
echo "请输入 DashScope / 百炼 API Key。输入不会回显，也不会写入 skill 包。"
if [[ -t 0 ]]; then
  read -rsp "DashScope API Key: " DASH_KEY
  echo ""
else
  DASH_KEY="$(cat)"
fi

if [[ -z "${DASH_KEY// }" ]]; then
  echo "未收到 key，已跳过 TTS 配置。"
  exit 0
fi

printf '%s\n' "$DASH_KEY" | node "$SKILL_DIR/scripts/configure-dashscope-tts.mjs" --project-dir="$PROJECT_DIR" >/dev/null

echo "✅ 已配置 qwen-tts。"
echo "   项目目录: $PROJECT_DIR"
echo "   key 文件: $PROJECT_DIR/.secrets/dashscope_api_key"
echo "   环境文件: $PROJECT_DIR/.env.local"
echo ""
echo "后续该项目生成视频时会默认请求 qwen-tts；如果服务不可用，再按项目逻辑降级。"
