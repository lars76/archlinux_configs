#!/usr/bin/env zsh
# Claude Code status line.
#
#   Path:     ~/measurements
#   Context:  ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    20.0%   Opus (high)
#   5-hour:   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░    51.0%   reset 03:29       ends 78%
#   Weekly:   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░    34.0%   reset Fri 20:59   ends 119%
#   Fable 7d: ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░    60.0%   reset Fri 21:00   ends 210%
#
# Fixed columns — label, bar, percent, reset, ends — so the limits sit on the
# same grid and can be read against each other.
#
# "ends" is what this pace lands on when the window resets:
#
#     ends = used × window / elapsed
#
# Sixty percent gone a quarter of the way in ends at 240. It is a straight
# proportion, and its threshold is 100: under lands inside the budget, over runs
# out early, and the amount over is how many budgets the pace is asking for.
# Because the gauges are denominated in percent of their own budget rather than
# in tokens, this needs no per-model cost table — an expensive model simply moves
# the gauge further.
#
# It replaced a burn figure, the ratio of the rate spent to the rate still
# affordable. That number was right and unreadable. Its denominator shrinks as
# the budget empties, so a nearly spent window reads ×83 — a magnitude nobody has
# intuition for, and one that invites both wrong readings on sight: neither
# "83 times my budget" nor "83 times my usual speed". A projection avoids the
# problem structurally, by being denominated in the same units as the percentage
# beside it. One says where you are, the other where you are going, and no third
# quantity has to be learnt to compare them.
#
# What burn did better is worth naming, since it is what was traded away: the
# ratio was the size of the *correction*, so 1/burn of the current rate was
# exactly what fitted. "ends" is the size of the *problem*. Landing on 207 does
# not mean halving — the cut falls only on what remains, so the required brake is
# steeper. Clear beat prescriptive, because a prescription nobody can read is not
# one.
#
# It also replaced, earlier, a projected exhaustion timestamp. That is a
# different object and the objection to it still stands: a wall-clock moment
# presents as a commitment the data cannot support, and it moved with the duty
# cycle, since dividing by calendar time counts nights and weekends as
# consumption at rate zero. A percentage of budget claims no instant. It is read
# against a fixed line rather than against the clock, and it says the same thing
# whether the remaining days are working ones or not.
#
# The two rows divide the work. A 5-hour window is short enough that its average
# IS recent, so its projection responds within the hour — that is the row that
# answers "is my cut landing". The weekly one is the slow strategic number and
# lags a change of habit by design. That split is why nothing here is stored: no
# trailing window, no history, nothing to synchronise between machines.
#
# Colour marks two facts that are allowed to disagree, and keeps them apart. The
# percentage carries level, which is about headroom; "ends" carries trajectory.
# Being at 93% on the last day heading for 95 is fine, and 40% on day one heading
# for 280 is not, so folding them together would report the wrong one.
#
# Both stay silent while there is nothing to say. Neither is coloured for being
# healthy — a warning is worth less the more often it is on screen, and the row
# that needs catching is the second of those two, where a comfortable percentage
# sits beside a projection that is not. Colouring that percentage for its comfort
# put the calmer colour on the larger number and buried the warning beside it.
#
# The bar itself is never coloured: it carries proportion, which the eye reads
# from length rather than hue, and forty cells of saturation would drown both
# signals. It also already says everything a colour on the percentage could say
# about level, which is why that colour is free to mean something scarcer.
#
# ▓ rather than █ for the same reason. At roughly three-quarters ink the
# dithered block still reads as a mass whose length is easy to judge, without
# turning a wide bar into a slab.
#
# Bar width follows $COLUMNS, which Claude Code sets before running this script
# (v2.1.153+). Wider terminals buy resolution rather than whitespace.
#
# Reset times are absolute wall-clock in 24-hour form, never countdowns. The
# weekday prefix is added only when the time does not land today: a bare
# "02:15" would not say which day it meant.
#
# Three sources report the same account-wide limits, and none of them is simply
# preferred.
#
#   stdin.json      five_hour and seven_day only, from the rate-limit headers of
#                   the last API response a session made, written back here.
#                   Absent until that first response. The refresh timer re-renders
#                   stdin without updating it, so the record is stamped only when
#                   the reading actually changes — otherwise every refresh would
#                   launder a morning-old observation into a fresh one, and the
#                   age below would mean nothing. Shared across the machine, so a
#                   session that has sat idle shows what an active one was told
#                   instead of its own frozen copy.
#   usage.json      our own poll of the usage endpoint. The only source that
#                   keeps up through an idle session, and the only one carrying
#                   the per-model weekly caps.
#   ~/.claude.json  Claude Code's own copy of that same response, refreshed when
#                   /usage is opened. It cannot lead, then — but it is written by
#                   a process that can refresh an expired OAuth token, which this
#                   script cannot, so it is what survives when our own poll 401s.
#
# Utilization only rises inside a window, so any reading of a live window is a
# lower bound on the truth and the largest of them is the closest: group by
# window, take the max. That holds at any age, which is why a reading is
# discarded for only two reasons.
#
# Its window has already reset, in which case it describes a budget that no
# longer exists. That was the failure behind all of this — a five-hour row
# reporting a percentage from before the rollover, against a reset time already
# in the past.
#
# Or it is over an hour old, which is a claim about the display rather than the
# arithmetic: nothing here marks a stale number as stale, so a row that vanishes
# is the only honest way left to say that nothing recent is known. The rule
# applies to all three, which is what stamping stdin bought — an access token
# lasts eight hours and is renewed by making requests, so a session left open
# overnight wakes up unable to poll, and an unstamped stdin would quietly hold
# the rows at whatever they read before you walked away.
#
# Lining those windows up is fussier than it looks. The endpoint returns
# fractional seconds that jitter either side of the true instant, while stdin's
# integer seconds are Math.round of the same value — so truncating the fraction
# puts two readings of one window a second apart about half the time, and they
# stop comparing equal. Round instead, and match within a minute.
#
# The poll is detached: the line renders from cache and never waits on the
# network, so the timeout can be generous rather than a guess at how long is too
# long to freeze a prompt. Its file descriptors are all redirected — a
# background child holding the captured stdout open would stall the very render
# it exists to keep instant.
#
# Forks jq once per refresh, and curl at most once every five minutes — every
# thirty seconds while an attempt is failing, so a blip at startup heals on the
# next refresh instead of leaving five minutes of something older on screen.
# Times come from zsh/datetime's strftime builtin rather than date(1), which
# also sidesteps the GNU/BSD -d-vs--r split; arithmetic is zsh's own floating
# point.
#
# Requires: zsh 5.x, jq. curl only for the usage endpoint, without which the
# limits fall back to stdin's two windows. Portable across Linux and macOS.

emulate -L zsh
zmodload zsh/datetime
zmodload -F zsh/stat b:zstat
zmodload zsh/files

# Percentages arrive dotted. Under a comma-decimal locale (de_DE, fr_FR, …)
# printf would otherwise misread and misprint them.
export LC_NUMERIC=C

FIVE_HOUR=18000     # seconds in the 5-hour window
ONE_WEEK=604800     # seconds in the 7-day window

USAGE_URL='https://api.anthropic.com/api/oauth/usage'
FETCH_TTL=300       # seconds before a cached response is polled again
RETRY_TTL=30        # floor between attempts while one keeps failing
MAX_AGE=3600        # seconds a reading may lag and still be worth showing

# Catppuccin Mocha, to match kitty and vim. Peach has no slot among the ANSI 16,
# so the palette is only exact under truecolor; elsewhere fall back to the
# nearest indexed colours rather than emit escapes the terminal cannot render.
case $COLORTERM in
  truecolor|24bit)
    TEXT=$'\033[38;2;205;214;244m'    # Text      #cdd6f4
    PEACH=$'\033[38;2;250;179;135m'   # Peach     #fab387
    RED=$'\033[38;2;243;139;168m'     # Red       #f38ba8
    EMPTY=$'\033[38;2;69;71;90m'      # Surface1  #45475a
    ;;
  *)
    TEXT=$'\033[39m'                  # terminal default foreground
    PEACH=$'\033[33m'
    RED=$'\033[31m'
    EMPTY=$'\033[90m'
    ;;
esac
dim=$'\033[2m'; off=$'\033[0m'

IFS= read -rd '' input

# ─── usage endpoint ──────────────────────────────────────────────────────────
# The throttle is keyed on the age of the cache rather than of the attempt, so
# only a stale cache justifies a request: a success buys FETCH_TTL of quiet, a
# failure leaves the cache stale and comes back around in RETRY_TTL. The marker
# is what stops a dead network turning every refresh into a round trip, and it is
# shared rather than keyed on session_id — the usage it describes is account-wide,
# so concurrent sessions should pool one poll rather than each run their own.
#
# Everything after the marker is detached, and its three descriptors go to
# /dev/null: a child inheriting the captured stdout would hold the pipe open and
# block the render until curl returned, which is the whole failure being avoided.
# Since nothing waits on it, the timeout can be generous.
#
# The token is checked for expiry first because, unlike Claude Code, this script
# has no way to refresh one — the request would only spend an attempt to be told
# 401. It heals by itself: a refresh rewrites .credentials.json and the next
# attempt goes through.
#
# The response is stored raw and unkeyed. Keying it by account would mean
# wrapping the body, and buys little, since after a switch the next poll
# overwrites it anyway; the exposure is one FETCH_TTL. ~/.claude.json carries its
# own account id and is checked below, where doing so is free.

cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline
cache=$cache_dir/usage.json
marker=$cache_dir/.attempt
pub_file=$cache_dir/stdin.json

mtime() {  # REPLY = mtime of $1, or 0 when it does not exist
  local -a st
  REPLY=0
  zstat -A st +mtime -- $1 2>/dev/null && REPLY=$st[1]
}

mtime $cache;  integer api_age=$(( EPOCHSECONDS - REPLY ))
mtime $marker; integer since_try=$(( EPOCHSECONDS - REPLY ))

if (( api_age > FETCH_TTL && since_try > RETRY_TTL )); then
  mkdir -p -- $cache_dir 2>/dev/null
  : >| $marker 2>/dev/null
  {
    creds=$(jq -r '[.claudeAiOauth.accessToken // "",
                    ((.claudeAiOauth.expiresAt // 0) / 1000 | floor)] | @tsv' \
                 $HOME/.claude/.credentials.json 2>/dev/null)
    tok=${creds%%$'\t'*} exp=${creds##*$'\t'}
    if [[ -n $tok ]] && (( exp > EPOCHSECONDS )); then
      # $$-suffixed: the marker makes an overlap unlikely, not impossible.
      tmp=$cache.$$.tmp
      if curl -sS --fail --max-time 10 \
           -H "Authorization: Bearer $tok" \
           -H 'Content-Type: application/json' \
           -o $tmp -- $USAGE_URL; then
        mv -f -- $tmp $cache
      else
        rm -f -- $tmp
      fi
    fi
  } >/dev/null 2>&1 </dev/null &!
fi

api='null'
[[ -r $cache ]] && api=$(<$cache)
[[ -n $api ]] || api='null'

# --rawfile with fromjson? rather than --slurpfile: a half-written ~/.claude.json
# would otherwise fail the one jq invocation the whole line depends on.
cc_file=$HOME/.claude.json
[[ -r $cc_file ]] || cc_file=/dev/null

# What stdin last said, stamped with when it last said something new. Shared
# across the machine's sessions, so an idle one can see what an active one was
# told without waiting for the next poll.
pub='null'
[[ -r $pub_file ]] && pub=$(<$pub_file)
[[ -n $pub ]] || pub='null'

# ─── extract ─────────────────────────────────────────────────────────────────
# resets_at is epoch seconds on stdin but an ISO timestamp with fractional
# seconds and a +00:00 offset from the endpoint, which fromdateiso8601 rejects;
# normalise rather than fork date(1).
#
# The scoped weekly caps have no stdin counterpart, so they come from the two
# endpoint sources alone — but through the same merge as the other rows, so a
# reset Fable window drops out exactly like a reset five-hour one.

dir=$PWD ctx=0 model='' effort=''
five_pct=-1 five_reset=0 week_pct=-1 week_reset=0
scoped_names=() scoped_pcts=() scoped_resets=()
publish=''

assigns=$(jq -r --argjson api "$api" --rawfile cc $cc_file --argjson pub "$pub" \
             --argjson now $EPOCHSECONDS --argjson api_age $api_age \
             --argjson max_age $MAX_AGE '
  # Round, do not truncate: stdin holds Math.round of the same instant, and
  # truncating strands the two a second apart whenever the fraction is past half.
  # capture emits nothing when there is no fraction, which // absorbs.
  def iso: if . == null then 0
           else . as $t
           | ($t | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) as $base
           | (($t | capture("\\.(?<f>[0-9]+)") | .f) // "0") as $frac
           | $base + (if ("0." + $frac | tonumber) >= 0.5 then 1 else 0 end)
           end;

  # One gauge, from however many sources have an opinion. Drop what describes a
  # window that has already reset, and what is too far behind to admit to
  # showing unmarked; of the rest, keep the latest window and its largest
  # reading, which monotonicity makes the closest lower bound on the truth.
  def merge($rs):
      ($rs | map(select(. != null and .r > $now and .age <= $max_age)))
      | if length == 0 then {p: -1, r: 0}
        else (map(.r) | max) as $R
        | {p: (map(select(.r >= $R - 60)) | map(.p) | max), r: $R}
        end;

  # The published record for one window: whichever of the stored reading and
  # the one on stdin says more, stamped only when it actually says something
  # new. Re-stamping an unchanged value on every refresh would launder an old
  # observation into a fresh-looking one, which is the whole reason stdin needed
  # a timestamp in the first place.
  #
  # Rising percentage or a later window means ours is newer. The stale-and-
  # different branch is for an account switch, where the new figure can be lower
  # than the one it replaces; requiring a difference keeps it from re-stamping.
  def better($stored; $mine):
      if   $mine   == null                   then $stored
      elif $stored == null                   then $mine + {t: $now}
      elif $mine.r > $stored.r + 60          then $mine + {t: $now}
      elif $stored.r > $mine.r + 60          then $stored
      elif $mine.p > $stored.p               then $mine + {t: $now}
      elif ($now - $stored.t) > $max_age
           and ($mine.p != $stored.p or $mine.r != $stored.r)
                                             then $mine + {t: $now}
      else $stored
      end;

  . as $in
  | ($in.rate_limits // {}) as $rl
  | ($api // {})           as $a
  | ($cc | fromjson? // {}) as $j

  # Context stays on used_percentage rather than being recomputed from the token
  # counts beside it. The field is already whole, which is all this row prints, and
  # deriving it here would only introduce a way to round differently from the rest
  # of Claude Code and disagree with it by one.

  # Claude Code discards its own cache on an account mismatch; both halves of the
  # comparison sit in the one file, so honouring that costs nothing.
  | (if $j.cachedUsageUtilization.accountUuid != null
        and $j.cachedUsageUtilization.accountUuid == $j.oauthAccount.accountUuid
      then $j.cachedUsageUtilization else null end) as $c
  | ($c.utilization // {}) as $cu
  | ($now - (($c.fetchedAtMs // 0) / 1000 | floor)) as $c_age

  # Fold the stdin of this session into the shared record, and read the gauges back
  # out of that rather than off stdin directly — which is what gives the reading
  # an age, and lets a session that has been sitting idle show what an active
  # one on the same machine was told.
  | ($pub // {}) as $p0
  | better($p0.five_hour;
           (if $rl.five_hour.used_percentage == null then null
            else {p: $rl.five_hour.used_percentage, r: ($rl.five_hour.resets_at // 0)} end)) as $pub5
  | better($p0.seven_day;
           (if $rl.seven_day.used_percentage == null then null
            else {p: $rl.seven_day.used_percentage, r: ($rl.seven_day.resets_at // 0)} end)) as $pub7
  | (if $pub5 != $p0.five_hour or $pub7 != $p0.seven_day
     then {five_hour: $pub5, seven_day: $pub7} else null end) as $newpub

  | merge([
      (if $pub5 == null then null
       else {p: $pub5.p, r: $pub5.r, age: ($now - $pub5.t)} end),
      (if $a.five_hour.utilization == null then null
       else {p: $a.five_hour.utilization, r: ($a.five_hour.resets_at | iso), age: $api_age} end),
      (if $cu.five_hour.utilization == null then null
       else {p: $cu.five_hour.utilization, r: ($cu.five_hour.resets_at | iso), age: $c_age} end)
    ]) as $five
  | merge([
      (if $pub7 == null then null
       else {p: $pub7.p, r: $pub7.r, age: ($now - $pub7.t)} end),
      (if $a.seven_day.utilization == null then null
       else {p: $a.seven_day.utilization, r: ($a.seven_day.resets_at | iso), age: $api_age} end),
      (if $cu.seven_day.utilization == null then null
       else {p: $cu.seven_day.utilization, r: ($cu.seven_day.resets_at | iso), age: $c_age} end)
    ]) as $week

  # group_by sorts by the key, so the rows keep their order between renders.
  | ( [ ($a.limits[]?  | select(.kind == "weekly_scoped" and .percent != null)
         | {n: (.scope.model.display_name // "?"), p: .percent, r: (.resets_at | iso), age: $api_age}),
        ($cu.limits[]? | select(.kind == "weekly_scoped" and .percent != null)
         | {n: (.scope.model.display_name // "?"), p: .percent, r: (.resets_at | iso), age: $c_age}) ]
      | group_by(.n)
      | map({n: .[0].n} + merge(.))
      | map(select(.p >= 0)) ) as $sc

  | @sh "dir=\($in.workspace.current_dir // "?")",
    @sh "ctx=\($in.context_window.used_percentage // 0)",
    @sh "model=\($in.model.display_name // "")",
    @sh "effort=\($in.effort.level // "")",
    @sh "five_pct=\($five.p)",
    @sh "five_reset=\($five.r)",
    @sh "week_pct=\($week.p)",
    @sh "week_reset=\($week.r)",
    "scoped_names=("   + ([$sc[].n] | map(@sh)      | join(" ")) + ")",
    "scoped_pcts=("    + ([$sc[].p] | map(tostring) | join(" ")) + ")",
    "scoped_resets=("  + ([$sc[].r] | map(tostring) | join(" ")) + ")",
    @sh "publish=\($newpub | if . == null then "" else tojson end)"
' <<< $input 2>/dev/null) && eval "$assigns"

# Only when something moved, so the file keeps the time of the last real
# observation rather than of the last refresh. $$-suffixed and renamed into
# place: sessions publish independently, and a torn read here would take the
# limits down for every one of them.
if [[ -n $publish ]]; then
  mkdir -p -- $cache_dir 2>/dev/null
  tmp=$pub_file.$$.tmp
  if print -r -- $publish >| $tmp 2>/dev/null; then
    mv -f -- $tmp $pub_file 2>/dev/null || rm -f -- $tmp 2>/dev/null
  else
    rm -f -- $tmp 2>/dev/null
  fi
fi

# ─── geometry ────────────────────────────────────────────────────────────────
# The label column has to clear the widest scoped label ("Fable 7d:"); the bar
# takes what the terminal can spare, in steps of five so a cell stays a round
# fraction of the budget.

integer LBL_W=10
for n in $scoped_names; do
  (( ${#n} + 5 > LBL_W )) && LBL_W=$(( ${#n} + 5 ))
done

# Everything but the bar costs LBL_W + 38 columns: three gaps of three, four
# for the percent, "reset " and a nine-wide stamp, then "ends " and up to five
# for its value. Giving the bar less than it wants beats wrapping a five-row
# block, so the floor is coarse rather than wide.
integer BAR_W=10 cols=${COLUMNS:-0}
if (( cols > 0 )); then
  (( BAR_W = (cols - 38 - LBL_W) / 5 * 5 ))
  (( BAR_W < 5 ))  && BAR_W=5
  (( BAR_W > 40 )) && BAR_W=40
fi

# ─── pieces ──────────────────────────────────────────────────────────────────

# Headroom, on the percentage: plain under 80%, peach under 95%, red at or above.
# This says how much room is left, not how fast it is going.
#
# Plain rather than green while there is room, for the reason proj_heat gives a
# few lines down: a colour spent on the ordinary case leaves nothing louder for
# the one that matters. It matters more here than it looks. The row this display
# exists to catch is a low percentage against a high projection — and colouring
# that percentage green put the reassuring colour on the larger number, in the
# same row whose projection was red.
level() {
  local -F p=$1
  if   (( p >= 95 )); then REPLY=$RED
  elif (( p >= 80 )); then REPLY=$PEACH
  else                     REPLY=$TEXT
  fi
}

# BAR_W cells, rounded to nearest. Fill and remainder are shaded rather than
# hued, so the bar never competes with the two coloured numbers beside it.
bar() {
  local -F p=$1
  (( p < 0 ))   && p=0
  (( p > 100 )) && p=100
  local -i filled=$(( p * BAR_W / 100 + 0.5 ))   # integer assignment truncates
  local e=''
  REPLY="${TEXT}${(l:$filled::▓:)e}${EMPTY}${(l:$((BAR_W - filled))::░:)e}${off}"
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

# project <used_pct> <reset_epoch> <window_seconds>
# REPLY = percent of the budget this pace lands on at reset. Returns non-zero
# when the window is closed, or too young for the projection to mean anything.
#
# The elapsed fraction is the whole trick: the endpoint reports when the window
# resets, the length is fixed and known, so how far in you are is a subtraction
# rather than something to remember between renders. That is why no history is
# kept and why every machine computes the same figure from the same reading.
#
# The 2% floor carries more weight here than it did under a ratio. Three minutes
# into a five-hour window one message can read 2% used, which extrapolates to
# 200% — arithmetically right and worthless, being a straight line drawn through
# almost no data. Below the floor the column is absent rather than wrong.
#
# No sentinel for an exhausted budget. A projection stays finite and keeps its
# meaning at every level of use: 100% used simply projects to a large number,
# which is the honest reading of having spent the lot early.
project() {
  local -F u=$1
  local -i reset=$2 len=$3
  local -i remaining=$(( reset - EPOCHSECONDS ))
  local -i elapsed=$(( len - remaining ))
  (( remaining > 0 ))               || return 1
  (( elapsed > 0 ))                 || return 1
  (( 1.0 * elapsed / len >= 0.02 )) || return 1
  REPLY=$(( u * len / elapsed ))
}

# Trajectory, on the projection. Plain rather than green while it lands under
# budget: a healthy pace is the absence of a warning, and spending a colour on it
# would leave nothing louder for the case that matters. A band rather than a bare
# threshold at 100, since landing 2% over is noise.
proj_heat() {
  local -F v=$1
  if   (( v > 120 )); then REPLY=$RED
  elif (( v >= 80 )); then REPLY=$PEACH
  else                     REPLY=$TEXT
  fi
}

# Whole numbers, for the reason row() gives: nothing upstream carries a tenth
# worth printing. Clamped so a projection taken early — when the elapsed fraction
# is small enough to make the quotient large — cannot outgrow its column.
proj_fmt() {
  local -F v=$1
  if (( v > 999 )); then REPLY='>999%'
  else                   printf -v REPLY '%.0f%%' $v
  fi
}

# One row of the grid: label, shaded bar, right-aligned percent in level colour.
#
# Whole numbers. Nothing upstream carries a tenth to print: the rate-limit
# headers report two decimals of a fraction — a header of 0.07 is where the
# 7.000000000000001 in stdin.json comes from — the usage endpoint sends integers,
# and the context percentage is a whole number too. A decimal on any of them
# would be a digit that could only ever be zero.
#
# Three wide, so 7, 49 and 100 all end on the same column and the per-cent signs
# line up down the block. That is also three columns narrower than a tenth would
# need, which is three more cells of bar, and it pulls the number back toward the
# bar it belongs to rather than leaving it adrift in whitespace.
row() {
  local lbl=$1 pct_str c b
  local -F p=$2
  printf -v pct_str '%3.0f%%' $p
  level $p; c=$REPLY
  bar   $p; b=$REPLY
  printf -v REPLY '%s%-*s%s%s   %s%s%s' $dim $LBL_W $lbl $off $b $c $pct_str $off
}

# A rate-limit row: the grid, plus reset and the projection. Returns non-zero
# when the limit is absent, as both are under API-key auth and before the first
# response.
limit_row() {
  local lbl=$1 line pv pc ps padded
  local -F p=$2
  local -i rst=$3 len=$4
  (( p >= 0 )) || return 1
  row $lbl $p
  line=$REPLY
  if (( rst > 0 )); then
    if project $p $rst $len; then
      pv=$REPLY
      proj_heat $pv; pc=$REPLY
      proj_fmt  $pv; ps=$REPLY
      # Pad the reset stamp only when a column follows it, so rows without one
      # do not carry invisible trailing whitespace.
      stamp $rst; printf -v padded '%-9s' $REPLY
      line+="   ${dim}reset${off} ${padded}   ${dim}ends${off} ${pc}${ps}${off}"
    else
      stamp $rst
      line+="   ${dim}reset${off} ${REPLY}"
    fi
  fi
  REPLY=$line
}

# ─── render ──────────────────────────────────────────────────────────────────

# %~ — absolute path with $HOME collapsed to ~
pretty_dir=${dir/#$HOME/\~}

printf -v out '%s%-*s%s%s' $dim $LBL_W 'Path:' $off $pretty_dir

row 'Context:' $ctx
out+=$'\n'$REPLY
# The context window belongs to the active model, so the model names itself here
# rather than spending a row of its own.
if [[ -n $model ]]; then
  out+="   ${TEXT}${model}${off}"
  [[ -n $effort ]] && out+=" ${dim}($effort)${off}"
fi

limit_row '5-hour:' $five_pct $five_reset $FIVE_HOUR && out+=$'\n'$REPLY
limit_row 'Weekly:' $week_pct $week_reset $ONE_WEEK  && out+=$'\n'$REPLY

# Scoped weekly caps run alongside the overall one rather than replacing it:
# both are live, and either can be the one that stops you.
#
# C-style rather than {1..$#…}: a brace range counts *down* when the array is
# empty, which would render two garbage rows offline.
for (( i = 1; i <= $#scoped_names; i++ )); do
  limit_row "$scoped_names[i] 7d:" $scoped_pcts[i] $scoped_resets[i] $ONE_WEEK \
    && out+=$'\n'$REPLY
done

print -rn -- $out
