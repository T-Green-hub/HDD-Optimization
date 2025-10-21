#!/usr/bin/env bash
set -u
DEV="${1:-}"
if [[ -z "$DEV" ]]; then
  ROOT_SRC="$(findmnt -no SOURCE / || df -P / | awk 'NR==2{print $1}')"
  ROOT_DEV="$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | sed 's#^#/dev/#')"
  DEV="${ROOT_DEV:-/dev/sda}"
fi
echo "Watching $DEV  (Ctrl+C to quit)"
while :; do
  LCC="$(sudo smartctl -A "$DEV" 2>/dev/null | awk '$1==193{print $10}' | tail -n1)"
  TEMP="$(sudo smartctl -A "$DEV" 2>/dev/null | awk '$1==190||$1==194{print $10}' | tail -n1)"
  if [[ -z "$TEMP" ]]; then TEMP="$(sudo smartctl -l scttempsts "$DEV" 2>/dev/null | awk '/Current Temperature/{print $(NF-1)}' | tail -n1)"; fi
  echo "$(date +'%F %T')  LCC: ${LCC:-NA}  Temp: ${TEMP:-NA}°C"
  sleep 10
done
