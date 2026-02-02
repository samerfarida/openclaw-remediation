# openclaw-remediation

[![CI](https://github.com/samerfarida/openclaw-remediation/actions/workflows/test.yml/badge.svg)](https://github.com/samerfarida/openclaw-remediation/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Purpose-built detection, uninstall, and validation tooling for OpenClaw across macOS, Linux, and Windows.**

This repository exists to **safely test, detect, and fully remove OpenClaw installations** from endpoints and to **verify post-remediation cleanliness** using repeatable CI/CD workflows.

It is intentionally **scoped only to OpenClaw**.

---

## Why this repo exists

OpenClaw installs via remote bootstrap scripts and registers persistent user-level services across operating systems. In enterprise environments, this creates risk when installations occur **outside approved software delivery, governance, or security review processes**.

This repo provides:

- Deterministic detection of OpenClaw artifacts
- Safe, documented uninstall procedures
- Cross-platform validation that removal is complete
- CI-based testing to ensure uninstall coverage does not regress over time

This is **not** a malware classification project.  
This is **endpoint hygiene and lifecycle control**.

---

## Scope (explicit)

### In scope
- OpenClaw install detection
- OpenClaw uninstall (official + fallback)
- Verification of complete removal
- CI validation on macOS, Linux, and Windows

### Out of scope
- Blocking installation
- Network containment
- Credential rotation
- Incident response or forensics
- Other agent frameworks or vendors

If you are looking for a generalized agent control framework, this is **not** that repo.

---

## Supported Platforms

| Platform | Coverage |
|----------|----------|
| macOS | LaunchAgents, state directories, `/Applications/OpenClaw.app`, processes |
| Linux | systemd *user* units, state directories |
| Windows | Scheduled Tasks, state directories |

> **Note:** Full systemd-user lifecycle testing requires a systemd-enabled environment. GitHub-hosted Linux runners have limitations; self-hosted runners are recommended for full coverage.

**Tested against:** Uninstall scripts are validated against OpenClaw installs from [openclaw.ai](https://openclaw.ai/) (install.sh / install.ps1) as of 2025-02. When OpenClaw changes install layout or service names, re-run CI and update this note. See [docs/compatibility.md](docs/compatibility.md) for details.

---

## Repository Structure

```
.
├── scripts/
│   ├── uninstall_macos_linux.sh
│   └── uninstall_windows.ps1
├── .github/
│   ├── workflows/
│   │   ├── test.yml
│   │   └── release-checksums.yml
│   ├── ISSUE_TEMPLATE/
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/
│   ├── compatibility.md
│   ├── faq.md
│   ├── siem.md
│   └── mdm.md
├── artifacts/          # CI-generated (gitignored)
├── VERSION             # Script version (read by scripts for SIEM)
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── SECURITY.md
├── .pre-commit-config.yaml
└── README.md
```

---

## How it works

1. **Baseline snapshot** – Capture filesystem, process, and service state before install.
2. **Controlled install** – Execute the OpenClaw installer in an isolated CI runner (no secrets).
3. **Post-install inspection** – Enumerate state dirs, services (launchd/systemd/schtasks), processes.
4. **Remediation** – Run the official OpenClaw uninstaller when available; fall back to documented manual removal.
5. **Post-uninstall validation** – Assert that no OpenClaw artifacts remain; **fail CI if cleanup is incomplete**.
6. **Evidence retention** – Upload before/after snapshots as workflow artifacts.

---

## Usage

### macOS / Linux

```bash
chmod +x scripts/uninstall_macos_linux.sh
./scripts/uninstall_macos_linux.sh
```

With sudo (e.g. for `/var/log` or cross-user cleanup):

```bash
sudo ./scripts/uninstall_macos_linux.sh
```

### Windows

```powershell
.\scripts\uninstall_windows.ps1
```

Scripts are **idempotent** and safe to run multiple times.

**Detect only (no removal):** Use `--dry-run` or `--detect-only` to report what would be removed without making changes. Exit 0 = nothing found; exit 2 = OpenClaw artifacts present. Useful for audits and "who has OpenClaw?" See [docs/mdm.md](docs/mdm.md).

**FAQ:** Common questions (e.g. “What if OpenClaw isn’t installed?”, “Why exit 1?”) are in [docs/faq.md](docs/faq.md).

```bash
# macOS/Linux
./scripts/uninstall_macos_linux.sh --dry-run

# Windows
.\scripts\uninstall_windows.ps1 -DryRun
```

### Exit codes (MDM / SIEM)

| Code | Meaning |
|------|---------|
| 0 | Success (clean or already clean) |
| 1 | Partial (e.g. CLI uninstall failed but manual cleanup ran) |
| 2 | Failure (critical step failed), or dry-run found artifacts (would remove) |

---

## Running locally and via MDM

- **Local:** Run the script as the target user; use `sudo` on macOS/Linux if you need `/var/log` or to clean services for that user.
- **MDM:** Scripts are non-interactive and idempotent. Deploy the script and run it in the user (or system) context. Log paths and exit codes are stable for reporting. For **machine-wide cleanup** across multiple users, run the script **once per user context** (e.g. once per home dir or per logged-in user); an “all users” mode is not implemented yet—see [docs/mdm.md](docs/mdm.md).

---

## Logging and SIEM

Scripts write **SIEM-friendly**, key=value logs so log shippers can parse them without brittle regex.

| Platform | Default log path |
|----------|------------------|
| macOS / Linux | `/var/log/openclaw_removal.log` (fallback: `$HOME/.openclaw_removal.log` if unwritable) |
| Windows | `C:\ProgramData\OpenClawRemoval.log` |

- **Override:** Set `OPENCLAW_REMOVAL_LOG` (macOS/Linux) or `OPENCLAW_REMOVAL_LOG` (Windows) to a custom log path. On macOS/Linux, set `OPENCLAW_STATE_DIR` to also clean a custom OpenClaw state directory (in addition to default `~/.openclaw*`). Set `OPENCLAW_CONFIG_PATH` when OpenClaw was configured to use a config file/dir outside the state dir so the script removes it (per [uninstall docs](https://docs.openclaw.ai/install/uninstall)).
- **Format:** One line per event: `ts=<UTC ISO8601> host=... user=... os=... os_version=... os_arch=... event=... action=... result=... script=openclaw_remediation version=... severity=info|warning|error`. Includes OS name/version/arch for enterprise fleet visibility. Values with spaces or `=` are double-quoted for SIEM parsing.
- **Detection/removal detail:** In `action`, scripts log **kind** (state_dir, cli, app, service, etc.), **source** (npm, launchd, systemd, scheduled_task, etc.), **path**/label/unit, and **openclaw_version** when available. Each removal emits `event=removed` with `result=ok` and the same detail for audit. See [docs/siem.md](docs/siem.md).
- **Outcome:** Final line includes `result=success`, `result=partial`, or `result=failure` (or `result=would_remove` for dry-run). Use `severity=error` or `result=partial|failure` for alerting.
- **Log rotation:** Scripts do not rotate logs; rely on OS or SIEM log rotation for these paths.
- **SIEM:** Add the paths above to your log collection (e.g. Splunk, Elastic, Sentinel, Datadog) and parse on `event` and `result` for dashboards and alerts.
- **Integrity:** When deploying via MDM, verify script integrity with SHA-256. On release tag push, the repo workflow produces a `checksums.txt` artifact; you can also run `sha256sum scripts/*.sh scripts/*.ps1` (Unix) or equivalent locally.

---

## Definition of “clean”

An endpoint is considered **clean** when:

- No `~/.openclaw*` directories exist
- No OpenClaw services remain registered (launchd, systemd user units, or scheduled tasks)
- No OpenClaw processes are running

CI enforces this contract: the workflow **fails** if artifacts remain after uninstall.

---

## CI/CD

The workflow ([`.github/workflows/test.yml`](.github/workflows/test.yml)) runs on **pull requests and pushes to `main`**:

1. **Smoke** – Run uninstall script on a clean runner (no install). Fast check that scripts run without errors. Must pass.
2. **Lint** – ShellCheck on shell scripts, PSScriptAnalyzer on PowerShell. Must pass.
3. **Test** – Baseline → install (with `--no-onboard` on Unix) → post-install snapshot → uninstall → post-uninstall verification → **Assert clean** (fail if artifacts remain) → upload evidence.

Runs on: **macOS, Linux, Windows.**

**Releases:** On tag push (`v*`), [release-checksums.yml](.github/workflows/release-checksums.yml) computes SHA-256 of both scripts, creates a GitHub Release, and attaches `checksums.txt` plus the scripts. Use the [Releases](https://github.com/samerfarida/openclaw-remediation/releases) page to download and verify integrity when deploying via MDM.

**Branch protection:** Require the **Lint** and **Test** status checks to pass before merging into `main`.

### Security notes
- No secrets are used
- Runners are ephemeral
- Installers are treated as untrusted input

---

## Contributing

Contributions are welcome **only if they remain within scope**. See [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Scope and PR requirements (**CI and lint must pass**)
- How to run lint and tests locally
- Exit code convention

By participating, you agree to uphold the [Code of Conduct](CODE_OF_CONDUCT.md). Optional: use [pre-commit](https://pre-commit.com/) with [.pre-commit-config.yaml](.pre-commit-config.yaml) to run ShellCheck before each commit.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and notable changes.

---

## Legal & Compliance

- This project does not classify OpenClaw as malware
- Only publicly documented uninstall mechanisms are used
- No reverse engineering is performed
- No interference occurs beyond removal

This repository is suitable for enterprise IT, platform engineering, security operations, and compliance validation.

---

## Security

To report a vulnerability in **this repository**, see [SECURITY.md](SECURITY.md).  
For OpenClaw itself, see [OpenClaw’s security documentation](https://docs.openclaw.ai/gateway/security).

---

## Disclaimer

This repository is provided **as-is**.  
Always validate in a controlled environment before enterprise deployment.
