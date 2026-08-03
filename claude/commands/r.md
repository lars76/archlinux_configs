---
description: Codex + Claude review or independent ideas, planned before it runs
argument-hint: "what you want looked at, or nothing"
disable-model-invocation: true
disallowed-tools: Edit, Write, NotebookEdit
allowed-tools: Bash(codex exec:*), Bash(codex review:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(mkdir:*), Bash(cp:*), Bash(command -v:*), Bash(date:*), Bash(jq:*), Bash(tee:*), Bash(hostname:*), Read, Grep, Glob, Agent, AskUserQuestion, Workflow, Monitor
---

## Context

- Branch: !`git branch --show-current 2>/dev/null || echo "not a git repo"`
- Status: !`git status --short 2>/dev/null | head -20`
- Diff stat: !`git diff HEAD --stat 2>/dev/null | tail -5`
- Codex: !`command -v codex >/dev/null && codex --version || echo "NOT INSTALLED"`
- Codex trusts cwd: !`grep -q "\"$PWD\"" ~/.codex/config.toml 2>/dev/null && echo yes || echo "no, needs --skip-git-repo-check"`

## Request

$ARGUMENTS

## Your task

Second opinions from Codex and a fresh-context Claude, consolidated into one
verified, actionable report. Make a todo list from the steps below first.
Fixed defaults, never offered as menu choices: Codex on gpt-5.6-sol, the Claude
reviewer on opus, verifiers on sonnet. A plain-language override ("try terra",
"skip Codex") is honored for this run only.

### 1. Infer the mode

From session state (concluded work vs in flight), not from git:

| Mode | Reviewers get |
|---|---|
| review | the changed files or named target; hunt problems |
| improve | everything, including this session's analysis; the whole design is the subject |
| next | results and code; this session's analysis and next steps are withheld |
| assess | a written summary only, plus web search |

Resolve ambiguity narrow: assess before next before improve. `next`/`assess` are
blind: copy ONLY the granted files to `~/.claude/scratch/r-<project>-<ts>/` and
point the reviewers at the copy. The copy's file list goes on the plan in full;
that list is the withholding, so it is never shortened.

### 2. Offer the run (AskUserQuestion, inside this turn)

Above the question, a plan of about three sentences: what gets read, what is
withheld if blind (the full file list), what comes back. Never print the
reviewer commands to the user.

2 to 4 options, each a whole run described by effect and cost, never by mode
name: first the run as planned; always the other half of the bug-hunt vs
blind-ideas split, saying how blind; optionally a different scope and/or one
option only this project suggests, pointing at something specific you noticed
while reading. Generic angles (security, coverage, performance) are banned. An
option you would not run yourself is worse than an empty slot; never pad. No
cancel option. An answer via Other means re-render and ask again.

### 3. Launch both reviewers

Record `git rev-parse HEAD` and `git status --porcelain` as the starting-state
record (reviewers read live files; report drift at consolidation). Write ONE
reviewer prompt and give it to both, only the root differing. Output contract in
the prompt: findings as file:line, one-line claim, one-line rationale, then the
files actually read. State read-only in the prompt even though it is enforced.

Codex, in background, capture teed:

    codex exec -s read-only --ephemeral --json -m gpt-5.6-sol --skip-git-repo-check \
      -C <root> -o ~/.claude/reviews/<project>-<ts>.md "<prompt>" < /dev/null \
      | tee ~/.claude/reviews/<project>-<ts>.codex.jsonl

Load-bearing details: the prompt is the positional argument and stdin is
/dev/null (piped stdin is appended to the prompt; empty stdin with no argument
means it runs on nothing); never --add-dir (it grants writes); --json plus tee
captures the turn.completed event that carries usage and signals completion.
If Codex is not installed, say so and offer a Claude-only run.

Claude reviewer: one Agent, subagent_type Explore, model opus, same prompt and
root, in background. Save its returned text VERBATIM (heredoc into tee, no
reformatting) as `~/.claude/reviews/<project>-<ts>.claude.md`.

NO deadline. Wait for Codex's turn.completed (Monitor, generous timeout) and the
agent's completion notification. A reviewer that errors goes under `failures`
and the survivor is consolidated alone. Never abort a slow reviewer.

### 4. Dedup, then verify

Merge semantic duplicates across both reviewers before verifying anything; a
cross-reviewer merge is corroboration, and corroborated <= codex + claude -
deduped, always. Tag every item by origin. In blind modes translate sandbox
paths back to project paths before anything is reported.

In `review`/`improve`, verify every deduped finding:

- Doc-consistency claims (text says X, artifact does Y): adjudicate yourself by
  citing both locations, no agent; count them as adjudicated and score them with
  the same two numbers. EXCEPTION: when this session authored the changes under
  review, agents verify everything.
- Everything else: `Workflow({scriptPath: "~/.claude/workflows/r-verify.js",
  args: {root, mode, exclusions, findings: [{id, file, line, claim, scenario,
  origin}]}})`. This skill instructing the call is the Workflow opt-in. The
  script groups findings by location, runs one sonnet refuter per location with
  the rubric (which lives there, not here), and returns {id, confidence 0-100,
  severity high|medium|low, evidence} per finding. Ids that come back unscored
  (their agent died) are reported as WEAK 25 rather than dropped.

Exclusions (pass as args.exclusions, and apply them when adjudicating):
looks-like-a-bug-but-is-not; nits a senior engineer would not raise; anything a
linter, typechecker, or compiler catches; general quality complaints (coverage,
docs, broad security) unless the project requires them; issues the code
explicitly silences; likely-intentional changes. `review` additionally excludes
pre-existing issues and real issues on unmodified lines. `improve` excludes
neither, since the existing design is the subject.

In `next`/`assess` do not score. Label each proposal NEW / ALREADY TRIED (when,
and what happened) / RULED OUT (which constraint) / UNCLEAR, and group by who
raised it; what only one reviewer raised is the yield.

### 5. Report

Findings ordered by severity then confidence, one line each:

    HIGH 95 [both] file:line - claim

with a body of at most 3 lines only when the mechanism is not evident from the
claim. No code-quoting requirement, no mandatory fix line. Sub-80 entries stay
in the list marked WEAK: the exclusions filter relevance, confidence only marks.
Then Filtered, one line per killed finding: score plus the refutation that sank
it. Report what each reviewer read, note corroborations and disagreements
(disagreement is the product, never average it), and name any reviewed file that
changed since the starting-state record.

End with **My take**: with full session context, which findings you would fix
and in what order, what you would ignore and why, anything you noticed that
neither reviewer raised, and the offer to act. /r itself never edits; fixes are
the next request.

### 6. Log the run

Append EXACTLY one line to `~/.claude/reviews/log.jsonl` with `tee -a`. Codex
usage from `jq -c 'select(.type=="turn.completed").usage' <run>.codex.jsonl |
tail -1`, null when absent (a wrong number is worse than a missing one). Keep
every key in every mode. Fields, counted ones defined once here:

- ts (`date -Is`), host (`hostname -s`), project, mode, mode_corrected (user
  changed the inferred mode), gate (the chosen option's label text), lens,
  sandbox (a blind copy was built)
- codex {model, usage, total: input+output}; claude {reviewer, verifier}
- findings {codex, claude: items raised, before dedup; deduped: after merging,
  never more than codex+claude; adjudicated: verified without agents; reported:
  confidence >= 80; weak: under 80 but shown; filtered: killed}, and
  reported + weak + filtered = deduped
- filtered_by {codex, claude, both}: origins of the killed findings
- corroborated (cross-reviewer merges), disagreements (opposite conclusions on
  one subject), confidence (every score, descending, including killed), severity
  (one per reported finding, report order), duration_s (gate approval to log
  write), failures (reviewers that errored), notes: null always, the user's slot
- next/assess: confidence [], severity [], proposal count in reported, filtered 0

Append-only; if the write fails, say so and keep the report.

### Rules that never bend

- No reviewer implements: Codex is held by -s read-only, Claude reviewers by
  Explore. You never implement either; disallowed-tools enforces it this turn.
- Scratch scripts on request only: a writable dir under ~/.claude/scratch/,
  shown loudly on the plan (workspace-write for Codex, a general-purpose agent
  for Claude).
- The sandbox copy is real withholding, not a security boundary; never claim
  more isolation than exists.
- Decline what tooling answers better: types, formatting, "does it pass".
