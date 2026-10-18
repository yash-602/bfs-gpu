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

> **PLACEHOLDER-NOT-YET-DELIVERED (Member 2):** add the experiment list (E1-E7, playbook section 8.1) and
> any protocol change made during the runs (e.g. reduced SRC/TRIALS, omitted scales), with the reason.
