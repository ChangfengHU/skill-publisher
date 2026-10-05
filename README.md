# 🚀 Skill Publisher

**一句话将本地 AI skill 打包发布，生成可在任意机器一键安装的 bash 命令。**

就像 `npx` 之于 npm 包，`publish-skill` 让你的 AI skill 可以被任何人一键安装。

---

## ⚡ 一键安装 publish-skill

```bash
bash <(curl -fsSL https://skill.vyibc.com/install-publish-skill.sh)
```

安装完成后，直接对你的 AI 说：

```
把我的 my-skill 发布出去
```

AI 会自动打包、上传，返回一条安装命令：

```bash
bash <(curl -fsSL https://skill.vyibc.com/install-my-skill.sh)
```

把这条命令分享给任何人，他们就能在自己的机器上一键安装你的 skill。

---

## 工作原理

```
你说：把我的 my-skill 发布出去
         ↓
1. 在本机查找 skill 目录
   (~/.codex/skills/  ~/.cursor/skills/  ~/.copilot/skills/ 等)
2. 打包成 my-skill-<timestamp>.zip 上传到 skill.vyibc.com
3. 生成安装脚本 install-my-skill.sh 上传到 skill.vyibc.com
4. 输出一键安装命令
         ↓
bash <(curl -fsSL https://skill.vyibc.com/install-my-skill.sh)
```

安装脚本运行时：下载 zip → 解压 → 复制到目标 AI 工具的 skills 目录

---

## 支持的 AI 工具

安装时会弹出菜单，选择安装到哪个工具：

| # | 工具 | 安装路径 |
|---|------|---------|
| 1 | Codex | `~/.codex/skills/<name>/` |
| 2 | Cursor | `~/.cursor/skills/<name>/` |
| 3 | Claude | `~/.claude/skills/<name>/` |
| 4 | Gemini | `~/.gemini/skills/<name>/` |
| 5 | Antigravity | `~/.gemini/antigravity/skills/<name>/` |
| 6 | Copilot | `~/.copilot/skills/<name>/` |
| 7 | OpenClaw | `~/.openclaw/workspace/skills/<name>/` |
| 8 | Agents | `~/.agents/skills/<name>/` |
| 9 | Hermes | `~/.hermes/skills/devops/<name>/` |
| 10 | 全部安装 | — |

---

## 命令行直接使用

不依赖 AI，直接运行脚本：

```bash
# 发布指定 skill（自动在常见路径下查找）
bash ~/.codex/skills/publish-skill/scripts/publish-skill.sh <skill-name>

# 指定 skill 目录（仅允许 8 个受支持工具目录内的路径）
bash ~/.codex/skills/publish-skill/scripts/publish-skill.sh <skill-name> /path/to/skill

# 如果确实要从仓库目录等外部路径发布，需要显式开启覆盖
ALLOW_EXTERNAL_SKILL_DIR=1 bash ~/.codex/skills/publish-skill/scripts/publish-skill.sh <skill-name> /path/to/skill

# 自定义文件服务器
FILE_API_URL=http://your-server:1002 bash publish-skill.sh <skill-name>
```

---

## 兼容性

| 环境 | 支持 |
|------|------|
| macOS | ✅ |
| Linux | ✅ |
| Windows (Git Bash / WSL) | ✅ |
| Windows 原生 cmd/PowerShell | ❌ |

解压依赖：优先使用 `unzip`，自动回退到 `python3 -m zipfile`（无需额外安装）。

---

## 相关项目

- [auto-domain](https://github.com/ChangfengHU/auto-domain) — 自动分配域名 skill，本项目即用它发布

## Harness Skill 互通

默认发布流程同时登记 Fleet Hub 和 Harness：ZIP 上传 → 不可变版本安装脚本 → 最新便捷入口 → 校验并登记 Harness 的 Skill Registry、版本和能力目录。Harness 使用发布器返回的 `install_command`，例如：

```bash
bash <(curl -fsSL 'https://skill.vyibc.com/my-skill/releases/<release>/install-my-skill.sh') claude
```

同一发布包支持 `codex`、`claude`、`agents`、`all` 等目标。`PUBLISH_RESULT_JSON.harness_sync.status=registered` 表示 Harness 已核验 ZIP SHA256、安装脚本与包的一致性并接收版本；上传完成本身不代表登记成功。

- `HARNESS_SKILL_SYNC=0`：明确仅发布文件，不接入 Harness。
- `FLEET_HUB_SYNC=0`：明确不接入 Fleet；两项同步互相独立。
- `FILE_API_TOKEN`：文件服务需要认证时从授权环境注入，不写入安装脚本或命令。
- `SKILL_VERSION`：可选的发布版本名；默认使用 UTC 发布时间。
- `SKILL_INSTALL_DIR`：安装时可选的明确目标目录，便于项目内安装和隔离验证。
- 插件内单个 Skill 使用其真实目录发布；Git 仓库、提交和目录作为 `source_git` 保存在结果中。第一次替换 Harness 的 Git 条目时必须匹配已登记来源，保留原 Skill ID、插件关联和已有执行契约。
- 自动生成的 `sop-skill-contract.json` 仍是包内旁路元数据，不会自动成为 Harness 已验收的 Node 执行契约。
- 整个 Codex 插件包仍走现有插件安装流程，不把插件根目录冒充一个普通 Skill。

上传成功但同步失败时退出码为 2。保存完整 `PUBLISH_RESULT_JSON`，修复问题后把它作为 stdin 交给对应 `register-harness-release.py` / `register-hub-source.py`。登记重试不会再次上传文件，不覆盖旧版本回执。最新入口用于便捷安装；Harness 记录的是不可变版本路径。

本地验证：

```bash
bash -n skills/publish-skill/scripts/publish-skill.sh
python3 skills/publish-skill/scripts/test-register-hub-source.py
python3 skills/publish-skill/scripts/test-register-harness-release.py
python3 skills/publish-skill/scripts/test-publish-install.py
```
