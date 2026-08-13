#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: gemini-ask.sh <root> <brief-file> [--model M] [--write]" >&2
    exit 64
}

[ $# -ge 2 ] || usage
root=$1
brief=$2
shift 2

model="gemini-3.7-flash"
effort="high"
write_flags=()

while [ $# -gt 0 ]; do
    case $1 in
        --model)
            [ $# -ge 2 ] || usage
            model=$2
            shift 2
            ;;
        --write)
            write_flags=("--dangerously-skip-permissions")
            shift
            ;;
        *) usage ;;
    esac
done

# If model contains an effort specifier like gemini-3.7-flash:high
if [[ "$model" == *:* ]]; then
    effort="${model#*:}"
    model="${model%:*}"
fi

command -v agy >/dev/null 2>&1 || {
    echo "gemini-ask: agy is not installed" >&2
    exit 69
}
[ -d "$root" ] || {
    echo "gemini-ask: not a directory: $root" >&2
    exit 66
}
if [ ! -f "$brief" ] || [ ! -r "$brief" ] || [ ! -s "$brief" ]; then
    echo "gemini-ask: brief must be a readable non-empty file: $brief" >&2
    exit 66
fi

out=$HOME/.claude/gemini
mkdir -p "$out"
label=$(basename -- "$brief")
label=${label%.*}
label=${label:-brief}
run=$out/$label-$(date +%Y%m%dT%H%M%S)-$$

brief_content=$(cat "$brief")

status=0
(
    cd "$root" || exit 66
    agy --model "$model" --effort "$effort" "${write_flags[@]}" --print "$brief_content"
) > "$run.answer.md" 2> "$run.err" || status=$?

echo "gemini-ask: root=$root brief=$brief run=$run" >&2

if [ ! -s "$run.answer.md" ]; then
    echo "gemini-ask: agy exited $status without writing an answer" >&2
    tail -n 20 "$run.err" >&2
    if [ "$status" -eq 0 ]; then
        status=70
    fi
    exit "$status"
fi

cat "$run.answer.md"

if [ "$status" -ne 0 ]; then
    echo "gemini-ask: agy exited $status after writing an answer; treat it as partial" >&2
fi
exit "$status"
