#!/usr/bin/env bash
set -euo pipefail

USR="$HOME/.config/systemd/user"

systemctl --user disable --now hdd-lcc-logger.timer hdd-lcc-logger.service 2>/dev/null || true
systemctl --user disable --now hdd-lcc-alert.timer  hdd-lcc-alert.service  2>/dev/null || true

rm -f "$USR/hdd-lcc-logger.timer" "$USR/hdd-lcc-logger.service" \
      "$USR/hdd-lcc-alert.timer"  "$USR/hdd-lcc-alert.service"

systemctl --user daemon-reload
echo "Uninstalled units (data preserved in ~/.local/share/hdd-watch)."
