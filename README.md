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

## Dependencies

All optional — detected at runtime; the config works without them.

| Tool | Enables | macOS | Arch |
| --- | --- | --- | --- |
| JetBrains Mono | kitty font | `brew install --cask font-jetbrains-mono` | `yay -S ttf-jetbrains-mono` |
| vivid | catppuccin `ls`/completion colours¹ | `brew install vivid` | `yay -S vivid` |
| zsh-autosuggestions | inline suggestions | `brew install zsh-autosuggestions` | `yay -S zsh-autosuggestions` |
| zsh-syntax-highlighting | syntax colours | `brew install zsh-syntax-highlighting` | `yay -S zsh-syntax-highlighting` |
| zsh-history-substring-search | ↑/↓ substring search | `brew install zsh-history-substring-search` | `yay -S zsh-history-substring-search` |
| atuin | `Ctrl+R` history search² (dates, dirs, exit codes) | `brew install atuin` | `yay -S atuin` |
| eza | better `ls` | `brew install eza` | `yay -S eza` |
| bat | better `cat` | `brew install bat` | `yay -S bat` |
| ripgrep | `rg`, vim `:Rg` | `brew install ripgrep` | `yay -S ripgrep` |
| fzf | fuzzy history/files | `brew install fzf` | `yay -S fzf` |
| zoxide | smart `cd` | `brew install zoxide` | `yay -S zoxide` |
| direnv | per-directory envs | `brew install direnv` | `yay -S direnv` |
| uv | Python + completions | `brew install uv` | `yay -S uv` |
| fastfetch | welcome screen | `brew install fastfetch` | `yay -S fastfetch` |

¹ Catppuccin colours need a **true-colour** terminal (kitty ✓; Terminal.app → ANSI). vim also needs `curl` + network for its first-launch plugin bootstrap.
² atuin is optional; for the matching Catppuccin theme run the one-time setup below.

Everything at once:

```sh
# macOS
brew install vivid eza bat ripgrep fzf zoxide direnv uv fastfetch atuin zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search && brew install --cask font-jetbrains-mono
# Arch
yay -S vivid eza bat ripgrep fzf zoxide direnv uv fastfetch atuin zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search ttf-jetbrains-mono
```

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
- **Colour scheme:** Catppuccin Mocha — syntax highlighting, autosuggestions, the
  completion menu, and (with `vivid`) file colours, matching kitty + vim. Applied
  only on true-colour terminals; others fall back to plain ANSI.
- **History search:** if `atuin` is installed, **`Ctrl+R`** opens a SQLite-backed
  search UI showing each command's time, directory and exit code; it also feeds the
  inline autosuggestion. `↑`/`↓` stay on the built-in prefix search. Guarded — no
  atuin, no change. One-time setup for the matching theme:
  ```sh
  mkdir -p ~/.config/atuin/themes && curl -fsSL https://raw.githubusercontent.com/catppuccin/atuin/main/themes/mocha/catppuccin-mocha-mauve.toml -o ~/.config/atuin/themes/catppuccin-mocha-mauve.toml && { grep -qxF '[theme]' ~/.config/atuin/config.toml 2>/dev/null || printf '\n[theme]\nname = "catppuccin-mocha-mauve"\n' >> ~/.config/atuin/config.toml; } && atuin import auto
  ```
- **Tools it detects and lights up** are listed under [Dependencies](#dependencies).

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
| **Global** (Linux & macOS) | `sudo mkdir -p /etc/xdg/kitty && sudo cp kitty.conf /etc/xdg/kitty/kitty.conf` |
| **Per-user** | `mkdir -p ~/.config/kitty && cp kitty.conf ~/.config/kitty/kitty.conf` |

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

## Claude Code — `claude/`

Per-user only; Claude Code reads `~/.claude` and has no global config path.

```sh
mkdir -p ~/.claude
cp claude/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
sed "s|__HOME__|$HOME|" claude/settings.json > ~/.claude/settings.json
```

`settings.json` carries preferences only — model, effort level, permission mode,
the two LSP plugins, and the status line. The `__HOME__` placeholder is the one
path that has to be rewritten at install time, hence the `sed`.

- **`statusline.sh`** prints the status line Claude Code shows under the prompt:
  working directory, context usage, and the 5-hour and weekly rate limits, each
  with a bar and its reset time. A `runs out` column appears on a limit only when
  the current burn rate would exhaust that budget before it resets, so its
  presence is the warning — yellow when the shortfall is under a tenth of the
  window, red beyond that. Written in zsh; the only dependency is `jq`
  (`yay -S jq` / `brew install jq`). Times come from zsh's own `strftime`
  builtin rather than `date`, which avoids the GNU/BSD split, so the same file
  runs unmodified on Arch and macOS. It forks exactly one process per refresh.
- **Plugins** (`pyright-lsp`, `clangd-lsp`) reinstall themselves on first run
  from Anthropic's built-in marketplace — nothing to copy. They need `pyright`
  and `clangd` on the system to do anything.
- **Not committed, deliberately:** `~/.claude/.credentials.json` (OAuth tokens)
  and `~/.claude.json` (machine state, MCP auth). Everything else under
  `~/.claude` — session transcripts, caches, plugin payloads, per-project
  memory — is machine-local and regenerable.
- **Machine-specific permission grants** accumulate in
  `~/.claude/settings.local.json`, which stays local, same idea as
  `~/.zshrc.local`. Promote a rule to the committed `settings.json` only when
  it is genuinely reusable across machines.

## Updating

A global copy is a snapshot, not a live link — after pulling, re-copy whatever
you installed globally (use the same paths you chose above):

```sh
git pull
sudo cp zshrc /etc/zshrc                       # macOS  (Arch: /etc/zsh/zshrc)
sudo cp kitty.conf /etc/xdg/kitty/kitty.conf   # if installed globally
cp claude/statusline.sh ~/.claude/statusline.sh   # per-user, same snapshot rule
```
