// tools/graph_tool.cpp -- OWNER: Member 1
// Usage:
//   graph_tool convert <input.txt> <output.csr>
//   graph_tool rmat <scale> <edge_factor> <seed> <output.csr>
//   graph_tool stats <graph.csr|graph.txt>
//   graph_tool serial <graph.csr|graph.txt> <num_sources> [seed]
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <omp.h>
#include "bfs_api.h"
#include "timer.h"
#include "validate.h"

static int usage() {
    fprintf(stderr,
            "usage:\n  graph_tool convert <in.txt> <out.csr>\n  graph_tool rmat <scale> <edge_factor> "
            "<seed> <out.csr>\n"
            "  graph_tool stats <graph>\n  graph_tool serial <graph> <num_sources> [seed]\n");
    return 1;
}

int main(int argc, char** argv) {
    if (argc < 2) return usage();
    std::string cmd = argv[1];
    WallTimer t;
    if (cmd == "convert" && argc == 4) {
        CSRGraph g;
        if (!load_edge_list(argv[2], g)) return 2;
        printf("parsed+built in %.1f ms: n=%d m=%d\n", t.ms(), g.n, g.m);
        if (!save_binary(g, argv[3])) return 3;
        printf("wrote %s\n", argv[3]);
    } else if (cmd == "rmat" && argc == 6) {
        CSRGraph g = make_rmat(atoi(argv[2]), atoi(argv[3]), strtoull(argv[4], nullptr, 10));
        printf("generated in %.1f ms: n=%d m=%d\n", t.ms(), g.n, g.m);
        if (!save_binary(g, argv[5])) return 3;
        printf("wrote %s\n", argv[5]);
    } else if (cmd == "stats" && argc == 3) {
        CSRGraph g;
        if (!load_graph_auto(argv[2], g)) return 2;
        print_stats(g, compute_stats(g));
    } else if (cmd == "serial" && argc >= 4) {
        CSRGraph g;
        if (!load_graph_auto(argv[2], g)) return 2;
        int k = atoi(argv[3]);
        uint64_t seed = argc >= 5 ? strtoull(argv[4], nullptr, 10) : 1;
        std::vector<vid_t> srcs = pick_sources(g, k, seed);
        for (vid_t s : srcs) {
            std::vector<int> lv;
            WallTimer w;
            bfs_serial(g, s, lv);
            double ms = w.ms();
            long long te = count_traversed_edges(g, lv);
            ValidationResult vr = validate_levels_structural(g, s, lv);
            printf("src=%d time=%.3f ms levels=%d edges=%lld GTEPS=%.4f structural=%s\n", s, ms,
                   count_levels(lv), te, te / (ms * 1e6), vr.ok ? "OK" : vr.msg.c_str());
        }
    } else
        return usage();
    return 0;
}
