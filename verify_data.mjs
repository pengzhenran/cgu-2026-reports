#!/usr/bin/env node
/**
 * 校验 cgu_data.js 与 cgu_reports.json 完全等价（逐条逐字段）。
 * 归一化只有在“专题名/地点在一个专题内唯一”时才无损，本脚本就是这条假设的守卫。
 * 重新抓取数据并跑过 build_data.mjs 之后，请运行：node verify_data.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const src = JSON.parse(fs.readFileSync(path.join(root, 'cgu_reports.json'), 'utf8'));

globalThis.window = {};
eval(fs.readFileSync(path.join(root, 'cgu_data.js'), 'utf8'));
const D = globalThis.window.CGU_DATA;

const recs = D.reports.map((r) => {
  const s = D.subjects[r[0]];
  return {
    subject_no: s[0], subject_title: s[1], location: s[2],
    date: D.dates[r[1]] || '', type: D.types[r[2]] || '', moderator: D.mods[r[3]] || '',
    time: r[4], title: r[5], speaker: r[6],
  };
});

const fields = ['subject_no', 'subject_title', 'location', 'date', 'type', 'moderator', 'time', 'title', 'speaker'];
const problems = [];

if (src.length !== recs.length) problems.push(`条数不一致：json ${src.length} vs 重建 ${recs.length}`);
else {
  const bad = {};
  for (let i = 0; i < src.length; i++) {
    for (const f of fields) {
      const a = src[i][f] == null ? '' : String(src[i][f]);
      const b = recs[i][f] == null ? '' : String(recs[i][f]);
      if (a !== b) (bad[f] = bad[f] || []).push({ 行: i, 原: a, 新: b });
    }
  }
  for (const k of Object.keys(bad)) problems.push(`${k} 有 ${bad[k].length} 处不一致，例如 ${JSON.stringify(bad[k].slice(0, 2))}`);
}

if (problems.length) {
  console.error('❌ 数据校验未通过：');
  for (const p of problems) console.error('   ' + p);
  process.exit(1);
}
console.log(`✅ ${src.length} 条记录逐字段一致（${fields.join(', ')}）`);
