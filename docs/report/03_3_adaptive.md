# 3.3 Adaptive load-balanced BFS scheme

## Motivation

BFS frontier vertices can have very different degrees. A thread assigned to
a low-degree vertex may finish quickly, while a thread assigned to a
high-degree vertex must process a much longer adjacency list. This creates
work imbalance during GPU frontier expansion.

The adaptive implementation classifies frontier vertices by degree and
uses different cooperative expansion strategies for each group.

## Degree buckets

The frontier is divided into three buckets:

- LOW: degree below the warp threshold.
- MID: degree at least the warp threshold and below the block threshold.
- HIGH: degree at least the block threshold.

The experimental configuration uses warp threshold 8, block threshold 2048
and CUDA block size 256. These are experimental settings; the shared API
defaults have not been changed.

## Expansion kernels

The LOW bucket uses thread-per-vertex expansion. Each thread processes the
adjacency list of one vertex.

The MID bucket uses warp-per-vertex expansion. The 32 lanes of a warp
cooperatively process a vertex's adjacency list.

The HIGH bucket uses block-per-vertex expansion. Threads in a CUDA block
cooperate on the adjacency list of a high-degree vertex.

The kernels use the shared discovery and append helpers. Atomic claiming
prevents multiple workers from successfully discovering the same vertex.

## Classification and compaction

In SCAN mode, CUB `DeviceSelect::If` compacts frontier vertices into the
degree buckets. The corresponding expansion kernels process each bucket.

The implementation supports optional CUDA streams for bucket expansion.
Stream work is synchronized before the next BFS level is processed.

## FUSED variant

FUSED combines classification with immediate expansion of LOW vertices.
MID and HIGH vertices are deferred to their respective cooperative queues.
This avoids a separate LOW expansion pass, although the performance effect
depends on the graph and frontier distribution.

## Correctness

Atomic compare-and-swap ensures that only one worker claims a previously
unvisited vertex. A successful claim assigns the next BFS level and appends
the vertex once. Each frontier vertex is assigned to a degree bucket, and
stream work completes before the next BFS level begins.

The adaptive test suite passed 35 configurations. The recorded E3 and E6
experiment rows also report successful verification.

## Pipeline and overhead model

A SCAN BFS level consists conceptually of:

1. Read the current frontier and determine vertex degrees.
2. Classify and compact vertices into LOW, MID and HIGH buckets.
3. Expand each bucket using its thread-, warp- or block-cooperative kernel.
4. Complete stream work and advance to the next frontier.

A conceptual per-level time model is:

`T_level = T_classify + T_compact + T_expand_LOW + T_expand_MID + T_expand_HIGH + T_sync`

FUSED performs LOW expansion during classification, combining those operations.

This is a conceptual model. Per-level timing traces and Nsight profiling were
not collected, so no measured breakdown of these components is claimed.
