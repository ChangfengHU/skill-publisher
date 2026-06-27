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

read_secret_masked() {
  local prompt="$1"
  local out_var="$2"
  local input=""
  local char=""

  printf "%s" "$prompt" > /dev/tty
  while IFS= read -r -s -n 1 char; do
    if [[ -z "$char" || "$char" == $'\n' || "$char" == $'\r' ]]; then
      break
    fi
    case "$char" in
      $'\177'|$'\b')
        if [[ -n "$input" ]]; then
          input="${input%?}"
          printf '\b \b' > /dev/tty
        fi
        ;;
      *)
        input+="$char"
        printf '*' > /dev/tty
        ;;
    esac
  done
  printf '\n' > /dev/tty
  printf -v "$out_var" '%s' "$input"
}

key_fingerprint() {
  local key="$1"
  printf '%s' "$key" | sha256sum | awk '{print substr($1, 1, 12)}'
}

key_mask() {
  local key="$1"
  local prefix suffix middle_len stars
  if [[ -z "$key" ]]; then
    echo ""
    return
  fi
  if [[ "$key" == sk-* ]]; then
    prefix="sk-"
  else
    prefix="${key:0:3}"
  fi
  if (( ${#key} > ${#prefix} + 4 )); then
    suffix="${key: -4}"
  else
    suffix=""
  fi
  middle_len=$((${#key} - ${#prefix} - ${#suffix}))
  (( middle_len < 6 )) && middle_len=6
  (( middle_len > 18 )) && middle_len=18
  stars="$(printf '%*s' "$middle_len" '' | tr ' ' '*')"
  echo "${prefix}${stars}${suffix}"
}

report_config_result() {
  local config_json="$1"
  local project_dir="$2"
  local key_preview="${3:-}"
  local key_fp="${4:-}"
  local key_len="${5:-}"
  local provider status code message model voice

  provider="$(printf '%s' "$config_json" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.provider||"")}catch{}});')"
  status="$(printf '%s' "$config_json" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.verification?.status||"")}catch{}});')"
  code="$(printf '%s' "$config_json" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.verification?.code||"")}catch{}});')"
  message="$(printf '%s' "$config_json" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.verification?.message||"")}catch{}});')"
  model="$(printf '%s' "$config_json" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.model||"")}catch{}});')"
  voice="$(printf '%s' "$config_json" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.voice||"")}catch{}});')"

  echo "   项目目录: $project_dir"
  echo "   key 文件: $project_dir/.secrets/dashscope_api_key"
  echo "   环境文件: $project_dir/.env.local"
  echo "   模型/音色: ${model:-unknown} / ${voice:-unknown}"
  if [[ -n "$key_preview" ]]; then
    echo "   key 确认: $key_preview（${key_len:-?} 字符，sha256:${key_fp:-unknown}…）"
  fi
  if [[ "$provider" == "qwen-tts" && "$status" == "verified" ]]; then
    echo "✅ 已验证并启用 qwen-tts。后续该项目生成视频会默认使用千问 TTS。"
  else
    echo "⚠️  key 已保存，但 TTS 权限验证未通过，当前默认仍使用 edge-tts。"
    [[ -n "$code" ]] && echo "   验证代码: $code"
    [[ -n "$message" ]] && echo "   验证信息: $message"
    echo "   处理方式: 到百炼控制台开通对应 TTS 模型权限后，重新运行本向导。"
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
  echo "当前是非交互安装，无法打开 key 输入窗口，已跳过 TTS 配置。"
  echo "稍后可手动运行："
  echo "  bash \"$SKILL_DIR/scripts/install-wizard.sh\" --skill-dir=\"$SKILL_DIR\" --project-dir=\"<视频项目目录>\" --configure-tts"
  echo "手动配置时，输入中会显示星号，提交后会显示脱敏 key、长度和 sha256 指纹供你确认。"
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
KEY_STORE_PATH="$PROJECT_DIR/.secrets/dashscope_api_key"
ENV_STORE_PATH="$PROJECT_DIR/.env.local"

CHECK_JSON="$(node "$SKILL_DIR/scripts/tts-credential-check.mjs" --project-dir="$PROJECT_DIR" 2>/dev/null || true)"
QWEN_USABLE="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.qwenTts?.usable?"1":"0")}catch{process.stdout.write("0")}});')"
ACTIVE_PROVIDER="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.activeProvider||"")}catch{}});')"
KEY_FILE_REL="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);const src=(j.qwenTts?.keySources||[]).find(x=>x.startsWith("file:"));process.stdout.write(src?src.slice(5):"")}catch{}});')"

if [[ "$QWEN_USABLE" == "1" && -n "$KEY_FILE_REL" ]]; then
  KEY_FILE="$KEY_FILE_REL"
  [[ "$KEY_FILE" = /* ]] || KEY_FILE="$PROJECT_DIR/$KEY_FILE"
  if [[ -f "$KEY_FILE" ]]; then
    EXISTING_KEY="$(tr -d '\r\n' < "$KEY_FILE")"
    EXISTING_KEY_MASK="$(key_mask "$EXISTING_KEY")"
    EXISTING_KEY_FP="$(key_fingerprint "$EXISTING_KEY")"
    if [[ "$ACTIVE_PROVIDER" == "qwen-tts" ]]; then
      echo "检测到该项目已经启用 qwen-tts。无需重复配置。"
      echo "   项目目录: $PROJECT_DIR"
      echo "   key 文件: $KEY_FILE"
      echo "   环境文件: $ENV_STORE_PATH"
      echo "   已配置 key: $EXISTING_KEY_MASK（${#EXISTING_KEY} 字符，sha256:${EXISTING_KEY_FP}…）"
      echo "   如需更换 key，请重新运行本向导并先删除或替换上述 key 文件。"
      exit 0
    fi
    echo "检测到已有 DashScope key 文件，将验证 TTS 权限。"
    echo "已有 key：$EXISTING_KEY_MASK（${#EXISTING_KEY} 字符，sha256:${EXISTING_KEY_FP}…）"
    CONFIG_JSON="$(node "$SKILL_DIR/scripts/configure-dashscope-tts.mjs" --project-dir="$PROJECT_DIR" < "$KEY_FILE")"
    report_config_result "$CONFIG_JSON" "$PROJECT_DIR" "$EXISTING_KEY_MASK" "$EXISTING_KEY_FP" "${#EXISTING_KEY}"
    exit 0
  fi
fi

if [[ "$QWEN_USABLE" == "1" && "$ACTIVE_PROVIDER" == "qwen-tts" ]]; then
  echo "检测到该项目已经启用 qwen-tts。"
  echo "   项目目录: $PROJECT_DIR"
  echo "   环境文件: $ENV_STORE_PATH"
  echo "   key 来源: 环境变量或外部 key 文件；当前向导没有可读取的本地 key 文件，因此不显示预览。"
  echo "   如需在窗口里确认脱敏 key，请使用 .secrets/dashscope_api_key 文件方式配置。"
  exit 0
fi

echo ""
echo "将保存到："
echo "   key 文件: $KEY_STORE_PATH"
echo "   环境文件: $ENV_STORE_PATH"
echo ""
echo "请输入 DashScope / 百炼 API Key。输入会显示为星号掩码，不会写入 skill 包。"
echo "提交后会显示脱敏 key、长度和 sha256 指纹；不会显示原文。"
if [[ -t 0 ]]; then
  read_secret_masked "DashScope API Key: " DASH_KEY
else
  DASH_KEY="$(cat)"
fi

if [[ -z "${DASH_KEY// }" ]]; then
  echo "未收到 key，已跳过 TTS 配置。"
  exit 0
fi

KEY_LEN="${#DASH_KEY}"
KEY_FP="$(key_fingerprint "$DASH_KEY")"
KEY_MASK="$(key_mask "$DASH_KEY")"
echo "已接收 key：$KEY_MASK（${KEY_LEN} 字符，sha256:${KEY_FP}…；非密钥，仅用于确认）"

CONFIG_JSON="$(printf '%s\n' "$DASH_KEY" | node "$SKILL_DIR/scripts/configure-dashscope-tts.mjs" --project-dir="$PROJECT_DIR")"
report_config_result "$CONFIG_JSON" "$PROJECT_DIR" "$KEY_MASK" "$KEY_FP" "$KEY_LEN"
