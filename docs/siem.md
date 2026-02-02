# SIEM integration

Uninstall scripts write **SIEM-friendly**, key=value logs so you can ingest them without brittle regex.

## Log paths

| Platform | Default path | Override |
|----------|--------------|----------|
| macOS / Linux | `/var/log/openclaw_removal.log` | `OPENCLAW_REMOVAL_LOG` |
| Windows | `C:\ProgramData\OpenClawRemoval.log` | `OPENCLAW_REMOVAL_LOG` |

If `/var/log` is not writable (e.g. non-root), the Unix script falls back to `$HOME/.openclaw_removal.log`.

## Format

- **One event per line.** No multi-line messages.
- **Key=value** fields, space-separated. Values that contain spaces or `=` are double-quoted. Example:

  ```
  ts=2025-02-01T12:00:00Z host=hostname user=who os=Darwin os_version=14.2.1 os_arch=arm64 event=start action=uninstall script=openclaw_remediation version=1.0.0 severity=info
  ts=2025-02-01T12:00:01Z host=hostname user=who os=Linux os_version=ubuntu-22.04 os_arch=x86_64 event=detect action="state_dir=/home/user/.openclaw" script=openclaw_remediation version=1.0.0 severity=info
  ts=2025-02-01T12:00:02Z host=hostname user=who os=Windows os_version=10.0.19045 os_arch=64-bit event=complete result=success script=openclaw_remediation version=1.0.0 severity=info
  ```

- **Fields:** `ts` (UTC ISO8601), `host`, `user`, `os` (Darwin | Linux | Windows), `os_version` (e.g. macOS product version, Linux distro-VERSION_ID, Windows build), `os_arch` (e.g. x86_64, arm64, 64-bit), `event`, `action` (optional), `result` (on completion), `script=openclaw_remediation`, `version` (script version from repo `VERSION` file, or `unknown` when missing), `severity` (info | warning | error).
- **Detection/removal detail:** In `action`, scripts log **kind** (what was found or removed: `state_dir`, `cli`, `app`, `service`, `config_path`, `install_path`, `cli_shim`), **source** when relevant (e.g. `npm`, `pnpm`, `bun`, `git_wrapper`, `launchd`, `systemd`, `scheduled_task`), **path** or **label**/ **unit**/ **task_name**, and **openclaw_version** when available (CLI version from `openclaw --version` or npm list; app version from macOS Info.plist). Use `event=removed` with `result=ok` to see exactly what was uninstalled.
- **Outcome:** Last line has `result=success`, `result=partial`, or `result=failure` (or `result=would_remove` for dry-run). Use this for alerting.

## Example queries

### Splunk

- All remediation runs:
  ```
  source="/var/log/openclaw_removal.log" OR source="*OpenClawRemoval.log"
  ```
- By severity (e.g. errors only):
  ```
  script=openclaw_remediation severity=error
  ```
- Failures or partial:
  ```
  result=partial OR result=failure
  ```
- Dry-run “would remove” (OpenClaw present):
  ```
  event=complete result=would_remove
  ```

### Elastic / OpenSearch

- Index the log path and parse key=value (e.g. ingest pipeline or logstash).
- Filter: `event: complete AND (result: failure OR result: partial OR result: would_remove)`.

### Microsoft Sentinel / Azure

- Add the log path to your agent’s file collection; parse as key=value or custom log.
- Alert on `result=failure` or `result=would_remove`.

### Datadog

- Add the file as a log source; use a custom parser for key=value.
- Monitor: `result:failure` or `result:would_remove`.

## Dashboards

- **Count by result:** `event=complete` grouped by `result` (success / partial / failure / would_remove).
- **By OS/version:** Group by `os` and `os_version` for fleet coverage (e.g. remediation runs by macOS version, Linux distros).
- **By host/user:** Group by `host` and `user` for “who ran remediation and with what outcome.”
- **Dry-run “present”:** Count `result=would_remove` to see endpoints where OpenClaw is still present (audit only, no removal).

## Enterprise robustness

- **Parsing:** Values that contain spaces or `=` are written in double quotes (e.g. `action="state_dir=C:\Users\John Doe\.openclaw"`) so Splunk and other SIEMs can parse fields unambiguously. Use a parser that supports both `key=value` and `key="value"`.
- **Severity:** The last event includes `severity=info|warning|error` so you can filter by criticality (e.g. `severity=error` for failures).
- **Source:** Each line includes `script=openclaw_remediation` so you can identify the source in multi-tool environments.
- **Splunk:** Use a props.conf extractor that accepts quoted values, or index as a single string and run `rex`/`spath` for structured fields. The format is compatible with Splunk’s key=value and quoted-value parsing.

## Log rotation

Scripts do **not** rotate logs. Rely on OS or SIEM log rotation for these paths (e.g. logrotate on Unix, Windows Event Log or your SIEM agent).

### logrotate example (Linux / macOS)

To rotate `/var/log/openclaw_removal.log` on Linux or macOS, add a config (e.g. `/etc/logrotate.d/openclaw-remediation`):

```text
/var/log/openclaw_removal.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

- **daily** – rotate once per day
- **rotate 14** – keep 14 rotated files
- **compress** / **delaycompress** – compress older files
- **missingok** – do not error if the log is missing
- **notifempty** – do not rotate empty files
- **copytruncate** – copy then truncate the open file (avoids requiring the script to reopen the log)

Reload logrotate (e.g. `logrotate -d /etc/logrotate.d/openclaw-remediation` to test, or rely on your daily cron).
