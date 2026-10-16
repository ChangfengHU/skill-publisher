# Skill Publisher MCP

Independent authenticated Cloudflare Worker for **phase-one artifact publication**.
It reuses the existing `upload-r2.vyibc.com` uploader and `skill.vyibc.com` artifact
host. It never calls Fleet, Hub or Harness. Directory admission is phase two,
performed by an Agent through the separate `vyibc-hub` MCP.

Canonical endpoint: `https://skill-publisher-mcp.vyibc.com/mcp`.
Direct client alias: `https://vyibc-skill-publisher.2513120790.workers.dev/mcp`.
Use the Custom Domain for Hub admission: same-account Worker-to-Worker discovery
through workers.dev returned404, while native clients could already connect.
The Custom Domain fixes discovery without changing Fleet bindings. The publisher
also enables `global_fetch_strictly_public`: when invoked on the Custom Domain,
uploads and artifact reads must route through the public uploader Worker rather
than bypassing that same-zone route and reaching its origin. See
https://developers.cloudflare.com/workers/configuration/compatibility-flags/#global-fetch-strictly-public.
A real failed custom-domain publication left its immutable request reserved;
the unchanged guide was published successfully as version1.1.1 via workers.dev,
without mutating the failed job or manually registering anything.

Tools:

- `vyibc-skill-publisher_validate_skill`: validate complete supplied UTF-8 files.
- `vyibc-skill-publisher_publish_skill`: reserve a durable request, upload ZIP and
  installer, read back byte hashes, return a publication receipt.
- `vyibc-skill-publisher_get_publish_job`: recover the original request state.

Remote MCPs cannot read a caller's local filesystem: the authorized Agent supplies
`skill`, three-part `version`, and a relative-path-to-text `files` map. Publication
also requires a stable `requestId`. Version/request conflicts fail before uploads;
a failed or interrupted job is never automatically submitted again. Query the
original job and reconcile it before any new publication request.

First cloud version: UTF-8 text only, <=100 files, <=600KB in aggregate. Complete
binary-asset publishing, docs-to-page and automatic SOP-contract generation remain
in the established local CLI. Cloud publication does not silently invoke CLI
callbacks or auto-sync. A future expansion should maintain these explicit limits.

Configuration: private `MCP_TOKEN`, private existing uploader `UPLOAD_TOKEN`, and
independent `DB` binding. No credential belongs in Git, Skill files, tool arguments,
receipts or logs. Existing CLI and existing dirty source workspaces are untouched.
Owner operations only; not a multi-tenant public upload service.

Development (Node22+):

```bash
cd mcp
npm ci --ignore-scripts
npm test
npm run build
```

Provision only the new named Worker and its independent D1 database. Apply
`migration.sql` to that new DB, set private bindings, and deploy clean `main`.
Keep publication receipts and exact source digest. Do not repurpose Fleet's
Worker, database, bindings, routes or secrets for this service.

Health: `GET /healthz`. Verify native MCP initialize/list/call separately.
Installer supports `codex`, `claude`, `agents`; repeated installation verifies
complete local source and refuses changes rather than overwriting it. Reverting
service code and deleting published artifacts are separate operations: keep D1
receipts and existing ZIPs for recovery. Client uninstall removes only the new
publisher MCP connection and its `skill-publisher-cloud` Skill/plugin.

Real creation → MCP-only admission → retained native installation: [acceptance](ACCEPTANCE.md).

Connection template (obtain the dedicated owner credential from authenticated
Hub “安装与配置”; never use the Fleet/Vault master credential):

```json
{"mcpServers":{"vyibc-skill-publisher":{"type":"http","url":"https://skill-publisher-mcp.vyibc.com/mcp","headers":{"Authorization":"Bearer <OWNER_TOKEN>"}}}}
```

The published cloud Skill can also be installed independently:

```bash
bash <(curl -fsSL https://skill.vyibc.com/install-skill-publisher-cloud.sh) codex
```

Skill installation and service authentication are separate. The complete suite
can be obtained from the capability-square plugin entry linked in the acceptance
record. No live credential is included in either public artifact.
