---
name: skill-publisher-cloud
description: 通过云端 MCP 校验并发布本地 Skill 的完整文本文件，生成可验证安装包与发布回执；适用于用户要求分享或发布 Skill，不自动登记能力广场。
---

# 云端 Skill 发布

服务：`https://vyibc-skill-publisher.2513120790.workers.dev/mcp`。使用客户端配置中的专用凭据；不要把凭据传入工具参数或文件。

## 第一阶段：创建并发布

1. 从用户授权的 Skill 目录读取完整文件，保留相对路径。云端无法直接读取本机路径，需要由 Agent 传 `files`。当前支持不超过100个UTF-8文本文件、总计600KB；二进制资源请使用既有本地 `publish-skill` 流程，不能悄悄省略附件。
2. 选择稳定 `skill` ID 和三段数字版本；`SKILL.md` 中的 name 必须与 ID 一致。排除密钥、Cookie、Token和与本次发布无关的文件。
3. 调用 `vyibc-skill-publisher_validate_skill`，传 `skill/version/files`。通过后，用相同内容及稳定 `requestId` 调用 `vyibc-skill-publisher_publish_skill`。
4. 超时或失败先用 `vyibc-skill-publisher_get_publish_job` 查询原请求。相同请求不会再次上传。`publishing/failed` 不代表完全没有产物，不要不断换请求号重试；先核对原回执和产物。相同 ID/版本已保留时需检查原作业，内容变更使用新版本。
5. `status:published` 仅证明 ZIP 和安装脚本上传并逐字节验收。交付 `receipt` 中的安装命令、ZIP SHA256、来源和文件清单。

发布会更新该 Skill 名称的安装器入口，固定 ZIP 保留。发布前确认用户授权了这个 Skill 名称的发布，不能借此覆盖其他人的能力。

## 第二阶段：独立入驻

只有用户要求入驻时，再通过独立的 `vyibc-hub_register_hub_skill` 提交第一阶段 receipt 的五项来源：`skill/script_url/zip_url/zip_sha256/published_at`。不要调用 HTTP 登记接口、直接写 D1、手工改目录，或把上传成功当作已经入驻。

MCP 和组合插件分别使用 Hub 的对应登记工具。两个服务的凭据分别配置：发布器凭据负责上传，Hub 凭据负责目录登记。

输入样例和验证、卸载方式见 [协议与示例](references/protocol.md)。
