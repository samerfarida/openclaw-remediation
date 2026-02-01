#!/usr/bin/env bash
set -euo pipefail

# Optional: --dry-run / --detect-only = report what would be removed, no changes. Exit 0 = clean, 2 = artifacts present.
DRY_RUN=""
for arg in "$@"; do
  if [[ "$arg" = "--dry-run" ]] || [[ "$arg" = "--detect-only" ]]; then
    DRY_RUN=1
    break
  fi
done

# Log path: /var/log by default; OPENCLAW_REMOVAL_LOG overrides; fallback to $HOME/.openclaw_removal.log if unwritable
LOG_FILE="/var/log/openclaw_removal.log"
[[ -n "${OPENCLAW_REMOVAL_LOG:-}" ]] && LOG_FILE="$OPENCLAW_REMOVAL_LOG"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
# Use subshell for writability test so redirect failure under set -e does not exit the script
if ! ( : >> "$LOG_FILE" ) 2>/dev/null; then
  LOG_FILE="${HOME:-/tmp}/.openclaw_removal.log"
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
fi

# SIEM-friendly: one line per event, key=value, ts in UTC
ts() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }
HOST="$(hostname)"
USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" 2>/dev/null | cut -d: -f6)" || HOME_DIR="${HOME:-}"
[[ -z "$HOME_DIR" ]] && HOME_DIR="$HOME"

log() {
  local event="$1" action="${2:-}" result="${3:-}"
  local line
  line="ts=$(ts) host=$HOST user=$USER_NAME event=$event"
  [[ -n "$action" ]] && line="$line action=$action"
  [[ -n "$result" ]] && line="$line result=$result"
  printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
}

RESULT="success"
log "start" "uninstall" ""

# ---- detection ----
STATE_DIRS=( "$HOME_DIR/.openclaw" )
while IFS= read -r d; do STATE_DIRS+=( "$d" ); done < <(ls -d "$HOME_DIR"/.openclaw-* 2>/dev/null || true)
# Optional: honor OPENCLAW_STATE_DIR when set (e.g. for MDM / custom installs)
if [[ -n "${OPENCLAW_STATE_DIR:-}" ]] && [[ -d "$OPENCLAW_STATE_DIR" ]]; then
  STATE_DIRS+=( "$OPENCLAW_STATE_DIR" )
fi

FOUND=0
for d in "${STATE_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    FOUND=1
    log "detect" "state_dir=$d" ""
  fi
done

if [[ "$FOUND" -eq 0 ]]; then
  log "detect" "no_state_dirs" ""
fi

# ---- dry-run: report only, no removal ----
if [[ -n "${DRY_RUN:-}" ]]; then
  OS="$(uname -s)"
  if [[ "$OS" = "Darwin" ]]; then
    if launchctl list 2>/dev/null | grep -qE -i "openclaw|molt|claw"; then
      log "dry_run" "would_remove launchd_entries" ""
      FOUND=1
    fi
    [[ -d "/Applications/OpenClaw.app" ]] && { log "dry_run" "would_remove /Applications/OpenClaw.app" ""; FOUND=1; }
  else
    if command -v systemctl >/dev/null 2>&1; then
      if systemctl --user list-unit-files 2>/dev/null | grep -qE -i "openclaw|molt|claw"; then
        log "dry_run" "would_remove systemd_units" ""
        FOUND=1
      fi
    fi
  fi
  if command -v openclaw >/dev/null 2>&1; then
    log "dry_run" "would_remove global_cli_openclaw" ""
    FOUND=1
  fi
  if command -v npm >/dev/null 2>&1 && npm list -g openclaw --depth=0 2>/dev/null | grep -q openclaw; then
    log "dry_run" "would_remove global_cli_npm" ""
    FOUND=1
  fi
  log "complete" "" "$([[ "$FOUND" -eq 1 ]] && echo "would_remove" || echo "clean")"
  [[ "$FOUND" -eq 1 ]] && exit 2 || exit 0
fi

# ---- uninstall via official CLI if possible ----
if command -v openclaw >/dev/null 2>&1; then
  log "uninstall_cli" "openclaw uninstall --all --yes --non-interactive" ""
  if openclaw uninstall --all --yes --non-interactive >>"$LOG_FILE" 2>&1; then
    log "uninstall_cli" "ok" ""
  else
    RESULT="partial"
    log "uninstall_cli" "failed_fallback_manual" ""
  fi
else
  if command -v npx >/dev/null 2>&1; then
    log "uninstall_cli" "npx -y openclaw uninstall" ""
    if npx -y openclaw uninstall --all --yes --non-interactive >>"$LOG_FILE" 2>&1; then
      log "uninstall_cli" "ok" ""
    else
      RESULT="partial"
      log "uninstall_cli" "npx_failed_fallback_manual" ""
    fi
  else
    log "uninstall_cli" "skip_no_cli_nor_npx" ""
  fi
fi

# ---- manual service removal (per docs) ----
OS="$(uname -s)"

if [[ "$OS" = "Darwin" ]]; then
  log "manual" "launchd_bootout_bot.molt.gateway" ""
  launchctl bootout "gui/$(id -u "$USER_NAME")/bot.molt.gateway" >>"$LOG_FILE" 2>&1 || true
  rm -f "$HOME_DIR/Library/LaunchAgents/bot.molt.gateway.plist" 2>>"$LOG_FILE" || true

  for plist in "$HOME_DIR"/Library/LaunchAgents/bot.molt.*.plist; do
    [[ -e "$plist" ]] || continue
    label="$(basename "$plist" .plist)"
    log "manual" "launchd_remove_label=$label" ""
    launchctl bootout "gui/$(id -u "$USER_NAME")/$label" >>"$LOG_FILE" 2>&1 || true
    rm -f "$plist" 2>>"$LOG_FILE" || true
  done

  # Legacy com.openclaw.*: bootout before removing plist so service is unloaded
  for plist in "$HOME_DIR"/Library/LaunchAgents/com.openclaw*.plist; do
    [[ -e "$plist" ]] || continue
    label="$(basename "$plist" .plist)"
    log "manual" "launchd_bootout_legacy=$label" ""
    launchctl bootout "gui/$(id -u "$USER_NAME")/$label" >>"$LOG_FILE" 2>&1 || true
    rm -f "$plist" 2>>"$LOG_FILE" || true
  done

  # macOS app (per docs)
  if [[ -d "/Applications/OpenClaw.app" ]]; then
    log "manual" "remove_app=/Applications/OpenClaw.app" ""
    rm -rf "/Applications/OpenClaw.app" 2>>"$LOG_FILE" || true
  fi

else
  if command -v systemctl >/dev/null 2>&1; then
    log "manual" "systemd_disable_openclaw-gateway" ""
    # shellcheck disable=SC2024
    sudo -u "$USER_NAME" systemctl --user disable --now openclaw-gateway.service >>"$LOG_FILE" 2>&1 || true
    rm -f "$HOME_DIR/.config/systemd/user/openclaw-gateway.service" 2>>"$LOG_FILE" || true

    for unit in "$HOME_DIR"/.config/systemd/user/openclaw-gateway-*.service; do
      [[ -e "$unit" ]] || continue
      name="$(basename "$unit")"
      log "manual" "systemd_remove_unit=$name" ""
      # shellcheck disable=SC2024
      sudo -u "$USER_NAME" systemctl --user disable --now "$name" >>"$LOG_FILE" 2>&1 || true
      rm -f "$unit" 2>>"$LOG_FILE" || true
    done

    # shellcheck disable=SC2024
    sudo -u "$USER_NAME" systemctl --user daemon-reload >>"$LOG_FILE" 2>&1 || true
  else
    log "manual" "systemctl_not_found" ""
  fi
fi

# ---- delete state + workspace ----
for d in "${STATE_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    log "remove_state" "path=$d" ""
    rm -rf "$d"
  fi
done

# ---- remove global CLI (best-effort, per docs) ----
if command -v npm >/dev/null 2>&1; then
  log "cli_remove" "npm_rm_global" ""
  npm rm -g openclaw >>"$LOG_FILE" 2>&1 || true
fi
if command -v pnpm >/dev/null 2>&1; then
  log "cli_remove" "pnpm_rm_global" ""
  pnpm remove -g openclaw >>"$LOG_FILE" 2>&1 || true
fi
if command -v bun >/dev/null 2>&1; then
  log "cli_remove" "bun_rm_global" ""
  bun remove -g openclaw >>"$LOG_FILE" 2>&1 || true
fi

log "complete" "" "$RESULT"

if [[ "$RESULT" = "success" ]]; then
  exit 0
elif [[ "$RESULT" = "partial" ]]; then
  exit 1
else
  exit 2
fi
