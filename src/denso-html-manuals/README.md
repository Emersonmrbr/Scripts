# DENSO HTML manuals → PDF

Converts a DENSO robot user manual package (the offline HTML site shipped as `RC8UserManuals_<rev>_en.zip`, `RC9UserManuals_<rev>_en.zip`, ...) into one PDF per first-level book of its table of contents. The PDFs keep the page text, tables and images, without the site menus. They can then be added to any document catalog that indexes PDFs. The AURA industrial documents catalog is one example: drop them in `_Novos` and run `update`.

Everything runs in a container. Nothing is installed on the host.

## Files

| File | What it does |
| --- | --- |
| `make-pdfs.mjs` | `node make-pdfs.mjs <packageRoot> <product> <outDir>`. It reads the tree in `en/common/js/side_menu.js` (the root is the only node that is no one's child) and the revision in `en/common/js/data.js`. Each book becomes one PDF with its pages depth first, each page taken from its `div.main`. Output names look like `DENSO RC8 User Manuals Rev2.240 - 06 Programming.pdf`. `_summary.txt` lists the PDFs and the pages that are outside the tree. |
| `preview.mjs` | `node preview.mjs <packageRoot> <page.html> <out.png>`. Takes a screenshot of one page rendered the same way, so the layout can be checked when no PDF viewer is available. |

## Requirements

A Playwright image with Chromium and `playwright-core` in `/app/node_modules`. The AURA image `aura-mcp-playwright:local` works; it is built from `mcr.microsoft.com/playwright/mcp`. The scripts launch `/ms-playwright/chromium-1255/chrome-linux64/chrome` directly. Adjust `executablePath` in both scripts if the image ships another Chromium build.

## Usage (Git Bash on Windows)

```bash
W='C:\work\denso'                         # any working folder
mkdir -p /c/work/denso/pkg/RC8 /c/work/denso/out
cd /c/work/denso/pkg/RC8 && unzip -q ~/Downloads/RC8UserManuals_2240_en.zip
# the package folder must be writable: a temporary _aura_book_N.html is written to en/ and removed afterwards
MSYS_NO_PATHCONV=1 docker run --rm --entrypoint node \
  -v "$W\\pkg\\RC8:/pkg" -v "D:\\Repos\\scripts\\src\\denso-html-manuals:/scripts:ro" -v "$W\\out:/out" \
  aura-mcp-playwright:local /scripts/make-pdfs.mjs /pkg RC8 /out/RC8
```

The product name (`RC8`, `RC9`) is passed as an argument, because the RC8 `data.js` doesn't say it (`key[1]='USER MANUALS'`).

## Notes

- **Measured on 2026-11-20:**

  | Package | HTML pages | PDFs | Size | Time |
  | --- | --- | --- | --- | --- |
  | RC8 2240 | 4,845 | 11 | ~370 MB | ~15 min |
  | RC9 1150 | 2,556 | 6 | ~168 MB | ~4 min |
  | RC8 2201 | 4,295 | 11 | ~351 MB | ~15 min |

  The largest books (Robots, Option, Robot Motion Creation) reach 100–125 MB.
- **Error codes** are not in the HTML pages: they are in the attached `en/img/<id>/ErrorList.pdf`.
- **Attached PDFs** (`en/img/**/*.pdf`, hundreds per package) are not converted. Copy them as they are, and drop the ones that are identical to files you already have.
