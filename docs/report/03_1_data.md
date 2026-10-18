# 3 Design and implementation

## 3.1 Data representation and datasets

*(Owner: Member 1. Numbers from `docs/dataset_table.md`.)*

**CSR graph.** Every program uses the same host structure `CSRGraph` (`include/graph.h`): n, m, `row_offsets`
(n+1 entries) and `col_indices` (m entries), with 32-bit vertex ids and offsets (so n and m must stay below
2^31). Graphs are undirected and stored symmetrically, without self-loops or duplicate edges, and every
adjacency list is sorted. The GPU programs receive a non-owning `DeviceGraph` view, created once per graph by
`upload_graph()`, so no BFS implementation ever allocates or copies the graph itself.

**Building CSR from an edge list.** `build_csr_from_edges` turns an arbitrary edge list (any order, possibly
with duplicates, reversed duplicates and self-loops) into this canonical form in five OpenMP-parallel steps:
(1) count each vertex's raw degree with atomic increments, skipping self-loops; (2) prefix-sum the counts into
64-bit offsets, failing loudly if the total exceeds the 32-bit limit; (3) scatter both directions of every edge,
each thread claiming a slot with an atomic capture on the vertex's cursor; (4) sort and de-duplicate every
adjacency list, in parallel over vertices with dynamic scheduling because list lengths are very uneven;
(5) prefix-sum the de-duplicated degrees and compact the lists into the final arrays. Steps 1 and 3 touch
shared counters only through atomics, and steps 4 and 5 give each thread its own vertices. After sorting,
each list's content does not depend on the scatter order, so the result is identical for any thread count.

**Loading SNAP files and id compaction.** SNAP edge lists are text (`#` comment lines, one `u v` pair per
line, up to 1.8 GB). The loader memory-maps the file, gives every thread an equal byte range moved forward to
the next line start (so no line is split), parses integers by hand, and accepts tabs, spaces, commas and
Windows line endings. SNAP ids are sparse, so they are compacted to 0..n-1 in increasing order; n is the
number of distinct ids in the file. For all five SNAP graphs our n is exactly SNAP's node count, and for the
undirected ones m is exactly twice SNAP's edge count. soc-LiveJournal1 is directed; symmetrising it merges
reciprocal pairs, giving 42,851,237 undirected edges (m = 85,702,474) from 68,993,773 directed ones.

**Binary cache.** Parsing text is slow (12.3 s for com-orkut on our development machine), so each graph is
converted once to a binary `.csr` file: an 8-byte magic `BFSCSR01`, n and m as int32, then the two arrays.
Loading a `.csr` file is a plain sequential read.

**R-MAT generator.** Synthetic power-law graphs come from a Graph500-style R-MAT generator (A=0.57, B=0.19,
C=0.19, D=0.05), with 2^scale vertices and edge factor 16 (16 x 2^scale generated edges). For every edge and
every bit of the vertex id, one of the four quadrants is chosen at random. Vertex ids are then scrambled with
three bijections on [0, 2^scale) so that the hubs are not all at small ids. The generator runs in parallel and
is deterministic for any thread count: edges are generated in blocks of 65,536 and each block has its own
splitmix64 stream, seeded by passing (seed, block) through the splitmix finaliser. Seeding blocks with
seed + b would make consecutive streams overlap, so edges would collapse into duplicates and the average degree
would fall with scale; a regression test guards against this. After symmetrisation and de-duplication about
27-31 CSR entries per vertex remain (Table 3.1).

**Datasets.** Table 3.1 lists the graphs, grouped into three degree-distribution categories. The coefficient of
variation of the degree (CV = standard deviation / mean) is our one-number measure of imbalance; CV >= 1 is
high-variance (power-law like).

*Table 3.1: Test graphs (undirected; m = CSR entries = 2 x undirected edges). Diameter is a double-sweep
lower bound.*

| graph | category | n | m | avg deg | max deg | CV | top-1% share | diameter |
|-------|----------|---|---|---------|---------|----|--------------|----------|
| roadNet-CA | road | 1,965,206 | 5,533,214 | 2.82 | 12 | 0.35 | 1.7% | 852 |
| roadNet-PA | road | 1,088,092 | 3,083,796 | 2.83 | 9 | 0.36 | 1.8% | 780 |
| com-youtube | social | 1,134,890 | 5,975,248 | 5.27 | 28,754 | 9.64 | 36.5% | 24 |
| soc-LiveJournal1 | social | 4,847,571 | 85,702,474 | 17.68 | 20,333 | 2.94 | 19.3% | 19 |
| com-orkut | social | 3,072,441 | 234,370,166 | 76.28 | 33,313 | 2.03 | 11.9% | 8 |
| rmat16 | rmat | 65,536 | 1,818,618 | 27.75 | 9,713 | 4.86 | 36.6% | 7 |
| rmat18 | rmat | 262,144 | 7,612,566 | 29.04 | 25,096 | 6.47 | 41.9% | 7 |
| rmat20 | rmat | 1,048,576 | 31,402,974 | 29.95 | 64,699 | 8.57 | 48.7% | 7 |
| rmat22 | rmat | 4,194,304 | 128,313,944 | 30.59 | 163,377 | 11.30 | 56.0% | 8 |

(rmat15, 17, 19 and 21 are used only for weak scaling; see `docs/dataset_table.md`.)

The categories differ in exactly the ways that matter for load balancing. The road networks have a maximum
degree of 12 and CV 0.35, so every frontier vertex has about the same work, but they have hundreds of BFS levels
with small frontiers. The social and R-MAT graphs have hubs with tens of thousands of neighbours (up to 163,377
in rmat22), CV between 2 and 11, and diameters below 25, so their few frontiers are large and very uneven. In
R-MAT the imbalance grows with scale (CV 4.9 at scale 16, 11.3 at scale 22).

**Sources.** For every graph, `pick_sources(g, k, seed)` runs a BFS from the maximum-degree vertex and draws k
distinct sources (seed 1) among the reached vertices with degree > 0. This guarantees every BFS covers the giant
component; for R-MAT graphs only 57-74% of the vertices are in it, the rest being isolated vertices or small
components.

**Correctness checking.** Two validators are shared by all programs (`src/validate.cpp`): `compare_levels`
compares a result element by element with the serial reference (BFS levels are unique, so any difference is a
bug), and `validate_levels_structural` checks a result without any reference, Graph500 style: only the source
has level 0, every edge joins vertices whose levels differ by at most one, every reached vertex other than the
source has a neighbour one level lower, and reached and unreached vertices are never adjacent. A host unit-test
suite (39 checks) verifies the CSR invariants, known BFS answers on small graphs, R-MAT determinism across 1,
4 and the default number of threads, the R-MAT regression test, that both validators catch injected
corruption, the binary round trip, and that the text loader handles comments, tabs, CRLF line endings,
self-loops and a 200,000-line file without losing a line at thread boundaries.
