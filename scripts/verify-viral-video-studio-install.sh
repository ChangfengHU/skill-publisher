#!/usr/bin/env bash
set -euo pipefail

INSTALL_URL="${INSTALL_URL:-https://skill.vyibc.com/install-viral-video-studio.sh}"
EXPECTED_ZIP_URL="${EXPECTED_ZIP_URL:-}"
FAKE_KEY="${FAKE_KEY:-sk-verifyviralvideostudio00005678}"
FAKE_ROOT_KEY="${FAKE_ROOT_KEY:-sk-rootviralvideostudio00001234}"

TMPROOT="$(mktemp -d /tmp/verify-vvs-install-XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT

HOME_DIR="$TMPROOT/home"
RUN_DIR="$TMPROOT/run"
PROJECT_DIR="$TMPROOT/project"
mkdir -p "$HOME_DIR" "$RUN_DIR"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

file_mode() {
  local file="$1"
  if stat -c '%a' "$file" >/dev/null 2>&1; then
    stat -c '%a' "$file"
  else
    stat -f '%Lp' "$file"
  fi
}

assert_contains() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "expected '$needle' in $file"
}

assert_not_contains() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "unexpected secret/raw value in $file"
  fi
}

cd "$RUN_DIR"
INSTALL_SCRIPT="$TMPROOT/install-viral-video-studio.sh"
curl -fsSL "$INSTALL_URL" -o "$INSTALL_SCRIPT"
if [[ -n "$EXPECTED_ZIP_URL" ]]; then
  assert_contains "ZIP_URL=\"$EXPECTED_ZIP_URL\"" "$INSTALL_SCRIPT"
fi
HOME="$HOME_DIR" bash "$INSTALL_SCRIPT" codex > "$TMPROOT/install.out"

SKILL_DIR="$HOME_DIR/.codex/skills/viral-video-studio"
WIZARD="$SKILL_DIR/scripts/install-wizard.sh"
[[ -x "$WIZARD" ]] || fail "install wizard not found or not executable: $WIZARD"

bash -n "$WIZARD"
if LC_ALL=C grep -n $'\357\277\275' "$WIZARD" >/dev/null; then
  fail "install wizard contains Unicode replacement character"
fi
node --check "$SKILL_DIR/scripts/configure-dashscope-tts.mjs" >/dev/null
node --check "$SKILL_DIR/scripts/tts-credential-check.mjs" >/dev/null

HOME="$HOME_DIR" bash "$WIZARD" --skill-dir="$SKILL_DIR" --project-dir=/ --show-tts-status > "$TMPROOT/root-status.out"
assert_contains "向导版本: 20260628-tts-root-mask-fix" "$TMPROOT/root-status.out"
assert_contains "已默认改用 $HOME_DIR" "$TMPROOT/root-status.out"
assert_contains "视频项目目录: $HOME_DIR" "$TMPROOT/root-status.out"
assert_not_contains "默认 key 文件: //.secrets" "$TMPROOT/root-status.out"
assert_not_contains "环境文件: //.env.local" "$TMPROOT/root-status.out"

printf '%s\n' "$FAKE_ROOT_KEY" \
  | HOME="$HOME_DIR" VIRAL_VIDEO_STUDIO_TTS_SKIP_VERIFY=1 bash "$WIZARD" \
      --skill-dir="$SKILL_DIR" \
      --project-dir=/ \
      --configure-tts > "$TMPROOT/root-configure.out"

assert_contains "已默认改用 $HOME_DIR" "$TMPROOT/root-configure.out"
assert_contains "项目目录: $HOME_DIR" "$TMPROOT/root-configure.out"
assert_contains "key 文件: $HOME_DIR/.secrets/dashscope_api_key" "$TMPROOT/root-configure.out"
assert_not_contains "key 文件: //.secrets" "$TMPROOT/root-configure.out"
assert_not_contains "$FAKE_ROOT_KEY" "$TMPROOT/root-configure.out"
[[ -f "$HOME_DIR/.secrets/dashscope_api_key" ]] || fail "missing normalized root key file"
[[ "$(file_mode "$HOME_DIR/.secrets/dashscope_api_key")" == "600" ]] || fail "normalized root key file mode is not 600"

printf '%s\n' "$FAKE_KEY" \
  | HOME="$HOME_DIR" VIRAL_VIDEO_STUDIO_TTS_SKIP_VERIFY=1 bash "$WIZARD" \
      --skill-dir="$SKILL_DIR" \
      --project-dir="$PROJECT_DIR" \
      --configure-tts > "$TMPROOT/configure.out"

assert_contains "已接收 key：" "$TMPROOT/configure.out"
assert_contains "已保存并启用 qwen-tts" "$TMPROOT/configure.out"
assert_not_contains "$FAKE_KEY" "$TMPROOT/configure.out"

KEY_FILE="$PROJECT_DIR/.secrets/dashscope_api_key"
ENV_FILE="$PROJECT_DIR/.env.local"
[[ -f "$KEY_FILE" ]] || fail "missing key file"
[[ -f "$ENV_FILE" ]] || fail "missing env file"
[[ "$(file_mode "$KEY_FILE")" == "600" ]] || fail "key file mode is not 600"
[[ "$(file_mode "$ENV_FILE")" == "600" ]] || fail "env file mode is not 600"

assert_contains "CONTENT_TTS_PROVIDER=qwen-tts" "$ENV_FILE"
assert_contains "DASHSCOPE_TTS_ACCESS_STATUS=skipped" "$ENV_FILE"

HOME="$HOME_DIR" bash "$WIZARD" --skill-dir="$SKILL_DIR" --project-dir="$PROJECT_DIR" --show-tts-status > "$TMPROOT/status.out"
assert_contains "当前 provider: qwen-tts" "$TMPROOT/status.out"
assert_contains "权限 0600" "$TMPROOT/status.out"
assert_not_contains "$FAKE_KEY" "$TMPROOT/status.out"

echo "OK: viral-video-studio remote install and TTS wizard smoke passed"
