# 2026 年中国地球科学联合学术年会（CGU-2026）报告查询

一个**离线可用**的网页，收录 2026 年中国地球科学联合学术年会全部分会场专题报告（10月18–21日，杭州国际博览中心），
支持按 **报告人姓名 / 报告题目 / 专题名** 实时检索。

在线地址：<https://pengzhenran.github.io/cgu-2026-reports/>

## 功能

- 检索框输入姓名/题目/专题名即时过滤（自动忽略空格差异，如「王林松」可命中名册中「王　林松」）
- 类型筛选：特邀报告（标红 `*`）、学生报告（标绿 `◎`）、普通报告
- 结果表格：专题（含专题名）｜报告题目｜报告人｜日期｜时间｜会议地点｜类型；关键词高亮，按日期+时间排序
- 首屏只渲染前 100 条，点「显示更多」继续加载（避免 3244 行一次性塞进 DOM）
- 检索条件会写进地址栏，可直接分享某个查询，如 `?q=重力&type=特邀报告`
- 纯静态、无需服务器；首次访问后由 Service Worker 缓存，之后断网也能查

## 文件

| 文件 | 说明 |
| --- | --- |
| `index.html` | 页面本身：骨架 + 样式 + 逻辑，约 12 KB |
| `cgu_data.js` | 页面实际加载的紧凑数据，约 390 KB（gzip 150 KB / brotli 119 KB），由 `build_data.mjs` 生成 |
| `cgu_reports.json` | 原始结构化数据（3244 条，字段完整），便于二次利用 |
| `sw.js` | Service Worker：离线缓存，版本号由构建脚本写入 |
| `build_data.mjs` | 数据归一化脚本（生成 `cgu_data.js`） |
| `verify_data.mjs` | 数据一致性校验（保证压缩后与原始 JSON 逐字段等价） |
| `qrcode.jpg` | 课题组公众号二维码 |
| `_headers` | Cloudflare Pages 的缓存/安全响应头规则（GitHub Pages 会忽略）|

## 数据

- 共 **3244 条报告、149 个分会场专题**，抓取自年会官网专题页
  `https://www.cgu.org.cn/cugs/?q=node/109&subject=X&list=12`
- 原始字段：专题号、专题名、召集人、日期、地点、主持人、时间、序号、类型、题目、报告人

## 本地使用

直接用浏览器打开 `index.html` 即可（`cgu_data.js`、`qrcode.jpg` 需在同一目录）。

## 更新数据

```bash
# 1. 重新抓取，覆盖 cgu_reports.json
node build_data.mjs    # 生成 cgu_data.js，并自动更新 sw.js 里的 BUILD 版本号
node verify_data.mjs   # 逐条逐字段校验，必须输出 ✅ 再提交
```

## 部署

### GitHub Pages（当前线上）

Settings → Pages → Source 选 `main` 分支、`/ (root)` 目录。纯静态、无构建步骤。

### Cloudflare Pages（推荐，国内直连更快）

这是纯静态站点，**没有构建步骤**。

> ⚠️ **注意别建到 Workers 上去。** Cloudflare 控制台现在默认引导你建 Worker，给出的是
> `xxx.<账号>.workers.dev` 地址，两者在国内的可达性完全不同（2026-10-05 实测）：
>
> | 域名 | 直连结果 |
> | --- | --- |
> | `*.pages.dev` | DNS 解析到真实 Cloudflare IP（172.66.47.60），HTTP 200，TTFB 0.6 s ✅ |
> | `*.workers.dev` | DNS 被污染（同一小时内两次解析得到 115.126.100.160、199.96.63.53，都不是 Cloudflare 的 IP），连接直接失败 ❌ |
>
> 另外 Workers 静态资源需要仓库里有 `wrangler.jsonc`（配置 `assets.directory`）才能部署，Pages 什么都不用加。
> 控制台入口：**Workers & Pages → Create application**，页面上找 **"Looking to deploy Pages?"** 那一行
> （或直接打开 `https://dash.cloudflare.com/?to=/:account/pages/new`）。

**方式 A：Git 集成（推荐，推送即自动部署）**

1. 打开 <https://dash.cloudflare.com> → Workers & Pages → Create → Pages → Connect to Git
2. 选择仓库 `pengzhenran/cgu-2026-reports`
3. 构建设置填：
   - Framework preset：**None**
   - Build command：**留空**
   - Build output directory：**/**
4. Save and Deploy，稍后得到 `https://cgu-2026-reports.pages.dev`
5. 之后每次 `git push` 都会自动重新部署；也可以绑自己的域名

**方式 B：本地直传（wrangler，不需要 Git 集成）**

```bash
npx wrangler login
npx wrangler pages project create cgu-2026-reports
npx wrangler pages deploy . --project-name=cgu-2026-reports
```

> ⚠️ Direct Upload 建的项目**之后无法改成 Git 集成**，想要自动部署得另建项目。

**`_headers`**：只有 Cloudflare Pages 会解析它（GitHub Pages 忽略），里面规定了
`sw.js`、`index.html` 必须回源校验，`cgu_data.js` 短缓存，二维码长缓存。

### 国内访问实测（2026-10-05，直连、不走代理）

| 目标 | 文件 | 速度 |
| --- | --- | --- |
| `github.io`（Fastly） | `cgu_data.js` 154 KB | 2.7–12 KB/s（12–57 s）|
| Cloudflare 边缘 | 187 KB 文件 | 145–149 KB/s（1.3 s）|
| Cloudflare 测速端点 | 200 KB | 26–30 KB/s |

即使是 Cloudflare 最保守的那个数，也比 `github.io` 直连快数倍。不过：

- 免费版 Cloudflare 的境内访问仍是"环大陆"，节点可能落在洛杉矶/香港，速度随时段波动；
- `*.pages.dev` 在国内可以解析和访问，但偶有 DNS 污染，长期用建议绑自己的域名；
- 真要给国内访客稳定速度，只有**国内云 + 域名备案**这一条路（对象存储 + CDN）。
- 如果你本机开了系统代理，浏览器测出来的速度和访客直连的速度完全是两回事，对比时要用 `curl`（默认不走系统代理）来测。

## 关于加载速度

一开始整站是「所有数据内联进 index.html 的单文件」，浏览器必须等 1.29 MB 的 HTML 全部下载完才能画表格，
而且每次都把 3244 行一次性塞进 DOM。现在改成：

| | 优化前 | 优化后 |
| --- | --- | --- |
| 首屏 HTML | 1286 KB（gzip 204 KB，含 base64 二维码） | 12.6 KB（gzip 5.2 KB） |
| 数据 | 内联在 HTML 里 | 独立 `cgu_data.js` 390 KB（gzip 150 KB），`defer` 并行下载 |
| DOM 行数 | 3244 行（约 2.3 万节点） | 100 行，按需追加 |
| 纯前端耗时（本地、不含网络） | 2.4–3.3 s | 0.9–1.0 s |
| 再次打开 | 2.0 s，且 10 分钟后缓存失效 | 约 1 s，走 Service Worker，断网也能用 |

数据压缩靠归一化：专题名、地点、主持人、日期、类型在 3244 条里大量重复，
`build_data.mjs` 把它们拆成字典表，报告行只存下标，体积降到原来的 28%。

> 注意：首次访问仍要下载 150 KB 数据，网络差时这段等待无法靠前端消除；
> 真正有效的手段是换掉 github.io（见上）以及依赖 Service Worker 缓存后续访问。

数据来源：中国地球科学联合学术年会官网（cgu.org.cn / cugs.org.cn）。
