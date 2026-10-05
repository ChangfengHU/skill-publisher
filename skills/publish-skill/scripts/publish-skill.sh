#!/usr/bin/env bash
# publish-skill.sh — 将本地 skill 打包为 zip 发布，生成一键安装命令
#
# 用法: publish-skill.sh <skill-name> [skill-dir]
#
# 流程:
#   1. 将 skill 目录打成 zip 上传到文件服务器
#   2. 生成安装脚本（下载 zip → 解压 → 复制到目标目录）上传
#   3. 输出 bash <(curl -fsSL ...) 安装命令

set -euo pipefail

SKILL_NAME="${1:-}"
FILE_API_URL="${FILE_API_URL:-https://upload-r2.vyibc.com}"
FILE_API_TOKEN="${FILE_API_TOKEN:-}"
CDN_URL="${CDN_URL:-https://skill.vyibc.com}"
RELEASE_PATH="${RELEASE_PATH:-}"
export FILE_API_URL FILE_API_TOKEN CDN_URL
ALLOW_EXTERNAL_SKILL_DIR="${ALLOW_EXTERNAL_SKILL_DIR:-0}"
GENERATE_SOP_CONTRACT="${GENERATE_SOP_CONTRACT:-1}"
PRESERVE_SOP_CONTRACT="${PRESERVE_SOP_CONTRACT:-1}"

resolve_abs_path() {
  local path="$1"
  [[ -d "$path" ]] || return 1
  (cd "$path" && pwd -P)
}

is_allowed_skill_dir() {
  local dir_abs="$1"
  local candidate

  for candidate in \
    "${HOME}/.codex/skills/${SKILL_NAME}" \
    "${HOME}/.cursor/skills/${SKILL_NAME}" \
    "${HOME}/.copilot/skills/${SKILL_NAME}" \
    "${HOME}/.gemini/skills/${SKILL_NAME}" \
    "${HOME}/.gemini/antigravity/skills/${SKILL_NAME}" \
    "${HOME}/.claude/skills/${SKILL_NAME}" \
    "${HOME}/.openclaw/workspace/skills/${SKILL_NAME}" \
    "${HOME}/.agents/skills/${SKILL_NAME}"; do
    [[ -d "$candidate" ]] || continue
    if [[ "$dir_abs" == "$(resolve_abs_path "$candidate")" ]]; then
      return 0
    fi
  done

  return 1
}

# ── 参数检查 ──────────────────────────────────────────────
if [[ -z "$SKILL_NAME" ]]; then
  echo "用法: $0 <skill-name>" >&2
  echo ""
  echo "本机已安装的 skills:"
  for d in \
    "${HOME}/.codex/skills" \
    "${HOME}/.cursor/skills" \
    "${HOME}/.copilot/skills" \
    "${HOME}/.gemini/skills" \
    "${HOME}/.gemini/antigravity/skills" \
    "${HOME}/.claude/skills" \
    "${HOME}/.openclaw/workspace/skills" \
    "${HOME}/.agents/skills"; do
    [[ -d "$d" ]] && ls "$d" 2>/dev/null | grep -v '^\.' | sed "s|^|  [$d] |"
  done
  exit 1
fi

if [[ ! "$SKILL_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}$ ]]; then
  echo "❌ 无效 skill 名称" >&2; exit 1
fi
UPLOAD_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/upload-skill-file.py"

# ── 查找 skill 目录 ───────────────────────────────────────
SKILL_DIR="${2:-}"
if [[ -z "$SKILL_DIR" ]]; then
  for candidate in \
    "${HOME}/.codex/skills/${SKILL_NAME}" \
    "${HOME}/.cursor/skills/${SKILL_NAME}" \
    "${HOME}/.copilot/skills/${SKILL_NAME}" \
    "${HOME}/.gemini/skills/${SKILL_NAME}" \
    "${HOME}/.gemini/antigravity/skills/${SKILL_NAME}" \
    "${HOME}/.claude/skills/${SKILL_NAME}" \
    "${HOME}/.openclaw/workspace/skills/${SKILL_NAME}" \
    "${HOME}/.agents/skills/${SKILL_NAME}"; do
    if [[ -d "$candidate" ]]; then
      SKILL_DIR="$candidate"
      break
    fi
  done
fi

if [[ -n "$SKILL_DIR" && -d "$SKILL_DIR" ]]; then
  SKILL_DIR="$(resolve_abs_path "$SKILL_DIR")"
fi

if [[ -z "$SKILL_DIR" || ! -d "$SKILL_DIR" ]]; then
  echo "❌ 找不到 skill 目录: ${SKILL_NAME}" >&2
  echo "搜索路径: ~/.codex/skills/, ~/.cursor/skills/, ~/.copilot/skills/, ~/.gemini/skills/, ~/.gemini/antigravity/skills/, ~/.claude/skills/, ~/.openclaw/workspace/skills/, ~/.agents/skills/" >&2
  exit 1
fi

if ! is_allowed_skill_dir "$SKILL_DIR"; then
  if [[ "$ALLOW_EXTERNAL_SKILL_DIR" != "1" ]]; then
    echo "❌ skill 目录不在允许范围内: ${SKILL_DIR}" >&2
    echo "默认只允许发布以下路径中的 ${SKILL_NAME}:" >&2
    echo "  ~/.codex/skills/${SKILL_NAME}" >&2
    echo "  ~/.cursor/skills/${SKILL_NAME}" >&2
    echo "  ~/.copilot/skills/${SKILL_NAME}" >&2
    echo "  ~/.gemini/skills/${SKILL_NAME}" >&2
    echo "  ~/.gemini/antigravity/skills/${SKILL_NAME}" >&2
    echo "  ~/.claude/skills/${SKILL_NAME}" >&2
    echo "  ~/.openclaw/workspace/skills/${SKILL_NAME}" >&2
    echo "  ~/.agents/skills/${SKILL_NAME}" >&2
    echo "" >&2
    echo "如需从仓库目录等外部路径发布，请显式开启覆盖：" >&2
    echo "  ALLOW_EXTERNAL_SKILL_DIR=1 $0 ${SKILL_NAME} ${SKILL_DIR}" >&2
    exit 1
  fi
  echo "⚠️  使用外部 skill 目录发布: ${SKILL_DIR}" >&2
fi

[[ -s "$SKILL_DIR/SKILL.md" || -f "$SKILL_DIR/.codex-plugin/plugin.json" ]] || { echo "❌ SKILL.md 缺失" >&2; exit 1; }
echo "📦 打包 skill: ${SKILL_NAME}"
echo "   来源目录: ${SKILL_DIR}"
echo ""

TMPDIR_WORK=$(mktemp -d /tmp/publish-skill-XXXXXX)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

TS=$(date -u +%Y%m%d%H%M%S)
ZIP_FILENAME="${SKILL_NAME}-${TS}.zip"
ZIP_PATH="${TMPDIR_WORK}/${ZIP_FILENAME}"
PACKAGE_ROOT="${TMPDIR_WORK}/package"
PACKAGE_SKILL_DIR="${PACKAGE_ROOT}/${SKILL_NAME}"
CONTRACT_PATH="${PACKAGE_SKILL_DIR}/sop-skill-contract.json"

mkdir -p "$PACKAGE_ROOT"
python3 - "$SKILL_DIR" "$PACKAGE_SKILL_DIR" <<'COPYEOF'
import shutil,sys
shutil.copytree(sys.argv[1],sys.argv[2],ignore=shutil.ignore_patterns('.git','__pycache__','*.pyc','.DS_Store','.env'))
COPYEOF

if [[ -f "$CONTRACT_PATH" && "$PRESERVE_SOP_CONTRACT" == "1" ]]; then
  echo "🧾 使用 Skill 自带的 reviewed SOP Skill Contract..."
  python3 -m json.tool "$CONTRACT_PATH" >/dev/null
  echo "   ✅ ${CONTRACT_PATH}"
elif [[ "$GENERATE_SOP_CONTRACT" == "1" ]]; then
  CONTRACT_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/generate-sop-skill-contract.py"
  if [[ -f "$CONTRACT_TOOL" ]]; then
    echo "🧾 生成 SOP Skill Contract..."
    python3 "$CONTRACT_TOOL" "$PACKAGE_SKILL_DIR" --output "$CONTRACT_PATH" >/dev/null
    echo "   ✅ ${CONTRACT_PATH}"
  else
    echo "⚠️  找不到 contract 生成器，跳过 sop-skill-contract.json" >&2
  fi
fi

# ── 打 zip（保留目录结构，zip 解压后得到 <skill-name>/ 目录）──
echo "🗜  压缩..."
# 从 package 目录打包，解压后是 <skill-name>/...
if command -v zip &>/dev/null; then
  (cd "$PACKAGE_ROOT" && zip -qr "$ZIP_PATH" "$SKILL_NAME")
elif command -v python3 &>/dev/null; then
  python3 -c "
import zipfile, os, sys
skill_dir = sys.argv[1]
zip_path  = sys.argv[2]
base      = os.path.basename(skill_dir)
parent    = os.path.dirname(skill_dir)
with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(skill_dir):
        for f in files:
            abs_path = os.path.join(root, f)
            arc_name = os.path.join(base, os.path.relpath(abs_path, skill_dir))
            zf.write(abs_path, arc_name)
	" "$PACKAGE_SKILL_DIR" "$ZIP_PATH"
else
  echo "❌ 需要 zip 或 python3 来打包，请先安装其中一个" >&2
  exit 1
fi
echo "   ✅ $(du -sh "$ZIP_PATH" | cut -f1) — ${ZIP_PATH}"
ZIP_SHA256="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$ZIP_PATH")"
echo "   🔐 SHA-256: ${ZIP_SHA256}"
echo ""

RELEASE_PATH="${RELEASE_PATH:-${SKILL_NAME}/releases/${TS}-${ZIP_SHA256:0:16}}"

# ── 上传 zip ──────────────────────────────────────────────
echo "📤 上传 zip..."
ZIP_UPLOAD=$(python3 "$UPLOAD_TOOL" "$ZIP_PATH" "$ZIP_FILENAME" "$RELEASE_PATH")
ZIP_URL=$(printf '%s' "$ZIP_UPLOAD" | python3 -c 'import sys,json; print(json.load(sys.stdin)["url"])')

if [[ -z "$ZIP_URL" ]]; then
  echo "❌ zip 上传失败: $ZIP_UPLOAD" >&2
  exit 1
fi
echo "   ✅ ${ZIP_URL}"
echo ""

# ── 生成安装脚本 ──────────────────────────────────────────
INSTALL_FILENAME="install-${SKILL_NAME}.sh"
INSTALL_SCRIPT="${TMPDIR_WORK}/${INSTALL_FILENAME}"

# A plugin root carries the Codex manifest and its MCP declaration. Keep the
# detection local to publishing so no plugin-specific behavior leaks into
# ordinary Skill installers.
PLUGIN_MODE=0
PLUGIN_REPO=""
PLUGIN_ID="${SKILL_NAME}"
if [[ -f "${SKILL_DIR}/.codex-plugin/plugin.json" && -f "${SKILL_DIR}/.mcp.json" ]]; then
  PLUGIN_MODE=1
  PLUGIN_REPO="${PLUGIN_REPO:-${GITHUB_REPO:-}}"
  if [[ -z "${PLUGIN_REPO}" && -d "${SKILL_DIR}/.git" ]]; then
    PLUGIN_REPO="$(git -C "${SKILL_DIR}" remote get-url origin 2>/dev/null || true)"
    PLUGIN_REPO="${PLUGIN_REPO%.git}"
    PLUGIN_REPO="${PLUGIN_REPO#https://github.com/}"
    PLUGIN_REPO="${PLUGIN_REPO#git@github.com:}"
  fi
  if [[ -z "${PLUGIN_REPO}" ]]; then
    echo "⚠️ 检测到 Codex 插件，但未设置 PLUGIN_REPO；将发布包但不生成自动 marketplace 安装。" >&2
  fi
fi

cat > "$INSTALL_SCRIPT" << SCRIPT_EOF
#!/usr/bin/env bash
# Auto-generated one-click install script for: ${SKILL_NAME}
# Generated by publish-skill — https://skill.vyibc.com/install-publish-skill.sh
set -euo pipefail

SKILL_NAME="${SKILL_NAME}"
ZIP_URL="${ZIP_URL}"
ZIP_SHA256="${ZIP_SHA256}"

# Plugin metadata is optional. When the published package is a Codex plugin,
# the installer also runs the plugin marketplace install and wires its declared
# MCPs through the local Vault auth bridge. Ordinary Skills keep the legacy path.
PLUGIN_MODE="${PLUGIN_MODE:-0}"
PLUGIN_REPO="${PLUGIN_REPO:-}"
PLUGIN_ID="${PLUGIN_ID:-${SKILL_NAME}}"

# ── 工具选择 ──────────────────────────────────────────────
TARGET="\${1:-}"
if [[ -z "\$TARGET" ]]; then
  echo "🛠  选择安装 \${SKILL_NAME} 到哪个 AI 工具："
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
  read -rp "请输入编号 [1-10]: " CHOICE
  case "\$CHOICE" in
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

case "\$TARGET" in
  codex)       DIRS=("\$HOME/.codex/skills")                          ;;
  cursor)      DIRS=("\$HOME/.cursor/skills")                         ;;
  claude)      DIRS=("\$HOME/.claude/skills")  ;;
  gemini)      DIRS=("\$HOME/.gemini/skills")                         ;;
  antigravity) DIRS=("\$HOME/.gemini/antigravity/skills")             ;;
  copilot)     DIRS=("\$HOME/.copilot/skills")                 ;;
  openclaw)    DIRS=("\$HOME/.openclaw/workspace/skills")      ;;
  agents)      DIRS=("\$HOME/.agents/skills")                  ;;
  hermes)      DIRS=("\$HOME/.hermes/skills/devops")           ;;
  all)
    DIRS=(
      "\$HOME/.codex/skills"
      "\$HOME/.cursor/skills"
      "\$HOME/.claude/skills"
      "\$HOME/.gemini/skills"
      "\$HOME/.gemini/antigravity/skills"
      "\$HOME/.copilot/skills"
      "\$HOME/.openclaw/workspace/skills"
      "\$HOME/.agents/skills"
      "\$HOME/.hermes/skills/devops"
    ) ;;
  *) echo "❌ 不支持的 target: \$TARGET"; exit 1 ;;
esac

if [[ -n "\${SKILL_INSTALL_DIR:-}" ]]; then
  DIRS=("\$SKILL_INSTALL_DIR")
fi

echo ""
echo "🚀 安装 \${SKILL_NAME} ..."
echo ""

# ── 下载 zip ──────────────────────────────────────────────
TMPWORK=\$(mktemp -d /tmp/install-skill-XXXXXX)
trap 'rm -rf "\$TMPWORK"' EXIT

echo "   下载 \${ZIP_URL} ..."
curl -fsSL "\${ZIP_URL}" -o "\${TMPWORK}/skill.zip"

if command -v sha256sum &>/dev/null; then
  ACTUAL_SHA256=\$(sha256sum "\${TMPWORK}/skill.zip" | awk '{print \$1}')
elif command -v shasum &>/dev/null; then
  ACTUAL_SHA256=\$(shasum -a 256 "\${TMPWORK}/skill.zip" | awk '{print \$1}')
elif command -v python3 &>/dev/null; then
  ACTUAL_SHA256=\$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "\${TMPWORK}/skill.zip")
else
  echo "❌ 需要 sha256sum、shasum 或 python3 来验证安装包" >&2
  exit 1
fi
if [[ "\${ACTUAL_SHA256}" != "\${ZIP_SHA256}" ]]; then
  echo "❌ 安装包 SHA-256 校验失败" >&2
  exit 1
fi
echo "   🔐 SHA-256 校验通过"

# ── 解压到临时目录（优先 unzip，回退到 python3）────────────
mkdir -p "\${TMPWORK}/extracted"
if command -v unzip &>/dev/null; then
  unzip -q "\${TMPWORK}/skill.zip" -d "\${TMPWORK}/extracted"
elif command -v python3 &>/dev/null; then
  python3 -m zipfile -e "\${TMPWORK}/skill.zip" "\${TMPWORK}/extracted"
elif command -v python &>/dev/null; then
  python -m zipfile -e "\${TMPWORK}/skill.zip" "\${TMPWORK}/extracted"
else
  echo "❌ 需要 unzip 或 python3 来解压，请先安装其中一个" >&2
  exit 1
fi

# 解压后的目录就是 <skill-name>/
EXTRACTED_DIR="\${TMPWORK}/extracted/\${SKILL_NAME}"
if [[ ! -d "\$EXTRACTED_DIR" ]]; then
  # 兼容：如果 zip 里只有一个目录，用它
  EXTRACTED_DIR=\$(find "\${TMPWORK}/extracted" -mindepth 1 -maxdepth 1 -type d | head -1)
fi

# ── 复制到各目标目录 ──────────────────────────────────────
for BASE_DIR in "\${DIRS[@]}"; do
  DEST="\${BASE_DIR}/\${SKILL_NAME}"
  mkdir -p "\$BASE_DIR"
  rm -rf "\$DEST"
  cp -r "\$EXTRACTED_DIR" "\$DEST"
  find "\$DEST/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  echo "  ✅ → \$DEST"
done

if [[ "\$PLUGIN_MODE" == "1" && "\$TARGET" == "codex" ]]; then
  if [[ -z "\$PLUGIN_REPO" ]]; then
    echo "❌ 插件缺少 PLUGIN_REPO，停止自动接入" >&2
    exit 1
  fi
  echo "🔌 安装 Codex 插件：\$PLUGIN_ID"
  codex plugin marketplace add "\$PLUGIN_REPO"
  codex plugin add "\$PLUGIN_ID@personal"
  AUTH_HELPER="\${VYIBC_MCP_AUTH_HELPER:-\$HOME/.codex/bin/vyibc-mcp-auth}"
  if [[ ! -x "\$AUTH_HELPER" ]]; then
    echo "⚠️ 未找到 Vault 认证桥：\$AUTH_HELPER"
    echo "   插件已安装，但 MCP 尚未自动接入。"
  else
    echo "🔐 MCP 将通过 Vault 认证桥按需取短期凭据，不写入永久 Token。"
    MCP_JSON="\$EXTRACTED_DIR/.mcp.json"
    if [[ -f "\$MCP_JSON" && "\$(command -v jq || true)" ]]; then
      while IFS=$'\t' read -r MCP_ID MCP_URL; do
        [[ -n "\$MCP_ID" && -n "\$MCP_URL" ]] || continue
        case "\$MCP_ID" in
          vyibc-cartoon-assets|vyibc-youtube) TOKEN_SOURCE="\$MCP_ID" ;;
          *) TOKEN_SOURCE="fleet" ;;
        esac
        codex mcp remove "\$MCP_ID" >/dev/null 2>&1 || true
        codex mcp add "\$MCP_ID" -- "\$AUTH_HELPER" "\$MCP_URL" "\$TOKEN_SOURCE"
        echo "   ✅ MCP 接入：\$MCP_ID"
      done < <(jq -r '.mcpServers // {} | to_entries[] | [.key,.value.url] | @tsv' "\$MCP_JSON")
    else
      echo "⚠️ 缺少 jq 或插件 MCP 声明，跳过自动 MCP 接入。"
    fi
    echo "   请重新加载 Codex 会话以发现插件声明的 MCP 工具。"
  fi
fi

echo ""
echo "✅ 安装完成！对 AI 说触发词即可使用 \${SKILL_NAME}。"
echo ""
SCRIPT_EOF

chmod +x "$INSTALL_SCRIPT"

# ── 上传安装脚本 ──────────────────────────────────────────
echo "📤 上传安装脚本..."
SCRIPT_UPLOAD=$(python3 "$UPLOAD_TOOL" "$INSTALL_SCRIPT" "$INSTALL_FILENAME" "$RELEASE_PATH")
SCRIPT_URL=$(printf '%s' "$SCRIPT_UPLOAD" | python3 -c 'import sys,json; print(json.load(sys.stdin)["url"])')
# Keep the historical convenience URL; release receipts always use the immutable path.
LATEST_SCRIPT_UPLOAD=$(python3 "$UPLOAD_TOOL" "$INSTALL_SCRIPT" "$INSTALL_FILENAME" "")
LATEST_SCRIPT_URL=$(printf '%s' "$LATEST_SCRIPT_UPLOAD" | python3 -c 'import sys,json; print(json.load(sys.stdin)["url"])')

if [[ -z "$SCRIPT_URL" ]]; then
  echo "❌ 安装脚本上传失败: $SCRIPT_UPLOAD" >&2
  exit 1
fi
echo "   ✅ ${SCRIPT_URL}"

# ── 生成文档页 ────────────────────────────────────────────
SKILL_MD=""
[[ -f "${SKILL_DIR}/SKILL.md" ]] && SKILL_MD=$(cat "${SKILL_DIR}/SKILL.md")

export PUBLISH_DOC_SKILL_DIR="$SKILL_DIR" PUBLISH_DOC_SKILL_NAME="$SKILL_NAME" PUBLISH_DOC_SCRIPT_URL="$SCRIPT_URL" PUBLISH_DOC_TS="$TS"
DOC_RESP=$(python3 - <<'PYEOF'
import json, urllib.request, sys, os
from pathlib import Path
name = os.environ['PUBLISH_DOC_SKILL_NAME']
script = os.environ['PUBLISH_DOC_SCRIPT_URL']
stamp = os.environ['PUBLISH_DOC_TS']
md_path = Path(os.environ['PUBLISH_DOC_SKILL_DIR']) / 'SKILL.md'
skill_md = md_path.read_text() if md_path.is_file() else ''

content = f"""# {name} — 一键安装

## 安装命令

```bash
bash <(curl -fsSL '{script}?ts={stamp}')
```

---

{skill_md}"""

body = json.dumps({"content": content, "title": "Install: " + name}).encode()
if not os.environ.get("PUBLISH_DOC_URL", "default"):
    print("{}"); sys.exit(0)
req = urllib.request.Request(
    os.environ.get("PUBLISH_DOC_URL", "https://upload.vyibc.com/v1beta/documents:toPage"),
    data=body,
    headers={"Content-Type": "application/json"},
    method="POST"
)
try:
    with urllib.request.urlopen(req, timeout=10) as r:
        print(r.read().decode())
except Exception as e:
    print("{}")
PYEOF
)
DOC_URL=$(echo "$DOC_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('page_url',''))" 2>/dev/null || true)

# ── 本地备份 ──────────────────────────────────────────────
LOCAL_OUT="${PUBLISH_BACKUP_DIR:-${HOME}/.codex/skills/.system/published}/${INSTALL_FILENAME}"
mkdir -p "$(dirname "$LOCAL_OUT")"
cp "$INSTALL_SCRIPT" "$LOCAL_OUT"

# ── 输出结果 ──────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Skill 文件已上传"
echo ""
echo "📦 Skill:   ${SKILL_NAME}"
echo "🗜  包文件:  ${ZIP_URL}"
[[ -f "$CONTRACT_PATH" ]] && echo "🧾 Contract: sop-skill-contract.json"
echo ""
echo "🚀 一键安装命令："
echo ""
echo "   bash <(curl -fsSL '${SCRIPT_URL}?ts=${TS}')"
echo ""
[[ -n "$DOC_URL" ]] && echo "📄 文档页面: ${DOC_URL}"
echo "💾 本地备份: ${LOCAL_OUT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Publishing a Skill registers the exact same archive used by its installer.
# Plugin-mode installers are a different artifact type and are not Skill sources.
PUBLISH_SOURCE_METADATA_JSON='{}'
if [[ "$PLUGIN_MODE" == "0" ]]; then
  PUBLISH_SOURCE_METADATA_JSON=$(python3 "$(dirname "${BASH_SOURCE[0]}")/register-harness-release.py" --source-metadata "$SKILL_DIR")
fi
export PUBLISH_SOURCE_METADATA_JSON
HUB_SYNC_JSON='{"status":"not_applicable"}'
HUB_SYNC_FAILED=0
if [[ "$PLUGIN_MODE" == "0" ]]; then
  HUB_SOURCE_JSON=$(python3 -c 'import json,sys; print(json.dumps(dict(zip(["skill","script_url","zip_url","zip_sha256","published_at"],sys.argv[1:]))))' "$SKILL_NAME" "$SCRIPT_URL" "$ZIP_URL" "$ZIP_SHA256" "$TS")
  HUB_SYNC_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/register-hub-source.py"
  if [[ -f "$HUB_SYNC_TOOL" ]]; then
    HUB_SYNC_JSON=$(printf '%s' "$HUB_SOURCE_JSON" | python3 "$HUB_SYNC_TOOL") || HUB_SYNC_FAILED=1
  else
    HUB_SYNC_JSON='{"status":"failed","error":"hub_sync_tool_missing"}'
    HUB_SYNC_FAILED=1
  fi
fi
HARNESS_SYNC_JSON='{"status":"not_applicable"}'
HARNESS_SYNC_FAILED=0
if [[ "$PLUGIN_MODE" == "0" ]]; then
  HARNESS_SYNC_TOOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/register-harness-release.py"
  export PUBLISH_SKILL_SOURCE_DIR="$SKILL_DIR"
  if [[ -f "$HARNESS_SYNC_TOOL" ]]; then
    HARNESS_SYNC_JSON=$(printf '%s' "$HUB_SOURCE_JSON" | python3 "$HARNESS_SYNC_TOOL") || HARNESS_SYNC_FAILED=1
  else
    HARNESS_SYNC_JSON='{"status":"failed","error":"harness_sync_tool_missing"}'
    HARNESS_SYNC_FAILED=1
  fi
fi
export HUB_SYNC_JSON HARNESS_SYNC_JSON
export PUBLISH_CONTRACT_PATH="$CONTRACT_PATH"

# 机器可读输出（供 agent 解析）
python3 -c "
import json, os
print('PUBLISH_RESULT_JSON=' + json.dumps({
  'skill': '${SKILL_NAME}',
  'install_command': \"bash <(curl -fsSL '${SCRIPT_URL}?ts=${TS}')\",
  'script_url': '${SCRIPT_URL}',
  'zip_url': '${ZIP_URL}',
  'zip_sha256': '${ZIP_SHA256}',
  'published_at': '${TS}',
  'hub_sync': json.loads(os.environ['HUB_SYNC_JSON']),
  'harness_sync': json.loads(os.environ['HARNESS_SYNC_JSON']),
  'latest_script_url': '${LATEST_SCRIPT_URL}',
  'contract_path': 'sop-skill-contract.json' if os.path.isfile(os.environ['PUBLISH_CONTRACT_PATH']) else '',
  'doc_url': '${DOC_URL}',
  'local_backup': '${LOCAL_OUT}',
  **json.loads(os.environ['PUBLISH_SOURCE_METADATA_JSON'])
}))
"
if [[ "$HUB_SYNC_FAILED" == "1" || "$HARNESS_SYNC_FAILED" == "1" ]]; then
  echo '⚠️ Skill 文件已发布，但 Fleet 或 Harness 同步未确认。使用对应 register-*.py 重试登记；不要重复上传或误报全流程成功。' >&2
  exit 2
fi

echo "✅ 发布完成，已收到启用的登记回执。"
