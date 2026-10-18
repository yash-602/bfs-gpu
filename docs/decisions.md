# Team decisions (kept by Member 1)

One line per decision, with the date. Things in `<angle brackets>` are still open.

- Day 0 (`<date>`): reference machine = `<GPU model, owner, how others get access>`; contract version = 1.
- Day 0 (`<date>`): team names and roles = `<Member 1 name>` (M1), `<Member 2 name>` (M2), `<Member 3 name>` (M3).
- Day 0 (`<date>`): instructor's report template / page limit / demo format = `<answer from instructor>`.
- 2026-10-17: host library (H2) verified on Member 1's development machine (WSL2 Ubuntu 24.04, g++ 13.3,
  GNU make 4.3, 12 logical CPUs). `make host` has no warnings, `test_host` passes 39/39, and all golden
  values of playbook 6.7 are reproduced exactly (rmat18: n=262144, m=7612566, 88105 isolated, max degree
  25096, CV 6.473, est. diameter 7; serial src=149623 levels=6 edges=7612472 structural=OK).
  R-MAT output is byte-identical for OMP_NUM_THREADS=1 and 4.
- 2026-10-17: the development machine cannot run CUDA (no GPU visible inside WSL, no nvcc in WSL), so
  `hello_cuda` and `check_all.sh` steps 3-5 still have to be run on the reference machine.

- 2026-10-17 (proposed, needs M2 + M3 agreement): Member 1's own GPU is not usable, so the team will
  probably use Google Colab (T4, sm_75) via `colab/bfs_colab.ipynb`. If Colab becomes the reference machine,
  all final experiments run in ONE Colab session, and `results/env.txt` + `results/gpu_info.txt` from that
  session are stored with the CSVs (playbook 4.3).
- 2026-10-17: GPU build compile-tested without a GPU (nvcc 12.6 from conda-forge in WSL, ARCH=sm_75):
  `make all` has no warnings with the placeholders, and also with the naive/adaptive code exactly as printed in
  the Member 2 and Member 3 playbooks, so the contract headers work with the teammates' code. Not run (no GPU).

## Independent re-computations of results (quality gate, playbook 9.11)

| Date | CSV row checked (file, graph, impl, source) | graph_tool serial result | Matches? |
|------|---------------------------------------------|--------------------------|----------|
| `<to do after H8>` | | | |
| `<to do after H8>` | | | |
| `<to do after H8>` | | | |
