<#
.SYNOPSIS
    Regenerates the web image assets from the local raw content folder.

.DESCRIPTION
    Reads "project content raw/Projects/<project>/screenshots/" and writes
    web-sized JPEGs to "assets/img/<slug>/" as NN-thumb.jpg / NN-full.jpg.

    The raw folder is gitignored and stays local; assets/img is committed.
    Re-running is safe - output is deterministic and overwritten in place.

    Sources range from 800px to 2560px wide, so both sizes CAP rather than
    scale: an image already smaller than the target is only re-encoded, never
    upscaled. Aspect ratios vary (1.59-2.12); nothing is cropped here, the
    thumbnail grid absorbs the variance with a 16:9 box + object-fit: cover.

    The one exception is the Open Graph cover, which must be exactly 1200x630
    and is therefore centre-cropped.

.NOTES
    Windows PowerShell 5.1 + System.Drawing. No external dependencies.
#>

[CmdletBinding()]
param(
    [int] $FullMaxEdge  = 1440,
    [int] $ThumbMaxEdge = 480,
    [int] $FullQuality  = 78,
    [int] $ThumbQuality = 80
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$rawRoot  = Join-Path $repoRoot 'project content raw\Projects'
$outRoot  = Join-Path $repoRoot 'assets\img'

if (-not (Test-Path $rawRoot)) {
    throw "Raw content not found at '$rawRoot'. This folder is gitignored and local-only; restore it before rebuilding images."
}

# Raw folder name -> URL slug. Keys must match the folders on disk exactly.
$slugs = [ordered]@{
    'Black Mermaid - Moonscars'                    = 'moonscars'
    'Althimis - Meetaverse'                        = 'meetaverse'
    'DreamWorks - Sleigh Flight School'            = 'sleigh-flight-school'
    'DreamWorks - Color 2'                         = 'dreamworks-color'
    'VR Development Framework & VR Experiences'    = 'vr-framework'
    "Kellogg's Marvel's Civil War VR"              = 'civil-war-vr'
    'Planet3'                                      = 'planet3'
    'Synergy Technical - Blasteroids'              = 'blasteroids'
    'MADStudios - AR Card'                         = 'ar-card'
    'Fat Mage (University License Thesis project)' = 'fat-mage'
    'MatchThree Game'                              = 'match-three'
    'MallWeGo'                                     = 'mallwego'
    'Chrono Distortion (school project)'           = 'chrono-distortion'
}

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
             Where-Object { $_.MimeType -eq 'image/jpeg' }
if (-not $jpegCodec) { throw 'No JPEG encoder available on this system.' }

function New-EncoderParams {
    param([int] $Quality)
    $p = New-Object System.Drawing.Imaging.EncoderParameters 1
    $p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
        [System.Drawing.Imaging.Encoder]::Quality, [int64] $Quality)
    return $p
}

# Draws $Source into a $TargetW x $TargetH canvas and saves as JPEG.
# Without -Crop the canvas matches the scaled image exactly (no letterboxing).
function Save-Resized {
    param(
        [System.Drawing.Image] $Source,
        [string] $Destination,
        [int]    $MaxEdge,
        [int]    $Quality,
        [int]    $CropWidth  = 0,
        [int]    $CropHeight = 0
    )

    if ($CropWidth -gt 0) {
        # Cover-fit: scale to fill, then centre the overflow off-canvas.
        $targetW = $CropWidth
        $targetH = $CropHeight
        $scale   = [Math]::Max($targetW / $Source.Width, $targetH / $Source.Height)
        $drawW   = [int][Math]::Ceiling($Source.Width  * $scale)
        $drawH   = [int][Math]::Ceiling($Source.Height * $scale)
        $offsetX = [int](($targetW - $drawW) / 2)
        $offsetY = [int](($targetH - $drawH) / 2)
    }
    else {
        # Cap the long edge. Scale is clamped to 1.0 so we never upscale.
        $scale = [Math]::Min(1.0, $MaxEdge / [Math]::Max($Source.Width, $Source.Height))
        $drawW = [Math]::Max(1, [int][Math]::Round($Source.Width  * $scale))
        $drawH = [Math]::Max(1, [int][Math]::Round($Source.Height * $scale))
        $targetW = $drawW; $targetH = $drawH
        $offsetX = 0;      $offsetY = 0
    }

    $bmp = New-Object System.Drawing.Bitmap($targetW, $targetH,
               [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $enc = New-EncoderParams $Quality
    try {
        $gfx.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $gfx.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gfx.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $gfx.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        # Flatten onto black first: sources include PNGs with alpha, and JPEG
        # has no alpha channel - without this, transparent pixels land black
        # anyway but via an undefined path.
        $gfx.Clear([System.Drawing.Color]::Black)
        $gfx.DrawImage($Source, $offsetX, $offsetY, $drawW, $drawH)
        $bmp.Save($Destination, $jpegCodec, $enc)
    }
    finally {
        $enc.Dispose(); $gfx.Dispose(); $bmp.Dispose()
    }

    return [pscustomobject]@{ Width = $targetW; Height = $targetH }
}

$report    = @()
$atNativeSize  = 0
$sourceN   = 0

foreach ($entry in $slugs.GetEnumerator()) {
    $projectDir = Join-Path $rawRoot $entry.Key
    $shotsDir   = Join-Path $projectDir 'screenshots'

    if (-not (Test-Path $shotsDir)) {
        Write-Host ("  {0,-22} no screenshots folder - skipped" -f $entry.Value) -ForegroundColor DarkGray
        continue
    }

    $files = Get-ChildItem -Path $shotsDir -File |
             Where-Object { $_.Extension -match '^\.(jpg|jpeg|png)$' } |
             Sort-Object Name

    if ($files.Count -eq 0) { continue }

    $destDir = Join-Path $outRoot $entry.Value
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null

    $i = 0
    $bytes = 0
    foreach ($file in $files) {
        $i++
        $sourceN++
        $stem = '{0:d2}' -f $i
        $img = [System.Drawing.Image]::FromFile($file.FullName)
        try {
            if ($img.Width -le $FullMaxEdge -and $img.Height -le $FullMaxEdge) { $atNativeSize++ }
            Save-Resized -Source $img -Destination (Join-Path $destDir "$stem-full.jpg")  -MaxEdge $FullMaxEdge  -Quality $FullQuality  | Out-Null
            Save-Resized -Source $img -Destination (Join-Path $destDir "$stem-thumb.jpg") -MaxEdge $ThumbMaxEdge -Quality $ThumbQuality | Out-Null
        }
        finally { $img.Dispose() }

        $bytes += (Get-Item (Join-Path $destDir "$stem-full.jpg")).Length
        $bytes += (Get-Item (Join-Path $destDir "$stem-thumb.jpg")).Length
    }

    # Drop any stale outputs from a previous run with more screenshots.
    Get-ChildItem -Path $destDir -File -Filter '*.jpg' |
        Where-Object { [int]($_.BaseName -split '-')[0] -gt $files.Count } |
        Remove-Item -Force

    $report += [pscustomobject]@{
        Slug   = $entry.Value
        Images = $files.Count
        KB     = [int]($bytes / 1KB)
    }
    Write-Host ("  {0,-22} {1,2} images  {2,6} KB" -f $entry.Value, $files.Count, [int]($bytes / 1KB))
}

# --- Open Graph cover: exactly 1200x630, centre-cropped from Moonscars ---
$ogSource = Get-ChildItem -Path (Join-Path $rawRoot 'Black Mermaid - Moonscars\screenshots') -File |
            Sort-Object Name | Select-Object -First 1
if ($ogSource) {
    New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
    $img = [System.Drawing.Image]::FromFile($ogSource.FullName)
    try {
        Save-Resized -Source $img -Destination (Join-Path $outRoot 'og-cover.jpg') `
                     -MaxEdge 1200 -Quality 82 -CropWidth 1200 -CropHeight 630 | Out-Null
    }
    finally { $img.Dispose() }
    Write-Host ("  {0,-22}  1200x630 social preview" -f 'og-cover.jpg')
}

$totalKB  = ($report | Measure-Object KB -Sum).Sum
$totalOut = ($report | Measure-Object Images -Sum).Sum * 2

Write-Host ''
Write-Host ("{0} source images -> {1} output files, {2:N1} MB total" -f $sourceN, $totalOut, ($totalKB / 1024)) -ForegroundColor Green
Write-Host ("{0} sources were already <= {1}px and were re-encoded at native size (never upscaled)." -f $atNativeSize, $FullMaxEdge) -ForegroundColor DarkGray
