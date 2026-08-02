Never write new docstrings, tests, or type annotations.
Keep existing ones working and do not delete them unasked.
When asked for documentation or tests, `touch ~/.cache/claude-no-draft-check-$CLAUDE_CODE_SESSION_ID` first and remove it when done.
No `from __future__ import annotations`: Python 3.14 defers annotations by default.
Target Python 3.14 or newer, unless `requires-python` in the project's `pyproject.toml` says otherwise.
No em-dashes. No emoji unless asked.
