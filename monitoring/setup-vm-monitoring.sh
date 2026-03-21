#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash monitoring/setup-vm-monitoring.sh"
  exit 1
fi

echo "[1/7] Installing monitoring packages..."
apt-get update
apt-get install -y sysstat atop iotop procps psmisc

echo "[2/7] Enabling persistent journald storage..."
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/persistent.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=750M
RuntimeMaxUse=200M
RateLimitIntervalSec=30s
RateLimitBurst=2000
Compress=yes
EOF

mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal || true
systemctl restart systemd-journald

echo "[3/7] Enabling sysstat collection every minute..."
if grep -q '^ENABLED="false"' /etc/default/sysstat; then
  sed -i 's/^ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
fi

cat > /etc/cron.d/sysstat <<'EOF'
# Collect system activity each minute for crash forensics
* * * * * root command -v debian-sa1 > /dev/null && debian-sa1 1 1
53 23 * * * root command -v debian-sa1 > /dev/null && debian-sa1 --rotate
EOF

systemctl enable --now sysstat

echo "[4/7] Increasing atop sampling and retention..."
if [[ -f /etc/default/atop ]]; then
  sed -i 's/^LOGINTERVAL=.*/LOGINTERVAL=30/' /etc/default/atop || true
  sed -i 's/^LOGGENERATIONS=.*/LOGGENERATIONS=21/' /etc/default/atop || true
  sed -i 's/^LOGPATH=.*/LOGPATH=\/var\/log\/atop/' /etc/default/atop || true
fi

systemctl enable --now atop
systemctl restart atop

echo "[5/7] Enabling vmstat snapshot logger..."
install -d -m 0755 /usr/local/sbin
cat > /usr/local/sbin/vmstat-snapshot.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
LOG_DIR="/var/log/vm-snapshots"
mkdir -p "$LOG_DIR"
STAMP="$(date '+%F %T %z')"
OUT="$LOG_DIR/$(date +%F).log"
{
  echo "=== $STAMP ==="
  echo "--- vmstat 1 5 ---"
  vmstat 1 5
  echo "--- top cpu consumers ---"
  ps -eo pid,ppid,comm,%cpu,%mem,rss,vsz,state --sort=-%cpu | head -n 20
  echo "--- top memory consumers ---"
  ps -eo pid,ppid,comm,%mem,%cpu,rss,vsz,state --sort=-%mem | head -n 20
  echo
} >> "$OUT"
EOF
chmod +x /usr/local/sbin/vmstat-snapshot.sh

cat > /etc/systemd/system/vmstat-snapshot.service <<'EOF'
[Unit]
Description=Periodic vmstat and process snapshot

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/vmstat-snapshot.sh
EOF

cat > /etc/systemd/system/vmstat-snapshot.timer <<'EOF'
[Unit]
Description=Run vmstat snapshot every minute

[Timer]
OnBootSec=45s
OnUnitActiveSec=60s
AccuracySec=10s
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now vmstat-snapshot.timer

echo "[6/7] Adding boot diagnostic marker service..."
cat > /etc/systemd/system/boot-diagnostics.service <<'EOF'
[Unit]
Description=Capture quick boot diagnostics for post-crash analysis
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -lc 'echo "=== boot $(date --iso-8601=seconds) ===" >> /var/log/boot-diagnostics.log; uptime >> /var/log/boot-diagnostics.log; free -h >> /var/log/boot-diagnostics.log; lsblk >> /var/log/boot-diagnostics.log; echo >> /var/log/boot-diagnostics.log'

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now boot-diagnostics.service

echo "[7/7] Status summary"
echo
systemctl --no-pager --full status systemd-journald | sed -n '1,8p'
systemctl --no-pager --full status sysstat | sed -n '1,8p'
systemctl --no-pager --full status atop | sed -n '1,8p'
systemctl --no-pager --full status vmstat-snapshot.timer | sed -n '1,12p'

cat <<'EOF'

Setup complete.

Next steps:
1) Reboot once: sudo reboot
2) After any freeze/recovery, run:
   sudo bash monitoring/post-recovery-report.sh
EOF

