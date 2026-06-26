#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
const projectDir = path.resolve(args['project-dir'] || args.projectDir || process.cwd());
const keyFile = resolveProjectPath(projectDir, args['key-file'] || args.keyFile || '.secrets/dashscope_api_key');
const envLocalPath = path.join(projectDir, '.env.local');
const model = args.model || 'qwen3-tts-flash';
const voice = args.voice || 'Cherry';
const language = args.language || 'Chinese';

const key = (await readStdin()).trim();
if (!isUsableKey(key)) {
  console.error('No usable DashScope API key received on stdin.');
  process.exit(2);
}

fs.mkdirSync(path.dirname(keyFile), { recursive: true, mode: 0o700 });
fs.writeFileSync(keyFile, `${key}\n`, { mode: 0o600 });
fs.chmodSync(keyFile, 0o600);

const updates = {
  CONTENT_TTS_PROVIDER: 'qwen-tts',
  DASHSCOPE_API_KEY_FILE: keyFile,
  DASHSCOPE_TTS_MODEL: model,
  DASHSCOPE_TTS_VOICE: voice,
  DASHSCOPE_TTS_LANGUAGE: language,
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
  note: 'DashScope key was written to a local 0600 key file. The key value was not printed.'
}, null, 2));

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
