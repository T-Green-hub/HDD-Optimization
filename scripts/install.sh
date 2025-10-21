#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/projects/hdd-optimizer"
USR="$HOME/.config/systemd/user"

# Ensure runtime dirs
mkdir -p "$HOME/.local/share/hdd-watch" "$HOME/.local/share/hdd-watch/logs"

# Install units
mkdir -p "$USR"
install -m 0644 "$REPO/systemd/hdd-lcc-logger.service" "$USR/hdd-lcc-logger.service"
install -m 0644 "$REPO/systemd/hdd-lcc-logger.timer"   "$USR/hdd-lcc-logger.timer"
install -m 0644 "$REPO/systemd/hdd-lcc-alert.service"  "$USR/hdd-lcc-alert.service"
install -m 0644 "$REPO/systemd/hdd-lcc-alert.timer"    "$USR/hdd-lcc-alert.timer"

# Reload and enable
systemctl --user daemon-reload
systemctl --user enable --now hdd-lcc-logger.timer
systemctl --user enable --now hdd-lcc-alert.timer

echo "== Enabled timers =="
systemctl --user list-timers | grep -E 'hdd-lcc-(logger|alert)' || true
