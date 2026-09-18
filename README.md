# aleph93.github.io

Personal portfolio of **Alexandru Romanciuc**, Unity Developer — live at <https://aleph93.github.io>.

Static HTML and CSS with a small amount of vanilla JavaScript. No framework, no dependencies, no build step. Pushing to `master` publishes.

| | |
|---|---|
| `index.html` | Bio, skills, experience, education, contact |
| `projects.html` | All 13 projects on one page — Featured, Selected work, Early work |
| `assets/` | Stylesheet, script, favicon, generated images |
| `tools/` | PowerShell scripts that generate image assets and verify the pages |

## Rebuilding the images

Screenshots are generated from `project content raw/`, which is **not in the repository** — it lives locally and is gitignored, since the originals total 67 MB. After adding or replacing screenshots there:

```powershell
powershell -File tools/build-images.ps1     # resize + re-encode into assets/img/
powershell -File tools/build-galleries.ps1  # regenerate the galleries in projects.html
powershell -File tools/check-ats.ps1        # confirm the text still extracts cleanly
```

Run them in that order. All three are safe to re-run.

## Previewing locally

Serve over HTTP rather than opening the files directly — relative paths and the lightbox behave differently under `file://`:

```powershell
powershell -File tools/serve.ps1     # http://localhost:8765
```
