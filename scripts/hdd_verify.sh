#!/usr/bin/env bash
set -u
ts() { date +"%F %T"; }

ROOT_SRC="$(findmnt -no SOURCE / || df -P / | awk 'NR==2{print $1}')"
ROOT_DEV="$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | sed 's#^#/dev/#')"
DEV="${ROOT_DEV:-/dev/sda}"

echo "$(ts) Root source: $ROOT_SRC  Root dev: $DEV"

ROTATIONALS="$(lsblk -d -o NAME,ROTA | awk '$2==1{print "/dev/"$1}' | xargs -r echo)"
echo "$(ts) Rotational disks: ${ROTATIONALS:-none}"

SCHED="$(cat /sys/block/$(basename "$DEV")/queue/scheduler 2>/dev/null || echo '?')"
RA="$(cat /sys/block/$(basename "$DEV")/queue/read_ahead_kb 2>/dev/null || echo '?')"
NR="$(cat /sys/block/$(basename "$DEV")/queue/nr_requests 2>/dev/null || echo '?')"
RQ="$(cat /sys/block/$(basename "$DEV")/queue/rq_affinity 2>/dev/null || echo '?')"
echo "$(ts) $DEV scheduler: $SCHED  | read_ahead_kb: $RA | nr_requests: $NR | rq_affinity: $RQ"

if command -v tlp-stat >/dev/null 2>&1; then
  echo "$(ts) TLP excerpt (APM/Link):"
  sudo tlp-stat -d 2>/dev/null | sed -n '1,160p' | grep -E 'Type|APM Level|Link|SATA|AHCI' -n || true
fi

LCC="$(sudo smartctl -A "$DEV" 2>/dev/null | awk '$1==193{print $10}' | tail -n1)"; LCC="${LCC:-NA}"
TEMP="$(sudo smartctl -A "$DEV" 2>/dev/null | awk '$1==190||$1==194{print $10}' | tail -n1)"
if [[ -z "$TEMP" ]]; then TEMP="$(sudo smartctl -l scttempsts "$DEV" 2>/dev/null | awk '/Current Temperature/{print $(NF-1)}' | tail -n1)"; fi
TEMP="${TEMP:-NA}"
echo "$(ts) SMART 193 Load_Cycle_Count: $LCC"
echo "$(ts) SMART Temperature: ${TEMP}°C"

mount | awk '$3=="/"{print "'"$(ts)"' Root mount:",$0}'
