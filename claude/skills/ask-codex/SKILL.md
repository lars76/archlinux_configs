---
name: ask-codex
description: Hand one self-contained task to Codex (GPT-5.6-sol, read-only, no session context) and get a single written answer back. Use whenever an outside opinion beats another pass by this session: reviewing a proposal before it is built, reviewing an implementation after it is, researching how something works, critiquing a design, checking a claim against the code, or an autonomous loop step that wants a second reviewer. Triggers on "ask Codex", "second opinion", "have Codex look at", "what would Codex say".
---

# Ask Codex

Codex is a second agent, not a tool call. It runs `gpt-5.6-sol` at the reasoning
effort in `~/.codex/config.toml`, reads any file it wants, writes nothing, and
shares nothing with this session. One brief in, one answer out, no follow-up
turn.

That isolation is the point and the trap. Its answer is worth having precisely
because it did not watch you get here. It is worthless when it did not know
where "here" is.

## The brief is the whole job

Codex sees the file you write and nothing else. Not the conversation, not what
you already tried, not what the user said was off the table. A thin brief
returns a confident answer to a question nobody asked.

Five things, every time:

1. **The question.** One. Phrased so a wrong answer is recognizable as wrong.
   "Is this migration plan safe" invites an essay; "which steps in this plan can
   leave the table readable but half-migrated if the process dies" gets an
   answer you can act on.
2. **Where to look.** Absolute paths, entry points, the two or three files that
   matter. Point, do not paste: it reads faster than you can quote, and a pasted
   excerpt silently becomes the only thing it examines. Paste only what does not
   exist on disk, like a proposal you have not written down yet.
3. **Constraints.** What must hold, what it may not propose, what the user has
   already vetoed. Without this you get a rewrite in a framework you are not
   using.
4. **Already ruled out.** What was tried, and what happened. This is the single
   highest-yield line in the brief and the one most often left out: absent it,
   the fresh agent reliably proposes the thing that failed an hour ago and you
   learn nothing.
5. **The answer shape.** What a finding must carry (`file:line`, one-line claim,
   one-line why), how long, what to leave out. Say what you will do with the
   answer, so it can aim.

Also say "you are read-only, report rather than propose to edit". It cannot
write, but without being told it spends output describing patches it will
never apply.

## Running it

Write the brief with the Write tool. Never build the prompt on the command
line: a real brief has backticks, quotes and newlines in it, and the shell will
eat them silently.

```
~/.claude/codex-ask.sh <root> <brief-file>
```

Run it with `run_in_background: true`. A serious brief routinely runs past the
Bash tool's 10-minute ceiling, and a foreground call gets killed mid-thought.
Background also lets a Claude reviewer run against the same brief at the same
time, which is when the pairing is worth the most.

`<root>` is the directory Codex treats as its working root; it can read outside
it, but that is where it starts looking. stdout is the answer, verbatim, and
nothing else. Run artifacts land in `~/.claude/codex/`: the answer, the event
stream as JSONL, and stderr. Token usage is in the `turn.completed` event:

```
jq -c 'select(.type=="turn.completed").usage' ~/.claude/codex/<run>.jsonl | tail -1
```

A non-zero exit with an answer still on stdout means the turn was cut short:
treat the answer as partial and say so rather than discarding it.

## Reading what comes back

It is one opinion from an agent working without your context. Weigh it; do not
relay it as fact and do not launder it into your own voice. When it contradicts
something you verified in this session, say that plainly rather than splitting
the difference: the disagreement is the yield, and averaging destroys it.

Attribute it. The user should always be able to tell which claims are yours and
which are Codex's.

## Limits worth knowing before you reach for it

- One shot by design. The session is persisted, so quota accounting and an audit
  trail survive the run, but the wrapper never resumes one. To go deeper, write
  a new brief that quotes the previous answer and says what you want pushed on.
- Read-only, hardcoded in the wrapper. It cannot edit, install, or run a build.
- It has web search. `-s read-only` sandboxes the filesystem, not the network,
  so it will look things up, and a brief can point it at documentation for a
  library too niche to be in its training data. Two consequences: a run that
  searches takes considerably longer, and search queries carry fragments of
  what you asked about to a third-party service, so brief it accordingly on
  anything confidential.
- Not for what tooling answers better and faster: types, formatting, whether the
  tests pass. Ask it things that need judgment.
