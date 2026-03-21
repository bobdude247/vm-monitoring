# Kali VM Crash Monitoring

This monitoring setup is focused on **post-freeze / post-reboot forensics** so you can inspect what happened before VS Code or the whole VM became unresponsive.

## What this installs

- Persistent `journalctl` logs across reboots
- `sysstat` (`sar`) snapshots every minute
- `atop` process/resource history logging
- Additional minute-by-minute `vmstat` + top process snapshots
- A report generator for after recovery

## 1) Install and configure

Run once:

```bash
sudo bash monitoring/setup-vm-monitoring.sh
```

Then reboot once:

```bash
sudo reboot
```

## 2) After a freeze or forced reboot

Generate a report:

```bash
sudo bash monitoring/post-recovery-report.sh
```

The report is saved under:

- `/var/log/vm-recovery-reports/`

## 3) High-value commands to inspect manually

- Previous boot warnings/errors:

  ```bash
  sudo journalctl -b -1 -p warning --no-pager | less
  ```

- OOM / lockup / reset indicators in previous boot:

  ```bash
  sudo journalctl -b -1 --no-pager | grep -Ei "oom|out of memory|lockup|watchdog|panic|reset|segfault"
  ```

- CPU/memory/load history:

  ```bash
  sudo sar -u -r -q -f /var/log/sysstat/sa$(date +%d)
  ```

- Replay process activity around incident times:

  ```bash
  sudo atop -r /var/log/atop/atop_$(date +%Y%m%d)
  ```

## 4) Where to look first when CPU pins at 100%

1. `journalctl -b -1` for OOM kills, lockups, I/O errors, GPU resets.
2. `atop` replay near freeze timestamp to identify the process/thread causing load.
3. `sar -q` and `sar -u` for run queue and CPU saturation trend.
4. `/var/log/vm-snapshots/*.log` for quick minute-by-minute top offenders.

## 5) Notes for VirtualBox stability tuning

If logs indicate sustained CPU starvation or memory pressure, likely fixes are:

- Increase VM RAM and reduce host memory contention.
- Use at least 2 vCPUs (but avoid overcommitting host cores).
- Ensure VT-x/AMD-V + nested paging are enabled in VirtualBox.
- Keep guest additions and VirtualBox version current.
- Disable unnecessary desktop effects/background services in the guest.

## 6) Incident reports in this project

- Crash monitoring check results (2026-03-21):
  - `monitoring/crash-monitoring-check-results-2026-03-21.md`
