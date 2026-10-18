// src/bfs_naive.cu -- OWNER: Member 2
// =====================================================================================================
// PLACEHOLDER-NOT-YET-DELIVERED (Member 2, hand-off H3)
//
// This file is a stand-in written by Member 1 so that the repository builds and links.
// It does NOT implement BFS: calling bfs_naive_cuda() prints an error and exits with code 99.
//
// MEMBER 2: replace this WHOLE file with your naive kernel + host function from your playbook,
//           section 9.4 ("Task M2.2: the naive CUDA BFS"). Keep the signature below unchanged
//           (it is the frozen contract in include/bfs_api.h). Delete this comment block too.
// Done when: make bin/test_naive && ./bin/test_naive prints "TEST_NAIVE: PASS".
// =====================================================================================================
#include <cstdio>
#include <cstdlib>
#include <vector>
#include "bfs_api.h"

void bfs_naive_cuda(const DeviceGraph& g, vid_t src, std::vector<int>& h_levels, const NaiveConfig& cfg,
                    BFSStats& stats) {
    (void)g, (void)src, (void)h_levels, (void)cfg, (void)stats;
    fprintf(stderr, "bfs_naive_cuda: PLACEHOLDER - src/bfs_naive.cu has not been delivered by Member 2\n");
    std::exit(99);
}
