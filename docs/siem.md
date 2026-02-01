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
- **Key=value** fields, space-separated. Example:

  ```
  ts=2025-02-01T12:00:00Z host=hostname user=who event=start action=uninstall
  ts=2025-02-01T12:00:01Z host=hostname user=who event=detect action=state_dir=/home/user/.openclaw
  ts=2025-02-01T12:00:02Z host=hostname user=who event=complete result=success
  ```

- **Fields:** `ts` (UTC ISO8601), `host`, `user`, `event`, `action` (optional), `result` (on completion).
- **Outcome:** Last line has `result=success`, `result=partial`, or `result=failure` (or `result=would_remove` for dry-run). Use this for alerting.

## Example queries

### Splunk

- All remediation runs:
  ```
  source="/var/log/openclaw_removal.log" OR source="*OpenClawRemoval.log"
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
- **By host/user:** Group by `host` and `user` for “who ran remediation and with what outcome.”
- **Dry-run “present”:** Count `result=would_remove` to see endpoints where OpenClaw is still present (audit only, no removal).

## Log rotation

Scripts do **not** rotate logs. Rely on OS or SIEM log rotation for these paths (e.g. logrotate on Unix, Windows Event Log or your SIEM agent).
