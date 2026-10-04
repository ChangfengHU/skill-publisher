---
name: publish-skill
description: >
  当用户说"我想分享我的 skill"、"给我的 skill 生成安装脚本"、"publish skill"、
  "generate install command for my skill"、"把我的 skill 发布出去"、"项目远程发布skill" 时自动触发。
  一句话为本地任意 skill 生成一键安装命令，对方机器只需执行一行 bash 命令即可安装。
---

# 发布 Skill（Publish Skill）

**一句话将本地 skill 打包发布，生成可在任意机器上一键安装的命令。**

## 使用场景

- 本地开发了一个 skill，想分享给团队成员
- 在新机器上快速复现自己的 skill 环境
- 将 skill 以 `bash <(curl ...)` 命令形式发布

## 用法示例

```
把我的 allocate-domain skill 发布出去，生成安装命令

publish my todo-helper skill

给 my-skill 生成一键安装脚本
```

## 返回结果

```
✅ Skill 发布成功！

📦 Skill: allocate-domain

🚀 一键安装命令：
bash <(curl -fsSL 'https://skill.vyibc.com/install-allocate-domain.sh?ts=20261004000000')

📄 文档页面（可分享给他人查看）：
https://skill.vyibc.com/abc123.html

💡 使用方式：
  复制上方命令，在任意机器上执行即可安装该 skill
```

## 工作流程

```
用户说：把我的 my-skill 发布出去
         ↓
1. 找到本地 skill 目录（~/.codex/skills/my-skill/）
2. 生成/校验 sop-skill-contract.json sidecar（不改变 skill 本身执行）
3. 打包成 zip 文件并上传到 skill.vyibc.com
4. 生成安装脚本（下载 zip -> 解压 -> 安装到目标工具）并上传
5. 调用 documents:toPage 生成可分享的文档页
6. 用现有宿主凭据向 Fleet 登记该 ZIP 的地址、SHA-256 和 UTC 时间戳
7. 返回带 ?ts=YYYYMMDDHHMMSS 的安装命令，以及 hub_sync 结果
```

## SOP Skill Contract

发布脚本会默认在打包副本中生成 `sop-skill-contract.json`。这个文件是
SOP Node Builder / A2A Runtime 的旁路元数据，普通 agent 可以忽略它。

核心约束：

- Node 公开入参固定为 `instruction + materials`。
- CLI 参数、URL、token、输出目录等只作为内部 adapter hints。
- 输出统一按 `SOP_OUTPUT_DIR` + `manifest.json` / artifacts 发现。
- 不把任何密钥值写进 contract。

详细字段和 LLM patch 提示词见 `references/sop-skill-contract-v1.md`。
发布后的服务验收标准见 `references/sop-skill-service-acceptance.md`。

## 环境要求

- `zip`
- `python3`
- `curl`
- 网络连接

## Fleet 单一来源与插件更新

Skill 内容只维护发布目录，不再在插件页面另写 SKILL.md。插件的 Skill
来自同一个安装脚本指向的 ZIP，包括 scripts、references 和资源文件。

- 发布后安装命令和文档都带 UTC 时间戳；Fleet 登记成功才算同步完成。
- 登记使用 `FLEET_HUB_TOKEN`，或 `FLEET_HUB_TOKEN_FILE` 指向的私有文件；
  默认复用宿主 `~/.boss/token`（必须 0600）。不把凭据写进 Skill/安装命令。
- 插件页面依次 **刷新 Skill → 查看内容差异 → 生成版本 → 更新到 ChatGPT**。
  刷新只下载并校验 ZIP，不执行远程 Bash。只有内容变化才允许生成版本，
  时间戳和 ZIP 打包元数据变化不算新内容。旧插件版本不被原地修改。
- `PUBLISH_RESULT_JSON.hub_sync.status=registered` 才表示 Fleet 已接收。
  文件上传成功但登记失败时脚本退出 2，保留已上传产物；把结果中的
  skill/script_url/zip_url/zip_sha256/published_at 五个字段作为 JSON，交给
  `scripts/register-hub-source.py` 的 stdin 重试，不重复上传。
- `FLEET_HUB_SYNC=0` 仅用于明确不接入 Fleet 的发布，结果会标记 disabled。
- ChatGPT 官方更新接口不能删除旧文件。Fleet 展示删除差异但阻止上传；
  不使用改名/新建副本绕过既有身份和授权。

## 路径限制

- 默认只会从受支持工具的 skill 目录中查找和发布
- 如果手动传入第二个参数，路径也必须落在这些目录内
- 只有显式设置 `ALLOW_EXTERNAL_SKILL_DIR=1` 时，才允许从仓库目录等外部路径发布
- **特殊优化**：当用户明确提到“项目远程发布skill”时，通常是指发布当前项目（仓库）中的某个 skill。此时应当自动设置 `ALLOW_EXTERNAL_SKILL_DIR=1`，并根据用户提到的 skill 名称在当前项目的 `skills/` 目录下查找路径。
