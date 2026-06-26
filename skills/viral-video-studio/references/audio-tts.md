# Audio and TTS Rules

Use real narration by default. A short video with no voice or only a fallback tone bed cannot pass stable production.

## Provider Selection

For `content-agent-workbench`, inspect `server/videoRenderer.js` and `/api/audio/provider-status` first.

Recommended order:

1. `edge-tts`: default built-in path. Use when the user wants a reliable draft or no paid voice key is available.
2. `qwen-tts`: use only when DashScope credentials are configured and access is not denied.
3. `cosyvoice`: reserved provider. Do not claim it works unless the project has an implementation.

Relevant environment variables:

```bash
CONTENT_TTS_PROVIDER=edge-tts
CONTENT_TTS_VOICE=zh-CN-YunjianNeural
CONTENT_TTS_RATE=+35%
CONTENT_TTS_SCENE_CHUNKS=1
CONTENT_TTS_SCENE_PAUSE_SECONDS=0.12
```

For Qwen/DashScope:

```bash
CONTENT_TTS_PROVIDER=qwen-tts
DASHSCOPE_API_KEY_FILE=/path/to/key
DASHSCOPE_TTS_MODEL=qwen3-tts-flash
DASHSCOPE_TTS_VOICE=Cherry
```

Never write API keys into the skill or repo.

Before enabling Qwen/DashScope, run `scripts/tts-credential-check.mjs`. If no usable key is found, follow `references/credential-handling.md`.

## Voice Direction

Match the voice to the topic:

| Topic type | Voice direction |
|---|---|
| entertainment/IP critique | sharp, amused, fast but clear |
| suspense/novel/movie analysis | low, controlled, less cute |
| AI/product/news | clear, brisk, factual |
| career/developer strategy | calm, slightly urgent, not salesy |

Avoid broadcast-host stiffness. The narration should sound like a creator with a point of view.

## Speed and Alignment

- Use scene-level TTS chunks when possible.
- Keep each scene long enough for the viewer to read the card and hear the line.
- Start around `+30%` to `+45%` for fast Chinese short videos; slow down for dense factual claims.
- If subtitles feel late, shorten narration lines before changing animation timing.
- If cards disappear before they can be read, increase minimum scene duration before rerendering.

## Script Constraints for Good TTS

Write spoken lines, not essay sentences:

- one idea per line
- fewer commas
- no long embedded clauses
- avoid dense names/numbers unless visually supported
- keep punch lines short enough to land on screen

Bad:

```text
在当前行业变化的大背景下，我们可以从多个维度去理解程序员的长期竞争力。
```

Better:

```text
程序员的出路，不是转管理，也不是学 AI。是别再只卖工时。
```

## QC

Fail or rerun audio when:

- no real TTS is present
- voice is too slow or too robotic for the topic
- subtitles and voice drift by more than one scene
- music covers narration
- ffmpeg volume analysis shows clipped or barely audible voice

Always report provider, voice, rate, and whether scene chunking was used.
