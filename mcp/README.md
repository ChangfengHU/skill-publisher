# Skill Publisher MCP

Independent authenticated Cloudflare Worker for **phase-one artifact publication**.
It reuses the existing `upload-r2.vyibc.com` uploader and `skill.vyibc.com` artifact
host. It never calls Fleet, Hub or Harness. Directory admission is phase two,
performed by an Agent through the separate `vyibc-hub` MCP.

Endpoint: `https://vyibc-skill-publisher.2513120790.workers.dev/mcp`.

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
