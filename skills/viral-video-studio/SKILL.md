---
name: viral-video-studio
description: Turn a topic, hot trend, IP discussion, AI tool/news item, or creator brief into a high-quality vertical short video. Use when Codex needs to design sharp angles, write scene-by-scene video copy, create styleLock/asset prompts, choose or invent Remotion templates, render/upload MP4s, analyze quality, or build a reusable "template workshop" workflow instead of generic scripts or static slides.
---

# Viral Video Studio

Use this skill to produce short-form videos with a repeatable but topic-native workflow. The goal is not to fill a fixed template; the goal is to decide what the topic deserves, then use or create the right video structure.

## Operating Modes

Choose one mode before acting:

- **Fast production**: use existing templates and assets; optimize for a playable draft.
- **Stable production**: enforce gates; do not render if angle, script, styleLock, or assets are weak.
- **Template workshop**: judge whether existing Remotion templates fit; propose a new template when fit is low.
- **System evolution**: only with explicit user approval, edit the Remotion/video project, add a template, build, render, upload, and QC.

## Core Workflow

1. Classify the topic type and audience state.
2. Write a sharp thesis that can be disagreed with. Avoid "correct but empty" commentary.
3. Build a `creativeBrief` with topic anchors and anti-template rules.
4. Write a 45-75 second scene-by-scene script with visual reasons for each scene.
5. Create a `styleLock` and 6-10 asset prompts tied to topic anchors.
6. Run template fit: use an existing template if fit is high; otherwise enter template workshop.
7. Render only after the script, assets, and template are coherent.
8. QC the video with ffprobe, audio volume, contact sheet, public URL, and topic-fit checks.
9. If quality is below target, return to the specific failed stage instead of blindly rerendering.

For the full pipeline and JSON contracts, read `references/workflow.md`.

## Template Selection Rule

Do not ask "which template looks cool?" Ask "which visual structure explains this topic?"

- Career/life strategy, developer future, route decisions -> career map / route dashboard.
- Entertainment/IP/live-action adaptation -> evidence clipping / review board.
- AI tool proof, product launch, official docs -> proof stage / receipt flow.
- Investigation, food safety, public controversy -> timeline, evidence wall, accountability map; propose a new template if absent.

For fit scoring, template workshop prompts, and code-change boundaries, read `references/template-workshop.md`.

## Rendering Project Behavior

First inspect the workspace:

- If a video project already exists, prefer its existing render pipeline and templates.
- If it resembles `content-agent-workbench`, use `server/videoRenderer.js`, `remotion/root.jsx`, and `/api/video/jobs` patterns.
- If no render project exists, create a minimal Remotion workspace only after telling the user what will be installed or changed.
- Never overwrite unrelated user work. Add new templates beside existing templates.

## Quality Gate

Before calling a video "good", run deterministic checks. Use:

```bash
bash <skill-dir>/scripts/qc-video.sh <video.mp4> [public_url] [out_dir]
```

Then inspect the contact sheet. A video fails if it has no real audio, unreadable subtitles, generic visuals, image/text mismatch, or no topic-native thesis.

For scoring details, read `references/quality-gates.md`.

## Public Uploads and Domains

Use the user's configured upload service when available, but do not store API keys in the skill. Read `references/publishing.md` for environment variables and Cloudflare DNS guidance.

## Required Final Response

When you finish a video run, report:

- public URL and local path
- duration, resolution, audio provider, template/composition
- what was generated or changed
- QC result and score
- remaining issues and the next improvement
