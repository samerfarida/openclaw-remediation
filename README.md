# openclaw-remediation

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)](https://github.com/samerfarida/openclaw-remediation)
[![CI](https://github.com/samerfarida/openclaw-remediation/actions/workflows/test.yml/badge.svg)](https://github.com/samerfarida/openclaw-remediation/actions/workflows/test.yml)
[![GitHub release](https://img.shields.io/github/v/release/samerfarida/openclaw-remediation)](https://github.com/samerfarida/openclaw-remediation/releases)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/samerfarida/openclaw-remediation/badge)](https://scorecard.dev/viewer/?uri=github.com/samerfarida/openclaw-remediation)

**Detection, uninstall, and validation tooling for OpenClaw on macOS, Linux, and Windows.**

---

## Quick start

**macOS / Linux**
```bash
chmod +x scripts/uninstall_macos_linux.sh
./scripts/uninstall_macos_linux.sh
```

**Windows**
```powershell
.\scripts\uninstall_windows.ps1
```

Scripts are **idempotent** and safe to run multiple times. Use `--dry-run` (Unix) or `-DryRun` (Windows) to detect only—no removal. [Releases](https://github.com/samerfarida/openclaw-remediation/releases) → download scripts + `checksums.txt` for integrity verification.

---

## What is this?

This repo provides **purpose-built tooling** to:

- **Detect** OpenClaw installations across endpoints
- **Uninstall** using official or fallback procedures
- **Validate** that removal is complete (CI-enforced)

OpenClaw installs via remote bootstrap scripts and registers persistent user-level services. This repo helps enterprise IT, platform engineering, and security teams **remove OpenClaw** when it sits outside approved software delivery or governance.

This is **endpoint hygiene and lifecycle control**—not malware classification. Scoped only to OpenClaw.

---

## Why use this?

In enterprise environments, OpenClaw creates risk when it’s installed **outside approved software delivery, governance, or security review**. Security research (e.g. [Palo Alto Networks](https://www.paloaltonetworks.com/blog/network-security/why-moltbot-may-signal-ai-crisis/)) has analyzed OpenClaw and related agentic AI systems (Moltbot, Clawdbot) against the [OWASP Top 10 for Agentic AI](https://owasp.org/www-project-agentic-ai-top-10/). Autonomous agents with persistent memory, broad tool access, and minimal governance have a large attack surface. For teams that cannot enforce trust boundaries, human-in-the-loop controls, or runtime monitoring, **removal may be the appropriate control**.

This repo does not perform security assessment—it provides **detection and remediation tooling** for teams that have decided removal is the right approach.

| OWASP Agent Risk | OpenClaw / Agentic Context |
|------------------|----------------------------|
| **A01: Prompt Injection** | Web content, messages, and third-party skills can inject instructions the agent executes. |
| **A02: Insecure Tool Invocation** | Tools (bash, file I/O, email, messaging) run based on reasoning that includes untrusted memory. |
| **A03: Excessive Agent Autonomy** | Single agent can access filesystem, credentials, and network with no privilege boundaries or approval gates. |
| **A04: Missing Human-in-the-Loop** | No approval required for destructive operations even when influenced by untrusted or stale memory. |
| **A05: Agent Memory Poisoning** | Memory is undifferentiated by source; web scrapes, user commands, and third-party outputs stored without trust levels or expiration. |
| **A06: Insecure Third-Party Integrations** | Third-party skills run with full agent privileges and can write to persistent memory without sandboxing. |
| **A07: Insufficient Privilege Separation** | Untrusted input ingestion and high-privilege action execution share the same memory space. |
| **A08: Supply Chain Model Risk** | Upstream LLM use without validation of fine-tuning or safety alignment. |
| **A09: Unbounded Agent-to-Agent Actions** | Monolithic design today; future multi-agent versions could enable unconstrained communication. |
| **A10: Lack of Runtime Monitoring** | No policy layer between memory → reasoning → tool invocation; no anomaly detection on memory access or temporal causation. |

---

## Usage

### Commands

| Platform | Command |
|----------|---------|
| macOS / Linux | `./scripts/uninstall_macos_linux.sh` |
| Windows | `.\scripts\uninstall_windows.ps1` |

Use `sudo ./scripts/uninstall_macos_linux.sh` on macOS/Linux for `/var/log` or cross-user cleanup.

### Detect only (dry-run)

```bash
# macOS/Linux
./scripts/uninstall_macos_linux.sh --dry-run

# Windows
.\scripts\uninstall_windows.ps1 -DryRun
```

Useful for audits (“who has OpenClaw?”). Exit 0 = nothing found; exit 2 = artifacts present.

### Exit codes (MDM / SIEM)

| Code | Meaning |
|------|---------|
| 0 | Success (clean or already clean) |
| 1 | Partial (e.g. CLI uninstall failed but manual cleanup ran) |
| 2 | Failure, or dry-run found artifacts |

### MDM deployment

Scripts are non-interactive and idempotent. Deploy and run in user or system context. For machine-wide cleanup across multiple users, run **once per user context**. See [docs/mdm.md](docs/mdm.md).

### Environment variables

- `OPENCLAW_REMOVAL_LOG` – Custom log path (both platforms)
- `OPENCLAW_STATE_DIR` – Custom state dir to clean (macOS/Linux)
- `OPENCLAW_CONFIG_PATH` – Custom config path to remove (macOS/Linux)

---

## Platform support

| Platform | Coverage |
|----------|----------|
| macOS | LaunchAgents, state dirs, `/Applications/OpenClaw.app`, processes |
| Linux | systemd *user* units, state dirs |
| Windows | Scheduled Tasks, state dirs |

**Tested against:** OpenClaw installs from [openclaw.ai](https://openclaw.ai/) (2025-02). See [docs/compatibility.md](docs/compatibility.md).

---

## Logging and SIEM

Scripts write **SIEM-friendly** key=value logs:

| Platform | Default log path |
|----------|------------------|
| macOS / Linux | `/var/log/openclaw_removal.log` (fallback: `$HOME/.openclaw_removal.log`) |
| Windows | `C:\ProgramData\OpenClawRemoval.log` |

Format, exit codes, and alerting details: [docs/siem.md](docs/siem.md).

---

## FAQ and docs

- [docs/faq.md](docs/faq.md) – Common questions (“What if OpenClaw isn’t installed?”, “Why exit 1?”)
- [docs/siem.md](docs/siem.md) – Log format, SIEM integration
- [docs/mdm.md](docs/mdm.md) – MDM deployment
- [docs/compatibility.md](docs/compatibility.md) – Compatibility notes

---

## Contributing

Contributions welcome **within scope**. CI (lint + test) must pass. See [CONTRIBUTING.md](CONTRIBUTING.md). [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Legal and disclaimer

- This project does not classify OpenClaw as malware
- Only publicly documented uninstall mechanisms are used
- No reverse engineering; no interference beyond removal

**Security:** Report vulnerabilities in this repo → [SECURITY.md](SECURITY.md). OpenClaw itself → [OpenClaw security docs](https://docs.openclaw.ai/gateway/security).

**Changelog:** [CHANGELOG.md](CHANGELOG.md).

This repository is provided **as-is**. Validate in a controlled environment before enterprise deployment.
