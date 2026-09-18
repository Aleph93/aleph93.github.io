<#
.SYNOPSIS
    Verifies every local file reference and in-page anchor resolves.

.DESCRIPTION
    Walks the src/href attributes of index.html and projects.html and checks
    that each local target exists on disk, and that each "#fragment" points at
    an id that is actually present on the target page.

    Catches the easy mistakes: a renamed screenshot, a moved stylesheet, or a
    CV PDF that was linked but never added to the repo.

    External links (https, mailto) are listed but not fetched.

.NOTES
    Windows PowerShell 5.1. ASCII source only (5.1 reads .ps1 as ANSI).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$utf8     = New-Object System.Text.UTF8Encoding($false)

$pages = @{}
foreach ($p in @('index.html', 'projects.html')) {
    $pages[$p] = [System.IO.File]::ReadAllText((Join-Path $repoRoot $p), $utf8)
}

$checked = 0
$failed  = 0
$hosts   = @()

foreach ($page in ($pages.Keys | Sort-Object)) {
    $refs = [regex]::Matches($pages[$page], '(?:src|href)="(?<u>[^"]+)"') |
            ForEach-Object { $_.Groups['u'].Value } |
            Sort-Object -Unique

    foreach ($r in $refs) {
        if ($r -match '^(https?:|mailto:)') {
            $hosts += ($r -replace '^(https?://)?([^/]+).*$', '$2')
            continue
        }

        $checked++
        $file, $frag = $r -split '#', 2

        if ($file) {
            $onDisk = Join-Path $repoRoot ($file -replace '/', '\')
            if (-not (Test-Path $onDisk)) {
                Write-Host ("  MISSING FILE  {0} -> {1}" -f $page, $r) -ForegroundColor Red
                $failed++
                continue
            }
        }
        else {
            $file = $page      # bare "#anchor" targets this same page
        }

        if ($frag -and $pages.ContainsKey($file)) {
            if ($pages[$file] -notmatch ('id="' + [regex]::Escape($frag) + '"')) {
                Write-Host ("  DEAD ANCHOR   {0} -> {1}" -f $page, $r) -ForegroundColor Red
                $failed++
            }
        }
    }
}

Write-Host ("{0} local references checked" -f $checked)
Write-Host ("external hosts: {0}" -f (($hosts | Sort-Object -Unique) -join ', ')) -ForegroundColor DarkGray
Write-Host ''

if ($failed -eq 0) {
    Write-Host 'PASS - every local file and anchor resolves.' -ForegroundColor Green
    exit 0
}
Write-Host ("FAIL - {0} broken reference(s)." -f $failed) -ForegroundColor Red
exit 1
