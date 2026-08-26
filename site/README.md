# Product site (source)

Static product pages and assets for GitHub Pages. Built by `npm run build` (`scripts/build-site.mjs`) into `/_site`.

| Path | Role |
|---|---|
| `donations.yml` | BTC / XMR addresses (empty until the owner pastes real ones) |
| `assets/` | CSS and JS |
| `../docs/` | Install markdown — source of truth; HTML copies are generated |

## Donations

Edit `donations.yml` only. Leave addresses as `""` until you have real wallets. The donate UI for a coin renders only when that address is non-empty. Do not commit sample addresses.

## Local preview

```bash
npm ci
npm run build:local
# open _site/index.html (base path /)
```

Production base path defaults to `/hermes-self-hosted/` (project Pages URL).
