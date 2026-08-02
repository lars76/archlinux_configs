---
description: Codex + Claude review or independent ideas, planned before it runs
argument-hint: "what you want looked at, or nothing"
disable-model-invocation: true
disallowed-tools: Edit, Write, NotebookEdit
allowed-tools: Bash(codex exec:*), Bash(codex review:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(mkdir:*), Bash(cp:*), Bash(command -v:*), Bash(date:*), Bash(jq:*), Bash(tee:*), Read, Grep, Glob, Agent, AskUserQuestion
---

## Context

- Branch: !`git branch --show-current 2>/dev/null || echo "not a git repo"`
- Status: !`git status --short 2>/dev/null | head -20`
- Diff stat: !`git diff HEAD --stat 2>/dev/null | tail -5`
- Codex: !`command -v codex >/dev/null && codex --version || echo "NOT INSTALLED"`
- Codex trusts cwd: !`grep -q "\"$PWD\"" ~/.codex/config.toml 2>/dev/null && echo yes || echo "no — needs --skip-git-repo-check"`

## Request

$ARGUMENTS

## Your task

Get a second opinion from Codex and from a fresh-context Claude, then consolidate
the two into one verified answer. Five steps.

**Make a todo list first.** This is a multi-step procedure held in prose, and
prose steps are what get silently skipped under pressure — particularly the
approval gate and the dedup pass.

**Never end your turn between step 2 and step 5.** The `allowed-tools` grant above
lasts only for the turn that invoked `/r`; it clears the moment the user sends
another message. Approval therefore happens through `AskUserQuestion`, which
resolves *inside* this turn. If you stop and wait for the user to type "go", every
permission below is gone and the run will prompt for each one.

### Step 1 — Infer the mode

The primary signal is **whether the work is concluded or in flight**, read from
this session rather than from git. Git state is only a proxy.

| Session state | Mode | Grants |
| --- | --- | --- |
| Concluded — "that works", tests pass, edits stopped changing | `review` | the changed files or the named target; find problems |
| "improve my current X" — the wording presupposes the design | `improve` | everything, including your own prior analysis |
| In flight — experiments running, you proposed the current direction | `next` | results and code; **withholds** your analysis and next steps |
| Approach under discussion, nothing built | `assess` | nothing but a written summary, plus web search |

Secondary tells from the request text: a named path → `review`; "next" or "try"
→ `next`; "google", "what do others do", "is this standard" → `assess`; no
artifact mentioned at all → `assess`.

With no request text, infer entirely from session state. If there is genuinely
nothing to go on — fresh session, clean tree, no prior discussion — ask one
`AskUserQuestion` rather than invent a scope.

Resolve ambiguity **narrow**: `assess` before `next` before `improve`. Too little
context is recoverable by running again; independence quietly destroyed is not,
because the result still looks like an independent opinion.

`next` and `assess` are blind modes. Withholding in those is enforced physically
in step 3, not by asking a reviewer to look away.

### Step 2 — Render the plan, then gate on it

Write it as an ordinary markdown plan — the same kind of thing plan mode
produces, rendered as prose rather than as an ASCII block. There is no template
and no required structure. Use whatever headings, bold, and short paragraphs make
*this* run clear at a glance.

Two things have to be in it:

- **Which models are doing what.** The Codex command as it will actually be
  invoked, and the Claude reviewer's model and root. The command is both the
  disclosure of what runs and the only documentation its flags need, so show it
  as it will really be called; if the prompt is too long to inline, say so rather
  than printing a placeholder that looks like the real thing.
- **What will be done.** What gets read, what is being hunted for, and what comes
  back. In a blind mode, what the reviewers will *not* see is part of what will be
  done, and that list must be complete — the omissions are the withholding, and if
  they are wrong the mode is a lie.

Don't reprint what never changes. Dedup, refutation, the confidence threshold,
the log path — all fixed, all documented below, none of it belongs in the output.

Then gate with a single `AskUserQuestion`. Do not proceed without approval, and
do not end the turn to get it.

- **header** — the work, in the user's words: `docs diff`, `suspend path`. Never
  the word "gate", and never a mode name; the modes are internal machinery for
  deciding what the reviewers may see, not a vocabulary the user asked for.
- **question** — the task in one sentence, not its classification:
  *"Review the 18-file docs diff for cross-document consistency?"*
- **first option** — run it as planned. The description says what the run does and
  what it costs, not that it proceeds.
- **the other three** — each a whole run you would be willing to launch, along a
  different dimension, one keypress each. Draw from:
  - **The other half of the split.** Every project supports two kinds of run:
    finding what is wrong with what exists, and proposing what else could be
    done. Step 1 picks one; **the menu always offers the other**, described by
    effect and never by mode name. A user who wanted ideas and got a bug list has
    to run the whole thing again. In a repo with a trained model that reads
    *"Propose ways to improve the model, worked out from the task and the metrics
    alone, without reading the current implementation."*
    Say how blind it is, because that is what decides whether the ideas are worth
    anything: a reviewer that has read the code comes back with local refactors of
    that code. Step 3's copy is what makes the blindness real rather than
    requested.
  - **A different scope.** The obvious other target. If the plan scoped to a diff,
    offer the whole project — *"Sweep every important file for bugs and
    inconsistencies, not just the 18 that changed."* If it scoped wide, offer the
    narrow one. This is how a narrow inference gets widened: the user presses it,
    never you assuming it.
  - **Something only this project suggests.** At least one slot is yours to
    invent — a review worth running that was not asked for, that a template could
    not have produced, and that you can point at a specific reason for. It comes
    from what you noticed while reading: a number restated in three files, an
    install path nothing verifies, a config the docs and the code disagree about,
    a claim resting on one unrepeated measurement. Name what it would look for,
    not the category it belongs to.

**Ban generic angles.** *"Check for security issues"*, *"review test coverage"*,
*"look at performance"* — these are what a slot filler writes when it has not read
the project. They are indistinguishable across every repo, which is exactly the
evidence that they came from nowhere. If the invented option would read the same
in a different project, it is not the one.

**Fill the slots, but only with things you would defend.** Four options, and an
empty slot is a review the user has to type out instead of press. There is no
reserved ordering: if what you invented is stronger than the mechanical scope
alternative, it takes that place. But an option you would not run yourself is
worse than an empty slot, because it spends the user's attention arguing with
something you do not believe either. Never pad with a restatement of the first
option.

**Every description carries its cost.** These are not tweaks — a whole-project
sweep is a different order of spend from a diff, and the user is choosing what to
buy, not just what to look at.

**No cancel option, and no "change something" option.** Escape already aborts,
and an aborted turn and a declined run end identically. `AskUserQuestion` always
appends a free-text *Other*, which is where anything unanticipated goes — offering
it explicitly wastes a slot. If the user answers through *Other*, re-render and
ask again.

**Defaults are fixed and are never offered as choices:** Codex on `gpt-5.6-sol`,
Claude reviewer on `opus`, verifiers on `sonnet`, web search on, both reviewers
always run. Never present these as a menu. If the user asks for something else in
plain language — *"try terra"*, *"skip the Claude side"* — honour it for that run,
show it on the plan, and go back to the defaults next time.

### Step 3 — On approval, launch

Record `git rev-parse HEAD` and `git status --porcelain`. This is a
**starting-state record**, not a snapshot: both reviewers read live files, and the
record exists so step 4 can report drift. Do not call it a snapshot.

Both reviewers are **agents that pull.** Grant a root and a starting point; never
assemble a file manifest. Because they pull, you cannot enumerate in advance what
gets transmitted — say so on the plan rather than implying a precision that does
not exist, and keep the root as tight as the question allows.

#### Blind modes: build the sandbox first

In `next` and `assess`, copy the granted subset into
`~/.claude/scratch/r-<project>-<timestamp>/` with `mkdir -p` and `cp -r`, and copy
**only** what is granted. Withheld files are then absent rather than merely
un-mentioned — that is the whole point, and it is the only form of withholding
that survives a reviewer deciding to look around.

Do not copy reference roots; they are large and not secret. Name them in the
prompt instead.

**How blind is a dial, not a property of the mode.** `next` normally grants
results and code. When the point is ideas that must not be anchored to the
current implementation — *"how else could this model be improved"* — the grant
narrows to the task statement and the measurements, and the code stays out of the
copy. Whatever was promised on the plan is what gets copied.

Show the copy's contents and omissions on the plan, in full. **The file list is
the withholding** — if it is wrong, the mode is a lie, so this is the one thing
on the plan that is never shortened for brevity.

In `review` and `improve` there is nothing to withhold, so no copy is made and the
reviewers work in the real tree.

#### Codex

```
codex exec -s read-only --ephemeral --json -m gpt-5.6-sol \
  -C <root> -o ~/.claude/reviews/<project>-<timestamp>.md \
  "<the prompt>" < /dev/null \
  | tee ~/.claude/reviews/<project>-<timestamp>.codex.jsonl
```

Five details that are load-bearing:

- **The prompt is a positional argument.** Omit it and Codex reads the prompt from
  stdin, which `< /dev/null` has just emptied — it runs on nothing.
- **`< /dev/null`.** A piped stdin is appended to the prompt as a `<stdin>` block.
- **`--skip-git-repo-check`** whenever the working directory is not in
  `~/.codex/config.toml`'s trusted list — including every scratch sandbox. Without
  it Codex refuses to start.
- **No `--add-dir`.** It grants *writable* roots, which is the wrong thing
  entirely for a read-only reviewer. Reference roots go in the prompt.
- **`--json` + `tee`** captures the `turn.completed` event that step 5 needs.

Where the scope matches a git shape, `codex review --uncommitted` / `--base <ref>`
/ `--commit <sha>` is the simpler call. `-s read-only` forbids writes but permits
commands, so `journalctl`, `lspci`, and tests are fine.

If Codex is not installed, say so and offer a Claude-only run rather than failing.

#### Claude reviewer

Spawn via `Agent` with `subagent_type: Explore` — read-only by construction,
rather than a general-purpose agent carrying Write and Edit. Model `opus`. Same
root, same lens, same instructions as Codex, and the same output contract:
findings with `file:line`, a one-line claim, a one-line rationale, and a list of
what it read.

Context is **fresh** — a new context window, not a scrubbed one. You, the session,
already are the full-context Claude; your view is in this conversation and costs
nothing. A full-context subagent would mostly re-derive it, adding a reviewer
without adding a perspective. The fresh one contributes what the session cannot: a
Claude that has not been anchored by the discussion, and one whose context is
symmetric with Codex's, so a disagreement is attributable to the model rather than
to one of them having read more.

Save the subagent's report beside Codex's, as
`~/.claude/reviews/<project>-<timestamp>.claude.md`. Codex writes its own through
`-o`; without this the Claude half of a completed run survives only in the session
transcript, and the run is half-reproducible from its artifacts.

Launch Codex first, then the subagent, then wait. **If either has not returned
within 10 minutes, stop waiting**, report the survivor plus the timeout, and
record it under `failures` in the log.

**Codex is done when its capture file contains a `turn.completed` event** — the
same event step 5 reads for token usage. Test for that, never for the process
being gone: a wait built on the pid reports the same thing whether Codex finished
or the clock ran out, and those are exactly the two outcomes the 10-minute rule
has to tell apart. No `turn.completed` is a timeout, and a timeout goes in
`failures`.

### Step 4 — Consolidate

Apply the same scrutiny to **both reviewers**. Checking Codex while taking the
Claude subagent on trust would treat same-model output as more credible, which is
the exact bias this command exists to counter.

Always, in every mode:

- Tag every item by origin.
- **Translate sandbox paths back to the project before reporting.** A reviewer
  working in a blind copy cites `~/.claude/scratch/r-<project>-<ts>/findings/x.md:107`,
  because that is the only root it was ever given. Those citations resolve against
  nothing in the real tree and die when the copy is pruned. Rewriting them is the
  consolidator's job — the reviewers cannot do it, having never known the real path.
- Where both raised the same thing independently, note the corroboration — then
  check it anyway. Two models can share a wrong prior.
- **Report disagreements. Never average them.** Divergence is the product.
- Report what each reviewer actually read. It explains disagreements, and in blind
  modes it is how contamination becomes visible.
- Compare against the starting-state record and name any reviewed file that
  changed since — a verifier reads current source and would otherwise sink a
  finding that was correct about the version reviewed.
- A short honest result beats a padded one. If nothing real turned up, say so.

#### Dedup first

Merge semantic duplicates **across both reviewers before verifying anything**. A
finding both raised is verified once, not twice — note the corroboration, but do
not pay for it twice.

#### Then verify, in `review` and `improve`

For **each deduped finding**, spawn one `Agent` with `subagent_type: Explore` on
**sonnet**, fresh context, seeing that finding and nothing else.

Three things make this work:

- **One agent per finding.** A single agent checking twelve findings in sequence is
  anchored — after confirming the first six it judges the twelfth against that
  momentum rather than against the source.
- **Tell it to refute, not to check.** "Is this right?" invites agreement. "Try to
  refute this claim; default to refuted if you cannot verify it" invites scrutiny.
- **Two numbers, not one.** A single score cannot carry both "is this true" and
  "does it matter" — a certain but rare serious bug scores mid-range on a blended
  scale and vanishes.

Hand the agent this rubric **verbatim**; paraphrase drifts and the numbers stop
comparing across runs:

```
Return two values for this claim.

CONFIDENCE that the claim is factually correct, 0-100. Judge only whether it is
true, never whether it matters:
0    Refuted. Does not survive scrutiny, or describes something that is not
     actually the case.
25   Could not verify either way. Might be true; the evidence is absent.
50   Probably true, but one step of the argument is unconfirmed.
75   Verified against the source. You traced it and it holds.
100  Certain. Traced end to end, with the specific evidence quoted.

SEVERITY if the claim is true — high, medium, or low. Judge only the consequence,
never the likelihood of your being right:
high    incorrect behaviour, data loss, a silent wrong result, or a crash
medium  degraded behaviour, a wrong result in a narrow case, real maintenance cost
low     cosmetic, stylistic, or a nit
```

Also give it the false-positive list for the current mode, and the paths it may
read.

#### False positives — mode-dependent

Both modes exclude:

- Something that looks like a bug but is not
- Pedantic nitpicks a senior engineer would not raise
- Anything a linter, typechecker, or compiler catches — assume those run separately
- General code-quality complaints (coverage, docs, broad security observations)
  unless the project explicitly requires them
- Issues the project calls out but the code explicitly silences, e.g. a
  lint-ignore comment
- Changes that are likely intentional, or follow from the broader change

**`review` additionally excludes** — it is scoped to a change, so the surrounding
code is not the subject:

- Pre-existing issues not introduced by the work under review
- **Real issues on lines that were not modified.** A reviewer pointed at a diff
  will happily report problems in the untouched code around it

**`improve` excludes neither of those.** The whole existing design is the subject,
so pre-existing issues are precisely what was asked for. Applying the `review`
list here would filter out the entire point of the mode.

#### Report in two sections

- **Findings** — confidence ≥ 80, ordered by severity then confidence. Each cites
  `file:line` with at least one line of context either side, then one line on the
  problem and one on the fix.
- **Filtered** — everything below 80 confidence, with its score and the refutation
  that sank it.

**Severity orders; it never filters.** A certain, low-severity finding is reported
last, not dropped — relevance is the false-positive list's job, not the score's.

The Filtered section is the evidence that verification did anything, which is why
step 5 logs it.

#### In `next` and `assess`, do not score

The output is proposals, not claims. There is nothing in the source to refute them
against, so the rubric does not apply and using it would fabricate a rigour the
output cannot carry. Dedup still applies. Assess applicability instead:

- `NEW` — not tried, and consistent with the stated constraints
- `ALREADY TRIED` — say when, and what result it produced
- `RULED OUT` — conflicts with a constraint; name the constraint
- `UNCLEAR` — cannot tell without information the reviewer did not have

`ALREADY TRIED` earns its place: a blind reviewer cannot know your history, so
re-proposals are expected rather than a failure, and dropping them silently would
hide how much of the space was actually covered.

Report proposals grouped by what only one reviewer raised, what both raised, and
where they contradict. What only one raised is the yield.

### Step 5 — Log the run

Append **exactly one line** to `~/.claude/reviews/log.jsonl` with
`tee -a`, which creates the file if absent and cannot truncate it. A single run
tells you nothing; twenty tell you whether verification is doing work, which modes
get corrected, and what Codex actually costs.

Codex token usage comes from the **last `turn.completed` event** in the `.codex.jsonl`
capture — this exact shape, verified against codex-cli 0.146.0:

```
jq -c 'select(.type=="turn.completed").usage' <run>.codex.jsonl | tail -1
→ {"input_tokens":11912,"cached_input_tokens":8960,"cache_write_input_tokens":0,
   "output_tokens":5,"reasoning_output_tokens":0}
```

Log that object verbatim and add `total` = `input_tokens + output_tokens`. If no
`turn.completed` event is present, record `null` — a wrong number is worse than a
missing one. Note every call carries roughly 12k input tokens of Codex system
prompt before it reads anything, so a small review is not a small number.

**`codex.total` is Codex's spend, not the run's.** The Claude reviewer and the
verifier fan-out are not in the log, because `Agent` does not report usage — but
they are not unmeasurable. The harness writes per-call usage to the session
transcript, and each background subagent gets its own file:

```sh
~/.claude/projects/<project>/<session-id>.jsonl
~/.claude/projects/<project>/<session-id>/subagents/agent-*.jsonl

jq -s '[.[]|select(.message.usage!=null)]
       | {calls:length,
          fresh_input:(map(.message.usage.input_tokens)|add),
          cache_read:(map(.message.usage.cache_read_input_tokens//0)|add),
          cache_write:(map(.message.usage.cache_creation_input_tokens//0)|add),
          output:(map(.message.usage.output_tokens)|add)}' <file>
```

Recover it afterwards when the question is asked. It is not logged during the run
because finding one's own transcript mid-run is fragile, and nothing in the run
needs the number.

Wrapped here for readability; **write it as a single line** or `jq -s` will fail:

```json
{"ts":"2026-08-02T18:31:04+02:00","host":"framework","project":"measurements",
 "mode":"review","gate_choice":"as-planned","mode_corrected":false,
 "lens":"burn-rate math in statusline.sh","sandbox":false,
 "codex":{"model":"gpt-5.6-sol",
          "usage":{"input_tokens":48213,"cached_input_tokens":31002,
                   "cache_write_input_tokens":0,"output_tokens":5140,
                   "reasoning_output_tokens":900},"total":53353},
 "claude":{"reviewer":"opus","verifier":"sonnet"},
 "findings":{"codex":7,"claude":5,"deduped":9,"reported":4,"filtered":5},
 "confidence":[95,88,85,80,60,45,25,25,0],
 "severity":["high","medium","medium","low"],
 "corroborated":3,"disagreements":2,"duration_s":412,
 "failures":[],"notes":null}
```

Field rules. `ts`, `project`, `mode` and `lens` say what they are. **Every key
that carries a count or a judgement gets a definition below**, because a counted
key that exists only as a number in the example is a key that will be filled with
whatever seems plausible — which is how this log's first run came to claim
`corroborated: 5` against a `deduped` that had merged exactly one pair:

- `host` — `hostname`. Sessions run in parallel across machines, and without this
  twenty accumulated runs cannot be attributed to any of them. That is the whole
  of the multi-machine handling: the log stays per-machine and out of the repo,
  concurrent appends on one machine are safe because a ~650-byte line is a single
  `O_APPEND` write, and merging across machines is `cat`, the format being JSONL.
- `findings.codex` / `findings.claude` — items each reviewer raised, counted
  **before** dedup.
- `findings.deduped` — items remaining after merging semantic duplicates across
  both. Never greater than `codex + claude`.
- `findings.reported` / `findings.filtered` — of the deduped items, how many
  cleared 80 confidence and how many did not. They sum to `deduped`.
- `corroborated` — deduped items that **both** reviewers raised independently.
  Each one is a merged pair, so `corroborated ≤ codex + claude − deduped`, always.
  If your numbers break that, you are counting thematic overlap, which is not
  corroboration, and the dedup pass did not happen.
- `disagreements` — items where the reviewers reached opposite conclusions on the
  same subject. Distinct from an item only one of them raised.
- `duration_s` — gate approval to log write, the whole run. Not Codex's runtime,
  which is typically far shorter.
- `gate_choice` — which option the user pressed: `as-planned`, `other-half`,
  `other-scope`, `invented`, or `typed` for a free-text answer. This is how the
  menu gets judged. If `as-planned` is nearly everything, the alternatives are
  decoration and step 1 is doing the real work; if `invented` is never once
  pressed, that slot is filler dressed up as insight and should go back to being
  a second scope.
- `mode_corrected` — `true` if the user changed the inferred mode at the gate.
  The measure of whether step 1's inference is any good. Kept alongside
  `gate_choice` because a `typed` answer can change the mode too.
- `sandbox` — `true` when a sanitized copy was built (blind modes).
- `confidence` — every verifier score, descending, **including the rejected ones**.
  The distribution is the evidence; counts alone hide a run where everything
  landed on exactly 80.
- `severity` — one entry per *reported* finding, in report order.
- `failures` — reviewer names that errored or hit the 10-minute timeout.
- `notes` — always write `null`. It is a slot for the user to fill in by hand
  afterwards ("caught a real bug", "all noise"). Never invent a value; human
  judgement is the one signal this command cannot generate about itself.
- In `next` and `assess` write `"confidence":[]` and `"severity":[]`, put the
  proposal count in `findings.reported`, and `"filtered":0`. Keep every key in
  every mode — a stable shape is what makes the log queryable later.

Never rewrite earlier lines; the log is append-only. If this step fails, say so
and leave the report intact — a lost log line must not cost the user their review.

**Two questions the log exists to answer.** Is verification doing work — how often
is `findings.filtered` zero, since a run that rejects nothing means the verifiers
are rubber-stamping? And is the menu doing work — what does `gate_choice` look
like across runs? Scope the filtering check to the scoring modes, since `next` and
`assess` always report zero:

```sh
jq -s '[.[]|select(.mode=="review" or .mode=="improve")] as $scored
       | {runs:length,
          scored_runs:($scored|length),
          never_filtered:[$scored[]|select(.findings.filtered==0)]|length,
          gate:(group_by(.gate_choice)|map({(.[0].gate_choice):length})|add),
          mode_corrections:[.[]|select(.mode_corrected)]|length,
          codex_tokens:[.[].codex.total|numbers]|add}' ~/.claude/reviews/log.jsonl
```

Neither question is answerable until roughly twenty runs exist. One run is an
anecdote, and the log is deliberately dumb about that — it records and never
concludes.

## Rules that never bend

- **No reviewer implements.** Codex is held to it by `-s read-only`; the Claude
  reviewers by running as `Explore`, which has no Edit or Write. State it in their
  prompts anyway.
- **You never implement either.** `disallowed-tools` removes Edit and Write for
  the duration of this command, so this is enforced rather than promised. `/r`
  produces an assessment; fixes are a separate request afterwards.
- **Scratch scripts are fine, for both, on request.** A reviewer that wants to
  test an idea numerically gets a writable directory at
  `~/.claude/scratch/r-<project>-<timestamp>-work/`. For Codex that means
  `-s workspace-write -C <that dir>` instead of `-s read-only`, with the project
  named in the prompt as read-only context; for a Claude reviewer it means a
  general-purpose subagent confined to that path rather than `Explore`. Writes land
  in scratch, the project is untouched, and "no reviewer implements" survives.
  Off by default, never offered — granted when asked, and shown loudly on the plan
  when on, because it is the one setting that changes what a reviewer can do to
  disk.
- **Never claim more isolation than exists.** The sandbox copy is real
  withholding. It is not a security boundary, and nothing here should be described
  as one.
- **Decline what tooling answers better.** Typing is pyright's job, formatting the
  formatter's, "does it pass" the test suite's. Say so and skip the round trip
  rather than spending quota on a question with a deterministic answer.
