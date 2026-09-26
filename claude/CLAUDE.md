Never write new docstrings, comments, tests, or type annotations.
Keep existing ones working and do not delete them unasked.
No suppression directives either: `# noqa`, `# type:`, `# pragma:`, `# fmt:`, `# mypy:`, `# ruff:` and the like silence a tool instead of answering it, so fix the cause. Only a shebang or an encoding declaration is exempt.
When asked for documentation, tests, or typing, `touch ~/.cache/claude-no-draft-check-$CLAUDE_CODE_SESSION_ID` first and remove it when done.
No `from __future__ import annotations` for `list[str]` or `X | None`; both are native. Keep it in files with `if TYPE_CHECKING:` imports or unquoted forward references.
No new `_helper` whose body is a single `return` and that is called at most once: inline it at the call site. Decorating it, or naming it without calling it (`sorted(rows, key=_key)`), exempts it.
Target Python 3.13 or newer, unless `requires-python` in the project's `pyproject.toml` says otherwise.
No em-dashes. No emoji unless asked.
Ask before creating a branch.
If I ask a question, answer it and change nothing. If the target file or scope is unclear, name what you will touch before touching it.
A cleanup, simplification or refactor only removes code. Propose no new files, features, abstractions or versioning unless asked.
Before calling a change equivalent or claiming a flaw, test it on real data. Otherwise say it is unverified.
Prose: short plain sentences, no semicolons, no bold for emphasis, define every term, engineering-report tone rather than math paper.
A rewrite comes out shorter than the original unless I ask for more.
