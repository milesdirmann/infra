# tmux on the CX33

Base: oh-my-tmux (gpakosz/.tmux), installed during hardening. Config lives in
`~/.tmux.conf.local`. Chosen because it is the most popular, best-maintained
tmux base and integrates TPM natively.

## Plugins (via TPM, in .tmux.conf.local)

- `tmux-resurrect` save/restore full session state (windows, panes, dirs).
- `tmux-continuum` auto-saves every 15 min and auto-restores on server boot,
  so agent sessions survive a reboot, not just a disconnect.

Settings:
    set -g @continuum-restore 'on'
    set -g @continuum-save-interval '15'
    set -g @resurrect-capture-pane-contents 'on'

## Font-independent status bar

Powerline arrow separators replaced with blanks
(`tmux_conf_theme_*_separator_main=' '`) so the status bar renders identically
on the Mac terminal and in Secure ShellFish on the phone, with no Nerd Font
dependency.

## Session helpers (in ~/.bashrc, interactive shells only)

- `tmux`         attach to the active session, or create 'main' if none.
- `tmux <name>`  attach to that session, or create it (via `new -A -s`).
- `tmux ls` etc. real subcommands pass straight through.
- `p <name>`     open/resume a project session: named tmux, cd'd into
                 /root/projects/<name>, ready for `claude`. Tab-completes.
