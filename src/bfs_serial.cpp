// src/bfs_serial.cpp -- OWNER: Member 1
#include "bfs_api.h"

// Single-threaded queue-based level-order BFS. levels[v] = hop distance from src, or UNVISITED (-1).
void bfs_serial(const CSRGraph& g, vid_t src, std::vector<int>& levels) {
    levels.assign((size_t)g.n, UNVISITED);
    std::vector<vid_t> q((size_t)g.n);
    size_t head = 0, tail = 0;
    levels[src] = 0;
    q[tail++] = src;
    while (head < tail) {
        vid_t u = q[head++];
        const int next = levels[u] + 1;
        for (eid_t e = g.row_offsets[u]; e < g.row_offsets[u + 1]; ++e) {
            vid_t v = g.col_indices[e];
            if (levels[v] == UNVISITED) {
                levels[v] = next;
                q[tail++] = v;
            }
        }
    }
}
