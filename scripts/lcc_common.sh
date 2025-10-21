#!/usr/bin/env bash
# lcc_common.sh — shared helpers for HDD LCC logging
set -Eeuo pipefail

# --- Config (env-overridable) ---
: "${HDDO_STATE_DIR:="$HOME/.local/state/hdd-watch"}"
: "${HDDO_DATA_DIR:="$HOME/.local/share/hdd-watch"}"
: "${HDDO_LOG_DIR:="$HDDO_DATA_DIR/logs"}"
: "${HDDO_CSV_PATH:="$HDDO_LOG_DIR/lcc.csv"}"
: "${HDDO_DISKS:=""}"   # e.g. "/dev/sda /dev/sdb"; auto-detect if empty

ts_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

hddo_ensure_dirs() {
  mkdir -p "$HDDO_STATE_DIR" "$HDDO_DATA_DIR" "$HDDO_LOG_DIR"
}

hddo_require_tools() {
  command -v sudo >/dev/null || { echo "ERROR: sudo missing" >&2; return 127; }
  [ -x /usr/sbin/smartctl ] || { echo "ERROR: /usr/sbin/smartctl missing" >&2; return 127; }
}

# Discover rotational /dev/sdX disks when HDDO_DISKS is empty
hddo_discover_disks() {
  if [[ -n "${HDDO_DISKS:-}" ]]; then
    echo "$HDDO_DISKS"
    return
  fi
  while IFS= read -r name; do
    echo "/dev/$name"
  done < <(lsblk -ndo NAME,ROTA | awk '$2==1 && $1 ~ /^sd[a-z]+$/ {print $1}')
}

# Non-interactive sudo wrapper for smartctl (must be allowed in sudoers)
hddo_smart() {
  sudo -n /usr/sbin/smartctl "$@"
}

# Read Load_Cycle_Count (193) -> raw value or "NA"
hddo_read_lcc() {
  local dev="$1"
  local val
  val="$(hddo_smart -A "$dev" 2>/dev/null | awk '$1==193{print $10}' | tail -n1 || true)"
  [[ -n "$val" ]] && echo "$val" || echo "NA"
}

# Read temperature (tries 190, then 194, then SCT). Outputs "TEMP,SRC"
hddo_read_temp_csv() {
  local dev="$1" t src
  t="$(hddo_smart -A "$dev" 2>/dev/null | awk '$1==190{print $10}' | tail -n1 || true)"
  if [[ -n "$t" ]]; then echo "$t,190"; return; fi
  t="$(hddo_smart -A "$dev" 2>/dev/null | awk '$1==194{print $10}' | tail -n1 || true)"
  if [[ -n "$t" ]]; then echo "$t,194"; return; fi
  t="$(hddo_smart -l scttempsts "$dev" 2>/dev/null | awk '/Current Temperature/{print $(NF-1)}' | tail -n1 || true)"
  if [[ -n "$t" ]]; then echo "$t,sct"; return; fi
  echo "NA,NA"
}

hddo_csv_header_if_missing() {
  if [[ ! -s "$HDDO_CSV_PATH" ]]; then
    printf "timestamp_utc,disk,lcc,temp_c,temp_src\n" >> "$HDDO_CSV_PATH"
  fi
}

hddo_csv_append() {
  local ts="$1" dev="$2" lcc="$3" temp="$4" src="$5"
  hddo_csv_header_if_missing
  printf "%s,%s,%s,%s,%s\n" "$ts" "$dev" "$lcc" "$temp" "$src" >> "$HDDO_CSV_PATH"
}

hddo_log() {
  printf "%s %s\n" "$(date '+%F %T')" "$*" >&2
}
