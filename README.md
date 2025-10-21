# HDD Optimizer — LCC Weekly Logger (Linux Mint / Ubuntu)

This repository provides a **low-noise, systemd-user HDD Load Cycle Count (LCC) logger** for Linux Mint or Ubuntu.  
It helps monitor hard drives that suffer from excessive head-parking by logging **LCC and temperature** weekly.

---

## 🧩 Components
- **Script:** `scripts/lcc_log_once.sh`
- **CSV Log:** `~/.local/share/hdd-watch/logs/lcc.csv`
- **Systemd Service:** `~/.config/systemd/user/hdd-lcc-logger.service`
- **Timer:** runs **weekly on Sundays at 09:00**

---

## 💡 Why
Aggressive head parking (often caused by default APM values) can drastically increase the **Load Cycle Count (LCC)**, wearing out HDDs faster.  
This logger tracks changes silently, giving you data to confirm if APM and spindown settings are safe.

---

## ⚙️ Install (user mode)

```bash
# Ensure executable
chmod +x "$HOME/projects/hdd-optimizer/scripts/lcc_log_once.sh"

# Reload and enable user units
systemctl --user daemon-reload
systemctl --user enable --now hdd-lcc-logger.timer

# Verify timer status
systemctl --user list-timers | grep hdd-lcc-logger
