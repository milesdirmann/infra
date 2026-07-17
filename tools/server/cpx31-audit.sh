#!/usr/bin/env bash
# Inventory the CPX31 before decommissioning. Run ON the CPX31:
#   bash cpx31-audit.sh > cpx31-inventory.txt
# Paste the output back to Claude to build the triage list (keep/archive/delete).
set -uo pipefail
section() { printf '\n===== %s =====\n' "$1"; }

section "Disk usage overview"
df -h /
section "Top-level usage (what is actually big)"
sudo du -xh --max-depth=2 / 2>/dev/null | sort -rh | head -30
section "Home directories"
sudo du -sh /home/* /root 2>/dev/null
section "Biggest individual files (>200MB)"
sudo find / -xdev -type f -size +200M -exec du -h {} + 2>/dev/null | sort -rh | head -20

section "Running services (non-default)"
systemctl list-units --type=service --state=running --no-pager --no-legend
section "Enabled services"
systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend
section "Listening ports"
sudo ss -tlnp | tail -n +2

section "Docker (if present)"
command -v docker >/dev/null && { docker ps -a; docker images; docker volume ls; } || echo "no docker"

section "Cron jobs"
for u in root $(ls /home); do echo "--- $u ---"; sudo crontab -l -u "$u" 2>/dev/null || echo "none"; done
ls /etc/cron.d/ 2>/dev/null

section "Installed-by-hand packages hint (apt manual)"
apt-mark showmanual 2>/dev/null | head -50

section "Git repos on disk (and whether they have unpushed work)"
sudo find /home /root /srv /opt -maxdepth 4 -name .git -type d 2>/dev/null | while read -r g; do
  repo="$(dirname "$g")"
  dirty="$(git -C "$repo" status --porcelain 2>/dev/null | wc -l)"
  unpushed="$(git -C "$repo" log --branches --not --remotes --oneline 2>/dev/null | wc -l)"
  echo "$repo  (uncommitted: $dirty, unpushed commits: $unpushed)"
done

section "Databases (if present)"
command -v psql >/dev/null && sudo -u postgres psql -lqt 2>/dev/null || echo "no postgres"
command -v mysql >/dev/null && mysql -e 'show databases;' 2>/dev/null || echo "no mysql"
ls /var/lib/redis 2>/dev/null || true
