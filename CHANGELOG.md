# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- (Changes since last release go here.)

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

[Unreleased]: https://github.com/YOUR_ORG/openclaw-remediation/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/YOUR_ORG/openclaw-remediation/releases/tag/v1.0.0
