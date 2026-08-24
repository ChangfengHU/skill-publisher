# Viral Video Studio Workflow

## Stage Contract

Use these stages unless the user explicitly asks for a smaller task.

| Stage | Output | Gate |
|---|---|---|
| topic-inspiration | hot/source-backed idea pool | live source status, interest fit, usable source URL |
| topic-radar | 3-5 candidate topics | why now, emotional hook, visual potential, source boundary |
| angle-designer | 2-4 angles | conflict, audience payoff, scene angle, risk boundary |
| creative-director | 1-3 creative directions | sharp thesis, topic anchors, evidence policy, anti-template rules |
| script-master | one final script | 45-75s, every 8-12s has a turn, captions and visual hints are new |
| asset-director | styleLock + assets | each asset has sourceEvidence, semanticAnchors, notGenericReason |
| template-workshop | template fit decision | templateFitScore, needNewTemplate, development prompt |
| audio-director | TTS plan | provider, voice, rate, scene chunking, subtitle alignment |
| video-render | MP4 | real video stream, real audio track, public or local URL |
| evaluator | PASS / WAIT / REJECT | score, issues, rollback stage |

## Topic Inspiration Prompt

Use this before topic-radar when the user asks for inspiration or only gives broad preferences.

First run `scripts/topic-inspiration.mjs` when live web access is appropriate. Then choose 3-5 candidates by why-now, emotional hook, visual potential, thesis potential, and risk boundary. See `references/topic-inspiration.md`.

## Topic Radar Prompt

Ask what should be made now, not what is merely hot.

Return JSON:

```json
{
  "decision": "PASS",
  "cards": [
    {
      "title": "可执行选题",
      "source": "hot source or user brief",
      "whyNow": "30-80 字",
      "emotionalHook": "前 3 秒可用",
      "visualPotential": "具体画面/对比点",
      "recommendedFormat": "Remotion/图文/短剧/观点对撞",
      "score": 88,
      "evidence": "可核验边界"
    }
  ],
  "nextIterationStage": "none",
  "qualityNotes": []
}
```

## Angle Designer Prompt

Generate angles that create retention:

- one counterintuitive angle
- one controversy/comparison angle
- one scene-driven angle
- one risk-aware angle if the topic is sensitive

Each card must include `hook3s`, `conflict`, `audienceTakeaway`, `sceneAngle`, `style`, `risk`, and `score`.

## Creative Director Prompt

Do not choose a template first. Define:

- `topicType`
- `audienceState`
- `emotionalEngine`
- `formatDecision`
- `sharpTake`
- `visualLanguage`
- `rhythm`
- `shotList`
- `materialNeeds`
- `referenceUse`
- `antiTemplate`

Always output:

```json
{
  "creativeBrief": {
    "topicType": "",
    "audienceState": "",
    "corePromise": "",
    "formatDecision": "",
    "visualReason": "",
    "referencePolicy": "",
    "topicAnchors": [
      {
        "key": "anchor-key",
        "label": "观众能识别的题材信号",
        "terms": ["visible", "terms"],
        "visualTest": "只看画面也能知道这是该话题"
      }
    ],
    "topicAnchorPolicy": {
      "minCoveredAnchors": 4,
      "minSceneFitRatio": 0.75
    }
  },
  "styleCandidates": [],
  "antiTemplateRules": []
}
```

## Script Master Prompt

Write one final script, not options. It must include:

- `title`
- `coverCopy`
- `openingHook`
- `thesis`
- `videoCopyReview`
- `claimEvidenceMap`
- `topicAnchors`
- `timeline`
- `narration`
- `subtitles`
- `rhythmPlan`
- `remotionScenes`
- `riskCheck`
- `antiBoringCheck`
- `audioPlan`

Timeline items:

```json
{
  "time": "0-8",
  "voice": "spoken line",
  "caption": "large subtitle",
  "sceneHint": "visual action and why it fits",
  "semanticAnchors": ["anchor-key"],
  "sourceTag": "optional evidence",
  "receiptTitle": "optional panel title",
  "receiptItems": ["short item"]
}
```

## Audio Director Prompt

Before rendering, output:

```json
{
  "audioPlan": {
    "provider": "edge-tts|qwen-tts",
    "voice": "",
    "rate": "",
    "sceneChunking": true,
    "pauseSeconds": 0.12,
    "voiceDirection": "",
    "subtitleAlignmentPolicy": "",
    "fallback": "edge-tts if selected provider fails"
  }
}
```

Use `references/audio-tts.md` for provider and timing rules.

## Asset Director Prompt

Return one asset plan:

```json
{
  "styleLock": {
    "name": "topic-native-style",
    "palette": ["#0f766e", "#d97706"],
    "subtitleStyle": "",
    "motionStyle": "",
    "topicFit": "",
    "topicAnchors": [],
    "topicAnchorPolicy": {},
    "referencePolicy": "",
    "antiTemplate": "",
    "qualityBar": ""
  },
  "assets": [
    {
      "sceneIndex": 1,
      "assetRole": "",
      "visualPurpose": "",
      "sourceEvidence": "",
      "specificCanonSignals": [],
      "semanticAnchors": [],
      "imagePrompt": "",
      "negativePrompt": "",
      "notGenericReason": "",
      "expectedPath": "public/generated-assets/runs/{requestId}/scene-01.png",
      "status": "planned",
      "score": 90
    }
  ]
}
```

Image prompts must be scene-level. Include visible subject, setting, composition, event/action, light/color, and subtitle safe area. Do not write generic background prompts.

## Evaluator Prompt

Evaluate the whole chain and rendered video.

Return:

```json
{
  "decision": "PASS|WAIT|REJECT",
  "score": 0,
  "passed": [],
  "issues": [],
  "rollbackStage": "topic-inspiration|topic-radar|angle-designer|creative-director|script-master|audio-director|asset-director|template-workshop|video-render",
  "nextActions": [],
  "videoRubricAudit": {
    "version": "video-rubric-audit-v1",
    "status": "pass|wait|reject",
    "score": 0,
    "target": 90,
    "nextStage": "asset-director",
    "nextStageLabel": "素材生成",
    "summary": "当前分数、主要风险、下一步回退阶段",
    "items": [
      {
        "key": "topic-native-visuals",
        "label": "话题原生画面",
        "weight": 20,
        "score": 0,
        "status": "pass|wait|reject",
        "stage": "asset-director",
        "stageLabel": "素材生成",
        "reason": "为什么过/不过",
        "nextCheck": "下一轮如何验收",
        "failedGates": []
      }
    ],
    "topRisks": []
  }
}
```

Use `WAIT` when the video is promising but needs targeted repair. Use `REJECT` when the topic, thesis, or style direction is fundamentally wrong.
The evaluator must expose all seven rubric dimensions from `quality-gates.md`, not only a final score. The page should be able to show this object directly and route a repair run to `rollbackStage`.
