# Migration: retire CPX31 (Hillsboro) → CX33 (Helsinki) + cold-storage

Goal: CPX31 becomes unnecessary. Everything vital lives on the CX33's NVMe,
everything cold lives on the Storage Box, junk gets deleted with the server.

## Routing policy (the one rule)

| Data | Destination |
|---|---|
| Active code, running services, dotfiles/tmux config | CX33 (`89.167.110.196`) |
| Archives, old projects, large assets, DB dumps, backups | Storage Box (`u634219.your-storagebox.de:23`) |
| Caches, node_modules, build artifacts, distro packages | Nowhere — delete with the server |
| Heavy one-off compute | Modal (not a storage location) |

## Order of operations

1. **Inventory** — on the CPX31: `bash cpx31-audit.sh > cpx31-inventory.txt`.
   Review it (or paste to Claude). Two things block everything else:
   uncommitted/unpushed git work and databases — those must be
   pushed/dumped before any copying.

2. **Safety snapshot** — Hetzner console → CPX31 → Snapshots → take one.
   Costs cents, means a wrong `rm` during migration is recoverable.
   Delete the snapshot after the CX33 has run cleanly for a couple of weeks.

3. **Copy vital → CX33** (run from the CPX31; -z compresses for the
   transatlantic hop):
   ```bash
   rsync -avzP --exclude node_modules --exclude .venv --exclude target \
     ~/projects/ root@89.167.110.196:/root/projects/
   rsync -avzP ~/.ssh/authorized_keys ~/.tmux.conf* ~/.gitconfig root@89.167.110.196:/root/
   ```

4. **Copy cold → Storage Box** (from the CPX31):
   ```bash
   rclone copy ~/archives sbox:archive/cpx31/archives --transfers 4 -P
   # DB dumps, old assets, anything from the inventory marked "keep but cold"
   ```

5. **Re-point everything at the CX33**: Mountain Duck bookmark, VS Code
   Remote-SSH host, `VPS_HOST` in tools/mac/mount-hetzner.sh, any DNS records
   pointing at 5.78.108.176, and install `tools/server/hetzner-backup.*`
   on the CX33 so the hourly mirror runs there.

6. **Cool-off week**: work only from the CX33. If nothing sends you back to
   the old box, it wasn't needed.

7. **Decommission**: console → CPX31 → Delete. Billing stops immediately
   (final invoice is prorated hours). Keep the snapshot per step 2.

## CX33 first-boot hardening (10 min, do before copying data in)

```bash
apt update && apt upgrade -y
apt install -y rclone tmux git ufw fail2ban
ufw allow OpenSSH && ufw enable
# swap: cheap insurance even with 8GB
fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
# oh-my-tmux
git clone --single-branch https://github.com/gpakosz/.tmux.git ~/.tmux
ln -s -f ~/.tmux/.tmux.conf ~/ && cp ~/.tmux/.tmux.conf.local ~/
# storage box remote + hourly backup timer (see tools/server/rclone-backup.sh)
```
