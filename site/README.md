# Product site (source)

Static product pages and assets for GitHub Pages. Built by `npm run build` (`scripts/build-site.mjs`) into `/_site`.

| Path | Role |
|---|---|
| `donations.yml` | BTC / XMR addresses (empty until the owner pastes real ones) |
| `assets/` | CSS, JS, and self-hosted fonts (`assets/fonts/`) |
| `../docs/` | Install markdown — source of truth; HTML copies are generated |

`llms.txt` is generated into `_site/` from `INSTALL_DOCS` / `OTHER_DOCS` in the build script (absolute production URLs). `index.json` / `llms-full.txt` are not generated.

## Donations

Edit `donations.yml` only. Leave addresses as `""` until you have real wallets. The donate UI for a coin renders only when that address is non-empty. Do not commit sample addresses.

## Content-Security-Policy

The layout emits a strict CSP via `<meta http-equiv="Content-Security-Policy">` (`default-src 'self'`; no `'unsafe-inline'`). GitHub Pages cannot set custom response headers, so this is meta-only.

`frame-ancestors`, `report-uri`, and `sandbox` are header-only directives — they are ignored in a meta CSP. Clickjacking protection is therefore not achievable on Pages. That is accepted for this static docs site.

`upgrade-insecure-requests` is safe for local `file://` / http preview of `_site/` (no mixed-content upgrade to break).

`X-Content-Type-Options`, `X-Frame-Options`, and `Permissions-Policy` are not settable on GitHub Pages. Those are accepted gaps.

Referrer policy is set via `<meta name="referrer" content="strict-origin-when-cross-origin">`.

## Local preview

```bash
npm ci
npm run build:local
# open _site/index.html (base path /)
```

Production base path defaults to `/hermes-self-hosted/` (project Pages URL). Under `SITE_BASE=/`, `llms.txt` still points at the production origin — intended.
