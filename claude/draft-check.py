import ast, json, pathlib, re, sys


def calls(tree, name):
    return sum(isinstance(c, ast.Call) and (
        (isinstance(c.func, ast.Name) and c.func.id == name)
        or (isinstance(c.func, ast.Attribute) and c.func.attr == name)
    ) for c in ast.walk(tree))


TEST_PATH = re.compile(r"(^|/)(tests?/|test_[^/]*\.py$|[^/]*_test\.py$|conftest\.py$)")

data = json.load(sys.stdin)
if (pathlib.Path.home() / ".cache" / f"claude-no-draft-check-{data.get('session_id', '')}").exists():
    sys.exit(0)

ti = data.get("tool_input", {})
path = ti.get("file_path", "")
if not path.endswith(".py"):
    sys.exit(0)

out = []
if data.get("tool_name") == "Write" and TEST_PATH.search(path):
    out.append(f"{path}: new test file (ignore if you were asked for tests)")

src = ""
try:
    src = open(path).read()
    tree = ast.parse(src, path)
except (OSError, SyntaxError):
    tree = None

if tree is not None:
    added = ti.get("new_string") or ti.get("content") or ""
    i = src.find(added) if added else -1
    if i == -1:
        lo = hi = -1
    else:
        lo = src.count("\n", 0, i) + 1
        hi = lo + added.count("\n")
    span = lambda a, b: lo != -1 and not (b < lo or a > hi)
    for n in ast.walk(tree):
        if isinstance(n, ast.ImportFrom) and n.module == "__future__" \
                and any(a.name == "annotations" for a in n.names) and span(n.lineno, n.lineno):
            out.append(f"{path}:{n.lineno}: `from __future__ import annotations` is redundant on 3.14")
        if not isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        doc = n.body[0] if n.body and isinstance(n.body[0], ast.Expr) \
            and isinstance(n.body[0].value, ast.Constant) and isinstance(n.body[0].value.value, str) else None
        if doc is not None and span(doc.lineno, doc.end_lineno):
            out.append(f"{path}:{doc.lineno}: docstring on {n.name} (ignore if you were asked for documentation)")
        if not span(n.lineno, n.lineno):
            continue
        if n.returns or any(a.annotation for a in n.args.args):
            out.append(f"{path}:{n.lineno}: annotations on {n.name} (ignore if you were asked for typing)")
        body = [s for s in n.body if not (isinstance(s, ast.Expr) and isinstance(s.value, ast.Constant))]
        if len(body) == 1 and isinstance(body[0], ast.Return) and not n.decorator_list \
                and n.name.startswith("_") and calls(tree, n.name) <= 1:
            out.append(f"{path}:{n.lineno}: {n.name} is a one-line helper, inline it")

if out:
    print("\n".join(out), file=sys.stderr)
    sys.exit(2)
