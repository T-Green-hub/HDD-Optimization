#!/usr/bin/env bash
# HDD optimizer — applies safe queuing, BFQ, read_ahead, and TLP SATA link policy.
# Includes a quick LCC stability check. Idempotent and chatty.

set -euo pipefail

QUIET=${QUIET:-0}
QUICK_TEST_SECS=${QUICK_TEST_SECS:-30}

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" ; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    log "Re-exec with sudo"
    exec sudo -E -- "$0" "$@"
  fi
}

main() {
  log "Starting HDD optimization (final)"
  require_root

  # 1) Ensure deps
  log "Checking packages: smartmontools tlp"
  if ! dpkg -s smartmontools tlp >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y smartmontools tlp
  fi
  log "All required packages already present."

  # 2) Detect rotational block devices (whole disks), exclude loop/sr
  mapfile -t ROT_DISKS < <(lsblk -ndo NAME,ROTA,TYPE | awk '$2==1 && $3=="disk"{print "/dev/"$1}' | grep -vE '^/dev/loop|^/dev/sr')
  if (( ${#ROT_DISKS[@]} == 0 )); then
    log "WARN: No rotational disks found; nothing to tune."
    exit 0
  fi
  log "Detected rotational disks: ${ROT_DISKS[*]}"

  # 3) Udev queue tuning rule
  local UDEV_RULE=/etc/udev/rules.d/99-queue-tuning.rules
  if [[ -f "$UDEV_RULE" ]]; then
    cp -a "$UDEV_RULE" "${UDEV_RULE}.bak.$(date +%s)"
    log "Backup: $UDEV_RULE -> ${UDEV_RULE}.bak.$(date +%s)"
  fi
  cat > "$UDEV_RULE" <<'EOF'
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="128"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
  udevadm control --reload
  udevadm trigger --subsystem-match=block
  log "Applied udev queue tuning and triggered reload."

  # 4) TLP SATA link policy (keeps drive awake enough to stop aggressive LCC)
  local TLP_DIR=/etc/tlp.d
  local TLP_FILE=$TLP_DIR/60-sata-link.conf
  mkdir -p "$TLP_DIR"
  if [[ -f "$TLP_FILE" ]]; then
    cp -a "$TLP_FILE" "${TLP_FILE}.bak.$(date +%s)"
    log "Backup: $TLP_FILE -> ${TLP_FILE}.bak.$(date +%s)"
  fi
  cat > "$TLP_FILE" <<'EOF'
# Keep SATA link in max/perf states on AC and tame on battery (but not too low)
DISK_DEVICES="sd*"
SATA_LINKPWR_ON_AC="max_performance"
SATA_LINKPWR_ON_BAT="medium_power"
NMI_WATCHDOG=0
EOF
  systemctl restart tlp.service || true
  log "TLP settings applied and service restarted."

  # 5) Show current scheduler + read_ahead for visibility
  for d in "${ROT_DISKS[@]}"; do
    base=$(basename "$d")
    sched="/sys/block/$base/queue/scheduler"
    ra="/sys/block/$base/queue/read_ahead_kb"
    [[ -e "$sched" ]] && log "$d scheduler: $(cat "$sched")"
    [[ -e "$ra" ]] && log "$d read_ahead_kb: $(cat "$ra")"
  done

  # 6) Quick LCC stability check on the first real HDD found
  local ROOT_DEV=""
  for d in "${ROT_DISKS[@]}"; do
    ROOT_DEV="$d"; break
  done

  if command -v smartctl >/dev/null 2>&1; then
    before=$(smartctl -A "$ROOT_DEV" 2>/dev/null | awk '$1==193{print $10}')
    if [[ -z "${before:-}" ]]; then
      # try common fallbacks
      before=$(smartctl -d auto -A "$ROOT_DEV" 2>/dev/null | awk '$1==193{print $10}')
    fi
    if [[ -n "${before:-}" ]]; then
      log "LCC before: $before"
      log "Sleeping ${QUICK_TEST_SECS}s for quick LCC recheck..."
      sleep "$QUICK_TEST_SECS" >/dev/null 2>&1
      after=$(smartctl -A "$ROOT_DEV" 2>/dev/null | awk '$1==193{print $10}')
      [[ -z "${after:-}" ]] && after=$(smartctl -d auto -A "$ROOT_DEV" 2>/dev/null | awk '$1==193{print $10}')
      if [[ -n "${after:-}" ]]; then
        log "LCC after : $after"
      else
        log "WARN: Could not read LCC after wait."
      fi
    else
      log "WARN: Could not read LCC before wait (attribute 193)."
    fi
  else
    log "WARN: smartctl not found; skipping LCC recheck."
  fi

  log "Done. If LCC stays the same during light idle, the tuning is working."
  log "Tip: for a longer check, re-run with QUICK_TEST_SECS=120 (or higher)."
}

main "$@"
