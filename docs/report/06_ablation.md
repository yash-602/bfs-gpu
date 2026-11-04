# 6 Ablation and analysis

## Setup

The ablation compares the SCAN baseline with three variants: streams disabled,
block bucket disabled, and FUSED classification/expansion.

The experimental thresholds are warp threshold 8 and block threshold 2048,
with block size 256. The CSV rows report correctness verification.

## Initial E6 measurements

| graph            | tag                             |   mean_ms |   median_ms |   std_ms |   trials |
|:-----------------|:--------------------------------|----------:|------------:|---------:|---------:|
| rmat22           | ablation_baseline_rmat          |    44.425 |      44.477 |    0.45  |        5 |
| rmat22           | ablation_fused_rmat             |    41.458 |      41.602 |    0.341 |        5 |
| rmat22           | ablation_no_block_bucket_rmat   |    48.943 |      48.62  |    1.317 |        5 |
| rmat22           | ablation_no_streams_rmat        |    44.479 |      44.608 |    0.458 |        5 |
| roadNet-CA       | ablation_baseline_road          |   160.509 |     155.439 |   68.24  |        5 |
| roadNet-CA       | ablation_fused_road             |    23.294 |      23.097 |    0.612 |        5 |
| roadNet-CA       | ablation_no_block_bucket_road   |    37.233 |      36.006 |    2.517 |        5 |
| roadNet-CA       | ablation_no_streams_road        |    50.585 |      46.617 |    6.246 |        5 |
| soc-LiveJournal1 | ablation_baseline_social        |    28.645 |      28.592 |    0.237 |        5 |
| soc-LiveJournal1 | ablation_fused_social           |    29.19  |      28.9   |    3.061 |        5 |
| soc-LiveJournal1 | ablation_no_block_bucket_social |    29.314 |      29.541 |    0.506 |        5 |
| soc-LiveJournal1 | ablation_no_streams_social      |    28.65  |      28.893 |    0.987 |        5 |

RoadNet-CA was subsequently rerun with ten trials and three warmups.
Those measurements are reported separately and should be used instead of
the initial RoadNet measurements:

| tag                             |   mean_ms |   median_ms |   std_ms |   trials |
|:--------------------------------|----------:|------------:|---------:|---------:|
| road_validation_baseline        |    60.799 |      63.722 |   14.119 |       10 |
| road_validation_fused           |    21.978 |      22.026 |    0.352 |       10 |
| road_validation_no_block_bucket |    34.536 |      34.535 |    0.824 |       10 |
| road_validation_no_streams      |    41.029 |      40.268 |    3.964 |       10 |

## Interpretation

### R-MAT22

FUSED has the lowest median time at 41.602 ms, compared with 44.477 ms for
the SCAN baseline. Disabling the block bucket increases the median to
48.620 ms. Disabling streams gives 44.608 ms, close to the baseline.

### RoadNet-CA

In the ten-trial rerun, FUSED has the lowest median at 22.026 ms. The
no-block-bucket and no-streams variants have medians of 34.535 ms and
40.268 ms, respectively. The baseline median is 63.722 ms, with standard
deviation 14.119 ms, indicating substantial timing variability.

### LiveJournal1

The SCAN baseline has the lowest median at 28.592 ms. FUSED is 28.900 ms,
no streams is 28.893 ms, and no block bucket is 29.541 ms. These differences
are small and should not be overstated.

## When does adaptive load balancing help?

The measured result depends on the graph. FUSED has the lowest median on
R-MAT22 and RoadNet-CA, while the SCAN baseline is marginally fastest on
LiveJournal1. Removing the block bucket is slower on R-MAT22 and LiveJournal1
in these measurements.

These observations apply to the tested T4 setup and source selections.
They do not establish the low-level cause of the differences.

## Profiling limitations

Nsight Systems profiling and per-level traces were not collected. Therefore
the report does not claim measured stream overlap, occupancy, bucket
proportions per level or per-level kernel overhead. Those remain future work.
