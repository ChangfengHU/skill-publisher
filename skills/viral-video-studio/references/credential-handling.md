# Credential Handling

Use this when the user asks to use a paid or keyed provider, especially Qwen/Bailian/DashScope TTS.

## Rules

- Never include API keys in `SKILL.md`, references, repo files, screenshots, logs, final answers, or command arguments.
- Prefer a local secret file with `0600` permissions over putting keys directly in `.env.local`.
- Do not silently create persistent credentials. Ask the user before saving a key for reuse.
- If the user pastes a key in chat, do not repeat it. Confirm only that a key was received.
- Use environment variables only for runtime configuration; keep the secret value itself in a file.

## Detection

Run:

```bash
node <skill-dir>/scripts/tts-credential-check.mjs --project-dir=<video-project>
```

The script reports safe metadata only:

- active provider
- whether Qwen/DashScope TTS is usable
- whether a key exists in env or key file
- likely config files
- next actions

For quick status checks:

```bash
bash <skill-dir>/scripts/install-wizard.sh --skill-dir=<skill-dir> --project-dir=<video-project> --show-tts-status
```

## If Key Is Missing

Ask one concise question:

```text
要使用百炼/千问 TTS，我需要一个 DashScope API Key。你希望我只用于本次运行，还是保存到项目本地 .secrets/dashscope_api_key 以后复用？
```

If the user chooses local persistence, use:

```bash
bash <skill-dir>/scripts/install-wizard.sh --skill-dir=<skill-dir> --project-dir=<video-project> --configure-tts
```

Then provide the key through stdin/interactively. Do not pass it as a command argument. For non-interactive automation, pipe the key through stdin only.

Recommended two-step flow:

1. `bash <skill-dir>/scripts/install-wizard.sh --skill-dir=<skill-dir> --project-dir=<video-project> --show-tts-status`
2. `bash <skill-dir>/scripts/install-wizard.sh --skill-dir=<skill-dir> --project-dir=<video-project> --configure-tts`

Only step 2 writes files to disk (`.secrets/dashscope_api_key` + `.env.local`).

The lower-level script is:

```bash
node <skill-dir>/scripts/configure-dashscope-tts.mjs --project-dir=<video-project>
```

The script writes:

- `<project>/.secrets/dashscope_api_key` with `0600`
- `<project>/.env.local` entries for `CONTENT_TTS_PROVIDER`, `DASHSCOPE_API_KEY_FILE`, model, voice, access status, and scene chunking

The current installer verifies TTS access with a short DashScope request before enabling Qwen TTS:

- success: set `CONTENT_TTS_PROVIDER=qwen-tts` and `DASHSCOPE_TTS_ACCESS_STATUS=verified`
- model/account denied: save the key, set `CONTENT_TTS_PROVIDER=edge-tts`, set `DASHSCOPE_TTS_ACCESS_STATUS=denied`, and tell the user to open model access in Bailian
- network/unknown verification failure: save the key and mark status `unknown`; do not print the key
- test-only skipped verification: when `VIRAL_VIDEO_STUDIO_TTS_SKIP_VERIFY=1` is set, save the key, set `CONTENT_TTS_PROVIDER=qwen-tts`, and set `DASHSCOPE_TTS_ACCESS_STATUS=skipped`; do not use this as proof that real TTS access works

Interactive installs must show a TTS configuration window before asking whether to configure TTS. The window must include the video project directory, default key path, `.env.local` path, save/read rules, current provider, model/voice/access status, and any existing key as a masked preview with length and short SHA-256 fingerprint. Also print a `--show-tts-status` command so the user can re-open the same safe status window later. The key input should display `******` as a mask while typing, then report the same masked preview, length, and fingerprint for confirmation. If an existing key file is detected, including when Qwen TTS is already enabled, show the same masked preview, file path, permission mode, and fingerprint before exiting or verifying. Never display the raw key.

If the install command is launched from `/`, normalize the video project directory to `$HOME` before showing or writing `.secrets/dashscope_api_key`. Do not write `//.secrets/...` or `/.env.local`.

If the installer is running in a non-interactive shell, it cannot open the key prompt. Print the manual `install-wizard.sh --configure-tts` command and explain that the interactive run will show a masked preview after submission.

## Runtime-Only Option

If the user does not want persistence, set environment variables only for the current run:

```bash
CONTENT_TTS_PROVIDER=qwen-tts
DASHSCOPE_API_KEY_FILE=/path/to/user-provided-key-file
```

Do not create files.

## Verification

After configuration, run:

```bash
node <skill-dir>/scripts/tts-credential-check.mjs --project-dir=<video-project>
```

Then call the app's provider-status endpoint if available:

```bash
curl -sS http://localhost:<port>/api/audio/provider-status
```

Report only safe fields: provider, key source type, model, voice, access status, and fallback provider.
