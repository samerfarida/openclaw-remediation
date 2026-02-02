# MDM deployment

Scripts are designed to run **locally or via MDM** (Intune, Jamf, etc.): non-interactive, idempotent, with stable log paths and exit codes.

## Behavior

- **Non-interactive:** No prompts. Safe for scheduled or MDM-triggered runs.
- **Idempotent:** Safe to run multiple times; “already clean” is a normal outcome.
- **Exit codes:** 0 = success (clean or already clean), 1 = partial, 2 = failure (or “would remove” in dry-run). Use for reporting and alerting.
- **Logs:** See [SIEM](siem.md) for paths and format. Point your SIEM or MDM at these paths for evidence.

## Dry-run (detect only)

Use **dry-run** to **audit** “who has OpenClaw?” without removing anything:

- **macOS/Linux:** `./scripts/uninstall_macos_linux.sh --dry-run` or `--detect-only`
- **Windows:** `.\scripts\uninstall_windows.ps1 -DryRun`

- **Exit 0:** No OpenClaw artifacts found (clean).
- **Exit 2:** OpenClaw artifacts present (would be removed if you ran without dry-run).

Use dry-run in a discovery phase, then run the real uninstall where needed.

## Packaging for MDM

1. **Download** the script(s) from the repo (or a release). Prefer a **pinned tag** (e.g. `v1.0.0`) for reproducibility.
2. **Integrity:** Download scripts and `checksums.txt` from the [Releases](https://github.com/samerfarida/openclaw-remediation/releases) page; verify SHA-256 before deploying.
3. **Deploy** the script to endpoints (e.g. drop into a known path or embed in the MDM payload).
4. **Run** as the **target user** (or system, depending on your MDM). On Unix, `sudo` may be needed for `/var/log` and for unloading services; see README.
5. **Collect** logs from `/var/log/openclaw_removal.log` (Unix) or `C:\ProgramData\OpenClawRemoval.log` (Windows) and exit code for reporting.

## Per-user vs machine-wide

- Scripts target the **current user** (or `SUDO_USER` on Unix): they clean that user’s `~/.openclaw*` and user-level services.
- For **machine-wide** cleanup across multiple users, run the script **once per user context** (e.g. once per home dir or per logged-in user), or use a wrapper that iterates users. An “all users” mode is not implemented yet; see CONTRIBUTING if you want to add it.

## Example: Jamf (macOS)

- Add `uninstall_macos_linux.sh` as a script payload or from a package.
- Run with: `/bin/bash /path/to/uninstall_macos_linux.sh` (or with `--dry-run` for audit).
- Collect log: `/var/log/openclaw_removal.log` and script exit code in your Jamf reporting.

## Example: Intune (Windows)

- Deploy `uninstall_windows.ps1` (e.g. as a script or inside a package).
- Run: `powershell.exe -ExecutionPolicy Bypass -File .\uninstall_windows.ps1` (or `-DryRun` for audit).
- Collect log: `C:\ProgramData\OpenClawRemoval.log` and exit code for compliance reporting.

## Environment variables

| Variable | Platform | Purpose |
|----------|----------|---------|
| `OPENCLAW_REMOVAL_LOG` | All | Override log file path. |
| `OPENCLAW_STATE_DIR` | macOS/Linux | Also clean this state dir (e.g. custom install path). |
| `OPENCLAW_DRY_RUN` | (Use `-DryRun` on Windows instead) | Not used; use `--dry-run` on Unix. |
