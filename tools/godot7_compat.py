#!/usr/bin/env python3
"""Find (and optionally fix) single-line lambdas for Godot 7.x.

Godot 7 rejects a lambda body written on the same line as its declaration:

    ERROR: Parse Error: Expected indented block after lambda declaration.

A script that fails to parse never loads, so one occurrence can stop the
game from starting. This rewrites:

    timer.timeout.connect(func(): do_thing())

into the multi-line form, which is valid in both old and new GDScript:

    timer.timeout.connect(func():
        do_thing()
    )

Usage:
    python3 tools/godot7_compat.py            # report only (safe, no writes)
    python3 tools/godot7_compat.py --fix      # rewrite files in place

Run --fix from a clean git tree so you can inspect the diff afterwards.
"""
import argparse
import os
import re
import sys

SKIP_DIRS = {".git", ".godot", ".import", "addons"}

# A lambda is `func(` — a named declaration is `func name(`.
LAMBDA_RE = re.compile(r'\bfunc\s*\(')


def strip_strings_and_comments(line):
    """Blank out string literals and trailing comments so paren counting is
    not confused by parens/hashes appearing inside them. Returns a same-length
    string with those regions replaced by spaces."""
    out = []
    i = 0
    quote = None
    n = len(line)
    while i < n:
        c = line[i]
        if quote:
            if c == "\\" and i + 1 < n:
                out.append("  ")
                i += 2
                continue
            if c == quote:
                quote = None
            out.append(" ")
        else:
            if c in ('"', "'"):
                quote = c
                out.append(" ")
            elif c == "#":
                out.extend(" " * (n - i))
                break
            else:
                out.append(c)
        i += 1
    return "".join(out)[:n]


def match_paren(masked, open_idx):
    """Index of the ')' matching the '(' at open_idx, or -1 if unbalanced."""
    depth = 0
    for i in range(open_idx, len(masked)):
        if masked[i] == "(":
            depth += 1
        elif masked[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    return -1


def find_single_line_lambda(line, depth_at_line_start=0):
    """Return (indent, head, body, tail) if `line` holds a single-line lambda,
    else None.

      head = everything up to and including the lambda's ':'
      body = the statement that must move to its own line
      tail = the remainder (rest of the enclosing argument list, etc.)

    `depth_at_line_start` is the unclosed-paren depth carried in from earlier
    lines, so a lambda on a continuation line is still known to sit inside a
    call. Without it, `func(): a(), b)` looks top-level and the body would
    swallow the remaining arguments.

    A single-line lambda body is one statement. It ends at the first ',' or
    ')' encountered at the lambda's own nesting level -- a comma there returns
    to the enclosing argument list, it does not belong to the body.
    """
    masked = strip_strings_and_comments(line)
    for m in LAMBDA_RE.finditer(masked):
        open_idx = masked.index("(", m.start())
        close_idx = match_paren(masked, open_idx)
        if close_idx == -1:
            continue
        rest = masked[close_idx + 1:]
        cm = re.match(r'\s*(->\s*[A-Za-z_][A-Za-z0-9_\.]*\s*)?:', rest)
        if not cm:
            continue
        colon_abs = close_idx + 1 + cm.end()
        if not masked[colon_abs:].strip():
            continue  # already multi-line

        prefix = masked[:m.start()]
        enclosing = depth_at_line_start + prefix.count("(") - prefix.count(")")

        depth = 0
        end_abs = len(line)
        for i in range(colon_abs, len(masked)):
            ch = masked[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                if depth == 0 and enclosing > 0:
                    end_abs = i
                    break
                depth -= 1
            elif ch == "," and depth == 0 and enclosing > 0:
                end_abs = i
                break

        body = line[colon_abs:end_abs].strip()
        tail = line[end_abs:].rstrip()
        if not body:
            continue
        indent = re.match(r'[\t ]*', line).group(0)
        return indent, line[:colon_abs].rstrip(), body, tail
    return None


def convert_line(line, indent_unit, depth_at_line_start=0, stmt_indent=None):
    """`stmt_indent` is the indentation of the line the enclosing statement
    started on. The trailing fragment (', next_arg)' or ')') must align to it,
    not to the lambda's own line -- otherwise GDScript raises
    'Unindent doesn't match the previous indentation level' whenever the
    lambda sits on a continuation line."""
    found = find_single_line_lambda(line, depth_at_line_start)
    if not found:
        return None
    indent, head, body, tail = found
    if stmt_indent is None:
        stmt_indent = indent
    inner = indent + indent_unit
    # `if cond: stmt` needs its own nested block once expanded.
    im = re.match(r'((?:if|elif|else|for|while)\b[^:]*:)\s*(\S.*)', body)
    if im:
        lines = [head, inner + im.group(1), inner + indent_unit + im.group(2)]
    else:
        lines = [head, inner + body]
    # `tail` already holds the enclosing call's ')' (and any following
    # arguments) when there is one. A bare `var f = func(): body()` has no
    # enclosing call and needs no closer.
    if tail.strip():
        lines.append(stmt_indent + tail.strip())
    return lines


def process(path, fix, indent_unit):
    with open(path, "r", encoding="utf-8") as fh:
        original = fh.read()
    lines = original.split("\n")
    out, hits = [], []
    depth = 0
    stmt_indent = ""
    for idx, line in enumerate(lines, 1):
        # At depth 0 a new statement begins here; remember its indentation so
        # continuation lines know what to align their trailing fragment to.
        if depth == 0 and line.strip():
            stmt_indent = re.match(r'[\t ]*', line).group(0)
        converted = convert_line(line, indent_unit, depth, stmt_indent) if "func" in line else None
        if converted:
            hits.append((idx, line.strip()))
            out.extend(converted if fix else [line])
        else:
            out.append(line)
        # Track unclosed parens so a lambda on a continuation line still knows
        # it sits inside a call. Rewriting preserves paren balance, so this is
        # computed from the original line either way.
        masked = strip_strings_and_comments(line)
        depth = max(0, depth + masked.count("(") - masked.count(")"))
    if fix and hits:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(out))
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fix", action="store_true", help="rewrite files in place")
    ap.add_argument("--root", default=".", help="project root (default: cwd)")
    ap.add_argument("--spaces", type=int, default=0,
                    help="indent with N spaces instead of a tab")
    args = ap.parse_args()

    indent_unit = " " * args.spaces if args.spaces else "\t"
    total = 0
    files = 0
    for dirpath, dirnames, filenames in os.walk(args.root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in sorted(filenames):
            if not name.endswith(".gd"):
                continue
            path = os.path.join(dirpath, name)
            hits = process(path, args.fix, indent_unit)
            if hits:
                files += 1
                total += len(hits)
                rel = os.path.relpath(path, args.root)
                for line_no, text in hits:
                    print(f"{rel}:{line_no}: {text}")

    verb = "Fixed" if args.fix else "Found"
    print(f"\n{verb} {total} single-line lambda(s) across {files} file(s).")
    if total and not args.fix:
        print("Re-run with --fix to rewrite them.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
