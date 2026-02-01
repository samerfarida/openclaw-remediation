# Compatibility

Uninstall scripts in this repo are validated against **OpenClaw** installs produced by the official installers.

## Tested against

| Source | When validated |
|--------|----------------|
| [openclaw.ai](https://openclaw.ai/) – `install.sh` (macOS/Linux) | 2025-02 |
| [openclaw.ai](https://openclaw.ai/) – `install.ps1` (Windows) | 2025-02 |

Artifacts we remove are those created by these installers per [OpenClaw uninstall docs](https://docs.openclaw.ai/install/uninstall):

- State dirs: `~/.openclaw`, `~/.openclaw-<profile>`
- Services: launchd (`bot.molt.gateway`, `bot.molt.<profile>`, legacy `com.openclaw.*`), systemd user (`openclaw-gateway.service`), Windows scheduled task `OpenClaw Gateway`
- macOS app: `/Applications/OpenClaw.app`
- Global CLI: npm/pnpm/bun `openclaw`

## When OpenClaw changes

If OpenClaw changes install layout, service names, or paths:

1. Re-run the full CI workflow (install → uninstall → assert clean) and fix any failures.
2. Update this file and the **“Tested against”** note in [README.md](../README.md) with the validation date.
3. Bump version and add a CHANGELOG entry.

## Custom installs

- **OPENCLAW_STATE_DIR** (macOS/Linux): If OpenClaw was installed with a custom state dir, set this env var so the script also cleans that path.
- **OPENCLAW_REMOVAL_LOG**: Override log path on any platform if needed.
