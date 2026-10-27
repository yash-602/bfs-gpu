# 5 Results

> **PLACEHOLDER-NOT-YET-DELIVERED (Member 2): waiting for the GPU run.**
>
> The code that produces this section is complete (`bench`, `scripts/run_all.sh`, `scripts/analyze.py`); what
> is missing are real measurements, which need an NVIDIA GPU. Steps:
> 1. On the reference machine (or one Colab session): `bash scripts/env_report.sh > results/env.txt`, then
>    `bash scripts/run_all.sh` (use `IMPL=naive` while `src/bfs_adaptive.cu` is still a placeholder), then
>    `python3 scripts/analyze.py`.
> 2. Write one subsection per experiment E2, E4, E5, E6 (playbook M2 9.13), each with its figure from
>    `results/figs/`, its table from `results/tables.md`, and 3-5 sentences: what is plotted, what it shows,
>    the likely cause (with the supporting trace/profile), and the caveat.
> 3. Every caption states graph(s), implementation(s), metric, number of sources/trials and the GPU model.
>
> Expected figures: R1 `fig_time.png`, R2 `fig_speedup.png`, R3 `fig_gteps.png`,
> R4 `fig_ablation_adaptive_vs_naive.png`, R5 `fig_strong_<graph>.png` (one per category), R6 `fig_weak.png`,
> R7 `fig_blocksize.png`. Tables: main summary, strong scaling, weak scaling, correctness summary.
