#Requires -Version 5.1
<#
.SYNOPSIS
  Applies the unofficial Photoshop Export As filename workaround.
.DESCRIPTION
  Changes one minified expression in Adobe's installed UXP Export As module.
  The local file picker replaces the cloud-enabled Export Manager path.
  Only tested with Photoshop 28.0.0 on Windows 11.
#>
[CmdletBinding()]
param(
    [string]$PhotoshopDirectory = "C:\Program Files\Adobe\Adobe Photoshop 2027",
    [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
$relative = 'Required\UXP\com.adobe.photoshop.exportAs\js\0.js'
$path = Join-Path $PhotoshopDirectory $relative
$backup = "$path.filename-fix-original.bak"
$metadata = "$path.filename-fix-original.sha256"
$original = 'c=t().app.isCloudExportEnabled,u=1===a.length'
$patched = 'c=false,u=1===a.length'

function Require-ClosedPhotoshop {
    if (Get-Process -Name Photoshop -ErrorAction SilentlyContinue) {
        throw 'Close Adobe Photoshop before running this script.'
    }
}

Require-ClosedPhotoshop
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Export As JavaScript module not found: $path"
}
if (Test-Path -LiteralPath $backup) {
    throw "Backup already exists. Refusing to overwrite it: $backup"
}
if (Test-Path -LiteralPath $metadata) {
    throw "Backup metadata already exists. Refusing to overwrite it: $metadata"
}

$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
$bytes = [System.IO.File]::ReadAllBytes($path)
$code = $utf8Strict.GetString($bytes)
$originalCount = [regex]::Matches($code,[regex]::Escape($original)).Count
$patchedCount = [regex]::Matches($code,[regex]::Escape($patched)).Count
if ($originalCount -ne 1 -or $patchedCount -ne 0) {
    throw "Unexpected source state: original matches=$originalCount, patch matches=$patchedCount. No changes made."
}
# This exact upstream module size was observed in one tested installation.
# Refuse untested releases rather than modify a different version.
if ($bytes.Length -ne 2288226) {
    throw "Unsupported module size ($($bytes.Length) bytes); expected 2288226. No changes made."
}
$modifiedBytes = $utf8Strict.GetBytes($code.Replace($original,$patched))
if ($WhatIf) {
    Write-Host "DRY RUN: Would patch $path"
    Write-Host 'No changes made.'
    return
}

# Create original backup without replacing any existing file.
$createdBackup = $false
try {
    $stream = [System.IO.File]::Open($backup,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
    $createdBackup = $true
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $hash) {
        throw 'Backup hash verification failed; original file was not modified.'
    }
    [System.IO.File]::WriteAllText($metadata,$hash + [Environment]::NewLine,$utf8Strict)
    [System.IO.File]::WriteAllBytes($path,$modifiedBytes)
    $actual = $utf8Strict.GetString([System.IO.File]::ReadAllBytes($path))
    if ([regex]::Matches($actual,[regex]::Escape($patched)).Count -ne 1) {
        throw 'Patch verification failed.'
    }
    Write-Host 'Patch installed successfully.' -ForegroundColor Green
    Write-Host "Original SHA256: $hash"
    Write-Host "Backup: $backup"
    Write-Warning 'Export As cloud-saving functionality may be disabled. Photoshop updates may overwrite this change.'
} catch {
    if ($createdBackup -and (Test-Path -LiteralPath $backup)) {
        if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -eq (Get-FileHash -InputStream ([System.IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash) {
            [System.IO.File]::WriteAllBytes($path,$bytes)
        }
    }
    throw
}
