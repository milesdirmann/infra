#!/usr/bin/env bash
# VS Code setup audit — run this on your Mac, paste the output back for review.
# Usage: bash tools/vscode-audit.sh > vscode-audit.txt
set -uo pipefail

section() { printf '\n===== %s =====\n' "$1"; }

CODE_BIN="$(command -v code || command -v code-insiders || true)"
USER_DIR="$HOME/Library/Application Support/Code/User"
EXT_DIR="$HOME/.vscode/extensions"

section "VS Code version"
[ -n "$CODE_BIN" ] && "$CODE_BIN" --version || echo "code CLI not on PATH (Cmd+Shift+P -> 'Shell Command: Install code command in PATH')"

section "Installed extensions (with versions)"
[ -n "$CODE_BIN" ] && "$CODE_BIN" --list-extensions --show-versions || echo "skipped"

section "Extension disk usage (top 25)"
[ -d "$EXT_DIR" ] && du -sh "$EXT_DIR"/* 2>/dev/null | sort -rh | head -25 || echo "no extension dir found"

section "User settings.json"
[ -f "$USER_DIR/settings.json" ] && cat "$USER_DIR/settings.json" || echo "not found"

section "Keybindings (custom)"
[ -f "$USER_DIR/keybindings.json" ] && cat "$USER_DIR/keybindings.json" || echo "none"

section "SSH config (hosts only, no secrets)"
[ -f "$HOME/.ssh/config" ] && grep -iE '^\s*(Host|HostName|ControlMaster|ControlPersist|ServerAliveInterval|Compression|ForwardAgent|LocalForward)' "$HOME/.ssh/config" || echo "no ssh config"

section "Remote-SSH server installs (run on the VPS, not the Mac)"
echo "On the server: du -sh ~/.vscode-server 2>/dev/null; ls ~/.vscode-server/bin 2>/dev/null | wc -l"

section "Workspace storage size (stale workspace cache)"
du -sh "$USER_DIR/workspaceStorage" 2>/dev/null || echo "n/a"
du -sh "$HOME/Library/Application Support/Code/Cache" "$HOME/Library/Application Support/Code/CachedData" 2>/dev/null || true
