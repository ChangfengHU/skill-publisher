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
