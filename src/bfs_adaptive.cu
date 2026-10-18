// src/bfs_adaptive.cu -- OWNER: Member 3
// =====================================================================================================
// PLACEHOLDER-NOT-YET-DELIVERED (Member 3, hand-off H4)
//
// This file is a stand-in written by Member 1 so that the repository builds and links.
// It does NOT implement BFS: calling bfs_adaptive_cuda() prints an error and exits with code 99.
//
// MEMBER 3: replace this WHOLE file with the adaptive kernels + host driver from your playbook,
//           section 9.4 ("Task M3.2 and M3.3: write src/bfs_adaptive.cu"). Keep the signature below
//           unchanged (frozen contract, include/bfs_api.h). Delete this comment block too.
// Done when: make bin/test_adaptive && ./bin/test_adaptive prints "TEST_ADAPTIVE: PASS".
// =====================================================================================================
#include <cstdio>
#include <cstdlib>
#include <vector>
#include "bfs_api.h"

void bfs_adaptive_cuda(const DeviceGraph& g, vid_t src, std::vector<int>& h_levels,
                       const AdaptiveConfig& cfg, BFSStats& stats) {
    (void)g, (void)src, (void)h_levels, (void)cfg, (void)stats;
    fprintf(stderr,
            "bfs_adaptive_cuda: PLACEHOLDER - src/bfs_adaptive.cu has not been delivered by Member 3\n");
    std::exit(99);
}
