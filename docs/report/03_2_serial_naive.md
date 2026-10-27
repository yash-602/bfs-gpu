# 3.2 Serial and naive implementations

*(Owner: Member 2. Draft. Rewrite in your own words before submission.)*

## Serial CPU BFS

`bfs_serial` (`src/bfs_serial.cpp`) is the textbook queue-based level-order traversal and the ground truth
for every correctness check. It fills `levels` with -1 (UNVISITED), puts the source in a queue with level 0,
and repeatedly takes the next vertex u from the queue and gives every unvisited neighbour v the level
`levels[u] + 1` and appends it. The `levels` array doubles as the visited flag, and the queue is a plain array
of n vertex ids because every vertex enters it at most once. It is single-threaded on purpose: it is the
speedup baseline, and its simplicity is what makes it trustworthy. It is verified on graphs with known
answers (path, star, grid, two components, hub-and-path, single vertex) by the host unit tests.

## Naive CUDA BFS

`bfs_naive_cuda` (`src/bfs_naive.cu`) is the simplest reasonable GPU BFS: a level-synchronous frontier-queue
traversal with **one GPU thread per frontier vertex** and no awareness of vertex degree.

**State on the GPU.** `levels[n]` (initialised to -1, `levels[src] = 0`), the current frontier queue
`front[]` with size `fsize`, the next frontier queue `next[]` and a counter `next_n`. Both queues hold n vertex
ids, an upper bound, because a vertex is claimed at most once.

**One level.** The host resets `next_n` to 0 and launches `naive_expand_kernel` with
`ceil(fsize / block_size)` blocks (capped at `max_blocks` if set). Thread i takes frontier vertex
u = `front[i]` and walks u's *entire* adjacency list `col_indices[row_offsets[u] .. row_offsets[u+1]-1]`.
For each neighbour v it calls the shared helper `claim_and_push`: a cheap non-atomic check
`levels[v] == -1` skips neighbours visited long ago, and otherwise `atomicCAS(&levels[v], -1, level+1)` lets
exactly one thread win the vertex. The winner appends v to `next[]` with a *warp-aggregated* append
(`append_coalesced`): the threads that are appending at the same moment elect one leader, which reserves
slots for all of them with a single `atomicAdd`, so the counter sees up to 32 times fewer atomics. The host
then copies `next_n` back (a blocking copy that also waits for the kernel), swaps the queues and moves to the
next level, stopping when the new frontier is empty.

**Grid-stride loop.** The kernel loops `for (i = global id; i < fsize; i += gridDim.x * blockDim.x)`, so
any grid size covers the whole frontier. This is what makes `max_blocks` (the resource R of the strong- and
weak-scaling experiments) a valid way to limit the GPU resources a run may use.

**Why it is unbalanced.** All 32 threads of a warp run in lock-step. If one frontier vertex in a warp has
50,000 neighbours and the other 31 have 3, the 31 threads finish after 3 iterations and then idle for 49,997
more while their warp-mate walks its list alone, and the next level cannot start until that warp is done. On
power-law graphs such hubs appear at almost every level.

**Fair ablation by construction.** The naive kernel shares everything except the work distribution with the
adaptive program: the same queues, the same `claim_and_push` and append helper, the same timing definition.
Its inner edge loop is textually identical to the adaptive scheme's low-degree (thread-per-vertex) kernel.
The difference between the two programs therefore measures only the effect of degree-aware load balancing.

**Testing.** `tests/test_naive.cu` runs the shared correctness suite (10 graphs including a single vertex, a
999-level path, a star with a 4,999-degree hub, a grid, a random graph, two components, hub-and-path and two
R-MAT graphs; 6 sources each) for 12 configurations: block size 32/128/256/1024 x grid cap unlimited/1/3. Caps
of 1 and 3 blocks force each thread through many grid-stride iterations. Every result must equal the serial
reference exactly and also pass the structural validator.

## The benchmark driver (`bench`)

`bin/bench` (`src/bench.cu`) produces every number in Sections 5 and 6. For one graph it (1) loads or generates
the graph and checks that it fits in GPU memory, (2) picks the sources and uploads the graph once,
(3) runs the serial BFS from every source `serial_trials` times, keeping the first result as the reference,
and (4) runs each GPU implementation: one untimed warm-up run, then `trials` timed runs per source. After each
timed GPU run, an OpenMP task compares the result with the reference (and, with `--structural`, also runs the
structural validator) and appends one row to the CSV, while the main thread already launches the next GPU
run. Verification and logging therefore overlap GPU execution and never enter the timed region, which is
inside the BFS functions themselves. Any mismatch is reported as `VERIFICATION FAILED` and makes `bench` exit
with code 5.
