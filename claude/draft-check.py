import ast, builtins, difflib, json, os, pathlib, re, shutil, socket, sys, time

# The hook inherits whatever `python3` resolves to. On macOS that is Apple's
# frozen 3.9.6, too old to parse `match` or PEP 695, which made ast.parse raise
# and every check below silently skip. Arch's python3 is current, so this is a
# no-op there. Must run before stdin is read: execv inherits it unconsumed.
if sys.version_info < (3, 12) and not os.environ.get("DRAFT_CHECK_REEXEC"):
    # The marker bounds the exec chain: a candidate that itself reports < 3.12
    # (a stale pyenv shim, a mislabeled symlink) must degrade, not loop forever.
    os.environ["DRAFT_CHECK_REEXEC"] = "1"
    for _cand in ("python3.15", "python3.14", "python3.13", "python3.12"):
        _exe = shutil.which(_cand)
        if _exe:
            try:
                os.execv(_exe, [_exe, os.path.abspath(__file__), *sys.argv[1:]])
            except OSError:
                continue  # dangling symlink or not executable: try the next one


# Calls and references counted apart: `sorted(rows, key=_key)` names the helper
# without calling it, and that one cannot be inlined at a call site. Inlining is
# only sound advice when every reference is a direct call.
def uses(tree, name):
    ncalls = nrefs = 0
    for c in ast.walk(tree):
        if isinstance(c, ast.Call) and (
                (isinstance(c.func, ast.Name) and c.func.id == name)
                or (isinstance(c.func, ast.Attribute) and c.func.attr == name)):
            ncalls += 1
        if (isinstance(c, ast.Name) and c.id == name) \
                or (isinstance(c, ast.Attribute) and c.attr == name):
            nrefs += 1
    return ncalls, nrefs


# if/try/with/loops bind into the enclosing scope; class and function bodies do
# not, so `class B: class Foo` must not count as a module-level `Foo`. TryStar is
# 3.11+, hence the getattr.
NESTS = tuple(c for c in (ast.If, ast.Try, getattr(ast, "TryStar", None), ast.With,
                          ast.AsyncWith, ast.For, ast.AsyncFor, ast.While) if c)


# Module, class and function docstrings are all the same shape: a bare string
# expression as the first statement of the body.
def docstring_of(node):
    body = getattr(node, "body", None)
    if not isinstance(body, list) or not body:
        return None
    first = body[0]
    if isinstance(first, ast.Expr) and isinstance(first.value, ast.Constant) \
            and isinstance(first.value.value, str):
        return first
    return None


# Every annotation a def evaluates when it executes. `args.args` alone misses
# positional-only, keyword-only, *args and **kwargs, all of which are evaluated
# exactly like the rest.
def annotations_of(fn):
    a = fn.args
    for arg in a.posonlyargs + a.args + a.kwonlyargs + [a.vararg, a.kwarg]:
        if arg is not None and arg.annotation is not None:
            yield arg.annotation
    if fn.returns is not None:
        yield fn.returns


TYPE_ALIAS = getattr(ast, "TypeAlias", None)  # PEP 695, 3.12+


# Every way a statement introduces a name, including `type X = ...`: a guard body
# full of those binds nothing at runtime, and missing one reads as "no deferral
# needed" on a file that will not import without it.
# `A, B = make()` binds both sides. Missing them lets a genuine forward
# reference read as "no deferral needed", the one direction the ambiguity rule
# below forbids.
def target_names(t):
    if isinstance(t, ast.Name):
        yield t.id
    elif isinstance(t, (ast.Tuple, ast.List)):
        for e in t.elts:
            yield from target_names(e)
    elif isinstance(t, ast.Starred):
        yield from target_names(t.value)


def bound_names(stmts):
    b = {}
    for s in stmts:
        if isinstance(s, (ast.Import, ast.ImportFrom)):
            for a in s.names:
                b.setdefault((a.asname or a.name).split(".")[0], []).append(s.lineno)
        elif isinstance(s, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            b.setdefault(s.name, []).append(s.lineno)
        elif isinstance(s, ast.Assign):
            for t in s.targets:
                for name in target_names(t):
                    b.setdefault(name, []).append(s.lineno)
        elif isinstance(s, ast.AnnAssign) and isinstance(s.target, ast.Name):
            b.setdefault(s.target.id, []).append(s.lineno)
        elif TYPE_ALIAS is not None and isinstance(s, TYPE_ALIAS) and isinstance(s.name, ast.Name):
            b.setdefault(s.name.id, []).append(s.lineno)
        elif isinstance(s, (ast.For, ast.AsyncFor)):
            for name in target_names(s.target):
                b.setdefault(name, []).append(s.lineno)
        elif isinstance(s, (ast.With, ast.AsyncWith)):
            for item in s.items:
                if item.optional_vars is not None:
                    for name in target_names(item.optional_vars):
                        b.setdefault(name, []).append(s.lineno)
        # `except ... as e` binds too; handlers exist only on the Try shapes.
        for h in getattr(s, "handlers", []):
            if h.name:
                b.setdefault(h.name, []).append(h.lineno)
    return b


MATCH = getattr(ast, "Match", None)  # 3.10+, and this file must parse on 3.9


def module_stmts(body):
    for s in body:
        yield s
        if isinstance(s, NESTS):
            for part in (s.body, getattr(s, "orelse", []), getattr(s, "finalbody", [])):
                yield from module_stmts(part)
            for h in getattr(s, "handlers", []):
                yield from module_stmts(h.body)
        # match arms bind into the enclosing scope exactly like if branches.
        elif MATCH is not None and isinstance(s, MATCH):
            for case in s.cases:
                yield from module_stmts(case.body)


def dotted_path(node):
    parts = []
    while isinstance(node, ast.Attribute):
        parts.append(node.attr)
        node = node.value
    if not isinstance(node, ast.Name):
        return None
    parts.append(node.id)
    return ".".join(reversed(parts))


# Matches `if TYPE_CHECKING:`, `if TC:` after an alias import, and
# `if typing.TYPE_CHECKING:`. Deliberately not a substring test on the dump: that
# also matched `if not TYPE_CHECKING:`, whose body does run.
def type_checking_guard(test, aliases):
    # `if TYPE_CHECKING and flag:` never runs its body at runtime either, so a
    # TYPE_CHECKING conjunct anywhere in an `and` chain makes the guard real.
    if isinstance(test, ast.BoolOp) and isinstance(test.op, ast.And):
        return any(type_checking_guard(v, aliases) for v in test.values)
    return (isinstance(test, ast.Name) and test.id in aliases) \
        or (isinstance(test, ast.Attribute) and test.attr == "TYPE_CHECKING")


# PEP 563 is only dead weight once nothing in the file relies on deferral. Until
# 3.14 (PEP 649) that means a name that does not exist when the annotation is
# evaluated: a TYPE_CHECKING-only import, a binding introduced further down, or a
# class naming itself inside its own body. Ambiguity resolves to True, because a
# false True only costs an unreported nit while a false False tells the agent to
# delete a line the file needs.
def future_needed(tree):
    aliases = {"TYPE_CHECKING"}
    for n in ast.walk(tree):
        if isinstance(n, ast.ImportFrom) and n.module in ("typing", "typing_extensions"):
            aliases.update(a.asname or a.name for a in n.names if a.name == "TYPE_CHECKING")

    stmts = list(module_stmts(tree.body))

    # Guarded statements bind nothing at runtime, so they are collected separately
    # from the bindings below rather than counted as both. Scanned over the whole
    # tree: an `if TYPE_CHECKING:` inside a class or function body is just as lazy.
    guarded_stmts = []
    guarded = set()
    for s in ast.walk(tree):
        if not (isinstance(s, ast.If) and type_checking_guard(s.test, aliases)):
            continue
        for t in module_stmts(s.body):
            guarded_stmts.append(t)
            for u in ast.walk(t):
                guarded.add(id(u))
    lazy = set(bound_names(guarded_stmts))
    bound = bound_names([s for s in stmts if id(s) not in guarded])

    # Fallback for names bound inside a function, where an annotation in a local
    # def or class body still resolves against the enclosing scope. Consulted
    # only for annotations that themselves evaluate inside a function: a
    # module-level annotation sees nobody's locals, so a helper's `T = int`
    # must not make `def f(x: T)` look bound.
    nested = bound_names([n for n in ast.walk(tree) if id(n) not in guarded])

    dotted = {a.name for n in ast.walk(tree) if isinstance(n, ast.Import) for a in n.names}

    spans = {}
    for n in ast.walk(tree):
        if isinstance(n, ast.ClassDef):
            spans.setdefault(n.name, []).append((n.lineno, n.end_lineno))

    fn_spans = [(n.lineno, n.end_lineno) for n in ast.walk(tree)
                if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]

    # Each annotation carries whether it evaluates inside a function, which
    # decides if the `nested` fallback may vouch for its names. A def's own span
    # contains its def line, hence > 1 for "some other function encloses it".
    evaluated = []
    for n in ast.walk(tree):
        if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)):
            enclosed = sum(a <= n.lineno <= b for a, b in fn_spans) > 1
            evaluated.extend((ann, enclosed) for ann in annotations_of(n))
    # PEP 526: only module- and class-level annotations are evaluated. A local
    # `x: Foo` emits no bytecode at all, so it cannot require deferral.
    for scope in [tree] + [n for n in ast.walk(tree) if isinstance(n, ast.ClassDef)]:
        enclosed = isinstance(scope, ast.ClassDef) and any(a <= scope.lineno <= b for a, b in fn_spans)
        for s in scope.body:
            if isinstance(s, ast.AnnAssign) and s.annotation is not None:
                evaluated.append((s.annotation, enclosed))

    for ann, in_function in evaluated:
        for s in ast.walk(ann):
            # `pkg.sub.Type` needs `import pkg.sub`; the root name alone cannot
            # prove that, only a dotted import covering all but the last part.
            if isinstance(s, ast.Attribute) and isinstance(s.value, ast.Attribute):
                p = dotted_path(s)
                if p is not None and not any(
                        p == m or (p.startswith(m + ".") and "." not in p[len(m) + 1:])
                        for m in dotted):
                    return True
            if not isinstance(s, ast.Name):
                continue
            first = min(bound.get(s.id, []), default=None)
            if first is None and in_function:
                first = min(nested.get(s.id, []), default=None)
            # A TYPE_CHECKING-only name, unless an else: branch or a later plain
            # import also binds it at runtime before the annotation is evaluated.
            if s.id in lazy and not (first is not None and first <= ann.lineno):
                return True
            # Every runtime binding comes later: a forward reference, whether the
            # target is a class, an alias, a def, or a bottom-of-file import.
            if first is not None and first > ann.lineno:
                return True
            # Any same-named class whose body contains the annotation. All spans
            # are kept, so a nested class can no longer mask an outer one.
            if any(start <= ann.lineno <= end for start, end in spans.get(s.id, ())):
                return True
            # No binding this scope can see and not a builtin: star imports,
            # walrus targets and injected globals all land here, and the
            # ambiguity rule sends them to "needed" rather than telling the
            # agent to delete an import the file may rely on.
            if first is None and not hasattr(builtins, s.id):
                return True
    return False


TEST_PATH = re.compile(r"(^|/)(tests?/|test_[^/]*\.py$|[^/]*_test\.py$|conftest\.py$)")
LOG = pathlib.Path.home() / ".claude" / "drafts" / "log.jsonl"


# This hook ran zero times out of 41 for its whole existence and nothing noticed,
# because a failed hook is a non-blocking error the model never sees. So it now
# records every invocation. `py` and `parsed` are the fields that would have
# caught that silence: a 3.9.x line means the re-exec broke, `parsed: false`
# means the checks were skipped. A failed write is swallowed, since a broken log
# must never cost an edit.
def record(rec):
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG, "a") as f:
            f.write(json.dumps(rec, separators=(",", ":")) + "\n")
    except OSError:
        pass


data = json.load(sys.stdin)
ti = data.get("tool_input", {})
tr = data.get("tool_response") if isinstance(data.get("tool_response"), dict) else {}
path = ti.get("file_path", "")
if not path.endswith(".py"):
    sys.exit(0)

session = data.get("session_id", "")
# Parsed and counted even when bypassed, so a deliberate documentation pass is
# visible in the log as one; only the reporting is suppressed.
bypass = (pathlib.Path.home() / ".cache" / f"claude-no-draft-check-{session}").exists()

out = []
kinds = {}


def report(kind, message):
    out.append(message)
    kinds[kind] = kinds.get(kind, 0) + 1


# Overwriting an existing test file is maintenance, not a new test; the
# response's `type` tells them apart, and a response without `type` but with
# prior content is still an overwrite. Absent any response, assume create.
if data.get("tool_name") == "Write" and TEST_PATH.search(path) \
        and (tr.get("type") or ("update" if tr.get("originalFile") else "create")) == "create":
    report("newtest", f"{path}: new test file (ignore if you were asked for tests)")

src = ""
try:
    src = open(path).read()
    tree = ast.parse(src, path)
# UnicodeDecodeError is a ValueError: a non-UTF-8 file must log, not crash.
except (OSError, ValueError):
    tree = None
except SyntaxError as e:
    tree = None
    # On a current interpreter this is just a half-written file and the tests will
    # say so. On an older one it means the grammar is too new and every check
    # below was skipped, which is worth saying out loud rather than exiting 0.
    if sys.version_info < (3, 12):
        report("unparsed", f"{path}: every check skipped, Python {sys.version.split()[0]} "
                            f"cannot parse this file ({e.msg}, line {e.lineno})")

# What "this edit added" means, best source first. The tool response's
# structuredPatch carries exact new-file line numbers per hunk, which is what a
# text search cannot give: it covers every replace_all site, is immune to the
# new_string occurring earlier in the file, and leaves untouched lines out, so a
# docstring an edit merely carried through is context rather than an addition.
span_src = "none"
if tree is not None:
    added_lines = None
    patch = tr.get("structuredPatch") or []
    # Whatever arrives on stdin must not kill the hook: a malformed hunk falls
    # through to the next tier instead of dying with the log line unwritten.
    if not (isinstance(patch, list) and all(
            isinstance(h, dict) and isinstance(h.get("newStart"), int)
            and isinstance(h.get("lines"), list)
            and all(isinstance(l, str) for l in h["lines"]) for h in patch)):
        patch = []
    if patch:
        added_lines = set()
        for h in patch:
            ln = h["newStart"]
            for l in h["lines"]:
                if l.startswith("\\"):  # "\ No newline at end of file"
                    continue
                if l.startswith("+"):
                    added_lines.add(ln)
                if not l.startswith("-"):
                    ln += 1
        span_src = "patch"
    elif tr.get("type") == "create":
        added_lines = set(range(1, src.count("\n") + 2))
        span_src = "difflib"
    elif isinstance(tr.get("originalFile"), str) and tr.get("originalFile"):
        # Write over an existing file arrives with an empty patch; the old
        # content is still in the response, so diff it ourselves. A null or
        # empty originalFile on a non-create proves nothing and falls through
        # to the find tier rather than treating the whole file as added.
        added_lines = set()
        sm = difflib.SequenceMatcher(None, tr["originalFile"].splitlines(),
                                     src.splitlines(), autojunk=False)
        for tag, i1, i2, j1, j2 in sm.get_opcodes():
            if tag in ("insert", "replace"):
                added_lines.update(range(j1 + 1, j2 + 1))
        span_src = "difflib"

    if added_lines is not None:
        span = lambda a, b: not added_lines.isdisjoint(range(a, (b or a) + 1))
    else:
        added = ti.get("new_string") or ti.get("content") or ""
        i = src.find(added) if added else -1
        if i == -1:
            lo = hi = -1
        else:
            lo = src.count("\n", 0, i) + 1
            # A trailing newline terminates the last line rather than starting
            # another; counting it would leak the span onto the next line.
            hi = lo + added.count("\n") - (1 if added.endswith("\n") else 0)
            span_src = "find"
        span = lambda a, b: lo != -1 and not (b < lo or a > hi)

    # A diff counts a rewritten line as added, so a construct that merely rode
    # along on an edited line would re-report; text carried verbatim from the
    # old content proves it was already there.
    orig_src = tr.get("originalFile") if isinstance(tr.get("originalFile"), str) else ""
    carried = lambda seg: bool(orig_src) and seg is not None and seg in orig_src

    for node, label in [(tree, "module")] + [
        (n, n.name) for n in ast.walk(tree)
        if isinstance(n, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef))
    ]:
        doc = docstring_of(node)
        if doc is not None and span(doc.lineno, doc.end_lineno) \
                and not carried(ast.get_source_segment(src, doc)):
            report("docstring", f"{path}:{doc.lineno}: docstring on {label} (ignore if you were asked for documentation)")

    redundant_future = "__future__" in src and not future_needed(tree)
    for n in ast.walk(tree):
        if isinstance(n, ast.ImportFrom) and n.module == "__future__" \
                and any(a.name == "annotations" for a in n.names) and span(n.lineno, n.lineno) \
                and redundant_future:
            report("future", f"{path}:{n.lineno}: `from __future__ import annotations` looks redundant here "
                             "(check for deferred-annotation use before removing)")
        if not isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        # Annotations are span-tested on their own lines, not the def line: an
        # edit that adds `retries: int = 3,` to a multi-line signature never
        # touches the line the def sits on. Renaming a def rewrites the line its
        # old annotations sit on, so each one must also fail the carried test
        # before it counts as new.
        fa = n.args
        new_ann = False
        for arg in fa.posonlyargs + fa.args + fa.kwonlyargs + [fa.vararg, fa.kwarg]:
            if arg is not None and arg.annotation is not None \
                    and span(arg.annotation.lineno, arg.annotation.end_lineno) \
                    and not carried(ast.get_source_segment(src, arg)):
                new_ann = True
        if n.returns is not None and span(n.returns.lineno, n.returns.end_lineno):
            seg = ast.get_source_segment(src, n.returns)
            if not (orig_src and seg and re.search(r"->\s*" + re.escape(seg), orig_src)):
                new_ann = True
        if new_ann:
            report("annotations", f"{path}:{n.lineno}: annotations on {n.name} (ignore if you were asked for typing)")
        if not span(n.lineno, n.lineno):
            continue
        body = [s for s in n.body if not (isinstance(s, ast.Expr) and isinstance(s.value, ast.Constant))]
        if len(body) == 1 and isinstance(body[0], ast.Return) and not n.decorator_list \
                and n.name.startswith("_"):
            ncalls, nrefs = uses(tree, n.name)
            if ncalls <= 1 and ncalls == nrefs:
                report("helper", f"{path}:{n.lineno}: {n.name} is a one-line helper, inline it")

# Whole-file totals, not span-gated. The reported counts above are the numerator
# for "is the prompt working"; these are what make "did the model act on it"
# answerable, since span-gating means a removed docstring is never re-reported and
# absence alone proves nothing.
totals = {}
if tree is not None:
    defs = [n for n in ast.walk(tree)
            if isinstance(n, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef))]
    totals = {
        "docstrings": sum(docstring_of(n) is not None for n in [tree] + defs),
        "annotated": sum(next(annotations_of(n), None) is not None for n in defs
                         if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))),
    }

record({"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "host": socket.gethostname(),
        "session": session, "path": path, "tool": data.get("tool_name", ""),
        "py": ".".join(str(v) for v in sys.version_info[:3]),
        "bypass": bypass, "parsed": tree is not None, "span": span_src,
        "reported": kinds, "file": totals})

if out and not bypass:
    print("\n".join(out), file=sys.stderr)
    sys.exit(2)
