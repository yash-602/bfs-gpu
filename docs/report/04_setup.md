# 4 Experimental setup

*(Owners: Member 1 and Member 2.)*

## 4.1 Hardware and software

> **PLACEHOLDER-NOT-YET-DELIVERED (Member 2 + Member 1):** paste `results/env.txt` and `results/gpu_info.txt`
> from the reference machine here, as a table: GPU model, SM count, compute capability, GPU memory and
> bandwidth, driver, CUDA toolkit, CPU, cores, RAM, OS, g++ version, compiler flags (`-O3`, `-arch=...`) and
> the git commit of the run.

All final numbers come from one reference machine (`docs/decisions.md`), one git commit, and one run of
`scripts/run_all.sh`. The datasets and E7 were prepared on a separate development machine (Intel Core
i5-12450H, 12 logical CPUs, 7.6 GB RAM, Ubuntu 24.04 on WSL2, g++ 13.3); graph contents do not depend on the
machine, and E7 is reported for that machine.

## 4.2 Datasets

See Table 3.1 (and `docs/dataset_table.md` for all R-MAT scales and the comparison with SNAP).

## 4.3 Protocol

- Seed 1 everywhere. For each graph, 5 sources from `pick_sources(g, 5, 1)`, all in the hub's component.
- GPU programs: 1 untimed warm-up run per (implementation, source), then 5 timed trials per source, so 25
  values per configuration. Serial: 3 timed trials per source.
- The reported time of a configuration is the **median** of its runs. Medians are robust to single slow
  outliers (operating-system interruptions, clock changes).
- Every GPU result is compared element by element with the serial reference (and, with `--structural`, also
  checked by the reference-free validator). A run counts only if it is verified.

**What is timed.** The traversal only: everything inside the BFS level loop, i.e. kernel launches, per-level
memsets and copies of counters, host synchronisation, bucket classification and stream synchronisation.
The clock is the host steady clock, started after a `cudaDeviceSynchronize()` at the end of setup and stopped
after the final one. *Not* timed: GPU memory allocation and freeing, initialising the levels array, uploading
the graph, copying the final levels back, validation, CSV writing and graph loading.

**Limitation.** The serial time includes `bfs_serial`'s own O(n) initialisation and queue allocation, while
the GPU times exclude the equivalent setup. This biases the GPU speedups slightly upwards.

## 4.4 Metrics

| Metric | Definition |
|--------|------------|
| edges traversed | sum of degree(v) over all reached vertices (CSR entries scanned). Graph500 counts half of this for undirected graphs; we report the CSR-entry count. |
| TEPS / GTEPS | edges_traversed / (time_ms / 1000); GTEPS = edges_traversed / (time_ms x 10^6) |
| time of a configuration | median of time_ms over all (source, trial) rows |
| speedup over serial | S = T_serial / T_impl (medians) |
| ablation factor | A = T_naive / T_adaptive on identical graph, sources and hardware (A > 1: adaptive faster) |
| strong-scaling efficiency | for grid caps R0 < R1 < ...: E(R) = T(R0) / (T(R) x R / R0); 1.0 = perfect |
| weak-scaling efficiency | step i doubles both graph size and R: E_weak(i) = T(step 0) / T(step i) |
| per-SM efficiency (optional) | speedup over serial / number of SMs |
| resource R | `max_blocks`, the maximum grid size of each kernel launch (valid because all kernels use grid-stride loops); 0 = unlimited |

## 4.5 Experiments

All GPU experiments are run by `scripts/run_all.sh` through `bin/bench`; E7 by `scripts/omp_scaling.sh`.

| ID | Question | Graphs | What varies | Output |
|----|----------|--------|-------------|--------|
| E1 | Is everything correct? | the small test suite + every real graph | all implementations and configurations | `verified` column, `test_*` programs |
| E2 | How fast is each implementation per graph category? | roadNet-CA, com-youtube, soc-LiveJournal1, com-orkut, rmat16/18/20/22 | serial vs naive vs adaptive (defaults) | `results/E2_main.csv` |
| E3 | Which parts of the adaptive scheme matter? | roadNet-CA, soc-LiveJournal1, rmat22 | block bucket on/off, streams on/off, SCAN vs FUSED, thresholds (warp 8..128 x block 512..4096) | `results/E3_ablation.csv` |
| E4 | Strong scaling | roadNet-CA, soc-LiveJournal1, rmat22 | R = 1, 2, 4, ..., 1024 blocks per kernel, plus unlimited | `results/E4_strong.csv` |
| E5 | Weak scaling | rmat15 ... rmat22 | scale 15+i with R = 8 x 2^i | `results/E5_weak.csv` |
| E6 | Best block size? | roadNet-CA, soc-LiveJournal1, rmat22 | block size 32 ... 1024 | `results/E6_block.csv` |
| E7 | OpenMP host scaling | com-youtube, rmat20 | OMP_NUM_THREADS = 1, 2, 4, 8 | `results/omp_scaling.csv` |

E2 and E3 use 5 sources x 5 trials; E4, E5 and E6 use 3 sources x 3 trials and 1 serial trial. Note that R
is a per-kernel cap: the adaptive program may run up to three kernels at once on separate streams, so it can
use up to 3R blocks at a time (the `--no-streams` variant in E3 removes this difference).

> **PLACEHOLDER-NOT-YET-DELIVERED (Member 2):** after the final run, list any protocol change made during the
> runs (e.g. reduced SRC/TRIALS, graphs or scales omitted because of GPU memory or time), with the reason.
