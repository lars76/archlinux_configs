#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: codex-ask.sh <root> <brief-file>" >&2
    exit 64
fi

root=$1
brief=$2

command -v codex >/dev/null 2>&1 || {
    echo "codex-ask: codex is not installed" >&2
    exit 69
}
[ -d "$root" ] || {
    echo "codex-ask: not a directory: $root" >&2
    exit 66
}
if [ ! -f "$brief" ] || [ ! -r "$brief" ] || [ ! -s "$brief" ]; then
    echo "codex-ask: brief must be a readable non-empty file: $brief" >&2
    exit 66
fi

out=$HOME/.claude/codex
mkdir -p "$out"
label=$(basename -- "$brief")
label=${label%.*}
label=${label:-brief}
run=$out/$label-$(date +%Y%m%dT%H%M%S)-$$

status=0
codex exec -s read-only --skip-git-repo-check --color never \
    -C "$root" -o "$run.answer.md" --json - \
    < "$brief" > "$run.jsonl" 2> "$run.err" || status=$?

echo "codex-ask: root=$root brief=$brief run=$run" >&2

if [ ! -s "$run.answer.md" ]; then
    echo "codex-ask: codex exited $status without writing a final message" >&2
    tail -n 20 "$run.err" >&2
    if [ "$status" -eq 0 ]; then
        status=70
    fi
    exit "$status"
fi

cat "$run.answer.md"

if [ "$status" -ne 0 ]; then
    echo "codex-ask: codex exited $status after writing an answer; treat it as partial" >&2
fi
exit "$status"
