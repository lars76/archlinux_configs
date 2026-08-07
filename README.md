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

## SSH — `ssh_config`

Per-user only — appends `Host` aliases (`ssh laptop`, `ssh phone`) instead of
memorizing IPs, which drift on most routers.

| Target | Command |
| --- | --- |
| **Per-user** | `cat ssh_config >> ~/.ssh/config` |

- Addressed by **hostname**, not IP — most routers auto-register each
  device's DHCP hostname in local DNS, so `YOUR-DEVICE.lan` stays valid even
  as the IP changes. Confirm with `ping YOUR-DEVICE.lan` first.
- Requires key-based auth already set up: copy each device's public key into
  the other's `~/.ssh/authorized_keys` beforehand.
- **Android:** install Termux from
  [GitHub](https://github.com/termux/termux-app/releases/latest) or F-Droid
  (same signing key either way — needed if you ever add official plugins
  like Termux:Boot). Then:
  ```sh
  pkg install openssh termux-services
  passwd            # sets a login password, needed once to copy in a key
  sv-enable sshd    # runit brings sshd up, port 8022
  ```
  `sv-enable` means `sshd` restarts automatically every time Termux is
  opened — the runit supervisor starts every enabled service on session
  start, so there's no `sshd` command to remember. It won't survive Android
  never opening the app at all; that needs the separate Termux:Boot plugin,
  not covered here.

## Claude Code — `claude/`

Per-user only; everything lives under `~/.claude`, identically on Arch and macOS.
Run this once per account:

```sh
mkdir -p ~/.claude/themes ~/.claude/commands
cp claude/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
cp claude/themes/catppuccin-mocha.json ~/.claude/themes/
cp claude/commands/*.md ~/.claude/commands/
cp claude/draft-check.py ~/.claude/draft-check.py
cp claude/CLAUDE.md ~/.claude/CLAUDE.md
sed "s|__HOME__|$HOME|" claude/settings.json > ~/.claude/settings.json
```

There is a machine-wide managed path (`/etc/claude-code/` on Linux,
`/Library/Application Support/ClaudeCode/` on macOS) that would cover every
account from one root-owned copy. It is not used here: every other file above is
per-account anyway, so a second account already runs this block and `CLAUDE.md` is
one more line in it. Managed policy would buy nothing and cost `sudo`, an OS
branch, and Claude no longer being able to edit its own instructions.

`settings.json` carries preferences only: model, effort level, permission mode,
the theme, the renderer, the editor mode, auto memory off, the two LSP plugins,
git attribution, the status line, and the `draft-check.py` hook. The `__HOME__`
placeholder is the one path that has to be rewritten at install time, hence the
`sed`.

`autoMemoryEnabled: false` turns off the notes Claude writes itself under
`~/.claude/projects/<repo>/memory/`. Off because those notes are specific factual
claims about code that age badly and get trusted anyway; the durable preferences
worth keeping live in `CLAUDE.md` instead, where they are version-controlled.
Measured cost of the memory preamble on 2.1.220 is 684 tokens, not the 11 to 16k
an open bug report claims, so this is a decision about stale facts rather than
about tokens.

- **`CLAUDE.md`** is six lines of standing instructions, loaded at the start of
  every session in every repository. It says not to write docstrings, tests, or
  type annotations until they are asked for, not to delete existing ones, to
  target Python 3.13 or newer unless a project's `requires-python` says otherwise,
  and to avoid em-dashes and emoji. Keep it short: the file is loaded in full on
  every request, and a long one gets ignored in the middle.

- **`draft-check.py`** is the `PostToolUse` hook that backs the first two lines of
  `CLAUDE.md`, since a rule in a prompt is a request and a hook is not. It reads
  the tool payload on stdin and reports docstrings (module, class and function),
  type annotations, redundant `from __future__ import annotations`, new test files,
  and single-line private helpers. It never blocks and never edits: the write has
  already happened, and exit 2 only feeds the message back as text.

  It re-execs itself on `python3.12` or newer when the `python3` that started it is
  older, because macOS still ships 3.9.6 as `/usr/bin/python3` and that cannot parse
  `match` or PEP 695. Without this, 19 files in the main work tree failed
  `ast.parse` and every check on them was skipped in silence. If no newer
  interpreter is on `PATH` it says which file it could not parse instead of exiting
  0. Arch's `python3` is current, so the re-exec is a no-op there.

  The `from __future__ import annotations` report is conditional: it fires only
  when nothing in the file relies on deferral, meaning no `TYPE_CHECKING`-only
  name, no forward reference, no class naming itself in its own body, no dotted
  annotation whose submodule import is missing, and no name the analysis cannot
  resolve at all — unresolvable names count as needing deferral, because a wrong
  "redundant" tells the agent to delete a line the file needs. On 3.13
  that import is still load-bearing in those cases and only becomes unconditionally
  redundant on 3.14 under PEP 649.

  It inspects **only what the current edit added**. The added lines come from the
  tool response's `structuredPatch`, which carries exact new-file line numbers per
  hunk: every `replace_all` site is covered, a `new_string` that also occurs
  earlier in the file cannot mislead it, and a docstring an edit merely carried
  through unchanged is diff context rather than an addition. A `Write` over an
  existing file arrives with an empty patch, so the old content from the response
  is diffed with `difflib`; when no usable response is present at all it falls
  back to finding the tool's `new_string` or `content` in the file, which was the
  original mechanism. A rewritten line counts as added in a diff, so anything on
  it is additionally checked against the old content: a docstring or annotation
  carried verbatim through a rename or rewrite is recognised and skipped.
  Pre-existing docstrings and typing are therefore never reported (changing the
  text of an existing docstring still reports it, the edit being about
  documentation then), which is what makes it usable in a repo that is already
  fully documented. Editing or
  overwriting an existing test file is silent; only creating one is flagged. The
  one-line rule fires only on `_`-prefixed helpers whose every reference is a
  direct call and at most one exists — `sorted(rows, key=_key)` is a reference
  that cannot be inlined at a call site, so it does not trip it. No dependencies
  beyond the standard library: no ruff, no git.

  Every invocation on a Python file appends one line to `~/.claude/drafts/log.jsonl`
  (edits to other file types exit before anything is written, so `invocations`
  below really counts Python edits), because the
  hook spent its entire first existence running zero times out of 41 and nothing
  noticed: a failed hook is a non-blocking error the model never sees and the user
  only sees by looking. `py` and `parsed` are the tripwires for exactly that. Any
  `3.9.x` in `py` means the re-exec broke; any `parsed: false` means the checks
  were skipped (a non-UTF-8 file lands here too, logged rather than crashing the
  hook). `span` says which added-line source ran — `patch`, `difflib`, `find`, or
  `none` — so a harness change that stops sending `tool_response` shows up as
  `find` lines instead of going unnoticed. `reported` counts what this edit was
  told about; `file` carries the
  whole-file docstring and annotated-def totals, which is what makes "did Claude
  act on it" answerable at all, since span-gating means a removed docstring is
  never re-reported and its absence proves nothing on its own. A failed log write
  is swallowed: it must never cost an edit.

  Four questions it exists to answer, the first being the tripwire above:

  ```sh
  L=~/.claude/drafts/log.jsonl
  # is the hook alive at all: must be zero unparsed, no 3.9.x interpreter
  jq -s '{invocations:length, unparsed:[.[]|select(.parsed==false)]|length,
          interpreters:(group_by(.py)|map({(.[0].py):length})|add)}' $L
  # is CLAUDE.md working: fired should shrink relative to edits over weeks
  jq -s '[.[]|select(.bypass==false)] as $p
         | {edits:($p|length), fired:([$p[]|select(.reported|length>0)]|length),
            by_rule:([$p[]|.reported|to_entries[]]|group_by(.key)
                     |map({(.[0].key):(map(.value)|add)})|add)}' $L
  # does Claude act on the feedback: removed vs ignored
  jq -s 'group_by(.session+"|"+.path)|map(select(length>1))
         | map({first:.[0].file.docstrings, last:.[-1].file.docstrings})
         | {removed:[.[]|select(.last<.first)]|length,
            ignored:[.[]|select(.last>=.first and .first>0)]|length}' $L
  # was the second pass deliberate: bypassed edits and what they added
  jq -s '[.[]|select(.bypass)]|{edits:length,
          docstrings:([.[]|.reported.docstring//0]|add)}' $L
  ```

  A line per edit rather than per session, so unlike `reviews/log.jsonl` this has
  useful signal within days. The third query is a proxy and not proof: a falling
  count can also mean the code was deleted.

  To suppress it while writing documentation, tests, or typing you actually asked
  for, `touch ~/.cache/claude-no-draft-check-$CLAUDE_CODE_SESSION_ID`. The file is
  keyed to the session, so concurrent sessions do not interfere and an orphan left
  by a session that ended is inert. A `SessionEnd` hook removes it when the
  session ends normally; a crashed process never runs that hook, so its flag
  survives until the same session is resumed and ends properly — the hook narrows
  the stale-flag window rather than closing it. `CLAUDE.md` tells Claude to
  set and clear it, so in practice you ask for documentation and never touch the
  file yourself. It
  lives in `~/.cache` rather than `~/.claude` because `~/.claude` is a protected
  path that no allow rule can pre-approve, so a switch there would prompt for
  permission every time and defeat the purpose.

- **`statusline.sh`** prints the status line Claude Code shows under the prompt:
  working directory, context usage with the active model, and the 5-hour,
  weekly, and per-model weekly rate limits, each with a bar and its reset time.
  Every limit carries a `burn` column — the rate spent so far over the rate
  still affordable, so `×1` lands exactly on the limit at reset, below is
  sustainable and above is not. The 5-hour window is short enough that its
  average is recent, so its `burn` reacts within the hour; the weekly one is the
  slow strategic number. Nothing is stored between refreshes, so two machines on
  one account need no syncing. Bar width follows `$COLUMNS`, up to 40 cells.

  Colour marks two facts that are allowed to disagree, and keeps them apart. The
  percentage carries headroom — plain under 80%, peach under 95%, red above —
  and `burn` carries pace, plain under `×0.8`, peach to `×1.2`, red beyond. 93%
  consumed at `burn ×0.3` is fine; 40% at `×7` is not, so folding the two
  together would report the wrong one. Neither is coloured for being healthy:
  the row worth catching is that second one, where a comfortable percentage sits
  beside a burn that is not, and colouring the percentage for its comfort put the
  calmer colour on the larger number. The bar is never coloured — it carries
  proportion, which reads from length rather than hue, and it already says
  everything a colour on the percentage could. Palette is Catppuccin Mocha under
  truecolor, falling back to the ANSI 16 elsewhere.

  Written in zsh; `jq` is required (`yay -S jq` / `brew install jq`) and `curl`
  optional. Times come from zsh's own `strftime` builtin rather than `date`,
  which avoids the GNU/BSD split, so the same file runs unmodified on Arch and
  macOS. It forks `jq` once per refresh, plus `curl` at most once every five
  minutes — every thirty seconds while an attempt is failing, so a blip at
  startup heals on the next refresh.

  Three sources report the same account-wide limits, and the script merges them
  rather than preferring one. Stdin carries only the 5-hour and weekly windows,
  and only from the first API response of a session onward, so a fresh session
  would show none at all; the per-model weekly caps are never sent there. Those
  come from `https://api.anthropic.com/api/oauth/usage`, polled into
  `~/.cache/claude-statusline/`, with Claude Code's own copy of that response in
  `~/.claude.json` as a fallback — it is refreshed only when `/usage` is opened,
  but by a process that can renew an expired token, which this script cannot.
  All of it is server state rather than local history, which is why none of it
  needs to be shared between machines.

  What arrives on stdin is written back to `stdin.json` beside the cache, and
  stamped only when the reading actually changes rather than on every refresh.
  That earns it an age it would otherwise not have, and lets the machine's
  sessions pool what they know: one left idle shows what an active one was told
  instead of its own frozen copy.

  Utilization only rises inside a window, so any reading of a live one is a
  lower bound and the largest is the closest. A reading is dropped only when its
  window has already reset, or when it is over an hour old — nothing marks a
  stale number as stale, so a row that vanishes is the honest way to say that
  nothing recent is known. That hour matters more than it looks: an access token
  lasts eight, and is renewed by making requests, so a session left open
  overnight cannot poll until you type something. The poll itself is detached,
  so the line renders from cache and never waits on the network. Without `curl`
  or a valid token the script omits what it cannot reach.
- **`themes/catppuccin-mocha.json`** recolours Claude Code's own interface to
  match kitty and vim. A custom theme is a `base` preset plus a map of token
  overrides; unknown tokens and bad colour values are ignored, so a typo cannot
  break rendering. Claude Code watches `~/.claude/themes/` and reloads on change,
  though it needs one restart if the directory did not exist at startup. Two
  tokens matter beyond consistency: `warning` moves off the stock luminous
  yellow onto Catppuccin Peach, and `rate_limit_fill` / `rate_limit_empty` make
  the `/usage` meter agree with the status line, which draws the same data.

  The theme does **not** reach `statusline.sh` — Claude Code passes that script's
  ANSI through untouched — so the two files carry the same palette separately.
  Selecting a theme in `/theme` or `/config` writes to `~/.claude/settings.json`,
  which will then diverge from the committed copy until you re-install.
- **`commands/commit.md`** adds `/commit`, which prints one complete git sequence
  for the current changes and stops. It exists because asking for a commit
  normally produces a message and nothing else, leaving `git add`, `git push`, and
  any merge or tag to be asked for one at a time.

  It cannot write. `disallowed-tools` removes `git add`, `commit`, `push`, `merge`,
  `tag`, `checkout`, `reset` and `rebase` for the duration of the command, so it
  proposes and stops whatever it decides. Reading stays available, so it can still
  open a diff to judge how changes should be grouped. The restriction clears with
  your next message, which is how "run it" then works under the usual rules. That
  is why it needs no approval gate, unlike `/r`.

  Note that `allowed-tools` does the opposite of what the name suggests: it
  pre-approves without restricting. Listing only read-only git commands there
  leaves everything else available rather than blocked.

  The convention is read from the repository rather than configured, because there
  is no single right answer across the repos worked on from here. Three are in
  active use: typed prefixes (`fix(asusd): retry module unload`, which `asusctl`
  uses in 116 of its last 300 commits and `g2p` in 13 of 16), subsystem-scoped
  (`drm/amd/pm: fix fraction scaling`, which `linux`, `mutter`, `powertop` and
  `TLP` all use in roughly 40 to 85% of commits), and free text. Proposing a typed
  prefix on a kernel patch would be wrong, so the command counts both patterns over
  the last 300 subjects and follows whichever clears 30%, falling back to free text
  matched to the median subject length. Messages are one line, 60 characters at
  most, and carry no body unless asked.

  Merges and tags are proposed only when the history says they are yours to make. A
  merge needs the current branch to differ from the main branch, merges to exist,
  and the recent merge authors to be you: in `TLP` they are Koch's and linrunner's,
  so the command proposes a push and a pull request instead. A tag needs tags to
  exist and the commits since the last one to have reached the repository's own
  cadence, which is 13 commits in `asusctl` and 1555 in `linux`. Push is omitted
  entirely when there is no upstream, as in a local-only repo.

  Grouping is at file level, so unrelated changes are split into separate commits.
  A file whose changes span two groups goes with the dominant one and the output
  says so, since `git add -p` needs an interactive terminal that is not available
  here.

  It also refuses to propose something that would fail or do damage. Before any
  push it compares the real remote head against your recorded upstream with one
  `git ls-remote`, about 1.5 seconds and no download, because a stale
  `origin/main` reports "0 behind" right up until the push is rejected; when they
  differ it puts `git pull --rebase` in front. A branch with no upstream gets
  `push -u` with the remote's actual name, which is not always `origin`. If the
  repository is mid-merge or mid-rebase, or any file is unmerged, that is the whole
  answer and nothing is proposed on top of it. On a detached HEAD it says so and
  offers `git switch -c`. If local history was rewritten after being pushed, an
  ordinary push is rejected and `pull --rebase` would drag the old commits back, so
  on your own branch it proposes `--force-with-lease` and never bare `--force`, and
  on a shared or main branch it proposes no push at all and asks to talk it through.

  Release cadence comes from the interval between the last two tags rather than
  total commits divided by tag count: with a single tag that ratio equals the whole
  history, so a one-tag repo could never look due.

- **`commands/r.md`** adds `/r`, which asks Codex and a blank-context Claude the
  same question in parallel and returns one consolidated answer. It replaces a
  four-step manual loop — open Codex in another terminal, describe the task, wait,
  paste the reply back — of which only the describing was ever worth doing.

  `/r` first infers a mode from the session rather than from git, because the
  question that is worth asking depends on whether the work is finished or still
  running: `review` and `improve` look backward at something that exists, `next`
  asks what to do with results in hand, `assess` asks whether the approach is
  right at all and gets nothing but a written summary and a web search. It then
  renders a plan and stops. The plan states the mode, the evidence for the guess,
  and the alternatives, so correcting it costs one word.

  The two blind modes withhold this session's own conclusions, and withhold them
  physically: the granted subset is copied into a scratch directory and the
  reviewers are pointed at the copy, so `NEXT.md` is absent rather than merely
  unmentioned. An earlier version asked reviewers not to look, which is not a
  guarantee — a second opinion that read this session's conclusions is this
  session's opinion in another voice, and nothing in the output would say so. The
  copy's file list is therefore the thing the plan asks you to check. The Claude
  reviewer runs on a fresh context for the same reason: the session already is the
  full-context Claude, so a second one would mostly re-derive it, while a fresh one
  contributes what the session cannot and keeps its context symmetric with Codex's.
  Both reviewers are agents that read what they judge relevant, so the grant is a
  root, not a file list, and what gets transmitted cannot be enumerated in advance;
  the plan says that plainly instead of implying a precision it does not have.

  Findings from the two are then merged and verified adversarially, but not all
  the same way. Claims about documentation consistency — this text says X, that
  artifact does Y — the session adjudicates itself by citing both locations,
  because a fresh agent re-reading two lines it already has in context buys
  nothing; the exception is when the session authored the changes under review,
  where self-review bias means agents verify everything. Every other claim goes
  through a Claude Code workflow script (`~/.claude/workflows/r-verify.js`) that
  groups findings by code location and runs one read-only Sonnet refuter per
  location with schema-validated verdicts — grouping cuts the agent count by the
  location-collision rate without any candidate losing its own verdict, and the
  refutation framing is what stops a reviewer's confidence substituting for
  evidence. The rubric lives verbatim in that script, its single source, and
  returns two values because one number cannot carry both: confidence that the
  claim is *true*, and severity if it is. Confidence marks rather than filters —
  entries under 80 appear in the report flagged WEAK, killed findings are listed
  with the refutation that sank them — while severity merely orders, so a certain
  but rare serious bug is reported last rather than silently dropped. Relevance
  stays the job of an explicit exclusions list, which differs by mode: a diff
  review excludes pre-existing issues and untouched lines, and an architecture
  review cannot, since those are exactly what it was asked about. Both reviewers
  are scrutinised equally — checking only Codex would treat same-model output as
  more trustworthy, which is the bias the command exists to counter. Where the
  two disagree the disagreement is the finding, so it is never averaged away.
  The report closes with the session's own take — what it would fix first, what
  it would ignore, and what neither reviewer raised — because the consolidator
  is the one participant that knows the whole history, and the findings are
  already in its context to act on when asked.

  The plan shown before the gate is three sentences — what gets read, what is
  withheld when blind, what comes back — with the command lines kept in `r.md`
  where the executor needs them rather than printed at you. Everything is
  fixed — Codex on `gpt-5.6-sol`, the reviewer on Opus, verifiers on Sonnet —
  and nothing is offered as a choice, though anything can be changed by saying
  so. The one exception is the mode, which the gate's options let you correct
  with one keypress. Approval runs through a prompt rather than by waiting for a
  reply, which is not a stylistic choice: a command's tool permissions last only
  for the turn that invoked it, so stopping to wait for the word "go" would
  revoke every permission the run is about to need. Reviewers get no deadline —
  a slow reviewer is doing work, and only one that errors is given up on.

  Every run appends one line to `~/.claude/reviews/log.jsonl`: mode, whether the
  inferred mode was corrected, the label of the gate option actually chosen, the
  models used, Codex's own token accounting from its `--json` stream, the full
  score distribution including the rejected findings, and `filtered_by`, which
  attributes the killed findings to the reviewer that raised them — the one
  question the earlier schema could not answer. The log answers what the command
  cannot answer about itself — how often nothing gets filtered, which is what a
  rubber-stamping verifier looks like from the outside. A `notes` field is left
  null for a one-line human verdict after the fact. Lines from before the schema
  grew simply lack the new keys, so queries take them with jq's `// default`.
  Nothing else here records Codex usage; the status line tracks Claude's limits
  and is blind to the other budget.

  Neither reviewer can modify the project: Codex runs under `-s read-only`, which
  forbids writes but still permits commands, so it can check live values without
  being able to change anything, and the subagent is held to the same rule. Either
  can be given a scratch directory under `~/.claude/scratch/` when an idea needs
  testing numerically — writes land there, the project stays untouched.

  Needs the Codex CLI (`yay -S codex` / `npm i -g @openai/codex`) and its own
  authentication; model and reasoning effort come from `~/.codex/config.toml`.
  Without it, `/r` says so and offers a Claude-only run. Reviews are written to
  `~/.claude/reviews/`.
- **Plugins** (`pyright-lsp`, `clangd-lsp`) reinstall themselves on first run
  from Anthropic's built-in marketplace — nothing to copy. They need `pyright`
  and `clangd` on the system to do anything.
- **Not committed, deliberately:** `~/.claude/.credentials.json` (OAuth tokens)
  and `~/.claude.json` (machine state, MCP auth). Everything else under
  `~/.claude` — session transcripts, caches, plugin payloads, per-project
  memory — is machine-local and regenerable, as is
  `~/.cache/claude-statusline/`, which each machine refills on its own.
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
cp claude/themes/catppuccin-mocha.json ~/.claude/themes/
cp claude/commands/commit.md claude/commands/r.md ~/.claude/commands/
mkdir -p ~/.claude/workflows && cp claude/workflows/r-verify.js ~/.claude/workflows/
cp claude/draft-check.py ~/.claude/draft-check.py
cp claude/CLAUDE.md ~/.claude/CLAUDE.md
sed "s|__HOME__|$HOME|g" claude/settings.json > ~/.claude/settings.json
```
