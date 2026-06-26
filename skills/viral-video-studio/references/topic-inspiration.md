# Topic Inspiration Rules

Use this when the user asks for inspiration, wants a new topic, asks what is hot today, asks "你能做什么", or gives only a broad interest area.

If the user asks what the studio can do, answer briefly:

- topic inspiration from hot sources
- angle/thesis design
- scene-by-scene script
- TTS/audio plan
- image asset prompts
- Remotion template selection or workshop
- render/upload/QC

Then offer to run topic inspiration immediately.

## Source Strategy

Prefer live sources when available:

- DailyHot API: `https://dailyhotapi-hazel.vercel.app`
- entertainment/social: `douyin`, `bilibili`, `toutiao`, `weibo`
- AI/tech/product: `ithome`, `36kr`, `huxiu`, `sspai`
- user-supplied URLs, official docs, articles, or reference videos

Run:

```bash
node <skill-dir>/scripts/topic-inspiration.mjs --interest="AI,程序员,影视,微博热搜" --limit=24
```

If the source fails, continue with available sources and disclose failures.

## Ranking Criteria

Do not recommend a topic just because it is hot. Score by:

| Factor | Meaning |
|---|---|
| why now | happened recently or resurfaced with a new conflict |
| emotional hook | viewers can instantly care, laugh, argue, or feel seen |
| visual potential | there are concrete scenes, receipts, UI, people, maps, timelines, or comparisons |
| thesis potential | the video can make a disagreeable point, not just summarize |
| source boundary | claims can be framed without pretending certainty |
| format fit | topic maps to a video structure, not just text narration |

## Output Contract

Return 3-5 cards:

```json
{
  "cards": [
    {
      "title": "",
      "source": "",
      "whyNow": "",
      "emotionalHook": "",
      "sharpTakeSeed": "",
      "visualPotential": "",
      "recommendedFormat": "",
      "riskBoundary": "",
      "score": 88,
      "sourceUrl": ""
    }
  ],
  "rejected": [
    {
      "title": "",
      "reason": "hot but no visual thesis"
    }
  ]
}
```

## Topic Families

Use these as starting lanes, not templates:

- **AI/product**: official release, new agent idea, capability gap, developer workflow impact.
- **career/developer**: route choice, industry anxiety, tool displacement, pricing of skill.
- **entertainment/IP**: casting controversy, trailer/PV mismatch, adaptation risk, fandom expectation.
- **social/hot search**: public conflict, reversal, accountability, platform incentives.
- **consumer/productivity**: tool migration, office workflow, price/value contradiction.

## Selection Rule

Pick the topic that can produce the strongest first 3 seconds and the clearest visual proof. If the user dislikes the topic, do not defend it; rerun topic inspiration with their negative preference as a constraint.
