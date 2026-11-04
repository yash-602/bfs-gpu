# Adaptive scheme: design, tuning and final experimental configuration

**Owner: Member 3**

## Objective

The adaptive BFS implementation addresses load imbalance during frontier expansion.
Vertices have different adjacency-list lengths. A single thread per vertex can
therefore leave some threads with substantially more work than others.

The implementation classifies frontier vertices by degree and assigns different
cooperative expansion strategies to three buckets.

## Buckets and kernels

- LOW: degree below `warp_thresh`; thread-per-vertex expansion.
- MID: degree at least `warp_thresh` and below `block_thresh`; warp-per-vertex
  expansion using 32 lanes.
- HIGH: degree at least `block_thresh`; block-per-vertex expansion.

The experimental CUDA block size is 256 threads.

## Classification modes

SCAN uses CUB `DeviceSelect::If` to compact frontier vertices into degree
buckets. Each bucket is expanded using its corresponding kernel.

FUSED combines classification with immediate LOW-bucket expansion. MID and
HIGH vertices are queued for their cooperative kernels.

Optional CUDA streams allow bucket expansion to be submitted separately.
Stream work is synchronized before the next BFS level begins.

## Correctness argument

The shared atomic compare-and-swap claim ensures that only one worker discovers
and appends a previously unvisited vertex. A successful claim assigns the
next BFS level. Degree classification partitions the current frontier, and
the implementation completes stream work before advancing to the next level.

The adaptive correctness suite passed 35 configurations. All rows in the
saved E3 and E6 experiment CSVs report successful verification.

## E3 threshold grid

The following tables contain the single-run adaptive timing observations for
the 20 threshold combinations on each graph. These are exploratory grid
measurements, not repeated-trial estimates.

### R-MAT22

|   warp_thresh |   block_thresh |   time_ms |
|--------------:|---------------:|----------:|
|             8 |            512 |    44.778 |
|             8 |           1024 |    46.798 |
|             8 |           2048 |    45.162 |
|             8 |           4096 |    45.3   |
|            16 |            512 |    48.653 |
|            16 |           1024 |    45.893 |
|            16 |           2048 |    45.778 |
|            16 |           4096 |    49.569 |
|            32 |            512 |    46.185 |
|            32 |           1024 |    46.6   |
|            32 |           2048 |    46.547 |
|            32 |           4096 |    46.65  |
|            64 |            512 |    47.445 |
|            64 |           1024 |    47.691 |
|            64 |           2048 |    47.725 |
|            64 |           4096 |    47.867 |
|           128 |            512 |    49.813 |
|           128 |           1024 |    50.551 |
|           128 |           2048 |    50.21  |
|           128 |           4096 |    51.613 |
### RoadNet-CA

|   warp_thresh |   block_thresh |   time_ms |
|--------------:|---------------:|----------:|
|             8 |            512 |    55.245 |
|             8 |           1024 |    43.87  |
|             8 |           2048 |    42.274 |
|             8 |           4096 |    40.847 |
|            16 |            512 |    39.633 |
|            16 |           1024 |    39.818 |
|            16 |           2048 |    39.462 |
|            16 |           4096 |    42.138 |
|            32 |            512 |    42.456 |
|            32 |           1024 |    42.256 |
|            32 |           2048 |    39.811 |
|            32 |           4096 |    39.491 |
|            64 |            512 |    59.671 |
|            64 |           1024 |    69.971 |
|            64 |           2048 |    64.463 |
|            64 |           4096 |    63.779 |
|           128 |            512 |    44.598 |
|           128 |           1024 |    39.335 |
|           128 |           2048 |    39.446 |
|           128 |           4096 |    41.359 |
### LiveJournal1

|   warp_thresh |   block_thresh |   time_ms |
|--------------:|---------------:|----------:|
|             8 |            512 |    29.039 |
|             8 |           1024 |    29.337 |
|             8 |           2048 |    29.481 |
|             8 |           4096 |    30.734 |
|            16 |            512 |    30.12  |
|            16 |           1024 |    30.359 |
|            16 |           2048 |    30.555 |
|            16 |           4096 |    31.722 |
|            32 |            512 |    32.807 |
|            32 |           1024 |    32.979 |
|            32 |           2048 |    33.126 |
|            32 |           4096 |    34.855 |
|            64 |            512 |    36.312 |
|            64 |           1024 |    36.703 |
|            64 |           2048 |    41.037 |
|            64 |           4096 |    36.872 |
|           128 |            512 |    38.907 |
|           128 |           1024 |    39.257 |
|           128 |           2048 |    40.846 |
|           128 |           4096 |    39.401 |

## Candidate validation

Three candidates were tested with five trials per graph.

| graph            |   warp_thresh |   block_thresh |   mean_ms |   median_ms |   std_ms |   trials |
|:-----------------|--------------:|---------------:|----------:|------------:|---------:|---------:|
| rmat22           |             8 |           2048 |    44.537 |      44.691 |    0.387 |        5 |
| rmat22           |            16 |           1024 |    45.305 |      45.503 |    0.348 |        5 |
| rmat22           |            16 |           2048 |    47.287 |      46.755 |    2.563 |        5 |
| roadNet-CA       |             8 |           2048 |    39.25  |      37.54  |    4.977 |        5 |
| roadNet-CA       |            16 |           1024 |    39.803 |      39.963 |    0.561 |        5 |
| roadNet-CA       |            16 |           2048 |    47.464 |      46.136 |    3.574 |        5 |
| soc-LiveJournal1 |             8 |           2048 |    28.581 |      28.412 |    0.333 |        5 |
| soc-LiveJournal1 |            16 |           1024 |    45.445 |      43.718 |    5.792 |        5 |
| soc-LiveJournal1 |            16 |           2048 |    29.543 |      29.314 |    0.462 |        5 |

Geometric mean of the per-graph median times:

|   warp_thresh |   block_thresh |   geometric_mean_median_ms |
|--------------:|---------------:|---------------------------:|
|             8 |           2048 |                     36.258 |
|            16 |           2048 |                     39.84  |
|            16 |           1024 |                     42.998 |

The `8/2048` pair has the lowest geometric mean among these three validated
candidates. It is the selected experimental configuration, not a proven
global optimum.

**Selected experimental settings:** `warp_thresh=8`, `block_thresh=2048`,
`block_size=256`, `bucket_mode=SCAN`, streams enabled, block bucket enabled.

The shared `include/bfs_api.h` defaults have not been changed. Any shared
contract change requires team agreement and the repository's contract procedure.

## Limitations

- Initial threshold grid: one timed adaptive observation per pair.
- Candidate validation: five trials for three candidate pairs.
- Ablation: one source per graph.
- Nsight Systems profiling and saved per-level traces were not collected.
- Results are from the tested NVIDIA T4 environment.
- Future work: collect per-level bucket sizes, frontier sizes, kernel timings,
  stream overlap and occupancy; repeat tuning across more sources and GPUs.
