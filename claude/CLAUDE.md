Never write new docstrings, comments, tests, or type annotations.
Keep existing ones working and do not delete them unasked.
No suppression directives either: `# noqa`, `# type:`, `# pragma:`, `# fmt:`, `# mypy:`, `# ruff:` and the like silence a tool instead of answering it, so fix the cause. Only a shebang or an encoding declaration is exempt.
When asked for documentation, tests, or typing, `touch ~/.cache/claude-no-draft-check-$CLAUDE_CODE_SESSION_ID` first and remove it when done.
No `from __future__ import annotations` for `list[str]` or `X | None`; both are native. Keep it in files with `if TYPE_CHECKING:` imports or unquoted forward references.
Target Python 3.13 or newer, unless `requires-python` in the project's `pyproject.toml` says otherwise.
No em-dashes. No emoji unless asked.
