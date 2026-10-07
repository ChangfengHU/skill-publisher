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

默认发布流程为 ZIP 上传 → 不可变安装脚本 → Fleet 完整发布定义 → Fleet 分发到 Harness。Harness 使用同一个固定版本和一行安装命令：

```bash
bash <(curl -fsSL 'https://skill.vyibc.com/my-skill/releases/<release>/install-my-skill.sh') claude
```

`hub_sync.status=published` 表示 Fleet 已保存 release 和分发任务；`harness_sync.status=distributed_by_fleet` 表示交由 Fleet 分发，不能作为 Harness 已接收或 Runtime 已安装的证明。接收、环境准备、会话绑定和工具实际调用分别由后续回执展示。

- 发布凭据来自 `FLEET_CAPABILITY_PUBLISH_TOKEN` 或私有 `FLEET_CAPABILITY_PUBLISH_TOKEN_FILE`，默认 `~/.boss/capability-publisher-token`（0600）。服务端配置对应的 `HUB_CAPABILITY_PUBLISH_TOKEN`，不使用机主总令牌。
- 完整定义含 ZIP 摘要、全部文件摘要、Git 来源和兼容声明；Fleet 分配修订、release ID 和 distribution ID。
- `CAPABILITY_VERSION=1.2.3` 可指定展示版本；默认 `0.0.0-<UTC时间戳>`。
- `FLEET_HUB_SYNC=0` 明确关闭 Fleet 登记。`FLEET_HUB_LEGACY_REGISTRATION=1` 保留旧五字段登记；`HARNESS_SKILL_COMPAT_DUAL_WRITE=1` 显式启用旧 Harness 直写，届时 `HARNESS_SKILL_SYNC=0` 可关闭直写。默认不双写两个定义源。
- 发布结果及安装命令不包含凭据。同一发布包保留 codex、claude、agents、all 目标。
- 原插件 Skill ID、Git 仓库、固定提交、相对路径必须保持一致；不匹配的旧条目会拒绝迁移，不覆盖来源或已有关联。
- 整个插件包仍走其插件发布流程；不会把插件根目录冒充普通 Skill。

上传成功但登记失败时退出 2，保存机器结果和 ZIP。把 skill/script_url/zip_url/zip_sha256/published_at/source_git 字段作为 JSON，交给 `register-fleet-capability.py /path/to/published.zip` 的 stdin 重试。相同 publicationKey 返回同一 release 和分发任务，不重复上传。旧兼容入口的重试仍使用各自脚本。

本地验证：

```bash
bash -n skills/publish-skill/scripts/publish-skill.sh
python3 skills/publish-skill/scripts/test-register-hub-source.py
python3 skills/publish-skill/scripts/test-register-harness-release.py
python3 skills/publish-skill/scripts/test-register-fleet-capability.py
python3 skills/publish-skill/scripts/test-publish-install.py
```
