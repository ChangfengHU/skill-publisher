#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const args = parseArgs(process.argv.slice(2));
const projectDir = path.resolve(args['project-dir'] || args.projectDir || process.cwd());
const env = {
  ...readEnvFile(path.join(projectDir, '.env')),
  ...readEnvFile(path.join(projectDir, '.env.local')),
  ...process.env
};

const provider = normalizeProvider(env.CONTENT_TTS_PROVIDER || 'edge-tts');
const defaultKeyFile = path.join(projectDir, '.secrets', 'dashscope_api_key');
const configuredKeyFile = env.DASHSCOPE_API_KEY_FILE
  ? resolveProjectPath(projectDir, env.DASHSCOPE_API_KEY_FILE)
  : '';
const candidateKeyFiles = [...new Set([
  configuredKeyFile,
  defaultKeyFile
].filter(Boolean))];

const envKeyUsable = isUsableKey(env.DASHSCOPE_API_KEY || '');
const envKeySummary = envKeyUsable ? buildKeySummary(env.DASHSCOPE_API_KEY) : null;
const fileChecks = candidateKeyFiles.map((filePath) => checkKeyFile(filePath));
const usableFile = fileChecks.find((item) => item.usable);
const keyAvailable = envKeyUsable || Boolean(usableFile);
const accessStatus = normalizeAccessStatus(env.DASHSCOPE_TTS_ACCESS_STATUS || 'unknown');
const accessBlocked = isAccessBlocked(accessStatus);
const qwenUsable = keyAvailable && !accessBlocked;

const result = {
  ok: true,
  projectDir,
  activeProvider: provider,
  qwenTts: {
    requested: provider === 'qwen-tts',
    usable: qwenUsable,
    keyAvailable,
    accessBlocked,
    keySources: [
      envKeyUsable ? 'env:DASHSCOPE_API_KEY' : '',
      usableFile ? `file:${path.relative(projectDir, usableFile.path) || usableFile.path}` : ''
    ].filter(Boolean),
    envKeySummary,
    configuredKeyFile: configuredKeyFile ? path.relative(projectDir, configuredKeyFile) || configuredKeyFile : '',
    defaultKeyFile: path.relative(projectDir, defaultKeyFile),
    model: env.DASHSCOPE_TTS_MODEL || 'qwen3-tts-flash',
    voice: env.DASHSCOPE_TTS_VOICE || 'Cherry',
    accessStatus
  },
  edgeTts: {
    usableWithoutAppKey: true,
    voice: env.CONTENT_TTS_VOICE || 'zh-CN-YunjianNeural',
    rate: env.CONTENT_TTS_RATE || '-6%'
  },
  files: {
    envLocalExists: fs.existsSync(path.join(projectDir, '.env.local')),
    keyFiles: fileChecks.map((item) => ({
      path: path.relative(projectDir, item.path) || item.path,
      exists: item.exists,
      usable: item.usable,
      mode: item.mode,
      keyMask: item.keyMask || '',
      keyFingerprint: item.keyFingerprint || '',
      keyLength: item.keyLength || 0
    }))
  },
  recommendations: buildRecommendations({ provider, qwenUsable, keyAvailable, accessStatus, accessBlocked, envKeyUsable, usableFile })
};

console.log(JSON.stringify(result, null, 2));

function buildRecommendations({ provider, qwenUsable, keyAvailable, accessStatus, accessBlocked, envKeyUsable, usableFile }) {
  const items = [];
  if (provider !== 'qwen-tts') {
    items.push('Default edge-tts can run without an app key.');
  }
  if (provider === 'qwen-tts' && !keyAvailable) {
    items.push('Ask the user for a DashScope API key or a local key-file path before rendering with Qwen TTS.');
    items.push('Use configure-dashscope-tts.mjs to persist the key only after user approval.');
  }
  if (keyAvailable && accessBlocked) {
    items.push(`DashScope key is stored, but TTS access is ${accessStatus}; keep edge-tts active until the Bailian model permission is opened and the wizard is rerun.`);
  }
  if (qwenUsable && provider !== 'qwen-tts') {
    items.push('DashScope key is available; set CONTENT_TTS_PROVIDER=qwen-tts if the user wants Qwen TTS.');
  }
  if (envKeyUsable) {
    items.push('A key is present in the process environment; do not print it.');
  }
  if (usableFile) {
    items.push('A usable key file exists; keep permissions restricted.');
  }
  return items;
}

function checkKeyFile(filePath) {
  if (!filePath) {
    return { path: '', exists: false, usable: false, mode: '' };
  }
  try {
    const stat = fs.statSync(filePath);
    const text = fs.readFileSync(filePath, 'utf8').trim();
    const summary = buildKeySummary(text);
    return {
      path: filePath,
      exists: true,
      usable: isUsableKey(text),
      mode: `0${(stat.mode & 0o777).toString(8)}`,
      keyMask: summary?.keyMask || '',
      keyFingerprint: summary?.keyFingerprint || '',
      keyLength: summary?.keyLength || 0
    };
  } catch {
    return { path: filePath, exists: false, usable: false, mode: '' };
  }
}

function readEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const values = {};
  const text = fs.readFileSync(filePath, 'utf8');
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
    if (!match) continue;
    values[match[1]] = parseEnvValue(match[2]);
  }
  return values;
}

function parseEnvValue(value) {
  const trimmed = String(value || '').trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1).replace(/\\n/g, '\n');
  }
  return trimmed;
}

function resolveProjectPath(projectDir, value) {
  const expanded = String(value || '').replace(/^~(?=$|\/)/, process.env.HOME || '');
  return path.isAbsolute(expanded) ? expanded : path.resolve(projectDir, expanded);
}

function isUsableKey(value = '') {
  const key = String(value || '').trim();
  return key.length >= 20 && !/PASTE_|YOUR_|这里|占位|placeholder/i.test(key);
}

function buildKeySummary(value = '') {
  const key = String(value || '').trim();
  if (!isUsableKey(key)) return null;
  return {
    keyMask: maskKey(key),
    keyFingerprint: crypto.createHash('sha256').update(key).digest('hex').slice(0, 12),
    keyLength: key.length
  };
}

function maskKey(key = '') {
  const text = String(key || '');
  if (!text) return '';
  const prefix = text.startsWith('sk-') ? 'sk-' : text.slice(0, 3);
  const suffix = text.length > prefix.length + 4 ? text.slice(-4) : '';
  let middleLength = text.length - prefix.length - suffix.length;
  middleLength = Math.max(6, Math.min(18, middleLength));
  return `${prefix}${'*'.repeat(middleLength)}${suffix}`;
}

function normalizeProvider(provider = '') {
  const value = String(provider || '').trim().toLowerCase();
  if (value === 'qwen' || value === 'dashscope' || value === 'qwen-tts') return 'qwen-tts';
  if (value === 'cosyvoice' || value === 'cosy-voice') return 'cosyvoice';
  return 'edge-tts';
}

function normalizeAccessStatus(status = '') {
  const value = String(status || '').trim().toLowerCase();
  if (!value) return 'unknown';
  if (value === 'model.accessdenied' || value === 'accessdenied') return 'denied';
  return value;
}

function isAccessBlocked(status = '') {
  return ['denied', 'failed', 'invalid', 'invalid-api-key', 'rate_limited', 'ratelimited'].includes(normalizeAccessStatus(status));
}

function parseArgs(argv) {
  const parsed = {};
  for (const arg of argv) {
    const match = arg.match(/^--([^=]+)=(.*)$/);
    if (match) {
      parsed[match[1]] = match[2];
    }
  }
  return parsed;
}
