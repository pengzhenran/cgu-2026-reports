#!/usr/bin/env node
/**
 * 把 cgu_reports.json（原始抓取数据，字段高度冗余）压缩成网页实际加载的 cgu_data.js。
 *
 * 原理：3244 条报告里，专题名、会议地点、主持人、日期、类型都是重复的短字符串，
 * 原始 JSON 把它们逐条重复了一遍（占 1.4 MB 的 2/3）。这里做归一化：
 *   - subjects: 149 个专题，每个 [专题号, 专题名, 会议地点]
 *   - dates / types / mods: 字典表（日期、报告类型、主持人）
 *   - reports: 3244 行紧凑数组 [专题下标, 日期下标, 类型下标, 主持人下标, 时间, 题目, 报告人]
 * （原始 seq 字段是抓取时的表头残留，页面不用，未收录；主持人页面上暂未展示，留给以后加列）
 *
 * 用法：node build_data.mjs
 * 顺手会把 sw.js 里的 BUILD 版本号更新成数据指纹，避免旧缓存。
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const p = (...f) => path.join(root, ...f);

const src = JSON.parse(fs.readFileSync(p('cgu_reports.json'), 'utf8'));
if (!Array.isArray(src) || !src.length) throw new Error('cgu_reports.json 不是非空数组');

/** 去重，保留首次出现顺序，空字符串固定放 0 号位 */
function dict(values) {
  const seen = new Set(['']);
  const out = [''];
  for (const v of values) {
    if (v == null || v === '' || seen.has(v)) continue;
    seen.add(v);
    out.push(v);
  }
  return out;
}
const posOf = (dictArr) => new Map(dictArr.map((v, i) => [v, i]));

const subjects = [];
const subjectIdx = new Map(); // subject_no -> subjects 下标
let conflicts = 0;

for (const r of src) {
  const no = String(r.subject_no ?? '');
  const title = r.subject_title || '';
  const loc = r.location || '';
  if (!subjectIdx.has(no)) {
    subjectIdx.set(no, subjects.length);
    subjects.push([no, title, loc]);
  } else {
    // 归一化前提：专题名/地点在一个专题内唯一。原始数据不满足时只告警，不静默丢数据。
    const s = subjects[subjectIdx.get(no)];
    if (s[1] !== title || s[2] !== loc) {
      conflicts++;
      if (conflicts <= 3) console.warn(`  ! 专题 ${no} 的标题/地点不一致，已保留首次出现的值`);
    }
  }
}

const dates = dict(src.map((r) => r.date));
const types = dict(src.map((r) => r.type));
const mods = dict(src.map((r) => r.moderator));
const dPos = posOf(dates), tPos = posOf(types), mPos = posOf(mods);

const reports = src.map((r) => [
  subjectIdx.get(String(r.subject_no ?? '')),
  dPos.get(r.date || ''),
  tPos.get(r.type || ''),
  mPos.get(r.moderator || ''),
  r.time || '',
  r.title || '',
  r.speaker || '',
]);

const payload = {
  v: 1,
  built: new Date().toISOString().slice(0, 10),
  count: reports.length,
  subjects,
  dates,
  types,
  mods,
  reports,
};

const json = JSON.stringify(payload);
const file = `/* 自动生成，请勿手改：node build_data.mjs（数据源 cgu_reports.json） */\nwindow.CGU_DATA=${json};\n`;
const hash = crypto.createHash('sha1').update(json).digest('hex').slice(0, 10);
fs.writeFileSync(p('cgu_data.js'), file);

// 让 Service Worker 的缓存版本跟随数据变化
if (fs.existsSync(p('sw.js'))) {
  const before = fs.readFileSync(p('sw.js'), 'utf8');
  const after = before.replace(/const BUILD = '[^']*';/, `const BUILD = '${hash}';`);
  if (after !== before) fs.writeFileSync(p('sw.js'), after);
}

const kb = (n) => `${(n / 1024).toFixed(1)} KB`;
const rawOld = fs.readFileSync(p('cgu_reports.json'));
const rawNew = Buffer.from(file);
console.log(`报告 ${reports.length} 条 / 专题 ${subjects.length} 个 / 主持人 ${mods.length - 1} 位`);
if (conflicts) console.warn(`警告：${conflicts} 条记录的专题名或地点与同专题其他记录不一致`);
console.log(`原始 cgu_reports.json : ${kb(rawOld.length)}  (gzip ${kb(zlib.gzipSync(rawOld).length)})`);
console.log(`生成 cgu_data.js      : ${kb(rawNew.length)}  (gzip ${kb(zlib.gzipSync(rawNew).length)}, br ${kb(zlib.brotliCompressSync(rawNew).length)})`);
console.log(`数据指纹 BUILD=${hash}`);
