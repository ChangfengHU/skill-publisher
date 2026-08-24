# Quality Gates

## Minimum Technical Checks

Run these before subjective scoring:

- `ffprobe` detects video stream and audio stream.
- vertical output is 9:16, ideally 1080x1920.
- duration is appropriate for the script, usually 45-75 seconds.
- public URL returns HTTP 200 when a public URL is expected.
- audio peak is not clipping; mean volume is not effectively silent.
- contact sheet has nonblank frames and obvious visual changes.

Use `scripts/qc-video.sh`.

## Scoring Rubric

Total: 100.

| Area | Points | Fail examples |
|---|---:|---|
| Thesis and angle | 20 | safe platitudes, no clear stance |
| Script progression | 15 | same idea repeated, no turn every 8-12 seconds |
| Topic-native visuals | 20 | generic people/computers/backgrounds, no anchors |
| Audio/subtitle usability | 15 | robotic or missing TTS, clipped/overflowing subtitles |
| Motion and pacing | 10 | static PPT, cuts too fast to read |
| Evidence and boundaries | 10 | claims not tied to public evidence or stated boundaries |
| Technical delivery | 10 | no public URL, no audio stream, wrong resolution |

## Rubric Audit Contract

When a rendered video has `quality` and `retryPlan`, expose a seven-part audit instead of only a final score. This is the operator-facing explanation for why a video is or is not near 90.

Required dimensions:

| Key | Label | Points | Owner |
|---|---|---:|---|
| thesis-angle | 观点和角度 | 20 | angle-designer |
| script-progression | 脚本推进 | 15 | script-master |
| topic-native-visuals | 话题原生画面 | 20 | asset-director |
| audio-subtitles | 声音和字幕 | 15 | video-render |
| motion-pacing | 动效和节奏 | 10 | video-render |
| evidence-boundary | 证据和边界 | 10 | script-master |
| technical-delivery | 技术交付 | 10 | video-render |

Each item should include `score`, `weight`, `status`, `stage`, `stageLabel`, `reason`, `nextCheck`, and `failedGates`. The audit summary must name the next stage to repair. If the page exports project, report, prompt pack, or artifact pack, include this audit so a later Codex run can continue from the same quality diagnosis.

When building a quality repair prompt, include the audit summary, top risk dimensions, and seven-dimension score list before the failed gates. The repair agent should know both the failing gate such as `asset-topic-fit` and the human-readable dimension such as `话题原生画面`, then return a stage-specific JSON artifact that can be re-rendered and re-scored.

Evaluator repair prompts must work even when the evaluator stage has no direct `video.retryPlan`. If the evaluator returns `videoRubricAudit`, `rollbackStage`, `issues`, and `nextActions`, the page should build a "quality acceptance rollback" prompt from those fields. That prompt must be sent to the target stage when the operator clicks repair rerun, so the target agent sees the seven-dimension diagnosis instead of doing a blind rerun.

When a repair rerun completes, expose a `repairTrace` on the repaired stage output and in artifact exports. It should contain only safe metadata: source (`evaluator`, `video-quality`, or `preflight`), target stage, score summary, top risk dimensions, failed gates, prompt fingerprint, and prompt length. Do not store the full repair prompt in the trace.

The page should also expose a `qualityIteration` summary that aggregates the current rubric audit, retry plan, and latest `repairTrace`. It must show current score/target, top risk, repair count, latest repair source, and the next executable stage; if an upstream stage was repaired after the last video render, the next stage should be `video-render` for re-render verification.

## Decision Policy

- `PASS >= 88`: publishable or close enough to show.
- `WAIT 72-87`: promising, needs targeted repair.
- `REJECT < 72`: restart from angle or creative direction.

Do not call a video "90分" unless it passes all technical checks and has a topic-native visual language.

## Common Rollbacks

- Generic thesis -> rollback to `angle-designer`.
- Good thesis but boring narration -> rollback to `script-master`.
- Good script but mismatch visuals -> rollback to `asset-director`.
- Good assets but wrong visual structure -> rollback to `template-workshop`.
- Good video but subtitles/audio off -> rollback to `video-render`.

## Manual Inspection Checklist

Open the contact sheet and ask:

- Can a viewer identify the topic without reading the full caption?
- Does every image earn its place?
- Are the largest subtitles readable on a phone?
- Is there a visible motion idea beyond pan/zoom?
- Does the ending sharpen the thesis rather than summarize weakly?

If any answer is "no", do not keep rerendering. Repair the failed upstream stage.
