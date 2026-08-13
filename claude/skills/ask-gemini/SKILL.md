---
name: ask-gemini
description: Hand one self-contained task to Gemini (Gemini 3.7 Flash with high reasoning effort, read-only, no session context) and get a single written answer back. Use whenever an outside opinion beats another pass by this session: reviewing a proposal before it is built, reviewing an implementation after it is, researching how something works, critiquing a design, checking a claim against the code, or an autonomous loop step that wants a second/third reviewer. Triggers on "ask Gemini", "Gemini review", "have Gemini look at", "what would Gemini say", "ask 3.7 Flash".
---

# Ask Gemini

Gemini is an independent external agent, not a tool call. It runs `gemini-3.7-flash` (with high reasoning effort) via `agy`, reads files, writes nothing, and shares nothing with this session. One brief in, one answer out, no follow-up turn.

That isolation is the point and the trap. Its answer is worth having precisely because it did not watch you get here. It is worthless when it did not know where "here" is.

## The brief is the whole job

Gemini sees the file you write and nothing else. Not the conversation, not what you already tried, not what the user said was off the table. A thin brief returns a confident answer to a question nobody asked.

Five things, every time:

1. **The question.** One. Phrased so a wrong answer is recognizable as wrong.
   "Is this migration plan safe" invites an essay; "which steps in this plan can leave the table readable but half-migrated if the process dies" gets an answer you can act on.
2. **Where to look.** Absolute paths, entry points, the two or three files that matter. Point, do not paste: it reads faster than you can quote, and a pasted excerpt silently becomes the only thing it examines. Paste only what does not exist on disk, like a proposal you have not written down yet.
3. **Constraints.** What must hold, what it may not propose, what the user has already vetoed. Without this you get a rewrite in a framework you are not using.
4. **Already ruled out.** What was tried, and what happened. This is the single highest-yield line in the brief and the one most often left out: absent it, the fresh agent reliably proposes the thing that failed an hour ago and you learn nothing.
5. **The answer shape.** What a finding must carry (`file:line`, one-line claim, one-line why), how long, what to leave out. Say what you will do with the answer, so it can aim.

Also say "you are read-only, report rather than propose to edit".

## Running it

Write the brief with the Write tool. Never build the prompt on the command line: a real brief has backticks, quotes and newlines in it, and the shell will eat them silently.

```bash
~/.claude/gemini-ask.sh <root> <brief-file> [--model M]
```

Run it with `run_in_background: true` when appropriate, or in parallel alongside `codex-ask.sh` for multi-model panel reviews.

`<root>` is the directory Gemini treats as its working root. stdout is the answer, verbatim, and nothing else. Run artifacts land in `~/.claude/gemini/`: the answer, error logs, and timestamps.

A non-zero exit with an answer still on stdout means the turn was cut short: treat the answer as partial and say so rather than discarding it.

## Reading what comes back

It is an independent opinion from Gemini 3.7 Flash working without your context. Weigh it; do not relay it as fact and do not launder it into your own voice. When it contradicts something you verified in this session or what Codex reported, say that plainly rather than splitting the difference: the disagreement is the yield, and averaging destroys it.

Attribute it. The user should always be able to tell which claims are yours, which are Codex's, and which are Gemini's.

## Limits worth knowing before you reach for it

- One shot by design. The wrapper never resumes one. To go deeper, write a new brief that quotes the previous answer and says what you want pushed on.
- Read-only by default in review mode.
- Not for what tooling answers better and faster: syntax checks, formatting, whether the tests pass. Ask it things that need deep reasoning and judgment.
