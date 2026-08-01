#!/usr/bin/env zsh
# Claude Code status line.
#
#   Path:     ~/measurements
#   Context:  ██░░░░░░░░   20.0%
#   5-hour:   ███░░░░░░░   31.0%   reset 19:52       runs out 18:20
#   Weekly:   █████████░   91.2%   reset Wed 10:45   runs out Tue 08:00
#
# Fixed columns — label, bar, percent, reset, projection — so the two rate
# limits sit on the same grid and can be read against each other.
#
# "runs out" is a live extrapolation, recomputed every refresh: percent spent
# divided by time elapsed since the window opened, projected forward to 100%.
# It appears only when the budget is on course to be exhausted before the
# window resets, so its presence is itself the warning. Yellow when the
# shortfall is under a tenth of the window, red beyond that. It is suppressed
# for the first 10% of a window, where dividing by a small elapsed time makes
# the estimate meaningless.
#
# Bars are coloured by how much is left, which is a fact about the present.
# Pace is deliberately not folded into that colour — "runs out" carries it, and
# two competing signals in one glyph would be worse than one clear one.
#
# Reset times are absolute wall-clock in 24-hour form, never countdowns. The
# weekday prefix is added only when the time does not land today: a bare
# "02:15" would not say which day it meant.
#
# This runs on every refresh, forever, so it forks exactly one process: jq.
# Times come from zsh/datetime's strftime builtin rather than date(1), which
# also sidesteps the GNU/BSD -d-vs--r split; arithmetic is zsh's own floating
# point rather than awk.
#
# Requires: zsh 5.x, jq. Portable across Linux and macOS as-is.
#
# Session fields come from the JSON payload Claude Code pipes in on stdin.

emulate -L zsh
zmodload zsh/datetime

# Percentages arrive dotted. Under a comma-decimal locale (de_DE, fr_FR, …)
# printf would otherwise misread and misprint them.
export LC_NUMERIC=C

FIVE_HOUR=18000     # seconds in the 5-hour window
ONE_WEEK=604800     # seconds in the 7-day window

red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'
dim=$'\033[2m';  off=$'\033[0m'

IFS= read -rd '' input
eval "$(jq -r '
  @sh "dir=\(.workspace.current_dir)",
  @sh "ctx_pct=\(.context_window.used_percentage // 0)",
  @sh "hour_pct=\(.rate_limits.five_hour.used_percentage // -1)",
  @sh "hour_reset=\(.rate_limits.five_hour.resets_at // 0)",
  @sh "week_pct=\(.rate_limits.seven_day.used_percentage // -1)",
  @sh "week_reset=\(.rate_limits.seven_day.resets_at // 0)"
' <<< $input)"

# Green under 50%, yellow under 80%, red at or above.
heat() {
  local -F p=$1
  if   (( p >= 80 )); then REPLY=$red
  elif (( p >= 50 )); then REPLY=$yellow
  else                     REPLY=$green
  fi
}

# 10 cells, rounded to nearest: 78.4 -> ████████░░
bar() {
  local -F p=$1
  (( p < 0 ))   && p=0
  (( p > 100 )) && p=100
  local -i filled=$(( p / 10 + 0.5 ))   # integer assignment truncates
  local e=''
  REPLY="${(l:$filled::█:)e}${(l:$((10 - filled))::░:)e}"
}

# "23:15" when the time lands today, "Sat 09:00" when it does not.
stamp() {
  local today that
  strftime -s today '%F' $EPOCHSECONDS
  strftime -s that  '%F' $1
  if [[ $today == $that ]]; then
    strftime -s REPLY '%H:%M' $1
  else
    strftime -s REPLY '%a %H:%M' $1
  fi
}

# runs_out <used_pct> <reset_epoch> <window_seconds>
# REPLY = epoch at which the budget is projected to reach 100% at the average
# rate so far this window. Returns non-zero when the window is too young to
# extrapolate from, or when the budget outlasts the window.
runs_out() {
  local -F used=$1
  local -i reset=$2 len=$3
  local -i elapsed=$(( EPOCHSECONDS - (reset - len) ))
  (( elapsed > 0 ))                   || return 1
  (( 1.0 * elapsed / len >= 0.10 ))   || return 1   # too early to mean anything
  (( used > 0 ))                      || return 1
  local -i dry=$(( EPOCHSECONDS + (100.0 - used) * elapsed / used ))
  (( dry < reset ))                   || return 1   # on pace; nothing to warn about
  REPLY=$dry
}

# Yellow when the shortfall is under a tenth of the window, red beyond it —
# running dry twenty minutes early is a shrug, three days early is not.
dry_heat() {
  local -F early=$(( 1.0 * ($2 - $1) / $3 ))
  if (( early < 0.10 )); then REPLY=$yellow; else REPLY=$red; fi
}

# One row of the grid: label, coloured bar, right-aligned percent.
row() {
  local lbl=$1 pct_str c b
  local -F p=$2
  printf -v pct_str '%5.1f%%' $p
  heat $p; c=$REPLY
  bar  $p; b=$REPLY
  printf -v REPLY '%s%-9s%s%s%s   %s%s' $dim $lbl $off $c $b $pct_str $off
}

# A rate-limit row: the grid, plus reset and — when warranted — the projection.
# Returns non-zero when the limit is absent, as it is under API-key auth.
limit_row() {
  local lbl=$1 line rs ds dc padded
  local -F p=$2
  local -i rst=$3 len=$4 dry
  (( p >= 0 )) || return 1
  row $lbl $p
  line=$REPLY
  if (( rst > 0 )); then
    if runs_out $p $rst $len; then
      dry=$REPLY
      # Pad the reset stamp only when a projection follows it, so rows without
      # one do not carry invisible trailing whitespace.
      stamp $rst; printf -v padded '%-9s' $REPLY
      stamp $dry; ds=$REPLY
      dry_heat $dry $rst $len; dc=$REPLY
      line+="   ${dim}reset${off} ${padded}   ${dim}runs out${off} ${dc}${ds}${off}"
    else
      stamp $rst
      line+="   ${dim}reset${off} ${REPLY}"
    fi
  fi
  REPLY=$line
}

# %~ — absolute path with $HOME collapsed to ~
pretty_dir=${dir/#$HOME/\~}

printf -v out '%s%-9s%s%s' $dim 'Path:' $off $pretty_dir
row 'Context:' $ctx_pct
out+=$'\n'$REPLY

limit_row '5-hour:' $hour_pct $hour_reset $FIVE_HOUR && out+=$'\n'$REPLY
limit_row 'Weekly:' $week_pct $week_reset $ONE_WEEK  && out+=$'\n'$REPLY

print -rn -- $out
