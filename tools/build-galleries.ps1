<#
.SYNOPSIS
    Fills the screenshot galleries in projects.html from assets/img.

.DESCRIPTION
    projects.html carries one marker per gallery:

        <!--SHOTS:<slug>:<label>-->

    This script replaces everything between that marker and its matching
    <!--/SHOTS--> with a <ul class="shots"> built from the files actually
    present in assets/img/<slug>/. Markers are left in place, so the script
    is idempotent and safe to re-run after adding or removing screenshots.

    width/height come from the real thumbnail dimensions so the browser can
    reserve space and the grid does not shift as images lazy-load.

    Run tools/build-images.ps1 first - this reads its output, not the raw folder.

.NOTES
    Windows PowerShell 5.1 + System.Drawing. Reads and writes UTF-8 (no BOM).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$pagePath = Join-Path $repoRoot 'projects.html'
$imgRoot  = Join-Path $repoRoot 'assets\img'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$html = [System.IO.File]::ReadAllText($pagePath, $utf8NoBom)

$pattern = '(?s)<!--SHOTS:(?<slug>[^:]+):(?<label>.*?)-->(?:\s*<ul class="shots".*?</ul>\s*<!--/SHOTS-->)?'
$filled  = 0
$total   = 0

$evaluator = {
    param($m)

    $slug  = $m.Groups['slug'].Value
    $label = $m.Groups['label'].Value
    $dir   = Join-Path $imgRoot $slug

    if (-not (Test-Path $dir)) {
        Write-Warning "No image folder for '$slug' - marker left empty."
        return $m.Groups[0].Value
    }

    $thumbs = Get-ChildItem -Path $dir -File -Filter '*-thumb.jpg' | Sort-Object Name
    if ($thumbs.Count -eq 0) {
        Write-Warning "No thumbnails in '$slug' - marker left empty."
        return $m.Groups[0].Value
    }

    # &, < and > must be escaped for the aria-label and alt attributes.
    $safeLabel = $label -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("<!--SHOTS:$slug`:$label-->`n")
    [void]$sb.Append("          <ul class=`"shots`" aria-label=`"$safeLabel screenshots`">`n")

    $n = 0
    foreach ($thumb in $thumbs) {
        $n++
        $stem = $thumb.BaseName -replace '-thumb$',''
        $full = Join-Path $dir "$stem-full.jpg"
        if (-not (Test-Path $full)) {
            Write-Warning "$slug/$stem - thumbnail without a matching full image; skipped."
            continue
        }

        $img = [System.Drawing.Image]::FromFile($thumb.FullName)
        $w = $img.Width; $h = $img.Height
        $img.Dispose()

        [void]$sb.Append(
            "            <li><a href=`"assets/img/$slug/$stem-full.jpg`" data-shot>" +
            "<img src=`"assets/img/$slug/$stem-thumb.jpg`" alt=`"$safeLabel screenshot $n`" " +
            "width=`"$w`" height=`"$h`" loading=`"lazy`" decoding=`"async`"></a></li>`n")
    }

    [void]$sb.Append("          </ul>`n")
    [void]$sb.Append("          <!--/SHOTS-->")

    $script:filled++
    $script:total += $n
    Write-Host ("  {0,-22} {1,2} thumbnails" -f $slug, $n)

    return $sb.ToString()
}

$updated = [regex]::Replace($html, $pattern, $evaluator)

if ($updated -eq $html) {
    Write-Host 'No changes - galleries already up to date.' -ForegroundColor DarkGray
}
else {
    [System.IO.File]::WriteAllText($pagePath, $updated, $utf8NoBom)
}

Write-Host ''
Write-Host ("{0} galleries filled, {1} thumbnails total." -f $filled, $total) -ForegroundColor Green
