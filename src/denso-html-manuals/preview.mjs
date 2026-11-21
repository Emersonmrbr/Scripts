// Screenshot of one page rendered the way make-pdfs.mjs combines it. Usage: node preview.mjs <packageRoot> <href> <out.png>
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire('/app/node_modules/');
const { chromium } = require('playwright-core');
const [root, href, out] = process.argv.slice(2);
const en = path.join(root, 'en');
const browser = await chromium.launch({ executablePath: '/ms-playwright/chromium-1255/chrome-linux64/chrome', args: ['--no-sandbox'] });
const page = await browser.newPage({ viewport: { width: 794, height: 1123 } });
const main = await page.evaluate(src => {
  const el = new DOMParser().parseFromString(src, 'text/html').querySelector('div.main');
  el.querySelectorAll('script, noscript, style').forEach(x => x.remove());
  return el.innerHTML;
}, fs.readFileSync(path.join(en, href), 'utf8'));
const tmp = path.join(en, '_aura_preview.html');
fs.writeFileSync(tmp, `<!DOCTYPE html><html><head><meta charset="utf-8"><link rel="stylesheet" href="common/css/reset.css"><link rel="stylesheet" href="common/css/base.css"><link rel="stylesheet" href="common/css/skin.css"><style>body{background:#fff;margin:0}.main{width:auto!important;float:none!important;margin:0!important;padding:0!important}img{max-width:100%}</style></head><body><h2 style="font-family:Arial">${href}</h2><div class="main">${main}</div></body></html>`);
await page.emulateMedia({ media: 'print' });
await page.goto('file://' + tmp, { waitUntil: 'load' });
await page.screenshot({ path: out, clip: { x: 0, y: 0, width: 794, height: 1123 } });
fs.unlinkSync(tmp);
await browser.close();
