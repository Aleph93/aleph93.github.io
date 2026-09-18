<#
.SYNOPSIS
    Serves the site locally over HTTP for previewing.

.DESCRIPTION
    Always preview over HTTP rather than opening index.html from disk: under
    file:// the relative asset paths and the lightbox do not behave the way
    they will on GitHub Pages.

    Ctrl+C to stop.

.EXAMPLE
    powershell -File tools/serve.ps1
    powershell -File tools/serve.ps1 -Port 9000

.NOTES
    Windows PowerShell 5.1. ASCII source only (5.1 reads .ps1 as ANSI).
    Binding a port may prompt for elevation depending on URL ACLs; localhost
    on a high port normally does not.
#>

[CmdletBinding()]
param(
    [int]    $Port = 8765,
    [switch] $NoBrowser
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$prefix   = "http://localhost:$Port/"

$types = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.svg'  = 'image/svg+xml'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.png'  = 'image/png'
    '.json' = 'application/json'
    '.pdf'  = 'application/pdf'
    '.ico'  = 'image/x-icon'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)

try   { $listener.Start() }
catch { throw "Could not bind $prefix - is something already using port $Port? ($($_.Exception.Message))" }

Write-Host "Serving $repoRoot" -ForegroundColor Green
Write-Host "  $prefix" -ForegroundColor Green
Write-Host '  Ctrl+C to stop.' -ForegroundColor DarkGray
Write-Host ("  If it ever refuses to stop: Stop-Process -Id {0} -Force" -f $PID) -ForegroundColor DarkGray
Write-Host ''

if (-not $NoBrowser) { Start-Process $prefix | Out-Null }

try {
    while ($listener.IsListening) {

        # Accept asynchronously and poll in short waits instead of calling the
        # blocking GetContext(). PowerShell only honours Ctrl+C between
        # statements, so a thread parked inside a blocking .NET call ignores
        # the interrupt entirely - the server becomes unstoppable. Returning
        # to the engine every 200ms keeps Ctrl+C responsive.
        # Task.Wait(ms) rather than .AsyncWaitHandle.WaitOne(ms): the latter
        # lazily allocates a wait handle that nothing disposes, leaking one
        # per request.
        $task = $listener.GetContextAsync()
        try {
            while (-not $task.Wait(200)) { }
            $ctx = $task.GetAwaiter().GetResult()
        }
        catch { break }    # listener closed while an accept was pending

        $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
        if (-not $rel) { $rel = 'index.html' }

        $file = Join-Path $repoRoot ($rel -replace '/', '\')

        # Keep the server inside the repo even if a request contains "..".
        $full = [System.IO.Path]::GetFullPath($file)
        $inside = $full.StartsWith([System.IO.Path]::GetFullPath($repoRoot), [StringComparison]::OrdinalIgnoreCase)

        if ($inside -and (Test-Path $full -PathType Leaf)) {
            $bytes = [System.IO.File]::ReadAllBytes($full)
            $ext   = [System.IO.Path]::GetExtension($full).ToLower()
            if ($types[$ext]) { $ctx.Response.ContentType = $types[$ext] }
            $ctx.Response.ContentLength64 = $bytes.Length
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            Write-Host ("  200  /{0}" -f $rel) -ForegroundColor DarkGray
        }
        else {
            $ctx.Response.StatusCode = 404
            Write-Host ("  404  /{0}" -f $rel) -ForegroundColor DarkYellow
        }

        $ctx.Response.Close()
    }
}
finally {
    # Runs on Ctrl+C too, which is what frees the port for the next run.
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
    Write-Host ''
    Write-Host 'Stopped.' -ForegroundColor DarkGray
}
