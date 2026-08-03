---
description: Propose the full git sequence, in this repo's own convention
argument-hint: "anything to steer the message or grouping, or nothing"
disable-model-invocation: true
disallowed-tools: Edit, Write, NotebookEdit, Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git merge:*), Bash(git checkout:*), Bash(git reset:*), Bash(git rebase:*)
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git tag:*), Bash(git rev-list:*), Bash(git rev-parse:*), Bash(git config:*), Bash(git describe:*), Bash(git symbolic-ref:*)
---

## Tree

- Status: !`git status --short 2>/dev/null | head -40 || true`
- Diff: !`git diff --stat 2>/dev/null | tail -30 || true`

## Position

- Branch: !`b=$(git branch --show-current 2>/dev/null); echo "${b:-DETACHED HEAD}" || true`
- Upstream: !`git rev-parse --abbrev-ref @{u} 2>/dev/null || echo none`
- Remotes: !`git remote -v 2>/dev/null | awk '$3=="(fetch)"{print $1}' | paste -sd, || echo none`
- Remote branches: !`git branch -r 2>/dev/null | grep -v HEAD | sed 's|^ *[^/]*/||' | sort -u | paste -sd, | cut -c1-100 || true`
- HEAD is a descendant of the upstream ref: !`git rev-parse -q --verify @{u} >/dev/null 2>&1 && (git merge-base --is-ancestor @{u} HEAD 2>/dev/null && echo yes || echo "no, local history was rewritten") || echo "n/a"`
- Me: !`git config user.email 2>/dev/null || true`
- Identity this commit would carry: !`echo "$(git config user.name 2>/dev/null) <$(git config user.email 2>/dev/null)>" || true`
- Identity comes from: !`git config --show-origin user.email 2>/dev/null | sed 's|\t.*||; s|^file:||' || echo unknown`
- Addresses this author name has used in this repo: !`n=$(git config user.name 2>/dev/null); [ -n "$n" ] && git log -300 --format='%an|%ae' 2>/dev/null | awk -F'|' -v n="$n" '$1==n{print $2}' | sort -u | paste -sd, || true; echo "${x:-}" | head -0; true`
- Commits signed by default: !`git config commit.gpgsign 2>/dev/null || echo "no, commit.gpgsign is unset"`
- Signed-off-by, of last 50 non-merge commits: !`git log -50 --no-merges --format='%(trailers:key=Signed-off-by,valueonly,separator=%x2C)' 2>/dev/null | grep -c . || true` of !`git log -50 --no-merges --format=%H 2>/dev/null | wc -l || true`
- Assisted-by, same 50: !`git log -50 --no-merges --format='%(trailers:key=Assisted-by,valueonly,separator=%x2C)' 2>/dev/null | grep -c . || true`
- Unmerged paths: !`git diff --name-only --diff-filter=U 2>/dev/null | head -20 || true`
- Operation in progress: !`d=$(git rev-parse --git-dir 2>/dev/null); o=$(ls -d "$d"/MERGE_HEAD "$d"/rebase-merge "$d"/rebase-apply "$d"/CHERRY_PICK_HEAD "$d"/REVERT_HEAD 2>/dev/null | sed 's|.*/||' | paste -sd,); echo "${o:-none}" || true`
- Local upstream ref: !`git rev-parse @{u} 2>/dev/null || echo none`
- Remote head right now: !`u=$(git rev-parse --abbrev-ref @{u} 2>/dev/null) && timeout 10 git ls-remote "${u%%/*}" "refs/heads/${u#*/}" 2>/dev/null | cut -f1 || echo "unavailable"`

## Convention

- Typed prefixes, last 300: !`git log -300 --format=%s 2>/dev/null | grep -cE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: ' || true`
- Scoped prefixes, last 300: !`git log -300 --format=%s 2>/dev/null | grep -E '^[a-z0-9][a-z0-9/_.-]*: [A-Za-z]' | grep -cvE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: ' || true`
- Subject length, median of 100: !`git log -100 --format=%s 2>/dev/null | awk '{print length}' | sort -n | awk '{a[NR]=$1} END{print a[int(NR/2)]}' || true`
- Unprefixed subjects capitalised: !`git log -300 --format=%s 2>/dev/null | grep -vE '^[a-z0-9][a-z0-9/_.()-]*: ' | grep -cE '^[A-Z]' || true` of !`git log -300 --format=%s 2>/dev/null | grep -cvE '^[a-z0-9][a-z0-9/_.()-]*: ' || true`
- Prefixed subjects capitalised after the colon: !`git log -300 --format=%s 2>/dev/null | grep -E '^[a-z0-9][a-z0-9/_.()-]*: .' | sed 's/^[^:]*: //' | grep -cE '^[A-Z]' || true` of !`git log -300 --format=%s 2>/dev/null | grep -cE '^[a-z0-9][a-z0-9/_.()-]*: .' || true`
- Recent subjects: !`git log -12 --format='%s' 2>/dev/null || true`

## Flow

- Commits: !`git rev-list --count HEAD 2>/dev/null || echo 0` total, !`git rev-list --count --merges HEAD 2>/dev/null || echo 0` merges
- Unpushed commits: !`git rev-parse -q --verify @{u} >/dev/null 2>&1 && git rev-list --count @{u}..HEAD 2>/dev/null || echo "n/a"`
- Recent merges, author email first: !`git log --merges -5 --format='%ae | %s' 2>/dev/null | cut -c1-90 || true`
- Tags: !`git tag 2>/dev/null | wc -l || true` total, latest !`git tag --sort=-creatordate 2>/dev/null | head -4 | paste -sd, || true`
- Since last tag: !`t=$(git describe --tags --abbrev=0 2>/dev/null) && git rev-list --count "$t..HEAD" 2>/dev/null || echo "no tags"`
- Commits between the last two tags: !`set -- $(git tag --sort=-creatordate 2>/dev/null | head -2); [ -n "$2" ] && git rev-list --count "$2..$1" 2>/dev/null || echo "fewer than two tags"`

## Request

$ARGUMENTS

## Your task

Print one complete git sequence for the current changes, in this repo's own convention.
Do not run it. This command is read-only by construction, so propose and stop.

**Always produce output.** Every path below ends in something printed. Returning nothing
is never correct.

The tree is clean only when `Status` is empty. An empty `Diff` does not mean clean:
untracked files never appear in `git diff --stat`, so a repo whose changes are all new
files shows an empty diff and a `Status` full of `??` entries. Those are the changes.

If `Status` is empty and `Unpushed commits` is 0 or n/a, say so in one line and stop.
If the tree is clean but there are unpushed commits, there is nothing to commit and the
answer is the push alone: say what is waiting and propose it.

If `Branch` is `DETACHED HEAD`, stop. A commit there is reachable from nothing and is
lost on the next checkout. Say so, and offer `git switch -c <name>` to keep the work.

If `Commits` is 0 this is the first commit in an empty repository. There is no history
to read a convention from, so use the defaults: a capitalised unprefixed subject, and
`git add` for everything that is untracked.

### Read the convention from the context above

**Message style**, first match wins:

1. Typed count is 30% or more of 300 → typed prefixes. Look at the recent subjects to
   see whether scopes are used: `fix(asusd):` or bare `fix:`.
2. Scoped count is 30% or more → `subsystem: description`, where the subsystem comes
   from the changed paths and matches the granularity in the recent subjects.
3. Otherwise → free text, matching the recent subjects for mood.

**Capitalisation** comes from the counted figures above, never from whichever recent
subjects you happened to read. The defaults, when a repo has too little history to
count: capitalise an unprefixed subject, because it is a standalone sentence, and
lowercase the description after a prefix colon, because it continues one. A repo that
disagrees wins: GNOME projects capitalise after the colon in 100% of subjects.

Match the median subject length. **One line per commit, 60 characters maximum, no body.**
Bodies only if the request above explicitly asks for one.

**Grouping** is at file level. Split unrelated changes into separate commits. When one
file's changes span two groups, put it with the dominant group and say so in the caveat.
Never propose `git add -p`: interactive git does not work here.

**Stop first if the repo is mid-operation.** If `Unmerged paths` is non-empty or
`Operation in progress` is anything but `none`, that is the whole answer. Report the
state, say which files are unmerged, and stop. Do not propose commits on top of it.
Resolving a conflict is a conversation, not a command list: offer to walk through it.

**Check the remote before proposing a push.** If `Remote head right now` differs from
`Local upstream ref`, someone pushed since your last fetch and `git push` will be
rejected. Put `git pull --rebase` before the push in the proposal, and say in one
sentence that if the rebase reports conflicts you should stop there and work through
them rather than pressing on. Rebase rather than merge, because these commits have not
been shared yet. If `Remote head right now` is `unavailable`, say the check could not
run and leave the push line as-is.

**Merge** only when all four hold: the current branch is not the main branch, merges
exist, the recent merge authors match `Me` above, and there is a branch to merge into.

**Pull request** only when the current branch is not the main branch and merges exist
that are not yours. On the main branch there is nothing to open a pull request from, so
propose neither a merge nor a PR: the change simply lands with a push.

**Tag** only when tags exist and `Since last tag` has reached the cadence. The cadence is
`Commits between the last two tags`, which measures the most recent release interval.
Do not use `total commits / tag count`: with a single tag that ratio equals the whole
history and can never be exceeded, so a one-tag repo would never look due. When the
figure reads `fewer than two tags` there is no interval to judge from, so say that and
propose no tag unless the request asks for one. Match the existing tag format exactly, including whether
it carries a `v`. Reproduce the full sequence the history shows for previous releases,
not just the tag: if earlier releases were merged back into an integration branch
afterwards, that step belongs in the proposal too. With typed prefixes, a `feat:` in the range means a minor bump and
`BREAKING CHANGE:` a major one; otherwise propose a patch bump and say it is a guess.
Below cadence, one sentence saying a release is not due, or nothing.

**Push.** When an upstream exists, `git push`. When `Upstream` is none but `Remotes`
names one, this branch has never been pushed, so use `git push -u <remote> <branch>`
with the remote's real name, which is often but not always `origin`. When there is no
remote at all, omit the push entirely.

**Rewritten history.** If `HEAD is a descendant of the upstream ref` says the local
history was rewritten, an ordinary push is rejected and `git pull --rebase` is the wrong
fix: it would replay the remote's copy of your old commits back on top. This is the
amend-or-rebase-after-push case. On your own branch that nobody else builds on,
`git push --force-with-lease` is the answer, and never plain `--force`. On a shared
branch, or the main branch, do not propose a force push at all: say the history diverged
and that it needs a conversation.

### Output

Markdown, rendered. Four parts, no other headings.

```
## What would be committed

<the git diff --stat block, verbatim, in a plain fence>

Untracked: `a`, `b`, `c`
```

The untracked line is separate because `git diff --stat` cannot see untracked files.
Omit it when there are none. List the entries from `git status --short` that start with
`??`. When `Diff` is empty and everything is untracked, drop the fence entirely and give
the untracked list alone: an empty code block says nothing.

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

**Trailers and identity.** Name the identity the commit would carry in the Repo
paragraph, as `Name <email>`, and say where it comes from when that is the global
`~/.gitconfig` rather than the repository's own config. A commit made under the wrong
address is silent at the time and awkward to correct later, so it is worth one clause.

Compare it against `Addresses this author name has used in this repo`. If that list is
non-empty and does not contain the current address, the same person has committed here
under a different one, which usually means a work and personal account have been mixed
up. Say so plainly and give `git config user.email <the one the history uses>` before
the proposal. If the list is empty you have simply never committed here, which is a
normal first contribution and not worth mentioning.

If `Signed-off-by` covers most of the last 50 non-merge commits, this project requires
the Developer Certificate of Origin and a patch without it is rejected. Use
`git commit -s` in the proposal rather than a plain `git commit`.

If `Assisted-by` appears in the history, the project expects coding-assistant use to be
declared, and omitting it breaks their policy rather than protecting your privacy. The
Linux kernel documents the format in `Documentation/process/coding-assistants.rst` as
`Assisted-by: AGENT_NAME:MODEL_VERSION`. Follow whatever shape the existing trailers
use, and add it with `--trailer`.

Otherwise never volunteer attribution: no `Co-Authored-By`, no generated-with footer, no
mention of Claude anywhere in the message. The exception above is the project's rule,
not ours.

Never use the phrase "conventional commits" in the output.
