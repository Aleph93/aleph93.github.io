<#
.SYNOPSIS
    Verifies the site's prose survives plain-text extraction.

.DESCRIPTION
    The portfolio has to be readable by ATS and AI resume parsers, which see
    something close to the page's extracted text. This strips tags the way a
    naive extractor would and asserts that a distinctive sentence from every
    project still shows up.

    If this fails, something has been hidden behind JS, moved into an image,
    or collapsed behind a toggle - all of which break the core requirement.

.NOTES
    Windows PowerShell 5.1. ASCII source only (5.1 reads .ps1 as ANSI).
#>

[CmdletBinding()]
param([switch] $Dump)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$utf8     = New-Object System.Text.UTF8Encoding($false)

function Get-PlainText {
    param([string] $Html)
    $t = $Html -replace '(?s)<script.*?</script>', ' ' `
               -replace '(?s)<style.*?</style>', ' ' `
               -replace '(?s)<!--.*?-->', ' '
    # Block-level tags become line breaks, everything else just disappears.
    $t = $t -replace '<(p|div|li|h[1-6]|dd|dt|br|tr|section|article)[^>]*>', "`n"
    $t = $t -replace '<[^>]+>', ' '
    $t = [System.Net.WebUtility]::HtmlDecode($t)
    return (($t -split "`n" |
             ForEach-Object { $_.Trim() -replace '\s+', ' ' } |
             Where-Object { $_ }) -join "`n")
}

# One distinctive phrase per project. Deliberately mid-paragraph, so a
# heading surviving while its body is lost still fails the check.
$probes = [ordered]@{
    'Moonscars'         = 'inspired by the Soulslike and Metroidvania genres'
    'Meetaverse'        = 'serializing environment data, downloading content'
    'Sleigh Flight'     = 'DreamWorks holiday installations across shopping malls'
    'DreamWorks Color'  = 'image-processing pipeline that transformed scanned coloring pages'
    'VR Framework'      = 'recording and playback system that allowed developers'
    'Civil War VR'      = 'product barcode scanning functionality'
    'Planet3'           = 'teach environmental science concepts'
    'Blasteroids'       = 'hand gestures to shoot virtual asteroids'
    'AR Card'           = 'watches a Monty Python-styled experience'
    'Fat Mage'          = 'role of an adventurous mage'
    'Match Three'       = 'explode in a specific pattern'
    'MallWeGo'          = 'walk around the mall freely and chat'
    'Chrono Distortion' = 'act in symbiosis with their past projections'
}

# The CV side: these must be extractable from the home page.
$cvProbes = [ordered]@{
    'Email'      = 'sanromanciuc@gmail.com'
    'Headline'   = 'Unity Developer with 10+ years of experience'
    'Black Mermaid' = 'Co-founded the studio and served as the sole programmer'
    'Bully!'     = 'Contributed to commercial AR, VR, mixed reality'
    'Fruitware'  = 'multiplayer mobile game using C++ and Cocos2d'
    'Education'  = 'Bachelor Degree in Computer Science'
}

$texts = @{}
foreach ($page in @('index.html', 'projects.html')) {
    $html = [System.IO.File]::ReadAllText((Join-Path $repoRoot $page), $utf8)
    $texts[$page] = Get-PlainText $html
    $words = ($texts[$page] -split '\s+').Count
    Write-Host ("{0,-15} {1,5} words extracted" -f $page, $words)

    if ($Dump) {
        $out = Join-Path $repoRoot "$page.extracted.txt"
        [System.IO.File]::WriteAllText($out, $texts[$page], $utf8)
        Write-Host "                dumped to $out" -ForegroundColor DarkGray
    }
}

$failed = 0

Write-Host ''
Write-Host 'projects.html - project descriptions'
foreach ($k in $probes.Keys) {
    if ($texts['projects.html'] -like "*$($probes[$k])*") {
        Write-Host ("  ok    {0}" -f $k) -ForegroundColor DarkGray
    } else {
        Write-Host ("  LOST  {0}" -f $k) -ForegroundColor Red
        $failed++
    }
}

Write-Host ''
Write-Host 'index.html - CV content'
foreach ($k in $cvProbes.Keys) {
    if ($texts['index.html'] -like "*$($cvProbes[$k])*") {
        Write-Host ("  ok    {0}" -f $k) -ForegroundColor DarkGray
    } else {
        Write-Host ("  LOST  {0}" -f $k) -ForegroundColor Red
        $failed++
    }
}

Write-Host ''
if ($failed -eq 0) {
    Write-Host 'PASS - all content survives plain-text extraction.' -ForegroundColor Green
    exit 0
}
Write-Host ("FAIL - {0} item(s) lost." -f $failed) -ForegroundColor Red
exit 1
