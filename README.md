# archlinux_configs

Portable, framework-free configs for **zsh**, **kitty**, and **vim** — working on
both Arch Linux and macOS. Install each **globally** where the OS allows,
per-user otherwise.

```sh
git clone https://github.com/lars76/archlinux_configs.git
cd archlinux_configs
```

Global = every user on the machine inherits it with no personal dotfile.
System files are read *before* the per-user ones, so a user can still override
(or opt out entirely with `unsetopt GLOBAL_RCS` in their `~/.zshenv`).

## zsh — `zshrc`

Single-file interactive config: OS detection, a fast prompt with an
outcome/duration/CPU footer, tuned history + completion caching, and integrations
(fzf, zoxide, direnv, uv, …) that activate **only if the tool is installed**.

| Target | Command |
| --- | --- |
| **Arch — global** (recommended) | `sudo cp zshrc /etc/zsh/zshrc && rm -f ~/.zshrc` |
| **macOS — global** (see caveat) | `sudo cp zshrc /etc/zshrc && rm -f ~/.zshrc` |
| **Per-user** (any OS, or override) | `cp zshrc ~/.zshrc` |

- **Secrets and machine-specific settings** go in `~/.zshrc.local` — sourced
  automatically, per user, never committed (e.g. `export HF_TOKEN=…`, extra
  `PATH`, `umask`).
- **macOS caveat:** a *major* macOS upgrade rewrites `/etc/zshrc`, wiping the
  global copy. Fine if you rarely upgrade; otherwise prefer the per-user install.
- **Optional tools** it lights up when present: `eza`/`exa`, `bat`, `fzf`,
  `zoxide`, `direnv`, `uv`, `fastfetch`, `zsh-autosuggestions`,
  `zsh-syntax-highlighting`, `zsh-history-substring-search`.

### Shared Homebrew on a multi-admin Mac

Homebrew officially supports only **single-user** installs. If two admin accounts
share one `/opt/homebrew`, the common (unofficial) workaround is to make the
prefix group-writable and have every user create files group-writable:

- Put `umask 002` in **each** account's `~/.zshrc.local` (new files become
  group-writable; this config sources that file automatically).
- One-time, fix the existing files:
  ```sh
  sudo chgrp -R admin /opt/homebrew
  sudo chmod -R g+rwX /opt/homebrew
  sudo find /opt/homebrew -type d -exec chmod g+s {} +   # new files inherit the group
  ```

Caveats: this is unsupported (a `brew` update or `brew doctor` may re-flag
permissions), and `admin` covers every admin user — a dedicated `brew` group is
tighter. The fully supported alternative is a **separate per-user Homebrew** per
account.

## kitty — `kitty.conf`

| Target | Command |
| --- | --- |
| **Global** (Linux & macOS) | `sudo install -Dm644 kitty.conf /etc/xdg/kitty/kitty.conf` |
| **Per-user** | `install -Dm644 kitty.conf ~/.config/kitty/kitty.conf` |

Requires the **JetBrains Mono** font.

## vim — `vimrc`

| Target | Command |
| --- | --- |
| **Linux — global** | `sudo cp vimrc /etc/vimrc` (confirm the path with `vim --version \| grep vimrc`) |
| **Per-user** (required on macOS) | `cp vimrc ~/.vimrc` |

macOS can't do global vim: Apple's `vim` reads a SIP-protected, read-only system
`vimrc` and ignores `/etc/vimrc`, so use the per-user install there.

Plugins auto-install on first launch via
[vim-plug](https://github.com/junegunn/vim-plug) into `~/.vim` (per user; needs
`curl` + network). Fuzzy-find (`<leader>ff` / `fb` / `fg`) needs `fzf` +
`ripgrep`.

## Updating

A global copy is a snapshot, not a live link — after pulling, re-copy whatever
you installed globally:

```sh
git pull
sudo cp zshrc /etc/zsh/zshrc      # (and any other file you placed globally)
```
