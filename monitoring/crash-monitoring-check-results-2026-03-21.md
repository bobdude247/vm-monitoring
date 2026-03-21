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

## Incident follow-up: VS Code lockup + return to login screen (conversation log)

### User-reported symptom

- VS Code became unresponsive and was about to show a force-shutdown message.
- Before that dialog fully completed, Kali returned to the login screen and the desktop session restarted.

### Investigation steps performed

1. Reviewed login/session history with `last -x` to confirm session transitions.
2. Inspected previous-boot journal errors and the end-of-boot timeline.
3. Inspected current-boot logs around the incident window (`14:53:30` to `14:55:30`).
4. Searched specifically for OOM/panic/segfault/watchdog/GPU reset indicators.
5. Checked Xorg logs (`/var/log/Xorg.0.log` and `.old`) for display-stack errors.

### Key evidence captured

- `lightdm` closed the active user session around `14:54:31`.
- `systemd-logind` recorded logout immediately after (`Session 3 logged out`).
- VirtualBox guest graphics components logged multiple fatal X-window-related errors:
  - `VBoxClient VMSVGA: Error: A fatal guest X Window error occurred`
  - related SHCLX11 / seamless / drag-and-drop IPC broken-pipe messages
- XFCE user services failed right after X teardown:
  - `xfce4-notifyd.service: Failed with result 'exit-code'`
  - `xdg-desktop-portal-gtk.service: Failed with result 'exit-code'`
- `lightdm` then created a greeter and a new user X11 session around `14:55:15`.

### Negative findings (what was *not* seen)

- No kernel panic in the incident window.
- No OOM-killer event in the incident window.
- No watchdog-triggered reboot/reset signature.
- No evidence of full OS reboot at that exact event; behavior matches X/desktop session reset.

### Likely root cause

The event is most consistent with a **GUI/X session crash-reset caused by virtual graphics stack instability** (VirtualBox VMSVGA/X11 path), rather than a VS Code-only failure or full-kernel crash.

### Practical mitigations recorded

1. Ensure VirtualBox Guest Additions and host VirtualBox versions are matched.
2. Test VM display settings for stability (graphics controller mode and 3D acceleration on/off).
3. Increase VM video memory and provide slightly more RAM/CPU headroom if currently constrained.
4. Keep autosave and versioned backups enabled to reduce disruption from session resets.
