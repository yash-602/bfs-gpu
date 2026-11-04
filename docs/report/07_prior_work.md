# 7 Comparison with prior work

## Qualitative comparison

GPU BFS research has explored frontier scheduling, cooperative processing,
direction optimisation and alternative hardware execution strategies.
The following works provide relevant context for this implementation.

| Work | Relevant idea | Relationship to this implementation |
|---|---|---|
| Merrill, Garland and Grimshaw, PPoPP 2012 | Scalable GPU graph traversal and fine-grained load balancing | Foundational context for cooperative GPU graph traversal. |
| Beamer et al., SC 2012 | Direction-optimising BFS switches between top-down and bottom-up traversal | Orthogonal to degree-based frontier buckets; direction switching is not implemented here. |
| Raval et al., arXiv:1711.00231 | Dynamic load-balancing strategies for GPU graph applications | Relevant motivation for distributing irregular graph work. |
| Olgu et al., SC Workshops 2025 | Portable load-balanced BFS across GPU vendors | Addresses portability and load balancing across architectures, unlike this NVIDIA T4-focused implementation. |
| Elbek and Kaya, BLEST, 2025 | Tensor-Core-oriented BFS formulation | Uses a different hardware execution approach from the CUDA-core bucket kernels here. |

## Quantitative comparison

The playbook requests hardware, memory bandwidth, graph size, metric definition,
reported value and exact paper table/page for quantitative comparisons.
Those details have not yet been independently verified against the original
papers, so no paper performance numbers are invented here.

| Work | Hardware | Graph (n,m) | Metric/counting convention | Reported value and source table/page |
|---|---|---|---|---|
| Merrill et al. | To verify | To verify | To verify | Not verified |
| Beamer et al. | To verify | To verify | To verify | Not verified |
| Raval et al. | To verify | To verify | To verify | Not verified |
| Olgu et al. | To verify | To verify | To verify | Not verified |
| Elbek and Kaya | To verify | To verify | To verify | Not verified |

## Metric comparability

This project reports throughput using its CSR-entry/edge-traversal convention.
The playbook notes that Graph500 counts undirected edges as half the CSR-entry
count for a fully represented undirected graph. Comparisons must state and
reconcile the counting convention.

Results from different graph datasets, GPU architectures and memory systems
are not directly comparable. A quantitative comparison requires the original
paper's hardware, graph, metric and table/page details.

## Limitations

The quantitative literature table remains incomplete pending verification
of the original publications. This section therefore provides qualitative
context only.
