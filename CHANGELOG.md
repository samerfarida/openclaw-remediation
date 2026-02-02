# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Windows:** Detection and removal of global CLI (npm/pnpm/bun) and common install paths (`%LOCALAPPDATA%\openclaw`, `OpenClaw`, `Programs\openclaw`, `Programs\OpenClaw`); npm shims (`openclaw.cmd`, `openclaw`, `openclaw.ps1`) in `%APPDATA%\npm` removed when present. Prevents “already clean” when only the CLI was installed (e.g. CI with `OPENCLAW_NO_ONBOARD=1`).
- CI artifacts README and uninstall script log (`uninstall_script.log`) now uploaded with test evidence.
- **SIEM:** `script=openclaw_remediation`, `version` (from repo `VERSION` file), `severity` (info|warning|error), and quoted values for paths so Splunk/enterprise SIEMs parse reliably.
- **Release workflow:** Tag push (`v*`) now creates a GitHub Release and attaches `checksums.txt`, `VERSION`, and scripts (not just workflow artifact).
- **VERSION file** at repo root; scripts include `version=` in every log line (or `unknown` when file is missing).
- **FAQ** ([docs/faq.md](docs/faq.md)): “What if OpenClaw isn’t installed?”, “Why exit 1?”, “Why exit 2?”, “Script seemed to hang”, “Which version ran?”, “All users?”, log paths, log rotation.
- **logrotate example** in [docs/siem.md](docs/siem.md) for `/var/log/openclaw_removal.log`.
### Changed
- **CI (Windows):** Assert clean now also fails if `openclaw` remains in PATH, npm global `openclaw` is installed, npm shim exists in `%APPDATA%\npm`, or any LocalAppData OpenClaw path exists. Post-uninstall verification artifacts now include openclaw-in-PATH and `npm list -g openclaw` for debugging.
- **Scripts:** “Already clean” early exit so we skip uninstall/npx when no OpenClaw artifacts are present; stderr progress so interactive runs don’t appear to hang.
- CI badge and docs: replaced YOUR_ORG with samerfarida; updated README badges and logging/exit-code docs.

## [1.0.0] - 2025-02-01

### Added
- **Uninstall scripts** for macOS/Linux (`scripts/uninstall_macos_linux.sh`) and Windows (`scripts/uninstall_windows.ps1`) per [OpenClaw uninstall docs](https://docs.openclaw.ai/install/uninstall).
- **Detection and removal** of OpenClaw state dirs (`~/.openclaw*`), launchd/systemd/scheduled tasks, `/Applications/OpenClaw.app` (macOS), global CLI (npm/pnpm/bun).
- **SIEM-friendly logging**: key=value format, UTC timestamps, `event`/`action`/`result`; log paths configurable via `OPENCLAW_REMOVAL_LOG`.
- **Exit codes**: 0 = success, 1 = partial, 2 = failure (for MDM/SIEM).
- **Optional `OPENCLAW_STATE_DIR`** (macOS/Linux) and **`--dry-run` / `--detect-only`** (both scripts) for audits without removal.
- **CI workflow** (`.github/workflows/test.yml`): lint (ShellCheck + PSScriptAnalyzer), install → uninstall → assert clean on macOS, Linux, Windows; smoke job on clean runner.
- **Docs**: README, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, LICENSE (MIT), CHANGELOG; SIEM and MDM guides in `docs/`.
- **Issue/PR templates**, pre-commit config, Dependabot for Actions, release checksums workflow.

[Unreleased]: https://github.com/samerfarida/openclaw-remediation/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/samerfarida/openclaw-remediation/releases/tag/v1.0.0
