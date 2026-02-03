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

# SIEM-friendly: one line per event, key=value, ts in UTC; quote values with space or = for parsing
ts() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }
siem_quote() {
  local v="$1"
  if [[ "$v" = *" "* ]] || [[ "$v" = *"="* ]]; then
    printf '"%s"' "${v//\"/\\\"}"
  else
    printf '%s' "$v"
  fi
}
HOST="$(hostname)"
USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" 2>/dev/null | cut -d: -f6)" || HOME_DIR="${HOME:-}"
[[ -z "$HOME_DIR" ]] && HOME_DIR="$HOME"

# OS and arch for SIEM (enterprise context)
OS_NAME="$(uname -s)"
OS_ARCH="$(uname -m)"
OS_VERSION=""
if [[ "$OS_NAME" = "Darwin" ]]; then
  OS_VERSION="$(sw_vers -productVersion 2>/dev/null)" || OS_VERSION="$(uname -r)"
elif [[ "$OS_NAME" = "Linux" ]]; then
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    OS_VERSION="$(. /etc/os-release 2>/dev/null && echo "${ID:-linux}-${VERSION_ID:-$(uname -r)}")"
  fi
  [[ -z "$OS_VERSION" ]] && OS_VERSION="$(uname -r)"
else
  OS_VERSION="$(uname -r)"
fi

# Script version for SIEM (from repo VERSION file when present)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../VERSION" ]]; then
  SCRIPT_VERSION="$(head -n1 "$SCRIPT_DIR/../VERSION" | tr -d '\r\n')"
else
  SCRIPT_VERSION="unknown"
fi

log() {
  local event="$1" action="${2:-}" result="${3:-}" sev="${4:-info}"
  local line
  line="ts=$(ts) host=$(siem_quote "$HOST") user=$(siem_quote "$USER_NAME") os=$OS_NAME os_version=$(siem_quote "$OS_VERSION") os_arch=$OS_ARCH event=$event script=openclaw_remediation version=$SCRIPT_VERSION"
  [[ -n "$action" ]] && line="$line action=$(siem_quote "$action")"
  [[ -n "$result" ]] && line="$line result=$(siem_quote "$result")"
  line="$line severity=$sev"
  printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
}

RESULT="success"
log "start" "uninstall" ""

# Progress to stderr so interactive runs don't appear to hang (CI/MDM can redirect)
echo "openclaw-remediation: logging to $LOG_FILE" >&2

# Resolve OpenClaw CLI version for SIEM (kind=cli, version=...); must not fail when absent (set -e)
OPENCLAW_CLI_VERSION=""
if command -v openclaw >/dev/null 2>&1; then
  OPENCLAW_CLI_VERSION="$(openclaw --version 2>/dev/null | head -n1 | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" || true
fi
if [[ -z "$OPENCLAW_CLI_VERSION" ]] && command -v npm >/dev/null 2>&1; then
  OPENCLAW_CLI_VERSION="$(npm list -g openclaw --depth=0 2>/dev/null | grep -oE 'openclaw@[^[:space:]]+' | head -n1 | sed 's/^openclaw@//')" || true
fi

# Resolve macOS app version for SIEM (kind=app, version=...)
OPENCLAW_APP_VERSION=""
if [[ "$(uname -s)" = "Darwin" ]] && [[ -d "/Applications/OpenClaw.app" ]]; then
  if [[ -f "/Applications/OpenClaw.app/Contents/Info.plist" ]]; then
    OPENCLAW_APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /Applications/OpenClaw.app/Contents/Info.plist 2>/dev/null)" || \
    OPENCLAW_APP_VERSION="$(defaults read /Applications/OpenClaw.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null)" || true
  fi
fi

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
    log "detect" "kind=state_dir path=$d" ""
  fi
done

# Git-install wrapper (install.sh --install-method git): ~/.local/bin/openclaw
if [[ -x "$HOME_DIR/.local/bin/openclaw" ]]; then
  FOUND=1
  log "detect" "kind=cli source=git_wrapper path=$HOME_DIR/.local/bin/openclaw openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" ""
fi

# Optional config path outside state dir (per https://docs.openclaw.ai/install/uninstall)
if [[ -n "${OPENCLAW_CONFIG_PATH:-}" ]] && [[ -e "$OPENCLAW_CONFIG_PATH" ]]; then
  FOUND=1
  log "detect" "kind=config_path path=$OPENCLAW_CONFIG_PATH" ""
fi

if [[ "$FOUND" -eq 0 ]]; then
  log "detect" "no_state_dirs" ""
fi

# ---- dry-run: report only, no removal ----
if [[ -n "${DRY_RUN:-}" ]]; then
  echo "openclaw-remediation: dry-run (detect only), no removal" >&2
  OS="$(uname -s)"
  if [[ "$OS" = "Darwin" ]]; then
    if launchctl list 2>/dev/null | grep -qE -i "openclaw|molt|claw"; then
      log "dry_run" "would_remove kind=service source=launchd" ""
      FOUND=1
    fi
    [[ -d "/Applications/OpenClaw.app" ]] && { log "dry_run" "would_remove kind=app path=/Applications/OpenClaw.app openclaw_version=$(siem_quote "${OPENCLAW_APP_VERSION:-unknown}")" ""; FOUND=1; }
  else
    if command -v systemctl >/dev/null 2>&1; then
      if systemctl --user list-unit-files 2>/dev/null | grep -qE -i "openclaw|molt|claw"; then
        log "dry_run" "would_remove kind=service source=systemd" ""
        FOUND=1
      fi
    fi
  fi
  if command -v openclaw >/dev/null 2>&1; then
    log "dry_run" "would_remove kind=cli source=path openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" ""
    FOUND=1
  fi
  if command -v npm >/dev/null 2>&1 && npm list -g openclaw --depth=0 2>/dev/null | grep -q openclaw; then
    log "dry_run" "would_remove kind=cli source=npm openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" ""
    FOUND=1
  fi
  if command -v pnpm >/dev/null 2>&1 && pnpm list -g openclaw 2>/dev/null | grep -q openclaw; then
    log "dry_run" "would_remove kind=cli source=pnpm openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" ""
    FOUND=1
  fi
  if command -v bun >/dev/null 2>&1 && bun pm ls -g 2>/dev/null | grep -q openclaw; then
    log "dry_run" "would_remove kind=cli source=bun openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" ""
    FOUND=1
  fi
  [[ -x "$HOME_DIR/.local/bin/openclaw" ]] && { log "dry_run" "would_remove kind=cli source=git_wrapper openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" ""; FOUND=1; }
  [[ -n "${OPENCLAW_CONFIG_PATH:-}" ]] && [[ -e "$OPENCLAW_CONFIG_PATH" ]] && { log "dry_run" "would_remove config_path" ""; FOUND=1; }
  log "complete" "" "$([[ "$FOUND" -eq 1 ]] && echo "would_remove" || echo "clean")" "$([[ "$FOUND" -eq 1 ]] && echo "warning" || echo "info")"
  [[ "$FOUND" -eq 1 ]] && exit 2 || exit 0
fi

# ---- already clean: skip uninstall and npx when nothing is present ----
OS="$(uname -s)"
if [[ "$OS" = "Darwin" ]]; then
  launchctl list 2>/dev/null | grep -qE -i "openclaw|molt|claw" && FOUND=1
  [[ -d "/Applications/OpenClaw.app" ]] && FOUND=1
else
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user list-unit-files 2>/dev/null | grep -qE -i "openclaw|molt|claw" && FOUND=1
  fi
fi
command -v openclaw >/dev/null 2>&1 && FOUND=1
if command -v npm >/dev/null 2>&1; then
  npm list -g openclaw --depth=0 2>/dev/null | grep -q openclaw && FOUND=1
fi
if command -v pnpm >/dev/null 2>&1; then
  pnpm list -g openclaw 2>/dev/null | grep -q openclaw && FOUND=1
fi
if command -v bun >/dev/null 2>&1; then
  bun pm ls -g 2>/dev/null | grep -q openclaw && FOUND=1
fi
[[ -x "$HOME_DIR/.local/bin/openclaw" ]] && FOUND=1
[[ -n "${OPENCLAW_CONFIG_PATH:-}" ]] && [[ -e "$OPENCLAW_CONFIG_PATH" ]] && FOUND=1
if [[ "$FOUND" -eq 0 ]]; then
  log "complete" "already_clean" "" "info"
  echo "openclaw-remediation: result=success (already clean, nothing to remove)" >&2
  exit 0
fi

# ---- uninstall via official CLI if possible ----
# CLI stdout/stderr to separate file so SIEM log stays one-event-per-line
CLI_OUTPUT="${LOG_FILE}.cli_output"
if command -v openclaw >/dev/null 2>&1; then
  log "uninstall_cli" "openclaw uninstall --all --yes --non-interactive" ""
  if openclaw uninstall --all --yes --non-interactive >>"$CLI_OUTPUT" 2>&1; then
    log "uninstall_cli" "ok" ""
  else
    RESULT="partial"
    log "uninstall_cli" "failed_fallback_manual" ""
  fi
else
  if command -v npx >/dev/null 2>&1; then
    log "uninstall_cli" "npx -y openclaw uninstall" ""
    echo "openclaw-remediation: trying npx openclaw uninstall (may take a moment)..." >&2
    if npx -y openclaw uninstall --all --yes --non-interactive >>"$CLI_OUTPUT" 2>&1; then
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
  for plist in "$HOME_DIR"/Library/LaunchAgents/bot.molt.*.plist; do
    [[ -e "$plist" ]] || continue
    label="$(basename "$plist" .plist)"
    log "manual" "remove kind=service source=launchd label=$label" ""
    launchctl bootout "gui/$(id -u "$USER_NAME")/$label" >>"$LOG_FILE" 2>&1 || true
    rm -f "$plist" 2>>"$LOG_FILE" || true
    log "removed" "kind=service source=launchd label=$label" "ok" ""
  done

  # Legacy com.openclaw.*: bootout before removing plist so service is unloaded
  for plist in "$HOME_DIR"/Library/LaunchAgents/com.openclaw*.plist; do
    [[ -e "$plist" ]] || continue
    label="$(basename "$plist" .plist)"
    log "manual" "remove kind=service source=launchd label=$label" ""
    launchctl bootout "gui/$(id -u "$USER_NAME")/$label" >>"$LOG_FILE" 2>&1 || true
    rm -f "$plist" 2>>"$LOG_FILE" || true
    log "removed" "kind=service source=launchd label=$label" "ok" ""
  done

  # macOS app (per docs)
  if [[ -d "/Applications/OpenClaw.app" ]]; then
    log "manual" "remove kind=app path=/Applications/OpenClaw.app openclaw_version=$(siem_quote "${OPENCLAW_APP_VERSION:-unknown}")" ""
    rm -rf "/Applications/OpenClaw.app" 2>>"$LOG_FILE" || true
    log "removed" "kind=app path=/Applications/OpenClaw.app openclaw_version=$(siem_quote "${OPENCLAW_APP_VERSION:-unknown}")" "ok" ""
  fi

else
  if command -v systemctl >/dev/null 2>&1; then
    if [[ -e "$HOME_DIR/.config/systemd/user/openclaw-gateway.service" ]]; then
      log "manual" "remove kind=service source=systemd unit=openclaw-gateway.service" ""
      # shellcheck disable=SC2024
      sudo -u "$USER_NAME" systemctl --user disable --now openclaw-gateway.service >>"$LOG_FILE" 2>&1 || true
      rm -f "$HOME_DIR/.config/systemd/user/openclaw-gateway.service" 2>>"$LOG_FILE" || true
      log "removed" "kind=service source=systemd unit=openclaw-gateway.service" "ok" ""
    fi

    for unit in "$HOME_DIR"/.config/systemd/user/openclaw-gateway-*.service; do
      [[ -e "$unit" ]] || continue
      name="$(basename "$unit")"
      log "manual" "remove kind=service source=systemd unit=$name" ""
      # shellcheck disable=SC2024
      sudo -u "$USER_NAME" systemctl --user disable --now "$name" >>"$LOG_FILE" 2>&1 || true
      rm -f "$unit" 2>>"$LOG_FILE" || true
      log "removed" "kind=service source=systemd unit=$name" "ok" ""
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
    log "remove_state" "kind=state_dir path=$d" ""
    rm -rf "$d"
    log "removed" "kind=state_dir path=$d" "ok" ""
  fi
done

# ---- remove optional config path (per https://docs.openclaw.ai/install/uninstall) ----
if [[ -n "${OPENCLAW_CONFIG_PATH:-}" ]] && [[ -e "$OPENCLAW_CONFIG_PATH" ]]; then
  log "manual" "remove kind=config_path path=$OPENCLAW_CONFIG_PATH" ""
  rm -rf "$OPENCLAW_CONFIG_PATH" 2>>"$LOG_FILE" || true
  log "removed" "kind=config_path path=$OPENCLAW_CONFIG_PATH" "ok" ""
fi

# ---- remove git-install wrapper (install.sh --install-method git) ----
if [[ -x "$HOME_DIR/.local/bin/openclaw" ]]; then
  log "manual" "remove kind=cli source=git_wrapper path=$HOME_DIR/.local/bin/openclaw openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" ""
  rm -f "$HOME_DIR/.local/bin/openclaw" 2>>"$LOG_FILE" || true
  log "removed" "kind=cli source=git_wrapper path=$HOME_DIR/.local/bin/openclaw openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" "ok" ""
fi

# When running under sudo, npm/pnpm/bun global installs live in the invoking user's home (e.g. ~/.npm-global).
# Run package-manager uninstalls as that user so we remove the right install (CI and MDM).
RUN_AS_USER=()
if [[ -n "${SUDO_UID:-}" ]] && [[ -n "${SUDO_USER:-}" ]] && [[ "$(id -u)" -eq 0 ]]; then
  RUN_AS_USER=( sudo -u "$USER_NAME" env "HOME=$HOME_DIR" "PATH=$PATH" )
fi

# ---- remove global CLI (best-effort, per docs) ----
if command -v npm >/dev/null 2>&1; then
  log "cli_remove" "remove kind=cli source=npm openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" ""
  "${RUN_AS_USER[@]}" npm rm -g openclaw >>"$LOG_FILE" 2>&1 || true
  log "removed" "kind=cli source=npm openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" "ok" ""
fi
if command -v pnpm >/dev/null 2>&1; then
  log "cli_remove" "remove kind=cli source=pnpm openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" ""
  "${RUN_AS_USER[@]}" pnpm remove -g openclaw >>"$LOG_FILE" 2>&1 || true
  log "removed" "kind=cli source=pnpm openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" "ok" ""
fi
if command -v bun >/dev/null 2>&1; then
  log "cli_remove" "remove kind=cli source=bun openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" ""
  "${RUN_AS_USER[@]}" bun remove -g openclaw >>"$LOG_FILE" 2>&1 || true
  log "removed" "kind=cli source=bun openclaw_version=$(siem_quote "${OPENCLAW_CLI_VERSION:-unknown}")" "ok" ""
fi

SEV="info"; [[ "$RESULT" = "partial" ]] && SEV="warning"; [[ "$RESULT" = "failure" ]] && SEV="error"
log "complete" "" "$RESULT" "$SEV"

echo "openclaw-remediation: result=$RESULT (see $LOG_FILE)" >&2
if [[ "$RESULT" = "success" ]]; then
  exit 0
elif [[ "$RESULT" = "partial" ]]; then
  exit 1
else
  exit 2
fi
