# Auto-generated tables

## Correctness

Total runs: 392. Failed verification: 0.

## Main results (E2)

| graph | category | serial_ms | naive_ms | naive_speedup | naive_GTEPS | adaptive_ms | adaptive_speedup | adaptive_GTEPS | adaptive_vs_naive |
|---|---|---|---|---|---|---|---|---|---|
| rmat16 | rmat | 3.983 | 5.506 | 0.723 | 0.331 | nan | nan | nan | nan |
| rmat18 | rmat | 23.769 | 23.097 | 1.029 | 0.337 | nan | nan | nan | nan |
| rmat20 | rmat | 161.865 | 43.857 | 3.691 | 0.792 | nan | nan | nan | nan |
| rmat22 | rmat | 1089.526 | 128.110 | 8.505 | 1.004 | nan | nan | nan | nan |
| roadNet-CA | road | 76.743 | 19.083 | 4.021 | 0.290 | nan | nan | nan | nan |
| com-orkut | social | 1349.363 | 118.620 | 11.376 | 1.982 | nan | nan | nan | nan |
| com-youtube | social | 53.218 | 35.201 | 1.512 | 0.170 | nan | nan | nan | nan |
| soc-LiveJournal1 | social | 757.211 | 60.781 | 12.458 | 1.413 | nan | nan | nan | nan |

## Weak scaling (E5)

| impl | step | graph | max_blocks | time_ms | weak_efficiency |
|---|---|---|---|---|---|
| naive | 0 | rmat15 | 8 | 5.005 | 1.000 |
| naive | 1 | rmat16 | 16 | 5.109 | 0.980 |
| naive | 2 | rmat17 | 32 | 8.644 | 0.579 |
| naive | 3 | rmat18 | 64 | 14.398 | 0.348 |
| naive | 4 | rmat19 | 128 | 18.794 | 0.266 |
| naive | 5 | rmat20 | 256 | 32.469 | 0.154 |
| naive | 6 | rmat21 | 512 | 88.157 | 0.057 |
| naive | 7 | rmat22 | 1024 | 121.872 | 0.041 |
