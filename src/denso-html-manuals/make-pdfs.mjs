// One PDF per first-level book of a DENSO HTML manual package.
// Usage: node make-pdfs.mjs <packageRoot> <product> <outDir>
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire('/app/node_modules/');
const { chromium } = require('playwright-core');

const [root, product, outDir] = process.argv.slice(2);
const en = path.join(root, 'en');
const sideMenu = fs.readFileSync(path.join(en, 'common/js/side_menu.js'), 'utf8');
const dataJs = fs.readFileSync(path.join(en, 'common/js/data.js'), 'utf8');

// var content_id = {...}; -> JSON object (parent id -> children)
const start = sideMenu.indexOf('{', sideMenu.indexOf('var content_id'));
let depth = 0, end = -1, inStr = false;
for (let i = start; i < sideMenu.length; i++) {
  const c = sideMenu[i];
  if (inStr) { if (c === '\\') i++; else if (c === '"') inStr = false; }
  else if (c === '"') inStr = true;
  else if (c === '{') depth++;
  else if (c === '}' && --depth === 0) { end = i; break; }
}
const tree = JSON.parse(sideMenu.slice(start, end + 1));
const childIds = new Set(Object.values(tree).flat().map(e => String(e.id)));
const roots = Object.keys(tree).filter(k => !childIds.has(k));
if (roots.length !== 1) throw new Error('roots: ' + roots.join(','));
const rootId = roots[0];
const rev = (dataJs.match(/\[Rev\.([\d.]+)\s*\((\d{4}-\d{2}-\d{2})\)\]/) || [])[1] || 'unknown';

const taken = new Set();
const books = [];
for (const book of tree[rootId]) {
  const pages = [];
  const seen = new Set();
  const walk = (e, level) => {
    if (seen.has(e.id)) return;
    seen.add(e.id);
    if (!taken.has(e.href) && fs.existsSync(path.join(en, e.href))) { taken.add(e.href); pages.push({ href: e.href, title: e.title.trim(), level }); }
    for (const child of tree[e.id] || []) walk(child, level + 1);
  };
  walk(book, 1);
  if (pages.length) books.push({ title: book.title.trim(), pages });
}

const allPages = fs.readdirSync(en).filter(f => /^\d+\.html$/i.test(f));
const outside = allPages.filter(f => !taken.has(f));
const safe = s => s.replace(/[\\/:*?"<>|]/g, '-').replace(/\s+/g, ' ').trim();
const titleCase = s => s.toLowerCase().replace(/(^|[\s(&/-])([a-z])/g, (m, a, b) => a + b.toUpperCase()).replace(/\bI-o\b/g, 'I-O').replace(/\bWincapsiii\b/g, 'WINCAPSIII');

fs.mkdirSync(outDir, { recursive: true });
const browser = await chromium.launch({ executablePath: '/ms-playwright/chromium-1255/chrome-linux64/chrome', args: ['--no-sandbox'] });
const context = await browser.newContext();
const page = await context.newPage();
const summary = [];

for (const [n, book] of books.entries()) {
  const sections = [];
  for (const p of book.pages) {
    const html = fs.readFileSync(path.join(en, p.href), 'utf8');
    const main = await page.evaluate(src => {
      const doc = new DOMParser().parseFromString(src, 'text/html');
      const el = doc.querySelector('div.main');
      if (!el) return '';
      el.querySelectorAll('script, noscript, style').forEach(x => x.remove());
      return el.innerHTML;
    }, html);
    const h = Math.min(p.level, 4);
    sections.push(`<section class="aura-page"><h${h} class="aura-title">${p.title.replace(/</g, '&lt;')}</h${h}><div class="main">${main}</div></section>`);
  }

  const doc = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>${book.title}</title>
<link rel="stylesheet" href="common/css/reset.css"><link rel="stylesheet" href="common/css/base.css"><link rel="stylesheet" href="common/css/skin.css">
<style>
  body { background: #fff; margin: 0; }
  .main { width: auto !important; float: none !important; margin: 0 !important; padding: 0 !important; }
  .aura-page { page-break-before: always; }
  .aura-page:first-child { page-break-before: auto; }
  .aura-title { font-family: Arial, sans-serif; border-bottom: 1px solid #999; margin: 0 0 8px; }
  img { max-width: 100%; }
  table { page-break-inside: auto; } tr { page-break-inside: avoid; }
</style></head><body>${sections.join('\n')}</body></html>`;
  const tmp = path.join(en, `_aura_book_${n}.html`);
  fs.writeFileSync(tmp, doc);
  await page.goto('file://' + tmp, { waitUntil: 'load', timeout: 600000 });
  const name = `DENSO ${product} User Manuals Rev${rev} - ${String(n + 1).padStart(2, '0')} ${safe(titleCase(book.title))}.pdf`;
  await page.pdf({ path: path.join(outDir, name), format: 'A4', printBackground: true, margin: { top: '15mm', bottom: '15mm', left: '12mm', right: '12mm' } });
  fs.unlinkSync(tmp);
  summary.push(`${name}\t${book.pages.length} pages`);
  console.log(`done ${name} (${book.pages.length} pages)`);
}

await browser.close();
fs.writeFileSync(path.join(outDir, '_summary.txt'), [`${product} Rev${rev}`, ...summary, `pages outside the tree (not in any PDF): ${outside.length}`].join('\n') + '\n');
console.log(`pages outside the tree: ${outside.length}`);
