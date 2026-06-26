#!/usr/bin/env node

const DEFAULT_BASE = 'https://dailyhotapi-hazel.vercel.app';
const DEFAULT_SOURCES = ['bilibili', 'douyin', 'toutiao', 'weibo', 'ithome', '36kr', 'huxiu', 'sspai'];

const args = parseArgs(process.argv.slice(2));
const baseUrl = String(args.base || process.env.DAILY_HOT_BASE || DEFAULT_BASE).replace(/\/+$/, '');
const sources = String(args.sources || DEFAULT_SOURCES.join(','))
  .split(',')
  .map((item) => item.trim())
  .filter(Boolean)
  .slice(0, 12);
const interests = String(args.interest || args.interests || '')
  .split(/[,，、\s]+/)
  .map((item) => item.trim())
  .filter(Boolean);
const limit = clamp(Number(args.limit || 24), 3, 80);

const settled = await Promise.allSettled(sources.map((source) => fetchSource(source)));
const failures = [];
const items = [];

for (let index = 0; index < settled.length; index += 1) {
  const result = settled[index];
  if (result.status === 'fulfilled') {
    items.push(...result.value);
  } else {
    failures.push({ source: sources[index], error: result.reason.message });
  }
}

const cards = items
  .map((item) => buildCard(item, interests))
  .sort((a, b) => b.score - a.score)
  .slice(0, limit);

const rejected = items
  .map((item) => buildCard(item, interests))
  .filter((item) => item.score < 62)
  .slice(0, 8)
  .map((item) => ({
    title: item.title,
    source: item.source,
    reason: item.visualPotential === '弱' ? 'hot but weak visual thesis' : 'weak interest or angle fit'
  }));

console.log(JSON.stringify({
  ok: cards.length > 0,
  generatedAt: new Date().toISOString(),
  baseUrl,
  sources,
  interest: interests,
  count: cards.length,
  failures,
  cards,
  rejected
}, null, 2));

async function fetchSource(source) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12_000);
  try {
    const response = await fetch(`${baseUrl}/${encodeURIComponent(source)}`, {
      signal: controller.signal,
      headers: { accept: 'application/json' }
    });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const json = await response.json();
    const data = Array.isArray(json.data) ? json.data : Array.isArray(json) ? json : [];
    return data.slice(0, 30).map((item, index) => normalizeItem({ source, sourceTitle: json.title || source, item, index }));
  } finally {
    clearTimeout(timer);
  }
}

function normalizeItem({ source, sourceTitle, item, index }) {
  const title = item.title || item.name || item.word || item.keyword || '未命名热点';
  return {
    source,
    sourceTitle,
    rank: Number(item.rank || item.index || index + 1),
    title: String(title).trim(),
    desc: String(item.desc || item.description || item.summary || '').trim(),
    hot: normalizeHot(item.hot || item.heat || item.score || item.hotValue || ''),
    url: item.url || item.mobileUrl || item.link || '',
    rawHot: item.hot || item.heat || item.score || item.hotValue || ''
  };
}

function buildCard(item, interests) {
  const family = classifyFamily(item);
  const titleText = `${item.title} ${item.desc}`;
  const interestHits = interests.filter((keyword) => titleText.toLowerCase().includes(keyword.toLowerCase()));
  const visualPotential = inferVisualPotential(item, family);
  const sourceWeight = inferSourceWeight(item.source, family);
  const hotScore = Math.min(22, Math.round(Math.log10(Math.max(10, item.hot || 10)) * 7));
  const rankScore = Math.max(0, 20 - Math.min(20, item.rank - 1));
  const interestScore = interestHits.length ? 24 + Math.min(8, interestHits.length * 4) : interests.length ? 0 : 8;
  const visualScore = visualPotential === '强' ? 18 : visualPotential === '中' ? 10 : 2;
  const score = clamp(sourceWeight + hotScore + rankScore + interestScore + visualScore, 0, 100);

  return {
    title: item.title,
    source: item.source,
    sourceTitle: item.sourceTitle,
    sourceUrl: item.url,
    hot: item.rawHot || item.hot,
    family,
    whyNow: buildWhyNow(item, family),
    emotionalHook: buildHook(item, family),
    sharpTakeSeed: buildSharpTakeSeed(item, family),
    visualPotential,
    recommendedFormat: recommendFormat(family),
    possibleAngles: buildAngles(item, family),
    riskBoundary: buildRiskBoundary(family),
    interestHits,
    score
  };
}

function classifyFamily(item) {
  const text = `${item.title} ${item.desc} ${item.source}`.toLowerCase();
  if (/\bai\b|openai|anthropic|claude|\bagent\b|大模型|模型|机器人|智能体|karpathy|卡帕西|qwen|千问|deepseek/.test(text)) return 'AI/product';
  if (/程序员|开发者|就业|裁员|转行|职场|工资|35岁|外包|开源|github|代码/.test(text)) return 'career/developer';
  if (/电影|剧|演员|肖战|毛晓彤|周星驰|女足|pv|预告|综艺|十日终焉|翻拍|票房|娱乐/.test(text)) return 'entertainment/IP';
  if (/食品|安全|通报|回应|道歉|争议|热搜|曝光|警方|官方|调查/.test(text)) return 'social/hot-search';
  if (/手机|电脑|wps|飞书|钉钉|app|价格|发布|会员|产品|办公/.test(text)) return 'consumer/productivity';
  if (['ithome', '36kr', 'huxiu', 'sspai'].includes(item.source)) return 'AI/product';
  if (['douyin', 'bilibili'].includes(item.source)) return 'entertainment/IP';
  return 'general-hot';
}

function inferSourceWeight(source, family) {
  if (family === 'AI/product' && ['ithome', '36kr', 'huxiu', 'sspai'].includes(source)) return 16;
  if (family === 'entertainment/IP' && ['douyin', 'bilibili', 'weibo'].includes(source)) return 16;
  if (family === 'social/hot-search' && ['toutiao', 'weibo', 'douyin'].includes(source)) return 14;
  return 10;
}

function inferVisualPotential(item, family) {
  const text = `${item.title} ${item.desc}`;
  if (/pv|预告|视频|发布会|官网|截图|回应|通报|排名|榜|地图|时间线|对比|测试|实测/.test(text)) return '强';
  if (['entertainment/IP', 'AI/product', 'career/developer', 'social/hot-search'].includes(family)) return '中';
  return '弱';
}

function buildWhyNow(item, family) {
  const prefix = item.rank <= 5 ? '榜单前排，说明讨论正在集中。' : '进入多个用户会刷到的热点池。';
  if (family === 'AI/product') return `${prefix} 适合从“新能力到底改变了什么”切入。`;
  if (family === 'career/developer') return `${prefix} 适合承接行业焦虑，但必须给出可执行判断。`;
  if (family === 'entertainment/IP') return `${prefix} 适合抓期待、错位和改编风险。`;
  if (family === 'social/hot-search') return `${prefix} 适合做时间线和责任边界，避免空喊情绪。`;
  return `${prefix} 需要先验证是否有足够画面和观点。`;
}

function buildHook(item, family) {
  if (family === 'AI/product') return '别急着夸新功能，先看它替谁省了时间，又让谁更难赚钱。';
  if (family === 'career/developer') return '程序员真正危险的，不是 AI 会写代码，而是你只会交代码。';
  if (family === 'entertainment/IP') return '观众不是怕翻拍，怕的是你连原作为什么好看都没看懂。';
  if (family === 'social/hot-search') return '热搜最吵的地方，通常不是事实最多的地方。';
  return '这个话题能不能拍，先看它有没有冲突和证据。';
}

function buildSharpTakeSeed(item, family) {
  if (family === 'AI/product') return '新工具不该按炫技打分，要按它重排了哪条工作流打分。';
  if (family === 'career/developer') return '出路不是岗位名变化，而是从执行者变成问题定价者。';
  if (family === 'entertainment/IP') return 'IP 改编失败往往不是选角先错，是气质和核心游戏规则先错。';
  if (family === 'social/hot-search') return '先拆时间线，再拆谁从混乱里获益。';
  return '不要复述热闹，要找热闹背后的结构。';
}

function recommendFormat(family) {
  if (family === 'AI/product') return 'proof stage / receipt flow / workflow before-after';
  if (family === 'career/developer') return 'career map / route dashboard / choice tree';
  if (family === 'entertainment/IP') return 'review board / evidence clipping / adaptation audit';
  if (family === 'social/hot-search') return 'timeline / evidence wall / accountability map';
  if (family === 'consumer/productivity') return 'comparison board / migration map';
  return 'angle test before template choice';
}

function buildAngles(item, family) {
  if (family === 'AI/product') return ['官方说了什么', '真实工作流变短了吗', '谁会被重新定价'];
  if (family === 'career/developer') return ['能力栈重排', '岗位名幻觉', '如何证明自己更贵'];
  if (family === 'entertainment/IP') return ['原作核心气质', '选角期待错位', 'PV/物料是否证明懂原作'];
  if (family === 'social/hot-search') return ['时间线', '证据边界', '平台情绪如何放大'];
  return ['冲突在哪里', '画面怎么证明', '观众看完得到什么'];
}

function buildRiskBoundary(family) {
  if (family === 'social/hot-search') return '只讲已公开信息和时间线，不替未证实事实下结论。';
  if (family === 'entertainment/IP') return '评论作品和公开物料，不做人身攻击。';
  if (family === 'AI/product') return '区分官方发布、实测推断和个人判断。';
  return '标清来源边界，不把猜测说成事实。';
}

function normalizeHot(value) {
  if (typeof value === 'number') return value;
  const text = String(value || '').replace(/,/g, '').trim();
  if (!text) return 0;
  const number = Number(text.replace(/[^\d.]/g, ''));
  if (!Number.isFinite(number)) return 0;
  if (/亿/.test(text)) return Math.round(number * 100_000_000);
  if (/万/.test(text)) return Math.round(number * 10_000);
  return number;
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

function clamp(value, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) return min;
  return Math.max(min, Math.min(max, number));
}
