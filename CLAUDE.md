# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The personal portfolio of Alexandru Romanciuc (Unity Developer), served as a GitHub Pages **user site** at https://aleph93.github.io.

Two pages, no framework, no dependencies, no build step for the HTML:

- [index.html](index.html) — hero + short bio, skills, experience history, education, a three-project teaser, contact. This is the CV.
- [projects.html](projects.html) — all 13 projects on **one page**, in three tiers: Featured (Moonscars) → Selected work → Early work.

Consequences that are not obvious from the files:

- The repo name is load-bearing. A user site must be named `<username>.github.io`; renaming it breaks the URL.
- Publishing is `git push origin master`. GitHub serves the committed files directly — there is no CI and nothing builds server-side.
- `.nojekyll` disables Jekyll, so **Jekyll conventions do not work**: no YAML front matter, no `_layouts/`, no Liquid tags. Files are served byte-for-byte. Don't remove it unless the user asks for Jekyll.

## The ATS constraint

The site is read by two audiences: human recruiters and ATS / AI resume parsers. The second one drives a hard rule:

> **All prose must be real text in the DOM, and must never be hidden behind tabs, accordions, "read more" toggles, or JS-injected content.**

This is why `projects.html` is one long page rather than 13 separate ones, why there is no collapse UI anywhere, and why the lightbox is a progressive enhancement — with JS off, thumbnails stay plain links to the full-size image and no content becomes unreachable.

Regression test for this, after any content change:

```powershell
# extracts visible text from both pages; every project description must survive
powershell -File tools/check-ats.ps1
```

`index.html` also carries a JSON-LD `Person` block. Keep it in sync with the visible CV when experience or contact details change.

## Content pipeline

Source content lives in `project content raw/` — **gitignored, local only**. It holds `about me.txt`, `short bio.txt`, and one folder per project with `text.txt`, `links.txt` and `screenshots/`. Note the two bio files are named the opposite way round from their contents: `about me.txt` is the CV, `short bio.txt` is the summary.

That folder is 67 MB of original screenshots and must never be committed. Two scripts turn it into web assets:

```powershell
powershell -File tools/build-images.ps1     # raw screenshots -> assets/img/<slug>/NN-{thumb,full}.jpg
powershell -File tools/build-galleries.ps1  # rewrites the <ul class="shots"> blocks in projects.html
```

Run them in that order; the second reads the first's output. Both are idempotent.

- `build-images.ps1` uses `System.Drawing` (Windows PowerShell 5.1, no dependencies). Sources range 800–2560px wide, so both sizes **cap rather than scale** — it never upscales. Full: 1440px long edge, q78. Thumb: 480px, q80. Current output: 78 images → 156 files, 10.4 MB.
- `build-galleries.ps1` finds `<!--SHOTS:slug:Label-->` markers in `projects.html` and replaces everything up to `<!--/SHOTS-->` with markup generated from the files on disk. Edit the markers, never the generated `<ul>`.

**These scripts must stay ASCII-only.** Windows PowerShell 5.1 reads `.ps1` as ANSI unless the file has a BOM, so a UTF-8 em-dash in a comment is a parse error. The HTML is UTF-8 and the scripts read/write it explicitly as UTF-8 without BOM.

**Never call a blocking .NET method in a long-running loop.** `tools/serve.ps1` originally used `$listener.GetContext()`, which parks the thread inside .NET; PowerShell only honours Ctrl+C between statements, so the server could not be stopped at all (measured: `Stop-Job` hit a 120s timeout and still failed, versus 161ms after the fix). It now accepts with `GetContextAsync()` and polls `$task.Wait(200)`, which hands control back to the engine often enough for Ctrl+C to land. Use `Task.Wait(ms)` rather than `.AsyncWaitHandle.WaitOne(ms)` — the latter lazily allocates a wait handle nothing disposes.

Screenshot aspect ratios vary (1.59–2.12). Nothing is cropped in the pipeline; thumbnails sit in a fixed 16:9 CSS box with `object-fit: cover`, so the lightbox still shows the uncropped frame. The one exception is `assets/img/og-cover.jpg`, centre-cropped to exactly 1200×630.

## Design

Dark-only by decision — there is deliberately **no** `prefers-color-scheme` branch in [assets/css/site.css](assets/css/site.css). One palette, defined once at `:root`. Accent (`--accent`) is for links, focus rings and the FEATURED tag only, never large fills. Contrast ratios are noted in comments next to the tokens; re-verify if you change them.

`@media print` in the same file is what makes the "Save CV as PDF" button useful — it strips nav, screenshots and iframes and prints the CV on white. There is no real `.pdf` in the repo; the button calls `window.print()`.

## Gotchas

- Videos are **always-embedded iframes** by the owner's explicit choice, not click-to-play. `loading="lazy"` plus a reserved 16:9 box is the mitigation; keep both on any new embed. YouTube uses `youtube-nocookie.com`.
- Planet3 has no year on purpose — the source content doesn't state one and nothing should be invented.
- MallWeGo and Match Three have no external links; their `links.txt` are empty.
- Meetaverse, VR Framework, AR Card and Chrono Distortion have no screenshots; their video carries the visual weight, and they have no `SHOTS` marker.
