#!/usr/bin/env bash
# install-on-server.sh -- run ON the CX33. Ensures the infra repo is present
# at /root/infra and tools are executable. Safe to re-run.
set -euo pipefail
if [ -d /root/infra/.git ]; then
  git -C /root/infra pull --ff-only
else
  git clone https://github.com/milesdirmann/infra.git /root/infra
fi
chmod +x /root/infra/tools/projects/*.sh /root/infra/tools/projects/lib/*.sh /root/infra/tools/projects/*.py
cp /root/infra/tools/server/rclone-backup.sh /usr/local/bin/rclone-backup.sh
chmod +x /usr/local/bin/rclone-backup.sh
install -D -m 644 /root/infra/tools/projects/templates/global-AGENTS.md /root/AGENTS.md
mkdir -p /root/.claude
[ -f /root/.claude/CLAUDE.md ] || printf 'This file routes. Follow /root/AGENTS.md.\n' > /root/.claude/CLAUDE.md
echo "installed. next backup run will scan and generate."
