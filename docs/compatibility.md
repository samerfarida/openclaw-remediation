# Compatibility

Uninstall scripts in this repo are validated against **OpenClaw** installs produced by the official installers and align with the official docs:

- [Platforms](https://docs.openclaw.ai/platforms) — macOS (menu-bar app, LaunchAgents), [Windows](https://docs.openclaw.ai/platforms/windows) (WSL2 recommended; native scheduled task), [Linux](https://docs.openclaw.ai/platforms/linux) (systemd user)
- [macOS](https://docs.openclaw.ai/platforms/macos) — LaunchAgents `bot.molt.gateway` / `bot.molt.<profile>`, legacy `com.openclaw.*`, `/Applications/OpenClaw.app`, exec-approvals in state dir
- [Uninstall](https://docs.openclaw.ai/install/uninstall) — CLI uninstall, manual service removal, state/config, global CLI, macOS app, optional `OPENCLAW_CONFIG_PATH`

## Tested against

| Source | When validated |
|--------|----------------|
| [openclaw.ai](https://openclaw.ai/) – `install.sh` (macOS/Linux) | 2025-02 |
| [openclaw.ai](https://openclaw.ai/) – `install.ps1` (Windows) | 2025-02 |

**CI note:** The workflow runs installers with **non-interactive flags** (`--no-onboard --no-prompt` and `OPENCLAW_NO_ONBOARD=1`, `OPENCLAW_NO_PROMPT=1` on macOS/Linux; same env on Windows). The **upstream install.sh does not install the macOS app** (`/Applications/OpenClaw.app`); it only installs the CLI (npm global or git checkout wrapper). So to test **app removal** on macOS, the workflow creates a **stub** `/Applications/OpenClaw.app` after install when missing. Assert clean fails if the app or any other artifact remains. On Windows, if the installer fails (e.g. network or prompts), the uninstall step runs on a clean runner and Assert clean still passes.

## Artifacts we remove

Per [OpenClaw uninstall docs](https://docs.openclaw.ai/install/uninstall) and [platforms](https://docs.openclaw.ai/platforms):

- **State dirs:** `~/.openclaw`, `~/.openclaw-<profile>` (includes workspace, exec-approvals, etc.)
- **Services:** launchd (`bot.molt.gateway`, `bot.molt.<profile>`, legacy `com.openclaw.*`), systemd user (`openclaw-gateway[-<profile>].service`), Windows scheduled task `OpenClaw Gateway` / `OpenClaw Gateway (<profile>)`
- **macOS app:** `/Applications/OpenClaw.app`
- **Global CLI:** npm/pnpm/bun `openclaw`; Windows: npm shims in `%APPDATA%\npm`, optional `%LOCALAPPDATA%` install paths
- **Git-install wrapper (macOS/Linux):** `~/.local/bin/openclaw` (from `install.sh --install-method git`)
- **Optional config path:** when `OPENCLAW_CONFIG_PATH` is set (file or dir outside state dir), we remove it

## When OpenClaw changes

If OpenClaw changes install layout, service names, or paths:

1. Re-run the full CI workflow (install → uninstall → assert clean) and fix any failures.
2. Update this file and the **“Tested against”** note in [README.md](../README.md) with the validation date.
3. Bump version and add a CHANGELOG entry.

## Custom installs

- **OPENCLAW_STATE_DIR** (macOS/Linux): If OpenClaw was installed with a custom state dir, set this env var so the script also cleans that path.
- **OPENCLAW_CONFIG_PATH**: If you pointed OpenClaw at a config file/dir outside the state dir, set this env var when running the uninstall script so we remove it (per [uninstall docs](https://docs.openclaw.ai/install/uninstall)).
- **OPENCLAW_REMOVAL_LOG**: Override log path on any platform if needed.
