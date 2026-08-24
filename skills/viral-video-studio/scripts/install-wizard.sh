#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR=""
PROJECT_DIR="$PWD"
INSTALL_TARGET=""
CONFIGURE_TTS=0
SHOW_TTS_STATUS=0
PRINT_HELP=0
SKIP_TTS="${VIRAL_VIDEO_STUDIO_SKIP_TTS:-0}"
WIZARD_VERSION="20260628-tts-root-mask-fix"
CONFIGURE_EXTRA_ARGS=()
if [[ "${VIRAL_VIDEO_STUDIO_TTS_SKIP_VERIFY:-0}" == "1" ]]; then
  CONFIGURE_EXTRA_ARGS+=("--skip-verify=1")
fi

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

normalize_project_dir() {
  local input="$1"
  if [[ "$input" == "/" && -n "${HOME:-}" && "$HOME" != "/" ]]; then
    echo "$HOME"
  else
    echo "$input"
  fi
}

resolve_project_path() {
  local base_dir="$1"
  local input="$2"
  if [[ -z "$input" ]]; then
    echo ""
  elif [[ "$input" == "~" ]]; then
    echo "$HOME"
  elif [[ "$input" == ~/* ]]; then
    echo "$HOME/${input#~/}"
  elif [[ "$input" = /* ]]; then
    echo "$input"
  else
    echo "$base_dir/$input"
  fi
}

read_env_value() {
  local file="$1"
  local name="$2"
  local value=""
  [[ -f "$file" ]] || return 0
  value="$(awk -v key="$name" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "", $0);
      print;
      exit;
    }
  ' "$file" 2>/dev/null || true)"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
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
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$key" | sha256sum | awk '{print substr($1, 1, 12)}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$key" | shasum -a 256 | awk '{print substr($1, 1, 12)}'
  elif command -v openssl >/dev/null 2>&1; then
    printf '%s' "$key" | openssl dgst -sha256 -r | awk '{print substr($1, 1, 12)}'
  else
    echo "unknown"
  fi
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

key_file_mode() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo ""
    return
  fi
  if stat -c '%a' "$file" >/dev/null 2>&1; then
    stat -c '0%a' "$file" 2>/dev/null
  else
    stat -f '0%Lp' "$file" 2>/dev/null || true
  fi
}

print_tts_status_command() {
  echo "   复查命令: bash \"$SKILL_DIR/scripts/install-wizard.sh\" --skill-dir=\"$SKILL_DIR\" --project-dir=\"$PROJECT_DIR\" --show-tts-status"
}

print_tts_config_window() {
  local project_dir="$1"
  local env_path="$project_dir/.env.local"
  local default_key_path="$project_dir/.secrets/dashscope_api_key"
  local configured_key_file key_path provider model voice access_status raw_env_key existing_key mode

  configured_key_file="$(read_env_value "$env_path" DASHSCOPE_API_KEY_FILE)"
  key_path="$(resolve_project_path "$project_dir" "$configured_key_file")"
  [[ -n "$key_path" ]] || key_path="$default_key_path"
  if [[ ! -f "$key_path" && -f "$default_key_path" ]]; then
    key_path="$default_key_path"
  fi

  provider="$(read_env_value "$env_path" CONTENT_TTS_PROVIDER)"
  model="$(read_env_value "$env_path" DASHSCOPE_TTS_MODEL)"
  voice="$(read_env_value "$env_path" DASHSCOPE_TTS_VOICE)"
  access_status="$(read_env_value "$env_path" DASHSCOPE_TTS_ACCESS_STATUS)"

  echo "TTS 配置窗口："
  echo "   向导版本: $WIZARD_VERSION"
  echo "   说明: 默认给当前视频项目配置；在哪个项目目录运行安装命令，key 就默认落到哪个项目。"
  echo "   视频项目目录: $project_dir"
  echo "   默认 key 文件: $default_key_path"
  [[ -n "$configured_key_file" ]] && echo "   .env 指向 key: $configured_key_file"
  echo "   环境文件: $env_path"
  echo "   保存规则: key 原文只写本项目 .secrets/dashscope_api_key；.env.local 只保存 provider 和 key 文件路径。"
  echo "   显示规则: 窗口永不回显明文，只显示脱敏 key、长度和 sha256 指纹。"

  if [[ -f "$key_path" ]]; then
    existing_key="$(tr -d '\r\n' < "$key_path" 2>/dev/null || true)"
    mode="$(key_file_mode "$key_path")"
    if [[ -n "$existing_key" ]]; then
      echo "   已配置 key: $(key_mask "$existing_key")（${#existing_key} 字符，sha256:$(key_fingerprint "$existing_key")…）"
      echo "   key 实际读取: $key_path${mode:+，权限 $mode}"
    else
      echo "   已配置 key: key 文件存在但内容为空"
      echo "   key 实际读取: $key_path${mode:+，权限 $mode}"
    fi
  else
    raw_env_key="$(read_env_value "$env_path" DASHSCOPE_API_KEY)"
    if [[ -n "$raw_env_key" ]]; then
      echo "   已配置 key: $(key_mask "$raw_env_key")（${#raw_env_key} 字符，sha256:$(key_fingerprint "$raw_env_key")…）"
      echo "   key 来源: .env.local 的 DASHSCOPE_API_KEY；建议迁移到 .secrets/dashscope_api_key"
    else
      echo "   已配置 key: 未检测到"
    fi
  fi

  echo "   当前 provider: ${provider:-edge-tts}"
  echo "   模型/音色/权限: ${model:-qwen3-tts-flash} / ${voice:-Cherry} / ${access_status:-unknown}"
  echo "   配置后预览示例: sk-************abcd（长度 + sha256 指纹；不显示原文）"
  echo ""
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
  elif [[ "$provider" == "qwen-tts" && "$status" == "skipped" ]]; then
    echo "✅ 已保存并启用 qwen-tts。本次按要求跳过联网验证。"
  elif [[ "$provider" == "qwen-tts" ]]; then
    echo "⚠️  key 已保存并启用 qwen-tts，但本次没有确认模型权限。"
    [[ -n "$code" ]] && echo "   验证代码: $code"
    [[ -n "$message" ]] && echo "   验证信息: $message"
    echo "   处理方式: 若生成语音失败，请开通对应 TTS 模型权限或临时切回 edge-tts。"
  else
    echo "⚠️  key 已保存，但 TTS 权限验证未通过，当前默认仍使用 edge-tts。"
    [[ -n "$code" ]] && echo "   验证代码: $code"
    [[ -n "$message" ]] && echo "   验证信息: $message"
    echo "   处理方式: 到百炼控制台开通对应 TTS 模型权限后，重新运行本向导。"
  fi
}

print_install_help() {
  echo "用法：bash \"$0\" [参数]"
  echo ""
  echo "主要参数："
  echo "  --skill-dir=<path>      指定 skill 目录（通常是安装后的 skill 根目录）"
  echo "  --project-dir=<path>    指定视频项目目录，key 和 .env.local 会写在该目录"
  echo "  --install-target=<name>  仅用于展示安装目标名"
  echo "  --configure-tts         直接进入百炼/千问配置向导"
  echo "  --show-tts-status       显示当前项目安全化的 TTS 配置快照"
  echo "  --skip-tts              跳过 TTS 配置（默认）"
  echo "  --status                --show-tts-status 的别名"
  echo "  --help                  打印帮助"
  echo ""
  echo "默认行为：先展示当前项目 TTS 配置快照，再按需进入配置向导。"
  echo "安全约束：不回显原文 key，只显示脱敏、长度、sha256 指纹和文件位置。"
}

print_tts_next_steps() {
  local configure_cmd status_cmd
  configure_cmd="bash \"$SKILL_DIR/scripts/install-wizard.sh\" --skill-dir=\"$SKILL_DIR\" --project-dir=\"$PROJECT_DIR\" --configure-tts"
  status_cmd="bash \"$SKILL_DIR/scripts/install-wizard.sh\" --skill-dir=\"$SKILL_DIR\" --project-dir=\"$PROJECT_DIR\" --show-tts-status"
  echo "下一步操作："
  echo "   已安装 skill 到：${INSTALL_TARGET:-当前项目目录}"
  echo "   查看/确认 key：$status_cmd"
  echo "   配置/重配 key：$configure_cmd"
  echo ""
}

for arg in "$@"; do
  case "$arg" in
    --skill-dir=*) SKILL_DIR="${arg#*=}" ;;
    --project-dir=*) PROJECT_DIR="${arg#*=}" ;;
    --install-target=*) INSTALL_TARGET="${arg#*=}" ;;
    --configure-tts) CONFIGURE_TTS=1 ;;
    --show-tts-status|--status) SHOW_TTS_STATUS=1 ;;
    --help|-h) PRINT_HELP=1 ;;
    --skip-tts) SKIP_TTS=1 ;;
  esac
done

if [[ -z "$SKILL_DIR" ]]; then
  SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi
RAW_PROJECT_DIR="$(resolve_path "$PROJECT_DIR")"
PROJECT_DIR="$(normalize_project_dir "$RAW_PROJECT_DIR")"
INSTALL_TARGET="${INSTALL_TARGET:-"当前项目目录"}"

if [[ "$PRINT_HELP" == "1" ]]; then
  print_install_help
  exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 viral-video-studio 初始化"
echo ""
if [[ "$RAW_PROJECT_DIR" == "/" && "$PROJECT_DIR" != "/" ]]; then
  echo "检测到视频项目目录是 /，已默认改用 $PROJECT_DIR，避免把 key 写入系统根目录。"
  echo ""
fi
echo "第 1 步：skill 已安装到 ${INSTALL_TARGET}。"
echo "第 2 步：可选配置百炼/千问 TTS。配置后该视频项目默认使用 qwen-tts；不配置则使用免 key 的 edge-tts。"
print_tts_next_steps
echo ""
print_tts_config_window "$PROJECT_DIR"
print_tts_status_command
echo ""

if [[ "$SHOW_TTS_STATUS" == "1" ]]; then
  exit 0
fi

if [[ "$SKIP_TTS" == "1" ]]; then
  echo "已跳过 TTS 配置。"
  exit 0
fi

if [[ "$CONFIGURE_TTS" != "1" && ! -t 0 ]]; then
  echo "当前是非交互安装，无法打开 key 输入窗口，已跳过 TTS 配置。"
  echo "稍后可手动运行："
  echo "  bash \"$SKILL_DIR/scripts/install-wizard.sh\" --skill-dir=\"$SKILL_DIR\" --project-dir=\"<视频项目目录>\" --configure-tts"
  echo "只查看当前脱敏配置："
  echo "  bash \"$SKILL_DIR/scripts/install-wizard.sh\" --skill-dir=\"$SKILL_DIR\" --project-dir=\"<视频项目目录>\" --show-tts-status"
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
  print_tts_next_steps
  echo "开始二阶段：TTS 配置。"
  read -rp "视频项目目录 [${PROJECT_DIR}]: " INPUT_PROJECT_DIR
  if [[ -n "$INPUT_PROJECT_DIR" ]]; then
    RAW_PROJECT_DIR="$(resolve_path "$INPUT_PROJECT_DIR")"
    PROJECT_DIR="$(normalize_project_dir "$RAW_PROJECT_DIR")"
    if [[ "$RAW_PROJECT_DIR" == "/" && "$PROJECT_DIR" != "/" ]]; then
      echo "检测到输入是 /，已改用 $PROJECT_DIR，避免把 key 写入系统根目录。"
    fi
  fi
  echo ""
  print_tts_config_window "$PROJECT_DIR"
  print_tts_status_command
fi

mkdir -p "$PROJECT_DIR"
KEY_STORE_PATH="$PROJECT_DIR/.secrets/dashscope_api_key"
ENV_STORE_PATH="$PROJECT_DIR/.env.local"

CHECK_JSON="$(node "$SKILL_DIR/scripts/tts-credential-check.mjs" --project-dir="$PROJECT_DIR" 2>/dev/null || true)"
QWEN_USABLE="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.qwenTts?.usable?"1":"0")}catch{process.stdout.write("0")}});')"
QWEN_KEY_AVAILABLE="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.qwenTts?.keyAvailable?"1":"0")}catch{process.stdout.write("0")}});')"
ACTIVE_PROVIDER="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.activeProvider||"")}catch{}});')"
KEY_FILE_REL="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);const src=(j.qwenTts?.keySources||[]).find(x=>x.startsWith("file:"));process.stdout.write(src?src.slice(5):"")}catch{}});')"
ENV_KEY_MASK="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.qwenTts?.envKeySummary?.keyMask||"")}catch{}});')"
ENV_KEY_FP="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(j.qwenTts?.envKeySummary?.keyFingerprint||"")}catch{}});')"
ENV_KEY_LEN="$(printf '%s' "$CHECK_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const j=JSON.parse(s);process.stdout.write(String(j.qwenTts?.envKeySummary?.keyLength||""))}catch{}});')"

if [[ "$QWEN_KEY_AVAILABLE" == "1" && -n "$KEY_FILE_REL" ]]; then
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
      print_tts_status_command
      echo "   如需更换 key，请重新运行本向导并先删除或替换上述 key 文件。"
      exit 0
    fi
    echo "检测到已有 DashScope key 文件，将验证 TTS 权限。"
    echo "已有 key：$EXISTING_KEY_MASK（${#EXISTING_KEY} 字符，sha256:${EXISTING_KEY_FP}…）"
    CONFIG_JSON="$(node "$SKILL_DIR/scripts/configure-dashscope-tts.mjs" --project-dir="$PROJECT_DIR" "${CONFIGURE_EXTRA_ARGS[@]}" < "$KEY_FILE")"
    report_config_result "$CONFIG_JSON" "$PROJECT_DIR" "$EXISTING_KEY_MASK" "$EXISTING_KEY_FP" "${#EXISTING_KEY}"
    print_tts_status_command
    exit 0
  fi
fi

if [[ "$QWEN_USABLE" == "1" && "$ACTIVE_PROVIDER" == "qwen-tts" ]]; then
  echo "检测到该项目已经启用 qwen-tts。"
  echo "   项目目录: $PROJECT_DIR"
  echo "   环境文件: $ENV_STORE_PATH"
  if [[ -n "$ENV_KEY_MASK" ]]; then
    echo "   key 来源: 环境变量 DASHSCOPE_API_KEY"
    echo "   key 脱敏预览: $ENV_KEY_MASK（${ENV_KEY_LEN:-?} 字符，sha256:${ENV_KEY_FP:-unknown}…）"
  else
    echo "   key 来源: 环境变量或外部 key 文件；当前向导没有可读取的本地 key 文件，因此不显示预览。"
  fi
  print_tts_status_command
  echo "   如需在窗口里确认脱敏 key，请使用 .secrets/dashscope_api_key 文件方式配置。"
  exit 0
fi

echo ""
echo "将保存到："
echo "   key 文件: $KEY_STORE_PATH"
echo "   环境文件: $ENV_STORE_PATH"
echo ""
echo "请输入 DashScope / 百炼 API Key。输入会显示为星号掩码，不会写入 skill 包。"
echo "提交后会显示类似 sk-************abcd 的脱敏 key、长度和 sha256 指纹；不会显示原文。"
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

CONFIG_JSON="$(printf '%s\n' "$DASH_KEY" | node "$SKILL_DIR/scripts/configure-dashscope-tts.mjs" --project-dir="$PROJECT_DIR" "${CONFIGURE_EXTRA_ARGS[@]}")"
report_config_result "$CONFIG_JSON" "$PROJECT_DIR" "$KEY_MASK" "$KEY_FP" "$KEY_LEN"
print_tts_status_command
print_tts_next_steps
