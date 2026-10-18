# Report: assembly order and status (assembled by Member 1)

Final report = these files concatenated in this order. A file (or a block inside a file) with a
"PLACEHOLDER" box is still waiting for its owner (list them with the grep command in the README). Every number in the report must be
traceable to a CSV row in `results/` (and so to a script and a commit).

| File | Section | Owner | Status |
|------|---------|-------|--------|
| `01_introduction.md` | 1 Introduction | M1 | draft written |
| `02_background.md` | 2 Background and related work | M1 (+ M3 for GPU-BFS paper details) | draft written; M3 detail boxes open |
| `03_1_data.md` | 3.1 Data representation and datasets | M1 | written, numbers from `docs/dataset_table.md` |
| `03_2_serial_naive.md` | 3.2 Serial and naive implementations | M2 | PLACEHOLDER |
| `03_3_adaptive.md` | 3.3 Adaptive scheme | M3 | PLACEHOLDER |
| `03_4_openmp.md` | 3.4 OpenMP usage | M1 | written, E7 numbers from the development machine; re-run on the reference machine |
| `04_setup.md` | 4 Experimental setup | M1 + M2 | M1 parts written; hardware block waits for `results/env.txt` |
| `05_results.md` | 5 Results | M2 | PLACEHOLDER |
| `06_ablation.md` | 6 Ablation and analysis | M3 | PLACEHOLDER |
| `07_prior_work.md` | 7 Comparison with prior work | M3 | PLACEHOLDER |
| `08_conclusion.md` | 8 Conclusion, limitations, future work | all | PLACEHOLDER |
| `appendix_reproduction.md` | Appendix: reproduction | M1 | written |

Before submission (playbook 9.12): every figure has a caption, every table a title, all references are
complete, and every member has read the whole report once.
