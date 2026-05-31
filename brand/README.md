# Brand assets

Source-of-truth brand assets for DVM (favicons, logo marks, OG image). The
web-serving subset is copied into `site/public/` and `site/src/assets/`; this
directory keeps the full set, including variants the site doesn't load directly.

## Palette

- Accent gradient: `#2dd4a7` (teal) → `#67e8f9` (cyan)
- Light-mode accent gradient: `#047857` → `#0e7490`
- Tile background: `#0a0e14`

## Files

| File | Use |
| --- | --- |
| `favicon.svg` | Scalable favicon (dark tile, works on any background) |
| `favicon.ico`, `favicon-16/32/48/64.png` | Raster favicon fallbacks |
| `favicon-192.png`, `favicon-512.png` / `icon-512.png` | PWA / manifest icons |
| `apple-touch-icon.png` (= `favicon-180.png`) | iOS home-screen icon |
| `logo-mark.svg` / `logo-mark-light.svg` | Header mark, dark / light scheme |
| `logo-lockup-dark.svg` / `logo-lockup-light.svg` | Mark + `dvm` wordmark lockup |
| `og-image.png` | 1200×630 social share card |
| `og-image.html` | Source used to render `og-image.png` |

## Regenerating the OG image

`og-image.html` renders the `.og` element at 1200×630. Screenshot that node
(e.g. with a headless browser) to produce `og-image.png`.
