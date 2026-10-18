// include/graph.h -- OWNER: Member 1 (frozen contract)
#pragma once
#include <string>
#include <vector>
#include <utility>
#include "types.h"

typedef std::pair<vid_t, vid_t> Edge;

// Host-side CSR graph. Always UNDIRECTED (every edge stored in both directions),
// no self-loops, no duplicate edges, each adjacency list sorted ascending.
struct CSRGraph {
    vid_t n = 0;                     // number of vertices
    eid_t m = 0;                     // number of stored (directed) entries = col_indices.size()
    std::vector<eid_t> row_offsets;  // size n+1
    std::vector<vid_t> col_indices;  // size m
    std::string name;                // short label, e.g. "roadNet-CA"
    inline eid_t degree(vid_t v) const { return row_offsets[v + 1] - row_offsets[v]; }
};

// Device-side view of a CSR graph. Plain pointers, no CUDA types, so host-only code can include it.
struct DeviceGraph {
    vid_t n = 0;
    eid_t m = 0;
    const eid_t* row_offsets = nullptr;  // device pointer, size n+1
    const vid_t* col_indices = nullptr;  // device pointer, size max(m,1)
};

// ---------------- graph_io.cpp (Member 1) ----------------
// Build CSR from an edge list. Symmetrizes, removes self-loops and duplicates, sorts adjacency lists.
// Vertex ids must already be in [0, n).
bool build_csr_from_edges(vid_t n, const std::vector<Edge>& edges, CSRGraph& out);
// Load a SNAP-style text edge list ('#' comment lines, "u v" per line). Ids are compacted to 0..n-1.
bool load_edge_list(const std::string& path, CSRGraph& out);
bool save_binary(const CSRGraph& g, const std::string& path);  // .csr cache file
bool load_binary(const std::string& path, CSRGraph& out);
bool load_graph_auto(const std::string& path, CSRGraph& out);  // ".csr" -> binary, else text

// ---------------- graph_gen.cpp (Member 1) ----------------
CSRGraph make_path(int n);                                // 0-1-2-...-(n-1)
CSRGraph make_star(int n);                                // vertex 0 connected to 1..n-1
CSRGraph make_grid(int w, int h);                         // w*h 4-neighbour grid
CSRGraph make_random(int n, int avg_deg, uint64_t seed);  // Erdos-Renyi-like
CSRGraph make_two_components(int n1, int n2);  // two disjoint paths (tests unreachable vertices)
CSRGraph make_hub_and_path(int hub_deg, int path_len);  // hub with many leaves + long tail path
CSRGraph make_rmat(int scale, int edge_factor, uint64_t seed, bool scramble = true);  // Graph500-style

// ---------------- sources / stats (Member 1) ----------------
std::vector<vid_t> pick_sources(const CSRGraph& g, int k, uint64_t seed);
