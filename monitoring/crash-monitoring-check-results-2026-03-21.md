# Crash Monitoring Check Results (2026-03-21)

## Task completed

Monitoring data was checked and useful signals were found.

## Findings

- The monitoring stack is present and writing data:
  - snapshots in `/var/log/vm-snapshots`
  - process history in `/var/log/atop`
  - sysstat data in `/var/log/sysstat`
- Previous boot timing:
  - previous boot: `12:32:09` to `13:53:02`
  - next boot started: `13:54:05`
  - interpretation: timing is consistent with abrupt power-off/reset rather than a normal shutdown.
- No kernel-level crash signatures were found in previous-boot journal for the monitored pattern set:
  - no OOM kill
  - no soft/hard lockup
  - no panic
  - no watchdog reset
  - no segfault indicators
- Minute snapshots near the end showed the VM mostly idle overall, with memory pressure/swap activity but not CPU saturation:
  - swap in use around `330 MB`
  - free memory roughly `67–84 MB` in sampled windows
  - CPU mostly idle in captured windows
  - largest memory consumers were multiple VS Code processes
- One notable warning in previous-boot logs:
  - repeated `vmwgfx unsupported-hypervisor` errors, which may correlate with display stack instability in VirtualBox setups.

## Interpretation

The evidence points to an external forced stop (matching the described behavior) with no clear in-guest kernel panic/OOM trigger captured before the stop.

There is mild-to-moderate memory pressure and persistent graphics-driver warnings that are more suspicious than CPU overload.

## Relevant project scripts

- Report generator: `monitoring/post-recovery-report.sh`
- Setup and manual checks: `monitoring/README.md`

## Recommended next actions

1. Run the full root report to save a forensic bundle:

   ```bash
   sudo bash monitoring/post-recovery-report.sh
   ```

2. In VirtualBox, switch graphics controller/settings to a known stable Kali-compatible combination and retest (`vmwgfx` warning is the main red flag observed).

3. If lockups repeat, compare:
   - newest snapshot tail
   - previous-boot journal window immediately before freeze time
   to capture the next precursor event.

