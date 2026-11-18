# iQube Companion — website

The landing page for [iQube Companion](https://github.com/Chetan-boi/iQube-companion), a macOS menu-bar
app and widget for TVS electric scooters. A static Astro site: one page, no JavaScript framework, a few
lines of script for the download dialog and the copy buttons.

## Commands

| Command | Action |
|---|---|
| `npm install` | Install dependencies |
| `npm run dev` | Dev server at `localhost:4321` |
| `npm run build` | Build the static site into `dist/` |
| `npm run preview` | Serve the built site locally |

## Layout

| Path | What it is |
|---|---|
| `src/data/site.ts` | Version, download path, file size, checksum, repo and license links. Edit this first. |
| `src/pages/index.astro` | The page: hero, bento grid, setup guide, privacy, disclaimer, footer, download dialog |
| `src/styles/global.css` | All styling. Light and dark follow the visitor's system setting. |
| `src/components/` | `Shot` (light/dark screenshot) and `Code` (command with copy button) |
| `public/images/` | App icon and screenshots, in light and dark versions |
| `public/downloads/` | `iQube-Companion-1.0.dmg`, its SHA-256, and `get_token_session.sh` |

## Releasing a new version

1. Build the app in the app repo with `scripts/build.sh`.
2. Make the DMG (see the app repo) and copy it into `public/downloads/`.
3. Update `version`, `dmg`, `dmgSize` and `dmgSha256` in `src/data/site.ts`
   (`shasum -a 256 public/downloads/iQube-Companion-X.Y.dmg`).
4. `npm run build` and deploy `dist/`.
