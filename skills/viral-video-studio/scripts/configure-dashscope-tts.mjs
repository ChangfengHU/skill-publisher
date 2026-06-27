#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
const projectDir = path.resolve(args['project-dir'] || args.projectDir || process.cwd());
const keyFile = resolveProjectPath(projectDir, args['key-file'] || args.keyFile || '.secrets/dashscope_api_key');
const envLocalPath = path.join(projectDir, '.env.local');
const existingEnv = {
  ...readEnvFile(path.join(projectDir, '.env')),
  ...readEnvFile(envLocalPath)
};
const model = args.model || existingEnv.DASHSCOPE_TTS_MODEL || 'qwen3-tts-flash';
const voice = args.voice || existingEnv.DASHSCOPE_TTS_VOICE || 'Cherry';
const language = args.language || existingEnv.DASHSCOPE_TTS_LANGUAGE || 'Chinese';
const endpoint = args.endpoint || existingEnv.DASHSCOPE_TTS_ENDPOINT || 'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';
const verifyAccess = args['skip-verify'] !== '1' && args['skipVerify'] !== '1';
const forceEnable = args['force-enable'] === '1' || args.forceEnable === '1';

const key = (await readStdin()).trim();
if (!isUsableKey(key)) {
  console.error('No usable DashScope API key received on stdin.');
  process.exit(2);
}

fs.mkdirSync(path.dirname(keyFile), { recursive: true, mode: 0o700 });
fs.writeFileSync(keyFile, `${key}\n`, { mode: 0o600 });
fs.chmodSync(keyFile, 0o600);

const verification = verifyAccess
  ? await verifyDashScopeTts({ apiKey: key, endpoint, model, voice, language })
  : { checked: false, ok: true, status: 'skipped', httpStatus: 0, code: '', message: 'verification skipped' };
const shouldEnableQwen = forceEnable || verification.ok || verification.status === 'unknown';

const updates = {
  CONTENT_TTS_PROVIDER: shouldEnableQwen ? 'qwen-tts' : 'edge-tts',
  DASHSCOPE_API_KEY_FILE: keyFile,
  DASHSCOPE_TTS_ENDPOINT: endpoint,
  DASHSCOPE_TTS_MODEL: model,
  DASHSCOPE_TTS_VOICE: voice,
  DASHSCOPE_TTS_LANGUAGE: language,
  DASHSCOPE_TTS_ACCESS_STATUS: verification.ok ? 'verified' : verification.status,
  CONTENT_TTS_SCENE_CHUNKS: '1',
  CONTENT_TTS_SCENE_PAUSE_SECONDS: '0.12'
};

upsertEnvFile(envLocalPath, updates);

console.log(JSON.stringify({
  ok: true,
  projectDir,
  keyFile: path.relative(projectDir, keyFile) || keyFile,
  envFile: path.relative(projectDir, envLocalPath) || envLocalPath,
  provider: updates.CONTENT_TTS_PROVIDER,
  model,
  voice,
  verification,
  note: 'DashScope key was written to a local 0600 key file. The key value was not printed.'
}, null, 2));

async function verifyDashScopeTts({ apiKey, endpoint, model, voice, language }) {
  const started = Date.now();
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model,
        input: {
          text: '语音测试。',
          voice,
          language_type: language
        }
      })
    });
    const payload = await response.json().catch(async () => ({ message: await response.text() }));
    const ok = response.ok && !(Number(payload.status_code || 200) >= 400) && Boolean(payload?.output?.audio?.url);
    const code = String(payload.code || payload.status_code || '');
    return {
      checked: true,
      ok,
      status: ok ? 'verified' : code === 'Model.AccessDenied' ? 'denied' : 'failed',
      httpStatus: response.status,
      elapsedMs: Date.now() - started,
      code,
      message: payload.message ? String(payload.message).slice(0, 180) : '',
      hasAudioUrl: Boolean(payload?.output?.audio?.url)
    };
  } catch (error) {
    return {
      checked: true,
      ok: false,
      status: 'unknown',
      httpStatus: 0,
      elapsedMs: Date.now() - started,
      code: 'VERIFY_REQUEST_FAILED',
      message: error.message,
      hasAudioUrl: false
    };
  }
}

async function readStdin() {
  if (process.stdin.isTTY) {
    console.error('Pass the key through stdin, not as a command argument.');
    process.exit(2);
  }
  let data = '';
  for await (const chunk of process.stdin) {
    data += chunk;
  }
  return data;
}

function upsertEnvFile(filePath, updates) {
  const existing = fs.existsSync(filePath) ? fs.readFileSync(filePath, 'utf8') : '';
  const seen = new Set();
  const lines = existing.split(/\r?\n/).map((line) => {
    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=/);
    if (!match || !(match[1] in updates)) return line;
    seen.add(match[1]);
    return `${match[1]}=${escapeEnvValue(updates[match[1]])}`;
  });

  if (existing && lines[lines.length - 1] !== '') {
    lines.push('');
  }
  for (const [key, value] of Object.entries(updates)) {
    if (!seen.has(key)) {
      lines.push(`${key}=${escapeEnvValue(value)}`);
    }
  }

  fs.writeFileSync(filePath, `${lines.join('\n').replace(/\n+$/g, '')}\n`, { mode: 0o600 });
  fs.chmodSync(filePath, 0o600);
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

function escapeEnvValue(value) {
  const text = String(value);
  if (/^[A-Za-z0-9_./:+-]+$/.test(text)) return text;
  return JSON.stringify(text);
}

function resolveProjectPath(projectDir, value) {
  const expanded = String(value || '').replace(/^~(?=$|\/)/, process.env.HOME || '');
  return path.isAbsolute(expanded) ? expanded : path.resolve(projectDir, expanded);
}

function isUsableKey(value = '') {
  const key = String(value || '').trim();
  return key.length >= 20 && !/PASTE_|YOUR_|这里|占位|placeholder/i.test(key);
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
