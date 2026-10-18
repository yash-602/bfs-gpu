#!/usr/bin/env python3
"""scripts/make_zip.py -- OWNER: Member 1.
Packs the repository's source (no data/, build/, bin/) into a zip for uploading to Google Colab.
Works on Windows and Linux.

Usage (from the repository root): python scripts/make_zip.py [../bfs-gpu.zip]
"""
import os
import sys
import zipfile

SKIP_DIRS = {"data", "build", "bin", ".git", "__pycache__", ".venv", ".vscode"}
SKIP_EXT = (".csr", ".o", ".d", ".zip", ".nsys-rep", ".ncu-rep", ".sqlite")

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "..", "bfs-gpu.zip"))
count = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for d, dirs, names in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
        for name in sorted(names):
            if name.endswith(SKIP_EXT):
                continue
            path = os.path.join(d, name)
            z.write(path, os.path.relpath(path, root).replace(os.sep, "/"))
            count += 1
print("wrote %s (%d files, %.0f KB)" % (out, count, os.path.getsize(out) / 1024))
