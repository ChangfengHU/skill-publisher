#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const topic = process.argv.slice(2).join(' ').trim() || '未命名话题';
const slug = topic
  .toLowerCase()
  .replace(/[^\p{L}\p{N}]+/gu, '-')
  .replace(/^-+|-+$/g, '')
  .slice(0, 48) || 'video-topic';
const outPath = path.resolve(process.cwd(), `${slug}-video-spec.json`);

const spec = {
  topic,
  target: {
    durationSeconds: 60,
    aspectRatio: '9:16',
    qualityTarget: 88,
    mode: 'stable'
  },
  topicInspiration: {
    sources: [],
    interest: '',
    candidates: [],
    rejected: []
  },
  topicRadar: {
    whyNow: '',
    emotionalHook: '',
    visualPotential: '',
    evidenceBoundary: ''
  },
  angle: {
    thesis: '',
    conflict: '',
    audienceTakeaway: '',
    riskBoundary: ''
  },
  creativeBrief: {
    topicType: '',
    audienceState: '',
    emotionalEngine: '',
    formatDecision: '',
    sharpTake: '',
    topicAnchors: [],
    antiTemplateRules: []
  },
  styleLock: {
    name: '',
    palette: [],
    subtitleStyle: '',
    motionStyle: '',
    topicFit: '',
    referencePolicy: '',
    antiTemplate: ''
  },
  timeline: [],
  audioPlan: {
    provider: 'edge-tts',
    voice: 'zh-CN-YunjianNeural',
    rate: '+35%',
    sceneChunking: true,
    pauseSeconds: 0.12,
    voiceDirection: '',
    subtitleAlignmentPolicy: ''
  },
  assets: [],
  templateFit: {
    bestExistingTemplate: '',
    templateFitScore: 0,
    needNewTemplate: false,
    proposedTemplate: null
  },
  qc: {
    decision: '',
    score: 0,
    issues: []
  }
};

fs.writeFileSync(outPath, JSON.stringify(spec, null, 2));
console.log(outPath);
