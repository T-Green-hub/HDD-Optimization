#!/usr/bin/env bash
set -Eeuo pipefail

LOG_DIR="$HOME/.local/share/hdd-watch/logs"
mkdir -p "$LOG_DIR"
LOG_TXT="$LOG_DIR/lcc.log"
LOG_CSV="$LOG_DIR/lcc.csv"

ts() { date '+%F %T'; }

# Make sudo non-interactive and predictable for systemd --user
export SUDO_ASKPASS=/bin/false
export PATH="/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# Find rotational disks (skip loops, optical)
mapfile -t DISKS < <(lsblk -dno NAME,ROTA,TYPE | awk '$2==1 && $3=="disk"{print "/dev/"$1}' | grep -Ev '/dev/(loop|sr)')

if [[ ${#DISKS[@]} -eq 0 ]]; then
  echo "$(ts) WARN: No rotational disks found" | tee -a "$LOG_TXT"
  exit 0
fi

# Header for CSV if new
if [[ ! -s "$LOG_CSV" ]]; then
  echo "timestamp,device,lcc" > "$LOG_CSV"
fi

rc=0
for d in "${DISKS[@]}"; do
  if ! out=$(sudo -n /usr/sbin/smartctl -A "$d" 2>&1); then
    echo "$(ts) ERROR: smartctl failed for $d :: $out" | tee -a "$LOG_TXT"
    rc=1
    continue
  fi
  # Pick attribute 193 / Load_Cycle_Count
  lcc=$(awk '$1==193 || /Load[_ ]Cycle[_ ]Count/ {print $10; found=1} END{ if(!found) print "" }' <<<"$out")
  if [[ -z "${lcc:-}" ]]; then
    echo "$(ts) WARN: Unable to read LCC for $d" | tee -a "$LOG_TXT"
    rc=1
    continue
  fi
  echo "$(ts) $d LCC=$lcc" | tee -a "$LOG_TXT"
  echo "$(date -u +%FT%TZ),$d,$lcc" >> "$LOG_CSV"
done

exit $rc
