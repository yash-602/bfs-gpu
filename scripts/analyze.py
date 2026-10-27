#!/usr/bin/env python3
"""scripts/analyze.py -- OWNER: Member 2.
Reads every results/*.csv written by bin/bench and produces summary tables
(results/summary_*.csv, results/tables.md) and figures (results/figs/*.png).

Usage: python3 scripts/analyze.py [--results results] [--sm-count N]
"""

import argparse, glob, os, re, sys
import numpy as np
import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

COL = {"serial": "#7f7f7f", "naive": "#e07b39", "adaptive": "#2b6cb0"}
CFG = [
    "block_size",
    "max_blocks",
    "warp_thresh",
    "block_thresh",
    "bucket_mode",
    "streams",
    "block_bucket",
]
KEYS = ["tag", "graph", "category", "impl"] + CFG


def md_table(df: pd.DataFrame, floatfmt="{:.3f}") -> str:
    cols = list(df.columns)
    out = ["| " + " | ".join(cols) + " |", "|" + "|".join("---" for _ in cols) + "|"]
    for _, r in df.iterrows():
        cells = []
        for c in cols:
            v = r[c]
            cells.append(floatfmt.format(v) if isinstance(v, (float, np.floating)) else str(v))
        out.append("| " + " | ".join(cells) + " |")
    return "\n".join(out)


def load(rdir):
    frames = []
    for p in sorted(glob.glob(os.path.join(rdir, "*.csv"))):
        name = os.path.basename(p)
        if "trace" in name or name.startswith("summary"):
            continue
        df = pd.read_csv(p)
        if "time_ms" in df.columns:
            frames.append(df)
    if not frames:
        sys.exit("no result CSVs found in " + rdir)
    return pd.concat(frames, ignore_index=True)


def summarize(df):
    g = (
        df.groupby(KEYS, dropna=False)
        .agg(
            time_ms=("time_ms", "median"),
            gteps=("gteps", "median"),
            runs=("time_ms", "size"),
            verified=("verified", "min"),
            levels=("levels", "median"),
        )
        .reset_index()
    )
    return g


def savefig(fig, figdir, name):
    os.makedirs(figdir, exist_ok=True)
    fig.tight_layout()
    fig.savefig(os.path.join(figdir, name), dpi=160)
    plt.close(fig)
    print("  wrote", os.path.join(figdir, name))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", default="results")
    ap.add_argument("--sm-count", type=int, default=0)
    a = ap.parse_args()
    rdir, figdir = a.results, os.path.join(a.results, "figs")
    df = load(rdir)
    sm = a.sm_count
    gi = os.path.join(rdir, "gpu_info.txt")
    if not sm and os.path.exists(gi):
        m = re.search(r"sm_count=(\d+)", open(gi).read())
        sm = int(m.group(1)) if m else 0
    md = []

    # ---- correctness ----
    bad = df[(df["verified"] == 0)]
    print("CORRECTNESS: %d rows, %d failed" % (len(df), len(bad)))
    md.append("## Correctness\n\nTotal runs: %d. Failed verification: %d.\n" % (len(df), len(bad)))
    if len(bad):
        print(bad.groupby(["graph", "impl", "tag"]).size())

    serial = df[df["impl"] == "serial"].groupby("graph")["time_ms"].median().rename("serial_ms")
    S = summarize(df)
    S = S.join(serial, on="graph")
    S["speedup_vs_serial"] = S["serial_ms"] / S["time_ms"]
    if sm:
        S["efficiency_per_SM"] = S["speedup_vs_serial"] / sm
    S.to_csv(os.path.join(rdir, "summary_all.csv"), index=False)

    # ---- E2 main table + figures ----
    M = S[S["tag"] == "E2_main"]
    if len(M):
        rows = []
        for gname, d in M.groupby("graph"):
            r = {"graph": gname, "category": d["category"].iloc[0]}
            r["serial_ms"] = d[d.impl == "serial"]["time_ms"].median()
            for impl in ("naive", "adaptive"):
                x = d[d.impl == impl]
                r[impl + "_ms"] = x["time_ms"].median() if len(x) else np.nan
                r[impl + "_speedup"] = r["serial_ms"] / r[impl + "_ms"] if len(x) else np.nan
                r[impl + "_GTEPS"] = x["gteps"].median() if len(x) else np.nan
            r["adaptive_vs_naive"] = r["naive_ms"] / r["adaptive_ms"]
            rows.append(r)
        T = pd.DataFrame(rows).sort_values(["category", "graph"])
        T.to_csv(os.path.join(rdir, "summary_main.csv"), index=False)
        md.append("## Main results (E2)\n\n" + md_table(T) + "\n")
        x = np.arange(len(T))
        w = 0.27
        for ycol, ylabel, fname, logy in [
            ("_ms", "time (ms, log)", "fig_time.png", True),
            ("_speedup", "speedup over serial CPU (log)", "fig_speedup.png", True),
            ("_GTEPS", "GTEPS", "fig_gteps.png", False),
        ]:
            fig, ax = plt.subplots(figsize=(9, 4.5))
            impls = ["serial", "naive", "adaptive"] if ycol == "_ms" else ["naive", "adaptive"]
            for k, impl in enumerate(impls):
                col = "serial_ms" if impl == "serial" else impl + ycol
                ax.bar(x + (k - (len(impls) - 1) / 2) * w, T[col], w, label=impl, color=COL[impl])
            if ycol == "_speedup":
                ax.axhline(1, color="k", lw=0.8, ls="--")
            ax.set_xticks(x)
            ax.set_xticklabels(T["graph"], rotation=30, ha="right")
            ax.set_ylabel(ylabel)
            if logy:
                ax.set_yscale("log")
            ax.legend()
            ax.grid(axis="y", alpha=0.3)
            savefig(fig, figdir, fname)
        fig, ax = plt.subplots(figsize=(9, 4.5))
        ax.bar(x, T["adaptive_vs_naive"], color=COL["adaptive"])
        ax.axhline(1, color="k", lw=0.8, ls="--")
        ax.set_xticks(x)
        ax.set_xticklabels(T["graph"], rotation=30, ha="right")
        ax.set_ylabel("adaptive speedup over naive (x)")
        ax.grid(axis="y", alpha=0.3)
        savefig(fig, figdir, "fig_ablation_adaptive_vs_naive.png")

    # ---- E3 ablation variants ----
    A = S[S["tag"].str.startswith("E3_") & (S["impl"] == "adaptive")]
    if len(A):
        rows = []
        for (gname, tag), d in A[A.tag != "E3_thresh"].groupby(["graph", "tag"]):
            rows.append(
                {
                    "graph": gname,
                    "variant": tag.replace("E3_", ""),
                    "time_ms": d["time_ms"].median(),
                    "gteps": d["gteps"].median(),
                }
            )
        V = pd.DataFrame(rows)
        if len(V):
            base = V[V.variant == "default"].set_index("graph")["time_ms"]
            V["relative_to_default"] = V.apply(lambda r: r.time_ms / base.get(r.graph, np.nan), axis=1)
            V.to_csv(os.path.join(rdir, "summary_ablation_variants.csv"), index=False)
            md.append("## Ablation variants (E3)\n\n" + md_table(V) + "\n")
        TH = A[A.tag == "E3_thresh"]
        for gname, d in TH.groupby("graph"):
            piv = d.pivot_table(
                index="warp_thresh", columns="block_thresh", values="time_ms", aggfunc="median"
            )
            if piv.size == 0:
                continue
            piv.to_csv(os.path.join(rdir, "summary_thresholds_%s.csv" % gname))
            fig, ax = plt.subplots(figsize=(6, 4))
            im = ax.imshow(piv.values, cmap="viridis_r", aspect="auto")
            ax.set_xticks(range(len(piv.columns)))
            ax.set_xticklabels(piv.columns)
            ax.set_yticks(range(len(piv.index)))
            ax.set_yticklabels(piv.index)
            ax.set_xlabel("block_thresh")
            ax.set_ylabel("warp_thresh")
            ax.set_title("adaptive time (ms), " + gname)
            for i in range(piv.shape[0]):
                for j in range(piv.shape[1]):
                    ax.text(
                        j, i, "%.1f" % piv.values[i, j], ha="center", va="center", color="w", fontsize=7
                    )
            fig.colorbar(im, ax=ax)
            savefig(fig, figdir, "fig_thresholds_%s.png" % gname)

    # ---- E4 strong scaling ----
    E4 = S[(S["tag"] == "E4_strong") & (S["impl"].isin(["naive", "adaptive"]))]
    rows = []
    for gname, d in E4.groupby("graph"):
        fig, axes = plt.subplots(1, 2, figsize=(11, 4.2))
        for impl in ("naive", "adaptive"):
            x = d[(d.impl == impl) & (d.max_blocks > 0)].sort_values("max_blocks")
            if not len(x):
                continue
            R0, T0 = x["max_blocks"].iloc[0], x["time_ms"].iloc[0]
            x = x.assign(
                speedup_vs_R0=T0 / x["time_ms"], efficiency=(T0 / x["time_ms"]) / (x["max_blocks"] / R0)
            )
            axes[0].plot(x["max_blocks"], x["time_ms"], "o-", color=COL[impl], label=impl)
            axes[1].plot(x["max_blocks"], x["efficiency"], "o-", color=COL[impl], label=impl)
            for _, r in x.iterrows():
                rows.append(
                    {
                        "graph": gname,
                        "impl": impl,
                        "max_blocks": int(r.max_blocks),
                        "time_ms": r.time_ms,
                        "speedup_vs_R0": r.speedup_vs_R0,
                        "scaling_efficiency": r.efficiency,
                    }
                )
            u = d[(d.impl == impl) & (d.max_blocks == 0)]
            if len(u):
                axes[0].axhline(u["time_ms"].iloc[0], color=COL[impl], ls=":", lw=1)
        axes[0].set_xscale("log", base=2)
        axes[0].set_yscale("log")
        axes[0].set_xlabel("R = max blocks per kernel launch")
        axes[0].set_ylabel("time (ms)")
        axes[0].set_title("strong scaling: " + gname + " (dotted = unlimited grid)")
        axes[1].set_xscale("log", base=2)
        axes[1].set_xlabel("R")
        axes[1].set_ylabel("efficiency T(R0) / (T(R) * R/R0)")
        axes[1].axhline(1, color="k", lw=0.8, ls="--")
        axes[1].set_title("parallel (scaling) efficiency")
        for ax in axes:
            ax.grid(alpha=0.3)
            ax.legend()
        savefig(fig, figdir, "fig_strong_%s.png" % gname)
    if rows:
        SS = pd.DataFrame(rows)
        SS.to_csv(os.path.join(rdir, "summary_strong.csv"), index=False)
        md.append("## Strong scaling (E4)\n\n" + md_table(SS) + "\n")

    # ---- E5 weak scaling ----
    E5 = S[(S["tag"] == "E5_weak") & (S["impl"].isin(["naive", "adaptive"]))]
    if len(E5):
        rows = []
        fig, ax = plt.subplots(figsize=(6.5, 4.2))
        for impl in ("naive", "adaptive"):
            x = E5[E5.impl == impl].sort_values("max_blocks")
            if not len(x):
                continue
            eff = x["time_ms"].iloc[0] / x["time_ms"]
            ax.plot(range(len(x)), eff, "o-", color=COL[impl], label=impl)
            for i, (_, r) in enumerate(x.iterrows()):
                rows.append(
                    {
                        "impl": impl,
                        "step": i,
                        "graph": r.graph,
                        "max_blocks": int(r.max_blocks),
                        "time_ms": r.time_ms,
                        "weak_efficiency": x["time_ms"].iloc[0] / r.time_ms,
                    }
                )
            ax.set_xticks(range(len(x)))
            ax.set_xticklabels(
                ["%s\nR=%d" % (g, r) for g, r in zip(x["graph"], x["max_blocks"])], fontsize=7
            )
        ax.axhline(1, color="k", lw=0.8, ls="--")
        ax.set_ylabel("weak efficiency T(step0)/T(step)")
        ax.set_title("weak scaling (problem and resources double each step)")
        ax.grid(alpha=0.3)
        ax.legend()
        savefig(fig, figdir, "fig_weak.png")
        W = pd.DataFrame(rows)
        W.to_csv(os.path.join(rdir, "summary_weak.csv"), index=False)
        md.append("## Weak scaling (E5)\n\n" + md_table(W) + "\n")

    # ---- E6 block size ----
    E6 = S[(S["tag"] == "E6_block") & (S["impl"].isin(["naive", "adaptive"]))]
    if len(E6):
        graphs = sorted(E6["graph"].unique())
        fig, axes = plt.subplots(1, len(graphs), figsize=(4.2 * len(graphs), 3.8), squeeze=False)
        for ax, gname in zip(axes[0], graphs):
            for impl in ("naive", "adaptive"):
                x = E6[(E6.graph == gname) & (E6.impl == impl)].sort_values("block_size")
                ax.plot(x["block_size"], x["time_ms"], "o-", color=COL[impl], label=impl)
            ax.set_xscale("log", base=2)
            ax.set_title(gname)
            ax.set_xlabel("block size")
            ax.set_ylabel("time (ms)")
            ax.grid(alpha=0.3)
            ax.legend()
        savefig(fig, figdir, "fig_blocksize.png")

    # ---- per-level traces ----
    for p in glob.glob(os.path.join(rdir, "*trace*.csv")):
        t = pd.read_csv(p)
        for gname, d in t.groupby("graph"):
            d = d.sort_values("level")
            fig, ax = plt.subplots(figsize=(8, 3.8))
            ax.stackplot(
                d["level"],
                d["n_low"],
                d["n_mid"],
                d["n_high"],
                labels=["low (thread)", "mid (warp)", "high (block)"],
                colors=["#9ecae1", "#3182bd", "#08306b"],
            )
            ax.set_xlabel("BFS level")
            ax.set_ylabel("frontier vertices")
            ax.set_title("bucket composition per level: " + gname)
            ax.legend(loc="upper right")
            ax.grid(alpha=0.3)
            savefig(fig, figdir, "fig_trace_%s.png" % gname)

    with open(os.path.join(rdir, "tables.md"), "w") as f:
        f.write("# Auto-generated tables\n\n" + "\n".join(md))
    print("wrote", os.path.join(rdir, "tables.md"))


if __name__ == "__main__":
    main()
