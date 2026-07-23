# =================================================================== #
#           The Definitive, Portable & Performant Zsh Config          #
# =================================================================== #

# §0. DEPENDENCIES & REQUIREMENTS
# -------------------------------------------------------------------
# Required: zsh 5.0+
# Recommended plugins: zsh-syntax-highlighting, zsh-autosuggestions,
#                      zsh-history-substring-search, zsh-completions
# Optional tools: eza/exa, bat, fastfetch, git, unrar, p7zip

# §1. ENVIRONMENT VARIABLES
# -------------------------------------------------------------------
export EDITOR=${EDITOR:-vim}
export VISUAL="$EDITOR"
export PAGER=${PAGER:-less}

# We show the active virtualenv in the prompt ourselves (venv_info), so stop the
# `activate` script from ALSO prepending "(venv)" — otherwise it shows twice.
# Generic: applies to uv, python -m venv, virtualenv, etc.
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Refuse `pip install` outside a virtualenv, so a stray bare `pip` (or a tool/
# script that calls it) can't silently pollute system Python. uv already enforces
# this for `uv pip`; this backstops plain pip. Deliberate global install:
#   PIP_REQUIRE_VIRTUALENV= pip install <pkg>
export PIP_REQUIRE_VIRTUALENV=true

# §2. NON-INTERACTIVE GUARD
# -------------------------------------------------------------------
# Use Zsh-specific test for interactive shell.
[[ -o interactive ]] || return

# §3. ENVIRONMENT DETECTION & PATHS
# -------------------------------------------------------------------
# Initialize plugin/completion arrays.
typeset -a _plugin_dirs=() _completion_dirs=()

if [[ "$(uname -s)" == "Darwin" ]]; then
  ZSH_OS="macOS"
  # Silence Homebrew's "Hide these hints with HOMEBREW_NO_ENV_HINTS=1" spam.
  export HOMEBREW_NO_ENV_HINTS=1
  # Try to detect Homebrew prefix.
  if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX=$(brew --prefix 2>/dev/null)
  fi
  # Fallback to common locations.
  if [[ -z "$BREW_PREFIX" ]]; then
    for prefix in "/opt/homebrew" "/usr/local"; do
      if [[ -x "${prefix}/bin/brew" ]]; then
        BREW_PREFIX="$prefix"; break
      fi
    done
  fi
  # Apply Homebrew environment (sets PATH, MANPATH, etc.).
  if [[ -n "$BREW_PREFIX" && -x "${BREW_PREFIX}/bin/brew" ]]; then
    eval "$(${BREW_PREFIX}/bin/brew shellenv 2>/dev/null)"
  fi
  # Add Homebrew and local paths.
  if [[ -n "$BREW_PREFIX" ]]; then
    _plugin_dirs+=("${BREW_PREFIX}/share")
    _completion_dirs+=("${BREW_PREFIX}/share/zsh-completions" "${BREW_PREFIX}/share/zsh/site-functions")
  fi
  _plugin_dirs+=("/usr/local/share" "$HOME/.local/share")
  _completion_dirs+=("/usr/local/share/zsh/site-functions" "$HOME/.local/share/zsh/site-functions")

else
  ZSH_OS="Linux"
  # Common plugin/completion locations across distributions.
  _plugin_dirs=(
    "/usr/share/zsh/plugins" "/usr/share" "/usr/local/share/zsh/plugins"
    "$HOME/.local/share/zsh/plugins" "/usr/local/share"
  )
  _completion_dirs=(
    "/usr/share/zsh/site-functions" "/usr/share/zsh-completions"
    "/usr/local/share/zsh/site-functions" "$HOME/.local/share/zsh/site-functions"
  )
fi

# §4. CORE SHELL OPTIONS & HISTORY
# -------------------------------------------------------------------
setopt PROMPT_SUBST
autoload -Uz colors && colors

export HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
if ! mkdir -p "$(dirname -- "${HISTFILE}")" 2>/dev/null; then
  echo "Warning: Could not create history directory at $(dirname -- "${HISTFILE}")" >&2
fi

HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_VERIFY SHARE_HISTORY
setopt APPEND_HISTORY INC_APPEND_HISTORY HIST_REDUCE_BLANKS EXTENDED_HISTORY

setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT CORRECT
# INTERACTIVE_COMMENTS: allow `#` comments at the prompt (only at the start of a
# word — URLs like host/page#frag and quoted `#` stay literal), so pasted
# commands with trailing comments don't error.
setopt NOTIFY LONG_LIST_JOBS NO_BEEP EXTENDED_GLOB INTERACTIVE_COMMENTS

# §5. COMPLETION SYSTEM
# -------------------------------------------------------------------
# Add completion directories to fpath, avoiding duplicates.
for dir in "${_completion_dirs[@]}"; do
  if [[ -d "$dir" ]]; then
    fpath=("$dir" ${fpath:#$dir})
  fi
done

# Initialize compinit with a dump-age cache and deterministic insecure-dir
# handling. On most startups the cached dump is reused via `compinit -C` (skips
# both the security audit and the rebuild — the fast path). Only when the dump
# is missing or stale (>24h) do we re-audit: `compinit -u` then trusts
# group/world-writable dirs (common with a shared Homebrew on macOS) and skips
# the interactive [y/n] prompt. Delete ~/.zcompdump to force a refresh after
# installing new completions.
# NOTE: compaudit is an autoloaded *function*, not an external command, so a
# `$+commands[compaudit]` test is always false — we check its output directly.
# NOTE: the dump-age test uses an ARRAY glob (${dump}(Nmh-24)); a glob qualifier
# does NOT expand inside [[ ]], so testing it there would always hit the cache.
autoload -Uz compinit compaudit
() {
  local zdump="${ZDOTDIR:-$HOME}/.zcompdump"
  local -a fresh=( ${zdump}(Nmh-24) )     # non-empty iff dump exists and is < 24h old
  if (( $#fresh )); then
    compinit -C -d "$zdump"                                    # fast path: trust cache
  elif [[ -n "$(compaudit 2>/dev/null)" ]]; then
    compinit -u -d "$zdump" 2>/dev/null || compinit -d "$zdump" 2>/dev/null
  else
    compinit -d "$zdump" 2>/dev/null
  fi
}

# Completion styling.
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
[[ -n "$LS_COLORS" ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}--- %d ---%f'
zstyle ':completion:*:messages' format '%F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format '%F{red} -- No matches for: %d --%f'
zstyle ':completion:*:corrections' format '%F{green}-- %d (errors: %e) --%f'
# Cache expensive completers (package managers, docker, …) between runs.
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# §5b. COMMAND-NOT-FOUND HANDLER
# -------------------------------------------------------------------
# When a command isn't found, suggest how to install it. On Linux, defer to the
# distro's handler if installed (it maps the command to its package: pkgfile on
# Arch, command-not-found on Debian/Ubuntu). On macOS (no such mapper ships by
# default) fall back to a Homebrew search hint.
if [[ "$ZSH_OS" != "macOS" ]]; then
  for _cnf in /usr/share/doc/pkgfile/command-not-found.zsh /etc/zsh_command_not_found; do
    [[ -r "$_cnf" ]] && source "$_cnf" && break
  done
  unset _cnf
fi
if ! (( ${+functions[command_not_found_handler]} )); then
  command_not_found_handler() {
    print -u2 "zsh: command not found: $1"
    [[ "$ZSH_OS" == "macOS" ]] && (( $+commands[brew] )) && \
      print -u2 "  search Homebrew:  brew search $1"
    return 127
  }
fi

# §5c. TOOL INTEGRATIONS
# -------------------------------------------------------------------
# All guarded, so each is a no-op when the tool is absent — forward-compatible:
# if uv is ever replaced, these simply do nothing.
#
# uv shell completions, cached: uv is spawned only when its binary is newer than
# the cache, not on every startup (keeps startup fast).
if command -v uv >/dev/null 2>&1; then
  _uv_comp="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/uv-completion.zsh"
  if [[ ! -f "$_uv_comp" || "${commands[uv]}" -nt "$_uv_comp" ]]; then
    mkdir -p "${_uv_comp:h}" && uv generate-shell-completion zsh >| "$_uv_comp" 2>/dev/null
  fi
  source "$_uv_comp" 2>/dev/null
  unset _uv_comp
fi

# direnv: per-directory environments (a project's .envrc can activate its venv
# on entry and unload it on exit, so an activated venv never leaks into an
# unrelated directory). Inert until `direnv` is installed and a .envrc exists.
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# §6. PROMPT CONFIGURATION
# -------------------------------------------------------------------
# High-resolution clock ($EPOCHREALTIME) for sub-second command timing.
zmodload zsh/datetime

# Check for git once to avoid repeated failed calls.
typeset -g _has_git=0
command -v git >/dev/null 2>&1 && _has_git=1

# Associative array for fast interactive command lookup.
typeset -A _INTERACTIVE_COMMANDS
_INTERACTIVE_COMMANDS=(vim 1 nvim 1 nano 1 emacs 1 less 1 more 1 man 1 htop 1 btop 1 top 1)

# Improved preexec: ignores wrappers (sudo/env/etc.) and checks the real subcommand.
preexec() {
  # Full commandline is $1. Use zsh word-splitting to inspect words robustly.
  local -a words
  words=(${(z)1})

  # If empty, do nothing
  [[ ${#words[@]} -eq 0 ]] && return

  # A real command is running this cycle. This gates the outcome footer below,
  # so Ctrl-C on an empty prompt does NOT falsely report an "interrupted" command.
  _prompt_cmd_ran=1

  # Determine the candidate command to check.
  # If the command is a wrapper (sudo, env, etc.), skip wrapper + options.
  local wrapperlist="sudo env nohup stdbuf nice time"
  local cmd="${words[1]}"

  if [[ " $wrapperlist " == *" $cmd "* ]]; then
    # Find first word after wrapper that does not start with '-'.
    local i=2 candidate
    while (( i <= ${#words[@]} )); do
      if [[ "${words[i]}" == -- ]]; then (( i++ )); break; fi # End of options
      if [[ "${words[i]}" == -* ]]; then (( i++ )); continue; fi # An option
      candidate="${words[i]}"
      break
    done
    # If we found a candidate subcommand, use it for the check.
    if [[ -n "$candidate" ]]; then
      cmd="$candidate"
    fi
  fi

  # Interactive programs (editors, pagers, TUIs) don't get a duration — sitting
  # in vim for 10 minutes shouldn't print "⏱ 10m". They still get an outcome.
  if (( _INTERACTIVE_COMMANDS[$cmd] )); then
    unset _prompt_timer
    return
  fi

  # Otherwise, start the duration timer and snapshot CPU for a later diff.
  _prompt_timer=$EPOCHREALTIME
  local REPLY; _prompt_read_cpu; _prompt_cpu0=$REPLY
}

# Command outcome + duration/CPU + finish-time footer. Everything about "what
# happened" prints on its own line ABOVE the next prompt (Pure-style preprompt),
# welded to the command that produced it, never decorating the line you type on.
# Shown only when noteworthy: a failure, OR a run >= 3s (a slow success is
# labelled too, for symmetry). Clean & fast commands print nothing. The outcome
# is a WORD — colour only reinforces it, so it is never a colour-only signal:
# green "ok" vs red "failed"/"interrupted"/…. CPU% (shell + child processes) is
# shown only for slow (>= 3s) runs, where the measurement is reliable, and is
# then shown ALWAYS — 0% meaningfully says "it waited rather than computed".
typeset -gA _STATUS_WORDS
_STATUS_WORDS=(
  130 interrupted  143 terminated  137 killed  139 segfault
  124 timeout  126 'not executable'  127 'not found'
)
_prompt_footer=""                    # preprompt line (incl. trailing newline) or empty
typeset -g _prompt_cmd_ran=0         # set by preexec when a real command runs
typeset -g _prompt_timer             # $EPOCHREALTIME at command start (unset for TUIs)
typeset -g _prompt_cpu0=0            # CPU seconds (shell+children) at command start
typeset -g _prompt_times_file="${TMPDIR:-/tmp}/.zsh-prompt-times.$$"

# Cumulative CPU (user+sys) seconds -> REPLY, summing the SHELL's own line
# (builtins/functions) and the CHILDREN line (external commands) from `times`,
# so a CPU-heavy shell loop reports too, not just external processes. Captured
# via a file redirect, NOT $(times): command substitution forks a subshell that
# reports zero, whereas a redirect runs in the current shell. ~0.07 ms/call.
_prompt_read_cpu() {
  REPLY=0
  times >| "$_prompt_times_file" 2>/dev/null || return
  local l1 l2
  { read -r l1; read -r l2 } <"$_prompt_times_file" 2>/dev/null || return
  local -F total=0
  local line u s
  for line in "$l1" "$l2"; do            # each "0m0.29s 0m0.00s" -> user / sys
    u=${line%% *} s=${line##* }; u=${u%s}; s=${s%s}
    [[ $u == *m* && $s == *m* ]] || continue
    (( total += ${u%m*} * 60 + ${u#*m} + ${s%m*} * 60 + ${s#*m} ))
  done
  REPLY=$total
}

# Human duration for float seconds $1 -> REPLY (e.g. 80ms, 4.2s, 18s, 2m14s).
_prompt_fmt_dur() {
  local -F w=$1
  local -i ms=$(( w * 1000 )) sec=$(( w ))
  if   (( w < 1 ));    then REPLY="${ms}ms"
  elif (( w < 10 ));   then printf -v REPLY '%.1fs' $w
  elif (( sec < 60 )); then REPLY="${sec}s"
  else REPLY="$(( sec / 60 ))m$(( sec % 60 ))s"; fi
}

_prompt_cleanup() { rm -f "$_prompt_times_file" 2>/dev/null; }

# Builds _prompt_footer. Must be the FIRST precmd hook so it captures $? before
# any other hook (or its own subshells) clobbers it.
_prompt_build_footer() {
  local code=$?
  _prompt_footer=""
  # Only report for lines where a command actually ran (preexec fired) — this is
  # what stops Ctrl-C on an empty prompt from claiming a command was interrupted.
  (( _prompt_cmd_ran )) || { _prompt_cmd_ran=0; unset _prompt_timer; return; }

  local -F wall=0
  [[ -n "$_prompt_timer" ]] && wall=$(( EPOCHREALTIME - _prompt_timer ))
  local failed=0
  (( code != 0 && code != 141 )) && failed=1     # 141 = benign SIGPIPE (e.g. | head)

  # Trigger: a failure, or a slow (>= 3s) command.
  if (( failed )) || (( wall >= 3 )); then
    local -a parts; local REPLY
    # Outcome word (colour reinforces; the word carries the meaning).
    if (( failed )); then
      local w=${_STATUS_WORDS[$code]}
      if [[ -n "$w" ]]; then parts+=("%F{red}${w}%f")
      elif (( code > 128 && code <= 192 )); then parts+=("%F{red}SIG${signals[code-128+1]:-error}%f")
      else parts+=("%F{red}failed%f"); fi
    else
      parts+=("%F{green}ok%f")
    fi
    # Duration always (when a timer ran, i.e. not a TUI). CPU% only for slow
    # (>= 3s) runs, where the long window makes the times-diff reliable; there it
    # is shown ALWAYS, including 0% (time went to waiting, not computing). Fast
    # commands never show it — over a tiny window the number would be noise. It
    # can exceed 100% (parallelism across cores).
    if [[ -n "$_prompt_timer" ]]; then
      _prompt_fmt_dur $wall; parts+=("$REPLY")
      if (( wall >= 3 )); then
        _prompt_read_cpu
        local -F cpu_used=$(( REPLY - _prompt_cpu0 ))
        (( cpu_used < 0 )) && cpu_used=0
        local -i pct=$(( 100 * cpu_used / wall ))
        parts+=("${pct}%% cpu")                     # %% -> literal % after prompt expansion
      fi
    fi
    # Completion time (prompt escape, expanded when PROMPT renders ≈ now).
    parts+=('%D{%H:%M:%S}')
    _prompt_footer="${(j: · :)parts}"$'\n'
  fi

  _prompt_cmd_ran=0
  unset _prompt_timer
}

perf_git_info() {
  (( _has_git )) || return
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then return; fi
  local branch; branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || branch=$(git rev-parse --short HEAD 2>/dev/null)
  local dirty=""; if ! git diff --no-ext-diff --quiet --exit-code --ignore-submodules --cached >/dev/null 2>&1; then dirty+='+'; fi
  if ! git diff --no-ext-diff --quiet --exit-code --ignore-submodules -- >/dev/null 2>&1; then dirty+='*'; fi
  if [[ -n "$(git ls-files --others --exclude-standard --directory -z 2>/dev/null)" ]]; then dirty+='?'; fi
  [[ -n "$dirty" ]] && echo " %F{red}git:(${branch}${dirty})%f" || echo " %F{green}git:(${branch})%f"
}

venv_info() { [[ -n "$VIRTUAL_ENV" ]] && echo " %F{magenta}[${VIRTUAL_ENV:t}]%f"; }

# node version, memoized: spawn `node --version` once and re-run only when the
# node binary changes (e.g. after `nvm use`/`fnm use`) — not on every prompt.
# Keyed on the resolved path, so a system node spawns once per session and a
# version-manager switch invalidates the cache automatically.
typeset -g _node_ver="" _node_bin=""
node_info() {
  [[ -f package.json ]] || return
  local nb=${commands[node]}; [[ -n $nb ]] || return
  if [[ $nb != $_node_bin ]]; then
    _node_bin=$nb; _node_ver=$(node --version 2>/dev/null)
  fi
  [[ -n $_node_ver ]] && echo " %F{green}node:${_node_ver}%f"
}

_prompt_update_title() {
  case "$TERM" in
    xterm*|rxvt*|screen*|tmux*|alacritty*|kitty*) print -Pn "\e]0;%n@%m: %~\a";;
  esac
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _prompt_build_footer   # must be first: captures $?
add-zsh-hook precmd _prompt_update_title
add-zsh-hook zshexit _prompt_cleanup       # remove the child-CPU scratch file

# ${_prompt_footer} prints the outcome/duration on its own line above the prompt
# (and only when there is something to say). The main line is anchored at the
# margin; the %#/%% sigil keeps its plain meaning (privilege indicator) with no
# status colouring. No RPROMPT — nothing transient sits on the line you type on.
PROMPT='${_prompt_footer}%F{cyan}%n%f@%F{blue}%m%f %F{yellow}%~%f$(perf_git_info)$(venv_info)$(node_info) %# '
RPROMPT=''

# §7. ALIASES & SHELL FUNCTIONS
# -------------------------------------------------------------------
# eza/exa with fallbacks.
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --color=always --group-directories-first'
  alias la='eza -la'; alias ll='eza -l'; alias lt='eza --tree'; alias l='eza -F'
elif command -v exa >/dev/null 2>&1; then
  alias ls='exa --color=always --group-directories-first'
  alias la='exa -la'; alias ll='exa -l'; alias lt='exa --tree'; alias l='exa -F'
else
  [[ "$ZSH_OS" == "macOS" ]] && alias ls='ls -G' || alias ls='ls --color=auto'
  alias la='ls -la'; alias ll='ls -l'; alias l='ls -F'
fi

if command -v bat >/dev/null 2>&1; then alias cat='bat --style=plain --paging=never'
elif command -v batcat >/dev/null 2>&1; then alias cat='batcat --style=plain --paging=never'; fi

if command -v grep >/dev/null 2>&1 && grep --color=auto "" /dev/null >/dev/null 2>&1; then
  alias grep='grep --color=auto'; alias fgrep='fgrep --color=auto'; alias egrep='egrep --color=auto'
fi

alias ..='cd ..'; alias ...='cd ../..'; alias ....='cd ../../..'
alias df='df -h'; alias du='du -sh'; alias rm='rm -i'; alias cp='cp -i'; alias mv='mv -i'
if [[ "$ZSH_OS" == "Linux" ]]; then alias free='free -h'; fi
alias myip='curl -s ifconfig.me && echo'
alias ping='ping -c 5'

if (( _has_git )); then
  alias g='git'; alias gs='git status -sb'; alias ga='git add'; alias gaa='git add --all'
  alias gcm='git commit -m'; alias gco='git checkout'; alias gcb='git checkout -b'
  alias gl='git log --oneline --graph --decorate --all'; alias gp='git push'; alias gpl='git pull'
  alias gd='git --no-pager diff'; alias gds='git --no-pager diff --staged'
fi

unalias zshrc 2>/dev/null
zshrc() { "${EDITOR:-vim}" "${ZDOTDIR:-$HOME}/.zshrc"; }

unalias reload 2>/dev/null
reload() { source "${ZDOTDIR:-$HOME}/.zshrc" && echo "✓ Zsh configuration reloaded."; }

mkcd() { [[ -z "$1" ]] && echo "Usage: mkcd <dir>" >&2 && return 1; mkdir -p "$1" && cd "$1"; }
qfind() { [[ $# -eq 0 ]] && echo "Usage: qfind <pattern> [path]" >&2 && return 1; find "${2:-.}" -iname "*$1*" 2>/dev/null; }

extract() {
  [[ $# -eq 0 ]] && echo "Usage: extract <archive_file> [...]" >&2 && return 1
  local had_error=0
  for file in "$@"; do
    if [[ ! -f "$file" ]]; then echo "Error: '$file' is not valid" >&2; had_error=1; continue; fi
    echo "Extracting: $file"; case "${file:l}" in
      *.tar.bz2|*.tbz2) tar xjf "$file" ;; *.tar.gz|*.tgz) tar xzf "$file" ;;
      *.tar.xz|*.txz) tar xJf "$file" ;; *.tar) tar xf "$file" ;;
      *.bz2) bunzip2 "$file" ;; *.gz) gunzip "$file" ;;
      *.zip) unzip "$file" ;; *.Z) uncompress "$file" ;;
      *.rar) command -v unrar >/dev/null && unrar x "$file" || { echo "Error: unrar not found" >&2; had_error=1; };;
      *.7z)  command -v 7z >/dev/null && 7z x "$file" || { echo "Error: 7z not found" >&2; had_error=1; };;
      *) echo "Error: '$file' unsupported" >&2; had_error=1 ;;
    esac
  done
  (( had_error )) && return 1 || return 0
}

# §8. PLUGIN LOADING FRAMEWORK
# -------------------------------------------------------------------
load_plugin() {
  local plugin_file="$1"
  if [[ -f "$plugin_file" ]]; then source "$plugin_file"; return 0; fi
  return 1
}

typeset -gA _loaded_plugins; _loaded_plugins=()
for plugin_dir in "${_plugin_dirs[@]}"; do
  [[ ! -d "$plugin_dir" ]] && continue
  if [[ -z "${_loaded_plugins[autosuggestions]}" ]] && \
    load_plugin "${plugin_dir}/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
    _loaded_plugins[autosuggestions]=1
  fi
  if [[ -z "${_loaded_plugins[history-substring-search]}" ]] && \
    load_plugin "${plugin_dir}/zsh-history-substring-search/zsh-history-substring-search.zsh"; then
    _loaded_plugins[history-substring-search]=1
  fi
done

# §9. KEYBINDINGS & INTERACTIVE BEHAVIOR
# -------------------------------------------------------------------
# Select the emacs keymap explicitly. Without this, zsh auto-selects the *vi*
# keymap whenever $EDITOR/$VISUAL matches *vi* — and we set EDITOR=vim above,
# so the shell would silently start in vi insert mode. That leaves Left/Right
# bound to vi-backward-char/vi-forward-char, which refuse to cross a line
# boundary: on a continued/multiline buffer the arrows appear dead. All the
# emacs-style bindings below (word motions, etc.) assume this keymap. Must come
# before the other bindkey calls so they bind into the emacs keymap.
bindkey -e

# History navigation: Up/Down do PREFIX search — cycle through history entries
# that BEGIN with the text before the cursor. Type "uv" then Up to walk
# "uv", "uvx", "uv pip install", …; type "uv " (trailing space) to restrict to
# entries starting with "uv " (the `uv` command itself). With an empty line
# they behave like plain Up/Down, and they cope with multiline buffers (move
# within the buffer before searching) and leave the cursor at end of line.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Substring-anywhere search (matches "uv" wherever it appears in a line) stays
# available on Ctrl+Up / Ctrl+Down when the plugin is loaded.
if (( _loaded_plugins[history-substring-search] )); then
  bindkey '^[[1;5A' history-substring-search-up
  bindkey '^[[1;5B' history-substring-search-down
fi
bindkey '^[[1;5C' forward-word; bindkey '^[[1;3C' forward-word
bindkey '^[[1;5D' backward-word; bindkey '^[[1;3D' backward-word
bindkey '^[[Z' reverse-menu-complete
WORDCHARS=${WORDCHARS/\/}

if (( _loaded_plugins[autosuggestions] )); then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
fi

# §10. WELCOME SCREEN & HEALTH CHECK
# -------------------------------------------------------------------
if command -v fastfetch >/dev/null 2>&1; then
  fastfetch --config none --logo small --structure "Title:Separator:OS:Host:Kernel:Uptime:Memory:Disk"
elif command -v neofetch >/dev/null 2>&1; then
  neofetch --config off --ascii_distro small
else
  echo "Welcome, $(whoami)!"
fi

zsh_health() {
  echo "--- Zsh Configuration Health Check ---"
  echo "OS: $ZSH_OS, Shell: Zsh $ZSH_VERSION"
  if (( ${#_loaded_plugins[@]} )); then echo "Loaded plugins: ${(k)_loaded_plugins}";
  else echo "Loaded plugins: None"; fi
  for tool in git eza exa bat; do
    echo -n "$tool: "; command -v "$tool" >/dev/null 2>&1 && echo "✓ found" || echo "✗ not found"
  done
  echo "--------------------------------------"
}

# §11. FINAL PLUGIN LOADING
# -------------------------------------------------------------------
if [[ -z "${_loaded_plugins[syntax-highlighting]}" ]]; then
  for plugin_dir in "${_plugin_dirs[@]}"; do
    if load_plugin "${plugin_dir}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; then
      _loaded_plugins[syntax-highlighting]=1; break
    fi
  done
fi

# §11b. PASTE HYGIENE
# -------------------------------------------------------------------
# Trim only the OUTER whitespace of PASTED text (leading/trailing spaces and
# newlines), so a command copied from a webpage/docs runs clean and — since it
# no longer starts with a space — is still recorded in history despite
# HIST_IGNORE_SPACE. Crucially this touches ONLY pasted text: input you type is
# never altered (so a deliberately-typed leading space still hides a command
# from history), and whitespace INSIDE a multi-line paste is preserved (heredocs
# and `\`-continued commands survive intact). Defined after the plugins so this
# override of the bracketed-paste widget wraps cleanly around theirs.
_trim_bracketed_paste() {
  zle .bracketed-paste                 # perform the real paste first
  LBUFFER=${LBUFFER##[[:space:]]#}      # strip leading whitespace/newlines
  LBUFFER=${LBUFFER%%[[:space:]]#}      # strip trailing whitespace/newlines
}
zle -N bracketed-paste _trim_bracketed_paste

# §12. USER PATH & LOCAL OVERRIDES
# -------------------------------------------------------------------
# Standard per-user bin dir (portable across Linux and macOS). Prepend only
# if present and not already on PATH.
if [[ -d "$HOME/.local/bin" ]]; then
  path=("$HOME/.local/bin" ${path:#"$HOME/.local/bin"})
fi

# Machine-specific settings (secrets, extra PATH entries, umask, etc.) belong
# in an untracked ~/.zshrc.local so this shared config stays portable and free
# of credentials. Create it per-machine; it is sourced last so it wins.
if [[ -r "${ZDOTDIR:-$HOME}/.zshrc.local" ]]; then
  source "${ZDOTDIR:-$HOME}/.zshrc.local"
fi

# --- End of Configuration ---
