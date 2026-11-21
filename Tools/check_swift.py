#!/usr/bin/env python3
"""本地静态检查（Windows/Linux 可跑）：括号配平、import、插值转义。"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "TianShen")


def main() -> int:
    files = []
    for dp, _, fn in os.walk(SRC):
        for f in fn:
            if f.endswith(".swift"):
                files.append(os.path.join(dp, f))
    files.sort()

    problems = 0
    total_lines = 0
    for path in files:
        text = io.open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, ROOT)
        total_lines += text.count("\n")
        stripped = re.sub(r'"(?:[^"\\]|\\.)*"', '""', text)
        for a, b in (("{", "}"), ("(", ")"), ("[", "]")):
            if stripped.count(a) != stripped.count(b):
                print("UNBALANCED %s %s  %d vs %d" % (a, rel, stripped.count(a), stripped.count(b)))
                problems += 1
        if "import " not in text:
            print("NO IMPORT", rel)
            problems += 1

    print("swift=%d lines=%d problems=%d" % (len(files), total_lines, problems))
    return 0 if problems == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
