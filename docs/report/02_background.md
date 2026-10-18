# 2 Background and related work

*(Owner: Member 1, with Member 3 for the technical detail of the GPU-BFS papers. Draft. Rewrite in your
own words. Do not add any number from a paper unless you have opened the paper and noted its
table/figure/page.)*

## 2.1 Breadth-first search

Given a graph G = (V, E) and a source vertex s, BFS computes for every vertex v its level: the number of
edges on a shortest path from s to v, or -1 if v cannot be reached. Level-synchronous BFS processes the graph
in rings: level 0 is {s}, level k+1 consists of all not-yet-visited neighbours of level-k vertices. The vertices
discovered at one level form the *frontier*. All parallel workers expand the current frontier together, and
level k+1 starts only after level k has finished. Every vertex enters a frontier at most once, so a BFS reads
each adjacency list of a reachable vertex exactly once: O(|V| + |E|) work.

Example: for the 7-vertex graph with edges 0-1, 0-2, 1-3, 2-3, 2-4, 4-5 (vertex 6 isolated) and source 0, the
frontiers are {0}, {1, 2}, {3, 4}, {5}, and the result is levels = [0, 1, 1, 2, 2, 3, -1].

## 2.2 Compressed sparse row (CSR) storage

All programs store graphs in CSR form, two integer arrays: `row_offsets` (n+1 entries) and `col_indices`
(m entries). The neighbours of v are `col_indices[row_offsets[v] .. row_offsets[v+1]-1]`, so
degree(v) = row_offsets[v+1] - row_offsets[v]. For the example graph, row_offsets =
[0, 2, 4, 7, 9, 11, 12, 12] and col_indices = [1,2, 0,3, 0,3,4, 1,2, 2,5, 4]. CSR is compact (4(n+1) + 4m bytes
with 32-bit indices), and one vertex's neighbours are contiguous, so a group of GPU threads reading one
adjacency list reads consecutive addresses (coalesced access). Our graphs are undirected, so each edge is
stored in both directions and m = 2 x (number of undirected edges).

## 2.3 GPU execution model (what matters for BFS)

An NVIDIA GPU consists of streaming multiprocessors (SMs). A kernel launch creates a grid of thread blocks;
each block (up to 1024 threads) runs on one SM, and its threads execute in warps of 32 in lock-step (SIMT). If
the threads of one warp need different numbers of loop iterations, the warp runs as long as its slowest thread
(divergence). Global memory has high bandwidth but high latency; it is used efficiently only when neighbouring
threads read neighbouring addresses (coalescing) and when enough warps are resident to hide the latency
(occupancy). Atomic operations (compare-and-swap, add) let threads claim a vertex or reserve queue slots
without races, at the cost of serialisation when many threads hit the same address. BFS performs almost no
arithmetic per edge; its speed is limited by memory traffic and by how evenly work is spread over the threads.

## 2.4 Related work

*(For each paper: 2-3 sentences on what it does and how it relates to us. The statements below are taken
from the team synopsis; Member 3 checks them against the papers and adds the technical details.)*

**Merrill, Garland and Grimshaw, "Scalable GPU Graph Traversal" (PPoPP 2012).** Introduced prefix-sum based
frontier compaction and several load-balancing strategies for GPU BFS (fine-grained, coarse-grained and their
combination), and established the vocabulary of frontier expansion and work-efficient compaction. Our
warp- and block-cooperative expansion belongs to the same family of strategies.

**Beamer, Asanovic and Patterson, "Direction-Optimizing Breadth-First Search" (SC 2012).** Switches
between top-down expansion and bottom-up search (unvisited vertices look for a parent in the frontier)
depending on frontier size, which removes many redundant edge checks on low-diameter graphs. This is an
optimisation axis orthogonal to load balancing and a natural extension of our work.

**Busato and Bombieri, "BFS-4K" (IEEE TPDS 2015).** An edge-based, warp-centric BFS tuned to the Kepler
architecture's warp and memory model; a reference point for our warp-cooperative kernel.

**Sundaram et al., dynamic load-balancing strategies for graph applications on GPUs (arXiv:1711.00231).**
Compares node-based and edge-based load balancing for BFS and SSSP. According to the synopsis, edge-based
processing beats the naive baseline for BFS while node-based splitting can be slower than it, which suggests
that load balancing is harder to get right for BFS than for other graph algorithms. This motivates our
degree-aware, edge-aware redistribution.

**Pan, Aluru and Bader (IrGL project), adaptive load balancer for graph analytics on GPUs
(arXiv:1911.09135).** A compiler-generated adaptive load balancer for several graph algorithms; we contrast it
with our hand-written CUDA kernels.

**Chen, Brock, Porumbescu, Buluc, Yelick and Owens, "Atos" (ICPP 2022).** A task-parallel GPU scheduler for
irregular graph workloads; a recent example of load balancing done by a runtime scheduler rather than by a
static mapping.

**Yang, Lu, Sattar, Liu and Wang, "Towards Efficient Load Balancing BFS on GPUs: One Code for AMD,
Intel & Nvidia" (SC'25 Workshops).** The closest recent work: work-group localisation, even workload
distribution and a hybrid strided-access scheme, evaluated on GPUs from three vendors. We target a single
NVIDIA GPU and use per-level degree classes computed at run time. (Member 3: verify the reported peak
throughput in the paper before quoting it.)

**Elbek and Kaya, "Blest" (arXiv:2512.21967, December 2025).** Addresses per-iteration imbalance in BFS with
a Tensor-Core formulation and a dedicated data structure (BVSS), compared against Gunrock and GSWITCH. It
works on the same problem as we do but on a different compute substrate (Tensor Cores rather than CUDA cores).
(Member 3: verify the claimed speedups and the hardware used.)

**Zhong and He, "Load-Balanced Breadth-First Search on GPUs" (2014).** Splits each BFS iteration into a
work-redistribution phase and a neighbour-gathering phase to aim for full load balance; it shows that no single
earlier strategy solved BFS imbalance in general.

**Khorasani, Vora, Gupta and Bhuyan, "CuSha" (HPDC 2014).** Vertex-centric GPU graph processing with the
G-Shards and concatenated-windows representations; relevant as an alternative to the CSR layout we use.

**Wang, Davidson, Pan, Wu, Riffel and Owens, "Gunrock" (PPoPP 2016).** The standard high-performance GPU
graph library and the usual performance reference. Matching a mature production library is not our goal; we
use it as an aspirational baseline.

**Summary.** The literature agrees on two points that motivate this project: a single fixed load-balancing
strategy works well on some graph topologies and poorly on others, and BFS resists simple node-level
balancing more than algorithms such as SSSP. We therefore evaluate an adaptive, degree-aware strategy across
topologically different graphs instead of tuning one heuristic for one graph type.

> **PLACEHOLDER-NOT-YET-DELIVERED (Member 3):** add 1-2 sentences of technical detail per GPU-BFS paper
> (mapping granularity, compaction method, hardware, graphs used), with the page/table you took it from.
