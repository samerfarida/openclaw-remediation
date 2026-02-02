# FAQ

## What if OpenClaw isn’t installed at all?

The scripts detect whether any OpenClaw artifacts are present (state dirs, services, app, global CLI). If **nothing is found**, they log `result=success` with `action=already_clean` and **exit 0** without running the official uninstaller or npx. No network calls, no removal steps—just a fast “already clean” outcome.

## Why did I get exit code 1 (partial)?

**Exit 1** means the script ran removal steps but the **official OpenClaw CLI uninstall** (e.g. `openclaw uninstall` or `npx openclaw uninstall`) failed or wasn’t available. The script still performed manual cleanup (state dirs, launchd/systemd/scheduled tasks, app removal). The endpoint may be clean; use the final log line `result=partial` and your “assert clean” checks (or CI) to confirm. In CI we treat exit 1 as acceptable and rely on the “assert clean” step to fail if anything remains.

## Why exit code 2?

**Exit 2** means either:

- **Normal run:** A critical step failed (e.g. script error, unexpected state).
- **Dry-run:** OpenClaw artifacts were detected and *would* be removed if you ran without `--dry-run` / `-DryRun`. So exit 2 in dry-run = “OpenClaw present on this endpoint.”

## The script seemed to hang or produced no output.

Scripts write **only to the log file** by default (no stdout). You’ll see brief progress on **stderr** (e.g. “logging to …”, “trying npx …”, “result=…”). If you run without OpenClaw installed, the script should exit quickly with “already clean”. If it runs the official uninstall or npx, that step can take 10–30+ seconds (network, package resolution). Use `OPENCLAW_REMOVAL_LOG` to point to a log path you can tail.

## How do I know which script version ran?

Each log line includes **`version=<version>`** (from the repo `VERSION` file when the script is run from a checkout that has it). If the script is deployed without the `VERSION` file (e.g. copied alone via MDM), logs will show `version=unknown`. Use this in your SIEM to filter or report by script version.

## Can I run this for all users on a machine?

Scripts target the **current user** (or `SUDO_USER` on Unix). For **machine-wide** cleanup you must run the script **once per user context** (e.g. each user’s home, or each logged-in user). An “all users” mode is not implemented; see [docs/mdm.md](mdm.md) for patterns.

## Where are logs written?

| Platform   | Default path                          | Override                |
|-----------|----------------------------------------|-------------------------|
| macOS/Linux | `/var/log/openclaw_removal.log`      | `OPENCLAW_REMOVAL_LOG`  |
| Windows   | `C:\ProgramData\OpenClawRemoval.log`   | `OPENCLAW_REMOVAL_LOG`  |

On Unix, if `/var/log` isn’t writable, the script falls back to `$HOME/.openclaw_removal.log`.

## How do I rotate the log file?

Scripts do **not** rotate logs. Use OS or SIEM mechanisms. On Linux/macOS, see the [logrotate example](siem.md#log-rotation) in the SIEM doc.
