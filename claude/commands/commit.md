---
description: Propose the full git sequence, in this repo's own convention
disable-model-invocation: true
disallowed-tools: Edit, Write, NotebookEdit
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git tag:*), Bash(git rev-list:*), Bash(git rev-parse:*), Bash(git config:*), Bash(git describe:*), Bash(git symbolic-ref:*)
---

## Tree

- Status: !`git status --short 2>/dev/null | head -40`
- Diff: !`git diff --stat 2>/dev/null | tail -30`

## Position

- Branch: !`git branch --show-current 2>/dev/null || echo "not a git repo"`
- Upstream: !`git rev-parse --abbrev-ref @{u} 2>/dev/null || echo none`
- Remote branches: !`git branch -r 2>/dev/null | grep -v HEAD | sed 's|.*origin/||' | sort -u | paste -sd, | cut -c1-100`
- Me: !`git config user.email 2>/dev/null`

## Convention

- Typed prefixes, last 300: !`git log -300 --format=%s 2>/dev/null | grep -cE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: '`
- Scoped prefixes, last 300: !`git log -300 --format=%s 2>/dev/null | grep -E '^[a-z0-9][a-z0-9/_.-]*: [A-Za-z]' | grep -cvE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: '`
- Subject length, median of 100: !`git log -100 --format=%s 2>/dev/null | awk '{print length}' | sort -n | awk '{a[NR]=$1} END{print a[int(NR/2)]}'`
- Recent subjects: !`git log -12 --format='%s' 2>/dev/null`

## Flow

- Commits: !`git rev-list --count HEAD 2>/dev/null` total, !`git rev-list --count --merges HEAD 2>/dev/null` merges
- Recent merges: !`git log --merges -5 --format='%an | %s' 2>/dev/null | cut -c1-90`
- Tags: !`git tag 2>/dev/null | wc -l` total, latest !`git tag --sort=-creatordate 2>/dev/null | head -4 | paste -sd,`
- Since last tag: !`t=$(git describe --tags --abbrev=0 2>/dev/null) && git rev-list --count "$t..HEAD" 2>/dev/null || echo "no tags"`

## Request

$ARGUMENTS

## Your task

Print one complete git sequence for the current changes, in this repo's own convention.
Do not run it. This command is read-only by construction, so propose and stop.

If the tree is clean, say so in one line and stop.

### Read the convention from the context above

**Message style**, first match wins:

1. Typed count is 30% or more of 300 → typed prefixes. Look at the recent subjects to
   see whether scopes are used: `fix(asusd):` or bare `fix:`.
2. Scoped count is 30% or more → `subsystem: description`, where the subsystem comes
   from the changed paths and matches the granularity in the recent subjects.
3. Otherwise → free text. Match the recent subjects for capitalisation and mood.

Match the median subject length. **One line per commit, 60 characters maximum, no body.**
Bodies only if the request above explicitly asks for one.

**Grouping** is at file level. Split unrelated changes into separate commits. When one
file's changes span two groups, put it with the dominant group and say so in the caveat.
Never propose `git add -p`: interactive git does not work here.

**Merge** only when all three hold: the current branch is not the main branch, merges
exist, and the recent merge authors match `Me` above. Otherwise you are a contributor,
so propose `git push origin <branch>` and `gh pr create` and never a merge.

**Tag** only when tags exist and `Since last tag` has reached the cadence
(`total commits / tag count`). Match the existing tag format exactly, including whether
it carries a `v`. With typed prefixes, a `feat:` in the range means a minor bump and
`BREAKING CHANGE:` a major one; otherwise propose a patch bump and say it is a guess.
Below cadence, one sentence saying a release is not due, or nothing.

**Push** is included when an upstream exists. When `Upstream` is none, there is nothing
to push, so omit the line entirely.

### Output

Markdown, rendered. Four parts, no other headings.

```
## What would be committed

<the git diff --stat block, verbatim, in a plain fence>

Untracked: `a`, `b`, `c`
```

The untracked line is separate because `git diff --stat` cannot see untracked files.
Omit it when there are none. List the entries from `git status --short` that start with
`??`.

```
## Repo

<two or three sentences: branches, commit and merge and tag counts, the detected
message style with its numbers, and what the flow is. State it as fact, not as a
recommendation.>
```

```
## Proposed

<one fenced sh block containing every command in order: add, commit, add, commit,
push, and merge if it applies>
```

Then one sentence introducing the alternative, and a short fence containing **only the
lines that change**, never the whole sequence again:

- If the detected style is free text or scoped: offer typed prefixes.
- If the detected style is already typed: offer plain messages instead.

If a tag applies, add one sentence and a short fence for it after that. Introduce it
with a sentence, not a heading.

Close with any caveat as a plain sentence: a file riding along in the wrong commit, a
stale branch, a guessed version bump. No caveat means no closing line.

Never mention Claude, never add a `Co-Authored-By` or generated-with footer, and never
use the phrase "conventional commits" in the output.
