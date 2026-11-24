# Changelog

## 1.0.0 — 2026-11-25

- Added an unofficial Export As filename workaround for the tested Photoshop 28.0.0 Windows module.
- Confirmed PNG and JPG export after patching.
- Require exact known original and patched SHA256 hashes.
- Preserve and reuse verified original backups; support repeated installation and removal as no-ops when appropriate.
- Stage and verify replacements using File.Replace with an explicit temporary rollback path compatible with Windows PowerShell 5.1.
- Support dry runs and reject unknown module hashes.
- Document limitations, including possible loss of cloud export, and link Adobe Community bug report #1657802.
