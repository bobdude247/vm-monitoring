#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash monitoring/post-recovery-report.sh"
  exit 1
fi

OUT_DIR="/var/log/vm-recovery-reports"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/recovery-$(date +%F-%H%M%S).txt"

exec > >(tee -a "$OUT_FILE") 2>&1

echo "============================================================"
echo "VM Recovery Report - $(date --iso-8601=seconds)"
echo "Host: $(hostname)"
echo "Kernel: $(uname -r)"
echo "============================================================"
echo

echo "[1] Last boot times"
who -b || true
uptime || true
echo

echo "[2] Previous boot critical journal messages"
journalctl -b -1 -p warning --no-pager | tail -n 300 || true
echo

echo "[3] Previous boot OOM / hang / gpu / reset signals"
journalctl -b -1 --no-pager | grep -Ei "out of memory|oom-killer|killed process|soft lockup|hard lockup|watchdog|nmi|gpu|i915|amdgpu|nouveau|reset|segfault|panic" | tail -n 300 || true
echo

echo "[4] Sysstat CPU/RAM pressure around end of previous day"
YDAY="$(date -d 'yesterday' +%d)"
sar -u -r -q -f "/var/log/sysstat/sa${YDAY}" 2>/dev/null | tail -n 200 || true
echo

echo "[5] atop logs present"
ls -lh /var/log/atop 2>/dev/null || true
echo

echo "[6] Recent vmstat snapshots"
tail -n 400 /var/log/vm-snapshots/$(date +%F).log 2>/dev/null || true
echo

echo "[7] Disk, memory, load now"
free -h || true
df -h || true
vmstat 1 5 || true
echo

echo "Report saved to: $OUT_FILE"

