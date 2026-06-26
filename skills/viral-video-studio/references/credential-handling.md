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

The lower-level script is:

```bash
node <skill-dir>/scripts/configure-dashscope-tts.mjs --project-dir=<video-project>
```

The script writes:

- `<project>/.secrets/dashscope_api_key` with `0600`
- `<project>/.env.local` entries for `CONTENT_TTS_PROVIDER=qwen-tts`, `DASHSCOPE_API_KEY_FILE`, model, voice, and scene chunking

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
