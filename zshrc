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

HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_VERIFY SHARE_HISTORY
setopt APPEND_HISTORY INC_APPEND_HISTORY HIST_REDUCE_BLANKS

setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT CORRECT
setopt NOTIFY LONG_LIST_JOBS NO_BEEP EXTENDED_GLOB

# §5. COMPLETION SYSTEM
# -------------------------------------------------------------------
# Add completion directories to fpath, avoiding duplicates.
for dir in "${_completion_dirs[@]}"; do
  if [[ -d "$dir" ]]; then
    fpath=("$dir" ${fpath:#$dir})
  fi
done

# Initialize compinit with deterministic insecure-dir handling.
autoload -Uz compinit
if (( $+commands[compaudit] )); then
  insecure_dirs=$(compaudit 2>/dev/null)
  if [[ -n "$insecure_dirs" ]]; then
    # Recommended fix: compaudit | xargs chmod g-w,o-w
    compinit -u 2>/dev/null || compinit 2>/dev/null
  else
    compinit 2>/dev/null
  fi
else
  compinit 2>/dev/null
fi

# Completion styling.
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
[[ -n "$LS_COLORS" ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}--- %d ---%f'
zstyle ':completion:*:messages' format '%F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format '%F{red} -- No matches for: %d --%f'
zstyle ':completion:*:corrections' format '%F{green}-- %d (errors: %e) --%f'

# §6. PROMPT CONFIGURATION
# -------------------------------------------------------------------
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

  # Check if the final command is in our interactive list.
  if (( _INTERACTIVE_COMMANDS[$cmd] )); then
    unset timer
    return
  fi

  # Otherwise, start the timer.
  timer=$SECONDS
}

smart_exit_status() {
  local last_status=$?
  if (( last_status != 0 && last_status != 141 )); then
    echo "%F{red}✘ ${last_status}%f "
  fi
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

venv_info() { [[ -n "$VIRTUAL_ENV" ]] && echo " %F{magenta}[$(basename "$VIRTUAL_ENV")]%f"; }
node_info() { [[ -f "package.json" ]] && command -v node >/dev/null && echo " %F{green}node:$(node --version)%f"; }

_prompt_exec_time_str=""
_prompt_update_timer() {
  if [[ -n "$timer" ]]; then
    local timer_result=$((SECONDS - timer))
    if (( timer_result >= 3 )); then
      local mins=$((timer_result / 60)) secs=$((timer_result % 60))
      if (( mins > 0 )); then
        _prompt_exec_time_str="%F{yellow}⏱ ${mins}m${secs}s%f"
      else
        _prompt_exec_time_str="%F{yellow}⏱ ${secs}s%f"
      fi
    else
      _prompt_exec_time_str=""
    fi
    unset timer
  else
    _prompt_exec_time_str=""
  fi
}

_prompt_update_title() {
  case "$TERM" in
    xterm*|rxvt*|screen*|tmux*|alacritty*|kitty*) print -Pn "\e]0;%n@%m: %~\a";;
  esac
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _prompt_update_timer
add-zsh-hook precmd _prompt_update_title

PROMPT='$(smart_exit_status)%F{cyan}%n%f@%F{blue}%m%f %F{yellow}%~%f$(perf_git_info)$(venv_info)$(node_info) %# '
RPROMPT='$_prompt_exec_time_str'

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
if (( _loaded_plugins[history-substring-search] )); then
  bindkey '^[[A' history-substring-search-up; bindkey '^[[B' history-substring-search-down
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

# --- End of Configuration ---
