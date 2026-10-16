# Real two-phase acceptance — 2026-10-16

## Phase 1: create and publish artifacts

- New independent Cloudflare Worker `vyibc-skill-publisher`, code main 31fea6693252d0ba875d22244b51bcf96bdbd061.
- Exact source readback SHA256 131d5eb992691a7941a2d6ef3c237a3bf6c635635d88ec25641d251073dff8b6.
- Independent D1 publication-job store; no Fleet Worker source/bindings or Fleet database schema changes.
- Actual native Codex MCP called validate/publish/replay/get (4 calls), publishing complete `skill-publisher-cloud@1.0.0` (2 source files).
- ZIP 2584 bytes; SHA256 `ef2974a8fec1e9c1ec33b4708451c5c1a4ae963c0a0e03e8f0e64a360e7a24e6`.
- After creation, public Hub registry still had NONE of the new MCP, Skill or suite. No registration callback is in this service.

## Phase 2: MCP-only admission

- Independent `vyibc-hub` native tools: dry-run, register, replay, receipt lookup for all3 kinds (12 calls).
- Direct HTTP registration calls0; direct directory database writes0; manual catalog edits0.
- New MCP `vyibc-skill-publisher@1.0.0` has3 tools and a dedicated owner credential.
- New Skill `skill-publisher-cloud@1.0.0` keeps its complete source and requires that MCP.
- New plugin `vyibc-skill-publisher-suite@1.0.0` freezes both dependencies.
- Plugin ZIP 16260 bytes; SHA256 `e47f943b872781508ea065d9d9e9f9201dc66ceb65aec9ebc2b8bc835a1b05e5`.
- Downloaded package, checked hashes and full files, loaded Skill in native client, reconnected publisher MCP and read the ORIGINAL phase-one publish job.

The first operation runner completed and saved all phase-two business assertions before its final print referenced the wrong local variable. The print was fixed; a separate read-only native MCP recheck verifies the three original receipts. No artifact regeneration, direct database fix or manual directory insertion was used.

## Retained native installation

- Official public plugin installer ran twice successfully; second inventory identical.
- Plugin installed/enabled; other plugins/marketplaces unchanged.
- Dedicated publisher MCP saved with native user-layer version CAS in private configuration; other configuration unchanged.
- Fresh native process used persistent configuration without environment-token injection, discovered3 tools and read the original publication receipt.
- Native Skill discovery found the real installed plugin-cache `skill-publisher-cloud` entry.
- The phase-one standalone published Bash installer also ran twice against a new temporary `agents` Skill target; both complete files and archive marker matched. Only this owned test target was removed afterward; the retained Codex plugin is untouched.
- No model turns or image/video generation calls.

## Routing and limits

Native clients could call the workers.dev alias, but Hub's Worker-to-Worker discovery returned404. A newly created, previously unclaimed Worker Custom Domain fixes this without changing Fleet's binding profile or global fetch behavior. See [Cloudflare Custom Domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/) for this routing distinction.

Canonical MCP: https://skill-publisher-mcp.vyibc.com/mcp .
Direct alias: https://vyibc-skill-publisher.2513120790.workers.dev/mcp .

Cloud v1 supports complete UTF-8 text Skill trees only; the existing local CLI and its legacy synchronization flags are unchanged. The new cloud service never automatically registers in any directory. This test did not exercise the local CLI's auto-sync flow.

Browser UI clicking is not part of these results; registry projection, downloads, native tools and retained installation were tested.

## Capability-square entries

- mcp: [vyibc-skill-publisher](https://fleet.vyibc.com/#/hub?view=capabilities&type=mcp&q=vyibc-skill-publisher) — receipt `85307f23-756c-4a76-a049-0116f7ab9e10`.
- skill: [skill-publisher-cloud](https://fleet.vyibc.com/#/hub?view=capabilities&type=skill&q=skill-publisher-cloud) — receipt `99614110-b124-481c-a370-c287457d1750`.
- plugin: [vyibc-skill-publisher-suite](https://fleet.vyibc.com/#/hub?view=plugins&plugin=vyibc-skill-publisher-suite) — receipt `702b83f5-0677-4f70-b67a-415c155bc53e`.


## 2026-10-16 Custom Domain outbound routing correction

`global_fetch_strictly_public` is now declared in wrangler.json (main1d56044)
and applied through the documented settings PATCH. Original script source SHA
131d5eb992691a7941a2d6ef3c237a3bf6c635635d88ec25641d251073dff8b6
and all three bindings/secrets are unchanged. Full settings readback preserved
other settings. The first PATCH had the wrong multipart part name and was
rejected400; the corrected request used `settings`. Intents were retained.

A guide publication through the Custom Domain had failed before this correction;
the failed request/version stays reserved. Read-only probes confirmed ZIP404
and old installer bytes. The same guide was published as1.1.1 through workers.dev,
with real native MCP calls and original ZIP hash verification. It was then admitted
only through the independent Hub MCP. No failed job was manually marked published.

After the correction, a tiny publisher-routing-check0.0.1 publication through
the Custom Domain succeeded: actual native validate/publish/job read, original
ZIP hash verification. It was never admitted to Hub. No model or media generation
was invoked. Existing phase separation, durable failure and auth checks remain.
Local publisher tests5/5 passed. This configuration fix does not add a new tool
or mutate the previously frozen cloud-guide Skill1.0.0.
