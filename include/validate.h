// include/validate.h -- OWNER: Member 1 (frozen contract)
#pragma once
#include <string>
#include <vector>
#include "graph.h"

struct ValidationResult {
    bool ok = true;
    long long mismatches = 0;
    long long first_bad = -1;
    int expected = 0, got = 0;
    std::string msg;
};

// Exact element-by-element comparison against the serial reference (OpenMP parallel).
ValidationResult compare_levels(const std::vector<int>& ref, const std::vector<int>& got);
// Reference-free check (Graph500 style): source level 0, every edge spans <=1 level,
// every reached non-source vertex has a neighbour one level lower, reached/unreached never adjacent.
ValidationResult validate_levels_structural(const CSRGraph& g, vid_t src,
                                            const std::vector<int>& levels);
// Sum of degrees of all reached vertices (CSR entries scanned) -- numerator of TEPS.
long long count_traversed_edges(const CSRGraph& g, const std::vector<int>& levels);
// max level + 1 (0 if nothing reached).
int count_levels(const std::vector<int>& levels);

// ---------------- graph statistics (graph_stats.cpp) ----------------
struct GraphStats {
    long long n = 0, m = 0;
    double avg_deg = 0, std_deg = 0, cv = 0;  // cv = std/avg (coefficient of variation)
    long long min_deg = 0, max_deg = 0, isolated = 0;
    double top1pct_edge_share = 0;     // fraction of entries owned by the top 1% highest-degree vertices
    int est_diameter = 0;              // double-sweep BFS lower bound
    double hub_reach_frac = 0;         // fraction of vertices reachable from the max-degree vertex
    long long deg0 = 0;                // number of vertices with degree 0
    std::vector<long long> log2_hist;  // log2_hist[b] = #vertices with degree in [2^b, 2^(b+1))
};

GraphStats compute_stats(const CSRGraph& g);
void print_stats(const CSRGraph& g, const GraphStats& s);
