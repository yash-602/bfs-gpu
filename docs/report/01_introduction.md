# 1 Introduction

*(Owner: Member 1. Draft. Rewrite in your own words before submission.)*

Breadth-first search (BFS) is one of the basic building blocks of graph processing. It is used directly for
shortest hop distances and connectivity, and as a step inside larger analyses of social networks, web graphs
and road maps. Because the graphs in these applications have millions to billions of edges, BFS is a natural
target for GPUs, which have thousands of threads and far higher memory bandwidth than a CPU.

BFS is hard to parallelise well because the work is irregular. A level-synchronous BFS expands one frontier
(the set of vertices discovered at the previous level) at a time. The simplest GPU mapping gives one thread
to each frontier vertex, and that thread walks the vertex's whole adjacency list. In real graphs vertex degrees
vary enormously: in a social network a few hub vertices have tens of thousands of neighbours while most have
only a handful. GPU threads execute in lock-step groups of 32 (warps), so one hub in a warp keeps the other
31 lanes idle until it is done, and the whole level waits for the slowest warp. Road networks are the
opposite: almost every vertex has degree 2 to 4, so there is little imbalance to remove, but the BFS has many
levels, each with a small frontier.

**Problem statement.** We ask whether a degree-aware, adaptive work distribution makes GPU BFS faster
than a naive one-thread-per-vertex mapping, on which kinds of graphs, and why. Equally important, we ask
when it does *not* help.

**Approach.** We build and compare three programs that share one graph format, one timing definition and one
correctness check:

1. a single-threaded serial CPU BFS, used as the correctness reference and the speedup baseline;
2. a naive CUDA BFS with one thread per frontier vertex and no degree awareness, which exposes the
   imbalance problem and serves as the ablation baseline;
3. an adaptive CUDA BFS that, at every level, sorts the frontier vertices into low-, medium- and high-degree
   buckets and expands them with one thread, one warp or one whole thread block per vertex respectively.

OpenMP is used on the CPU side for the work around the GPU kernels: parsing and building large graphs,
generating synthetic graphs, validating results, and overlapping validation and logging with the next GPU run.

**Contributions.**

- A shared, reproducible framework: compressed sparse row (CSR) graph storage, a parallel loader for SNAP
  edge lists, a deterministic parallel R-MAT generator, a serial reference BFS and two independent validators
  (exact comparison and a reference-free structural check).
- A naive and an adaptive CUDA BFS that differ *only* in how work is distributed, so that their difference
  isolates the effect of load balancing.
- An evaluation on road, social and R-MAT graphs using execution time, speedup, parallel efficiency, strong
  and weak scaling, and traversed edges per second (TEPS), plus an ablation of each part of the adaptive scheme.
- An honest comparison with recently published GPU BFS load-balancing work.

**Outline.** Section 2 introduces BFS, CSR, the GPU execution model and related work. Section 3 describes
the data and the three implementations, including the OpenMP host work. Section 4 gives the experimental
setup and the metrics. Section 5 presents the results, Section 6 the ablation and the analysis of when
adaptive load balancing helps, and Section 7 the comparison with prior work. Section 8 concludes.
