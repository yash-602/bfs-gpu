# Dataset table (OWNER: Member 1, hand-off H6)

Every number below was copied from `./bin/graph_tool stats data/csr/<graph>.csr` (full outputs, including the
log2 degree histograms, are in `docs/dataset_stats/<graph>.txt`). SNAP counts were read from each dataset's
page on https://snap.stanford.edu/data/ on 2026-10-17. All graphs are symmetrised (undirected), have no
self-loops or duplicate edges, and have compacted vertex ids; m counts CSR entries = 2 x undirected edges.

## Graph statistics

| graph | category | n | m (CSR entries) | avg deg | max deg | CV | top-1% edge share | est. diameter | reachable from hub |
|-------|----------|---|-----------------|---------|---------|----|-------------------|---------------|--------------------|
| roadNet-CA | road | 1,965,206 | 5,533,214 | 2.816 | 12 | 0.353 | 1.7% | 852 | 99.58% |
| roadNet-PA | road | 1,088,092 | 3,083,796 | 2.834 | 9 | 0.359 | 1.8% | 780 | 99.95% |
| com-youtube | social | 1,134,890 | 5,975,248 | 5.265 | 28,754 | 9.640 | 36.5% | 24 | 100.00% |
| soc-LiveJournal1 | social | 4,847,571 | 85,702,474 | 17.679 | 20,333 | 2.941 | 19.3% | 19 | 99.93% |
| com-orkut | social | 3,072,441 | 234,370,166 | 76.281 | 33,313 | 2.029 | 11.9% | 8 | 100.00% |
| rmat15 | rmat | 32,768 | 883,014 | 26.947 | 5,888 | 4.195 | 30.6% | 6 | 73.96% |
| rmat16 | rmat | 65,536 | 1,818,618 | 27.750 | 9,713 | 4.860 | 36.6% | 7 | 71.51% |
| rmat17 | rmat | 131,072 | 3,730,760 | 28.463 | 15,678 | 5.613 | 38.7% | 7 | 68.93% |
| rmat18 | rmat | 262,144 | 7,612,566 | 29.040 | 25,096 | 6.473 | 41.9% | 7 | 66.35% |
| rmat19 | rmat | 524,288 | 15,481,582 | 29.529 | 40,443 | 7.460 | 47.6% | 8 | 64.05% |
| rmat20 | rmat | 1,048,576 | 31,402,974 | 29.948 | 64,699 | 8.573 | 48.7% | 7 | 61.64% |
| rmat21 | rmat | 2,097,152 | 63,545,062 | 30.301 | 102,738 | 9.847 | 52.1% | 9 | 59.32% |
| rmat22 | rmat | 4,194,304 | 128,313,944 | 30.592 | 163,377 | 11.301 | 56.0% | 8 | 57.08% |

R-MAT graphs: `graph_tool rmat <scale> 16 1` (edge factor 16, seed 1, A=0.57 B=0.19 C=0.19 D=0.05, scrambled
ids). Their m values equal the golden values of playbook 6.7 exactly. Isolated vertices (degree 0):
soc-LiveJournal1 962; rmat15..22: 8,521 / 18,655 / 40,684 / 88,105 / 188,268 / 401,837 / 852,176 / 1,798,751;
all other graphs 0.

## Check against SNAP

| graph | SNAP nodes | SNAP edges | our n | our m | check |
|-------|-----------|-----------|-------|-------|-------|
| roadNet-CA | 1,965,206 | 2,766,607 | 1,965,206 | 5,533,214 | n equal, m = 2 x edges |
| roadNet-PA | 1,088,092 | 1,541,898 | 1,088,092 | 3,083,796 | n equal, m = 2 x edges |
| com-youtube | 1,134,890 | 2,987,624 | 1,134,890 | 5,975,248 | n equal, m = 2 x edges |
| soc-LiveJournal1 (directed) | 4,847,571 | 68,993,773 | 4,847,571 | 85,702,474 | n equal; m between 69 M and 138 M (reciprocal pairs merge: 42,851,237 undirected edges) |
| com-orkut | 3,072,441 | 117,185,083 | 3,072,441 | 234,370,166 | n equal, m = 2 x edges |

Every node count is identical to SNAP's, so the loader neither drops nor invents vertices. The 962 isolated
vertices in soc-LiveJournal1 come from self-loop-only lines in the SNAP file (the vertex id occurs, but its
only edge is a self-loop, which is removed). This was checked independently on the raw file with
`awk`/`sort`/`comm`: 518,382 self-loop lines, 962 ids that occur only in self-loops, 4,847,571 distinct ids.
Note that the SNAP soc-LiveJournal1 file has Windows (CRLF) line endings; the loader strips the `\r`.

## What the numbers predict (hypotheses for the experiments)

**Road networks.** roadNet-CA has maximum degree 12 and CV 0.35 (roadNet-PA: 9 and 0.36), so all frontier
vertices have almost the same amount of work and there is little imbalance for the adaptive scheme to fix.
Its BFS has at least 852 levels (780 for roadNet-PA), so each level has a small frontier and fixed per-level
costs (kernel launches, host round trips) are likely to dominate. We expect little or no gain from the
adaptive scheme here, possibly a loss.

**Social networks.** com-youtube is the most skewed graph we have (CV 9.64; one vertex has 28,754 neighbours
while the average is 5.3, and the top 1% of vertices own 36.5% of all entries), with an estimated diameter of
only 24. soc-LiveJournal1 (CV 2.94, max degree 20,333) and com-orkut (CV 2.03, max degree 33,313, average 76)
are less skewed relative to their average but still have hubs with tens of thousands of neighbours and
diameters of 19 and 8. Few levels with large, high-variance frontiers is the situation in which a naive
thread-per-vertex mapping suffers most, so we expect the largest adaptive gains on these graphs.

**R-MAT.** CV grows steadily with scale, from 4.2 (rmat15) to 11.3 (rmat22), and the maximum degree from
5,888 to 163,377, while the estimated diameter stays between 6 and 9. The imbalance therefore grows with
graph size, so the advantage of the adaptive scheme should grow along the weak-scaling series. Only 57-74% of
the vertices are reachable from the hub (the rest are isolated or in small components), which is why sources
are always picked inside the hub's component.
