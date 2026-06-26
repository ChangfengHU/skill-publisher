# Template Workshop

The template workshop is the difference between a generic video generator and a topic-native video studio.

## Fit Scoring

Score existing templates before writing code:

```json
{
  "bestExistingTemplate": "CareerMapVideo",
  "templateFitScore": 88,
  "needNewTemplate": false,
  "reason": "职业路线图模板能承载该话题",
  "gapAnalysis": [],
  "newTemplateIdea": ""
}
```

Thresholds:

- `>= 86`: use existing template.
- `78-85`: use existing template, but adapt scene fields and styleLock.
- `60-77`: propose template modification; ask user before code changes.
- `< 60`: do not force render; design a new template.

## Existing Template Patterns

Use these as semantic categories, not hard dependencies.

### CareerMapVideo

Best for:

- developer/career/future-of-work topics
- route choices, skill maps, "where is the path" questions
- AI impact on roles, workflow ownership, productized skills

Visual structure:

- route rail
- dashboard board
- code/debt panel
- evidence/decision cards
- bottom large subtitles

### EntertainmentReviewVideo

Best for:

- IP adaptation, live-action casting, entertainment hot search
- trailer/PV review, fandom concern, "is this adaptation risky?"

Visual structure:

- clipped source tag
- evidence receipt
- red-mark review language
- bottom punchline subtitles

### ProofStageVideo

Best for:

- AI tool/product launch proof
- official docs, feature claims, workflow receipts

Visual structure:

- browser/terminal proof card
- claim -> receipt -> result
- strict evidence hierarchy

### FastToolPromoVideo

Best for:

- fast-paced tool demos
- "why this tool matters" and short proof loops

Use carefully. Do not use for slow analysis or dense thought pieces.

### GeneratedAssetVideo

Fallback. Use only when the topic can be carried by high-quality generated assets and scene captions. If it feels like a generic slideshow, escalate to template workshop.

## New Template Proposal Schema

When a new template is needed, output:

```json
{
  "proposedTemplate": {
    "templateName": "InvestigationTimelineVideo",
    "topicTypes": ["食品安全", "调查复盘", "舆论反转"],
    "visualConcept": "证据墙 + 时间线 + 责任链",
    "sceneLayout": "left timeline, center evidence board, right verdict card, bottom subtitle",
    "motionRules": [
      "timeline node advances each scene",
      "evidence card flips in",
      "responsibility chain highlights one actor at a time"
    ],
    "propsNeeded": ["sourceTag", "receiptTitle", "receiptItems", "verdict", "captionTag"]
  },
  "developmentPrompt": "..."
}
```

## Development Prompt Contract

Only enter this mode after user confirmation. The prompt to Codex should include:

- topic and thesis
- why existing templates fail
- exact new composition name
- allowed files
- forbidden actions
- tests to run
- final response requirements

Example:

```text
You are in system evolution mode for a Remotion video project.
Create InvestigationTimelineVideo because existing templates cannot express evidence chronology and accountability.
Allowed edits: remotion/root.jsx, server/videoRenderer.js, server/templateRegistry.js if present, tmp/render-*.mjs, public/generated-assets/runs/*.
Do not delete existing compositions. Do not rewrite unrelated UI/server code.
Implement the composition, add selector rules from styleLock, render one sample video, run npm run build, ffprobe, contact sheet, and public URL HEAD check.
Return changed files, video URL, QC score, remaining issues.
```

## Promotion to Template Library

Promote a new template only if:

- build passes
- sample video renders
- contact sheet is readable
- subtitles do not overlap
- visual structure solves the stated topic type
- selector does not hijack unrelated styleLocks
- the template can be reused for at least two plausible future topics
