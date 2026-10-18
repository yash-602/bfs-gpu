#!/usr/bin/env python3
"""scripts/plot_omp_scaling.py -- OWNER: Member 1.
Experiment E7: plots speedup T(1)/T(t) of the host-side OpenMP preprocessing versus thread count.

Usage: python3 scripts/plot_omp_scaling.py [results/omp_scaling.csv] [results/figs/fig_omp_scaling.png]
Input columns (written by scripts/omp_scaling.sh): threads,convert_ms,rmat20_ms
"""
import csv
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

src = sys.argv[1] if len(sys.argv) > 1 else "results/omp_scaling.csv"
dst = sys.argv[2] if len(sys.argv) > 2 else "results/figs/fig_omp_scaling.png"

with open(src) as f:
    rows = [r for r in csv.DictReader(f)]
threads = [int(r["threads"]) for r in rows]
fig, ax = plt.subplots(figsize=(6, 4))
for col, label in [("convert_ms", "convert com-youtube (parse + build CSR)"),
                   ("rmat20_ms", "generate rmat20 (R-MAT + build CSR)")]:
    t = [float(r[col]) for r in rows]
    ax.plot(threads, [t[0] / x for x in t], "o-", label=label)
ax.plot(threads, threads, "k--", lw=0.8, label="ideal (speedup = threads)")
ax.set_xscale("log", base=2)
ax.set_xticks(threads)
ax.set_xticklabels(threads)
ax.set_xlabel("OpenMP threads (OMP_NUM_THREADS)")
ax.set_ylabel("speedup T(1) / T(t)")
ax.set_title("E7: host-side OpenMP scaling")
ax.grid(alpha=0.3)
ax.legend(fontsize=8)
os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
fig.tight_layout()
fig.savefig(dst, dpi=160)
print("wrote", dst)
