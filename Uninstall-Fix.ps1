#Requires -Version 5.1
<#
.SYNOPSIS
  Safely restores the original Photoshop Export As JavaScript module.
#>
[CmdletBinding()]
param(
    [string]$PhotoshopDirectory = "C:\Program Files\Adobe\Adobe Photoshop 2027",
    [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
if (Get-Process -Name Photoshop -ErrorAction SilentlyContinue) {
    throw 'Close Adobe Photoshop before running this script.'
}
$path = Join-Path $PhotoshopDirectory 'Required\UXP\com.adobe.photoshop.exportAs\js\0.js'
$backup = "$path.filename-fix-original.bak"
$metadata = "$path.filename-fix-original.sha256"
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Module not found: $path"
}
if (-not (Test-Path -LiteralPath $backup -PathType Leaf) -or -not (Test-Path -LiteralPath $metadata -PathType Leaf)) {
    throw 'Verified original backup and hash metadata are required. No changes made.'
}
$expectedHash = [System.IO.File]::ReadAllText($metadata).Trim()
if ($expectedHash -notmatch '^[A-Fa-f0-9]{64}$') {
    throw 'Malformed backup SHA256 metadata.'
}
$actualHash = (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
    throw 'Backup SHA256 mismatch. Aborting restoration.'
}
$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
$current = $utf8Strict.GetString([System.IO.File]::ReadAllBytes($path))
$patched = 'c=false,u=1===a.length'
$original = 'c=t().app.isCloudExportEnabled,u=1===a.length'
if ([regex]::Matches($current,[regex]::Escape($patched)).Count -ne 1 -or
    [regex]::Matches($current,[regex]::Escape($original)).Count -ne 0) {
    throw 'Current file does not match the expected patched state. This could be an Adobe update. No changes made.'
}
$backupBytes = [System.IO.File]::ReadAllBytes($backup)
$backupCode = $utf8Strict.GetString($backupBytes)
if ([regex]::Matches($backupCode,[regex]::Escape($original)).Count -ne 1) {
    throw 'Backup does not contain the expected original code. No changes made.'
}
if ($WhatIf) {
    Write-Host "DRY RUN: Would restore $path"
    return
}
[System.IO.File]::WriteAllBytes($path,$backupBytes)
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'Restored file verification failed; preserve the backup and investigate.'
}
Write-Host 'Original Export As module restored successfully.' -ForegroundColor Green
Write-Host "Backup remains at $backup (not deleted)."
