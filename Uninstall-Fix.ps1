#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$PhotoshopDirectory = "C:\Program Files\Adobe\Adobe Photoshop 2027",
    [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
$path = Join-Path $PhotoshopDirectory 'Required\UXP\com.adobe.photoshop.exportAs\js\0.js'
$backup = "$path.filename-fix-original.bak"
$metadata = "$path.filename-fix-original.sha256"
$originalHash = 'C47EF30FE8E81234550DE2FF93D82EF6A56E2C7663A23F43FE87042A79C13A15'
$patchedHash = '281E934FBC54879C3DB921F5448B994D4EF02FA69C7CFA882844598014D5E1EA'
$utf8 = [System.Text.UTF8Encoding]::new($false,$true)
function Get-BytesHash([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','') }
    finally { $sha.Dispose() }
}
function Assert-Closed {
    if (Get-Process -Name Photoshop -ErrorAction SilentlyContinue) {
        throw 'Close Photoshop before continuing.'
    }
}
Assert-Closed
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Module not found: $path" }
$bytes = [System.IO.File]::ReadAllBytes($path)
$currentHash = Get-BytesHash $bytes
# Stage and verify replacement before atomically replacing the target.
function Set-VerifiedModule([byte[]]$NewBytes,[string]$ExpectedCurrent,[string]$ExpectedNew) {
    $temp = "$path.filename-fix-$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::WriteAllBytes($temp,$NewBytes)
        if ((Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash -ne $ExpectedNew) { throw 'Staged file hash mismatch.' }
        Assert-Closed
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $ExpectedCurrent) { throw 'Target changed during operation. Aborting.' }
        $rollback = "$temp.rollback"
        [System.IO.File]::Replace($temp,$path,$rollback)
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $ExpectedNew) { throw "Final verification failed. Preserve the original backup and $rollback." }
        Remove-Item -LiteralPath $rollback -Force
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    }
}
function Assert-Backup {
    if (-not (Test-Path -LiteralPath $backup -PathType Leaf) -or -not (Test-Path -LiteralPath $metadata -PathType Leaf)) { throw 'Backup or metadata missing. No changes made.' }
    if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $originalHash -or [System.IO.File]::ReadAllText($metadata).Trim() -ne $originalHash) { throw 'Backup or metadata SHA256 mismatch. No changes made.' }
}
if ($currentHash -eq $originalHash) {
    Write-Host 'Original module already present. No changes made.'
    return
}
if ($currentHash -ne $patchedHash) { throw "Unsupported module SHA256: $currentHash. No changes made." }
Assert-Backup
$originalBytes = [System.IO.File]::ReadAllBytes($backup)
if ((Get-BytesHash $originalBytes) -ne $originalHash) { throw 'Backup changed during operation.' }
if ($WhatIf) {
    Write-Host "DRY RUN: Would restore $path"
    Write-Host 'No changes made.'
    return
}
Set-VerifiedModule $originalBytes $patchedHash $originalHash
Write-Host 'Original Export As module restored successfully.' -ForegroundColor Green
Write-Host "Backup remains at $backup (not deleted)."
