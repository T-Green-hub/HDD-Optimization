#!/usr/bin/env bash
# Alert if Load_Cycle_Count jumps faster than expected.
# Safe to run from systemd even when CSV has <2 rows. Always exit 0.
set -u

CSV="$HOME/.local/share/hdd-watch/lcc_history.csv"
ALOG="$HOME/.local/share/hdd-watch/logs/alerts.log"
mkdir -p "$(dirname "$ALOG")"

ts_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "$(ts_utc) $*" >>"$ALOG"; }

THRESHOLD_DELTA="${LCC_ALERT_DELTA:-10}"   # e.g., alert if +10 cycles since last sample
THRESHOLD_RATE="${LCC_ALERT_RATE:-120}"    # optional: cycles/hour

if [[ ! -s "$CSV" ]] || [[ "$(wc -l < "$CSV")" -lt 3 ]]; then
  log "[INFO] Not enough samples yet for alert logic."
  exit 0
fi

# Read last two data rows (skip header)
read -r ts2 lcc2 temp2 dev2 src2 < <(tail -n1 "$CSV" | awk -F, 'NR>0{print $1,$2,$3,$4,$5}')
read -r ts1 lcc1 temp1 dev1 src1 < <(tail -n2 "$CSV" | head -n1 | awk -F, 'NR>0{print $1,$2,$3,$4,$5}')

# If any NA, skip noisy alerts
if [[ "$lcc1" == "NA" || "$lcc2" == "NA" ]]; then
  log "[WARN] NA LCC values; skipping."
  exit 0
fi

delta=$(( lcc2 - lcc1 ))
if (( delta < 0 )); then
  log "[WARN] LCC decreased (counter reset?) delta=$delta; skipping."
  exit 0
fi

# Compute rate per hour if timestamps parse
rate_val="NA"
t1="$(date -u -d "$ts1" +%s 2>/dev/null || echo "")"
t2="$(date -u -d "$ts2" +%s 2>/dev/null || echo "")"
if [[ -n "$t1" && -n "$t2" && "$t2" -gt "$t1" ]]; then
  secs=$(( t2 - t1 ))
  if (( secs > 0 )); then
    rate_val=$(awk -v d="$delta" -v s="$secs" 'BEGIN{printf "%.2f", (d*3600)/s}')
  fi
fi

if (( delta >= THRESHOLD_DELTA )); then
  MSG="HDD LCC jumped by +$delta (last: $lcc1 → now: $lcc2). Temp: ${temp2:-NA}°C. Dev: $dev2."
  log "[ALERT] $MSG (rate/hr=${rate_val})"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "HDD LCC Alert" "$MSG"
  fi
  exit 0
fi

# Optional rate-based alert
if [[ "$rate_val" != "NA" ]]; then
  rate_int="${rate_val%.*}"
  if (( rate_int >= THRESHOLD_RATE )); then
    MSG="HDD LCC rate high: ~${rate_val}/hr (Δ=$delta). Temp: ${temp2:-NA}°C. Dev: $dev2."
    log "[ALERT] $MSG"
    if command -v notify-send >/dev/null 2>/dev/null; then
      notify-send "HDD LCC Rate Alert" "$MSG"
    fi
    exit 0
  fi
fi

log "[OK] LCC Δ=$delta; no alert. (rate/hr=${rate_val})"
exit 0
