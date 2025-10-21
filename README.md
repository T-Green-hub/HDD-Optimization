# HDD Optimizer — LCC Weekly Logger (Linux Mint / Ubuntu)

[![CI](https://github.com/T-Green-hub/HDD-Optimization/actions/workflows/ci.yml/badge.svg)](https://github.com/T-Green-hub/HDD-Optimization/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/T-Green-hub/HDD-Optimization?color=blue)](https://github.com/T-Green-hub/HDD-Optimization/releases)

A **low-noise, systemd-user HDD Load Cycle Count (LCC) logger** built for Linux Mint / Ubuntu systems.  
It monitors hard drives prone to excessive head parking by logging SMART data and helps verify APM/TLP tuning effectiveness over time.

---

## 🧩 Components

| Type | Path | Description |
|------|------|-------------|
| **Script** | `scripts/lcc_log_once.sh` | Reads SMART attribute 193 (Load Cycle Count) via `smartctl` |
| **CSV Log** | `~/.local/share/hdd-watch/logs/lcc.csv` | Time-stamped historical record |
| **Systemd Service** | `~/.config/systemd/user/hdd-lcc-logger.service` | Executes logger once per trigger |
| **Timer** | `~/.config/systemd/user/hdd-lcc-logger.timer` | Runs **weekly (Sun 09:00)** |

---

## 💡 Why

Aggressive head parking (from factory APM defaults) can quickly wear mechanical drives.  
This logger quietly tracks your disk’s **Load Cycle Count** to confirm that APM and spindown settings are stable and non-destructive.

---

## ⚙️ Install (user mode)

```bash
# Ensure the logger script is executable
chmod +x "$HOME/projects/hdd-optimizer/scripts/lcc_log_once.sh"

# Reload and enable user units
systemctl --user daemon-reload
systemctl --user enable --now hdd-lcc-logger.timer

# Verify timer status
systemctl --user list-timers | grep hdd-lcc-logger
