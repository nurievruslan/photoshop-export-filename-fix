# Photoshop Export As Filename Fix

An **unofficial Windows workaround** for Adobe Photoshop **Export As** truncating filenames that contain multiple dots.

> **Tested:** Adobe Photoshop 2027 / **28.0.0**, Windows 11; **PNG and JPG single-image export**. Other Photoshop versions, formats, and export modes have **not** been validated. This is **not** an Adobe-supported fix.

## Problem

When saving through **File → Export → Export As**, a filename with multiple dots can be truncated:

| Entered name | Incorrect output | Output after workaround |
| --- | --- | --- |
| `Test.24.11.2026` | `Test.24.11.png` | `Test.24.11.2026.png` |

**Save As**, **Save a Copy**, and **Quick Export** did not show the same issue during the reported testing. **Save for Web (Legacy)** is **not fixed** by this workaround.

## How the workaround works

The minified JavaScript file for Photoshop's bundled UXP Export As plugin has a branch that chooses a file picker based on `isCloudExportEnabled`:

```javascript
c=t().app.isCloudExportEnabled,u=1===a.length
```

The workaround changes just that branch:

```javascript
c=false,u=1===a.length
```

This causes the local export flow to use UXP's `storage.localFileSystem.getFileForSaving()` rather than the cloud-enabled `photoshop.exportmanager.getExportFolder()` path. Filename preservation was confirmed in PNG and JPG export tests. **It does not prove precisely where the native Export Manager truncates the name.**

**Trade-off:** Cloud export from Export As may stop working. No changes are made to Save for Web or Premiere Pro.

## Installation (Windows PowerShell)

1. **Close Photoshop completely**.
2. Download `Install-Fix.ps1` from this repository. Review the script before running it.
3. Open **Windows PowerShell as Administrator**.
4. From the folder containing the script, run a dry run first:

   ```powershell
   .\Install-Fix.ps1 -WhatIf
   ```

5. Apply the patch:

   ```powershell
   .\Install-Fix.ps1
   ```

The installer checks the exact SHA256 of the supported original module and the generated patch. It refuses unknown module hashes, reuses an existing verified original backup, and safely does nothing if the patch is already installed. Replacement is staged, verified and performed using Windows File.Replace.

Supported original SHA256: `C47EF30FE8E81234550DE2FF93D82EF6A56E2C7663A23F43FE87042A79C13A15`

Patched SHA256: `281E934FBC54879C3DB921F5448B994D4EF02FA69C7CFA882844598014D5E1EA`

These hashes identify the tested module, not an official Adobe signature.

Default module path:

```text
C:\Program Files\Adobe\Adobe Photoshop 2027\Required\UXP\com.adobe.photoshop.exportAs\js\0.js
```

For a different installation directory, use `-PhotoshopDirectory "C:\path\to\Adobe Photoshop 2027"`. A different installation directory does **not** make an otherwise unsupported module compatible.

**PowerShell execution policy:** If script execution is blocked, review your security settings and the script contents. Do not disable your machine-wide security policy just to run this workaround.

### Uninstall

Close Photoshop, run **Windows PowerShell as Administrator**, and use:

```powershell
.\Uninstall-Fix.ps1 -WhatIf
.\Uninstall-Fix.ps1
```

The uninstaller verifies the exact known patched SHA256 and original backup SHA256 before restoring. Repeated uninstall is a no-op when the original module is already present. It **preserves the backup** afterward. If Photoshop updated the target file, the uninstaller refuses to overwrite the newer version.

### Troubleshooting

- **Unsupported module SHA256 / unexpected source state:** Your installed Photoshop build is not the tested one, or the file has already been modified. Do not force the patch; open an issue with your exact Photoshop version and module SHA256.
- **Backup or metadata mismatch:** Stop and inspect the prior backup. A verified backup is reused automatically; incomplete or mismatched backups are rejected. Never overwrite an original backup with a modified file.
- **Access denied:** Start PowerShell with administrative privileges. Ensure Photoshop is closed.
- **Export As stops working:** Use `Uninstall-Fix.ps1` to restore the verified original file.
- **Photoshop updated:** The update may overwrite the workaround. Re-check compatibility rather than blindly reapplying it.

## Validation and limitations

Installation, dry runs, uninstall, repeated installation/uninstall, verified backup reuse and atomic replacement were tested on Windows 11 with Windows PowerShell 5.1. PNG and JPG export worked after installation. Fresh backup creation was tested with the earlier installer; the final revision was tested with an existing verified backup. Rejection of deliberately incompatible hashes and failure recovery have not been independently exercised. Other builds and cloud export are untested.

## Adobe bug report

[Photoshop Export As truncates filenames containing multiple dots — Adobe Community #1657802](https://community.adobe.com/bug-reports-711/photoshop-export-as-truncates-filenames-containing-multiple-dots-1657802)

Please vote and share reproducible findings there. This workaround is independent of Adobe.

## Disclaimer

This repository contains original PowerShell scripts and documentation, **not Adobe's proprietary application files**. Editing installed application files is unsupported and may be undone by updates or impact cloud features. Use at your own risk.

MIT License applies to the scripts and documentation in this repository, **not to Adobe Photoshop or its bundled files**.
