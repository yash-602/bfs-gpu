# 3.2 Serial and naive implementations

> **PLACEHOLDER-NOT-YET-DELIVERED (Member 2)**
>
> MEMBER 2: write this section. The serial BFS (`src/bfs_serial.cpp`, Member 1) is a single-threaded
> queue-based level-order traversal: `levels[]` doubles as the visited flag, and the queue is a plain array of
> n vertex ids. Describe the naive CUDA BFS (`src/bfs_naive.cu`): frontier queues, one thread per frontier
> vertex, `claim_and_push` / warp-aggregated append, the grid-stride loop and `max_blocks`, and why it is
> deliberately identical to the adaptive thread kernel (fair ablation).
