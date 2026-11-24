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
        [System.IO.File]::Replace($temp,$path,$null)
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $ExpectedNew) { throw 'Final verification failed. Preserve the original backup.' }
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    }
}
function Assert-Backup {
    if (-not (Test-Path -LiteralPath $backup -PathType Leaf) -or -not (Test-Path -LiteralPath $metadata -PathType Leaf)) { throw 'Backup or metadata missing. No changes made.' }
    if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $originalHash -or [System.IO.File]::ReadAllText($metadata).Trim() -ne $originalHash) { throw 'Backup or metadata SHA256 mismatch. No changes made.' }
}
if ($currentHash -eq $patchedHash) {
    Assert-Backup
    Write-Host 'Patch already installed. No changes made.'
    return
}
if ($currentHash -ne $originalHash) { throw "Unsupported module SHA256: $currentHash. No changes made." }
$old = 'c=t().app.isCloudExportEnabled,u=1===a.length'
$new = 'c=false,u=1===a.length'
$code = $utf8.GetString($bytes)
if ([regex]::Matches($code,[regex]::Escape($old)).Count -ne 1) { throw 'Unexpected source state.' }
$modified = $utf8.GetBytes($code.Replace($old,$new))
if ((Get-BytesHash $modified) -ne $patchedHash) { throw 'Generated patch SHA256 mismatch.' }
$reuse = (Test-Path -LiteralPath $backup) -or (Test-Path -LiteralPath $metadata)
if ($reuse) { Assert-Backup }
if ($WhatIf) {
    Write-Host "DRY RUN: Would patch $path"
    if ($reuse) { Write-Host 'Would reuse verified original backup.' }
    Write-Host 'No changes made.'
    return
}
if (-not $reuse) {
    $stream = [System.IO.File]::Open($backup,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
    $stream = [System.IO.File]::Open($metadata,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None)
    try {
        $hashBytes = $utf8.GetBytes($originalHash + [Environment]::NewLine)
        $stream.Write($hashBytes,0,$hashBytes.Length)
    } finally { $stream.Dispose() }
}
Assert-Backup
if ($reuse) { Write-Host 'Reusing verified original backup.' }
Set-VerifiedModule $modified $originalHash $patchedHash
Write-Host 'Patch installed successfully.' -ForegroundColor Green
Write-Host "Patched SHA256: $patchedHash"
Write-Warning 'Export As cloud-saving functionality may be disabled. Photoshop updates may overwrite this change.'
