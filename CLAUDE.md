# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A GitHub Pages **user site** (`git@github.com:Aleph93/aleph93.github.io`), served at https://aleph93.github.io. Currently a placeholder: a single [index.html](index.html) plus [.nojekyll](.nojekyll).

Consequences that are not obvious from the files:

- The repo name is load-bearing. A user site must be named `<username>.github.io`; renaming it breaks the URL.
- Publishing is `git push origin master`. There is no CI, no build step, and no deploy script — GitHub serves the committed files directly.
- `.nojekyll` disables Jekyll processing, so **Jekyll conventions do not work**: no YAML front matter, no `_layouts/`, `_includes/`, or `{% %}` Liquid tags. Files are served byte-for-byte, and underscore-prefixed paths are served rather than hidden. Deleting `.nojekyll` would opt back into Jekyll and change how every file is handled — don't remove it unless the user asks for Jekyll.

## Tooling

There is none — no package.json, no linter, no test suite, no dependencies. Prefer keeping it that way unless the user asks for a framework or build pipeline; if one is introduced, the built output must be committed to `master` (or Pages reconfigured), since nothing builds server-side.

To preview locally, serve the directory over HTTP (e.g. `python -m http.server 8000`) rather than opening `file://` paths, so relative URLs behave as they will in production.

## Paths

Use relative paths for assets and links. A user site is served from the domain root, so root-relative (`/style.css`) works too — but relative paths keep local preview and production consistent.
