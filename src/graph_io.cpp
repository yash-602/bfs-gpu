// src/graph_io.cpp -- OWNER: Member 1
#include <algorithm>
#include <cstdio>
#include <cstring>
#include <omp.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include "graph.h"

// ---------------------------------------------------------------------------
// build_csr_from_edges: edge list -> symmetric, simple, sorted CSR. OpenMP parallel.
// ---------------------------------------------------------------------------
bool build_csr_from_edges(vid_t n, const std::vector<Edge>& edges, CSRGraph& out) {
    if (n < 0) return false;
    const long long E = (long long)edges.size();

    // 1. count raw degree (both directions, skip self loops)
    std::vector<int> deg((size_t)n + 1, 0);
#pragma omp parallel for schedule(static)
    for (long long i = 0; i < E; ++i) {
        vid_t u = edges[i].first, v = edges[i].second;
        if (u == v) continue;
#pragma omp atomic update
        deg[u]++;
#pragma omp atomic update
        deg[v]++;
    }

    // 2. raw offsets (64-bit to detect overflow)
    std::vector<long long> raw_off((size_t)n + 1, 0);
    for (vid_t v = 0; v < n; ++v) raw_off[v + 1] = raw_off[v] + deg[v];
    const long long total = raw_off[n];
    if (total >= 2147483647LL) {
        fprintf(stderr, "build_csr_from_edges: %lld entries exceed int32 limit\n", total);
        return false;
    }

    // 3. scatter both directions into a raw adjacency array
    std::vector<vid_t> adj((size_t)std::max<long long>(total, 1));
    std::vector<long long> cursor(raw_off.begin(), raw_off.end() - 1);
#pragma omp parallel for schedule(static)
    for (long long i = 0; i < E; ++i) {
        vid_t u = edges[i].first, v = edges[i].second;
        if (u == v) continue;
        long long pu, pv;
#pragma omp atomic capture
        {
            pu = cursor[u];
            cursor[u]++;
        }
        adj[pu] = v;
#pragma omp atomic capture
        {
            pv = cursor[v];
            cursor[v]++;
        }
        adj[pv] = u;
    }

    // 4. sort + dedupe every adjacency list, record new degree
    std::vector<int> ndeg((size_t)n, 0);
#pragma omp parallel for schedule(dynamic, 1024)
    for (vid_t v = 0; v < n; ++v) {
        vid_t* b = adj.data() + raw_off[v];
        vid_t* e = adj.data() + raw_off[v + 1];
        std::sort(b, e);
        ndeg[v] = (int)(std::unique(b, e) - b);
    }

    // 5. final offsets and compaction
    out.n = n;
    out.row_offsets.assign((size_t)n + 1, 0);
    for (vid_t v = 0; v < n; ++v) out.row_offsets[v + 1] = out.row_offsets[v] + ndeg[v];
    out.m = out.row_offsets[n];
    out.col_indices.assign((size_t)std::max<eid_t>(out.m, 1), 0);
#pragma omp parallel for schedule(dynamic, 1024)
    for (vid_t v = 0; v < n; ++v)
        std::copy(adj.begin() + raw_off[v], adj.begin() + raw_off[v] + ndeg[v],
                  out.col_indices.begin() + out.row_offsets[v]);
    out.col_indices.resize((size_t)out.m);
    return true;
}

// ---------------------------------------------------------------------------
// Text edge-list loader (mmap + parallel parse). Lines starting with '#' or '%' are comments.
// ---------------------------------------------------------------------------
static inline bool is_digit(char c) {
    return c >= '0' && c <= '9';
}

// parse one unsigned integer starting at p (skipping leading blanks); returns false if none on this
// line
static inline bool parse_uint(const char*& p, const char* end, long long& val) {
    while (p < end && (*p == ' ' || *p == '\t' || *p == ',' || *p == '\r')) ++p;
    if (p >= end || !is_digit(*p)) return false;
    long long x = 0;
    while (p < end && is_digit(*p)) {
        x = x * 10 + (*p - '0');
        ++p;
    }
    val = x;
    return true;
}

bool load_edge_list(const std::string& path, CSRGraph& out) {
    int fd = open(path.c_str(), O_RDONLY);
    if (fd < 0) {
        perror(("open " + path).c_str());
        return false;
    }
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size == 0) {
        fprintf(stderr, "empty or unreadable: %s\n", path.c_str());
        close(fd);
        return false;
    }
    size_t size = (size_t)st.st_size;
    const char* data = (const char*)mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (data == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return false;
    }
    madvise((void*)data, size, MADV_SEQUENTIAL);

    const int T = omp_get_max_threads();
    std::vector<std::vector<std::pair<long long, long long>>> local(T);
    std::vector<long long> local_max(T, -1);

#pragma omp parallel num_threads(T)
    {
        int t = omp_get_thread_num();
        size_t b = size * (size_t)t / T, e = size * (size_t)(t + 1) / T;
        // move b forward to the start of a line (unless t == 0)
        if (t > 0) {
            while (b < size && data[b - 1] != '\n') ++b;
        }
        // move e forward to the end of its line, so lines are never split between threads
        while (e < size && data[e - 1] != '\n') ++e;
        const char* p = data + b;
        const char* end = data + e;
        auto& vec = local[t];
        long long mx = -1;
        while (p < end) {
            const char* line_end = (const char*)memchr(p, '\n', end - p);
            if (!line_end) line_end = end;
            if (*p != '#' && *p != '%') {
                const char* q = p;
                long long a, c;
                if (parse_uint(q, line_end, a) && parse_uint(q, line_end, c)) {
                    vec.emplace_back(a, c);
                    mx = std::max(mx, std::max(a, c));
                }
            }
            p = line_end + 1;
        }
        local_max[t] = mx;
    }
    munmap((void*)data, size);
    close(fd);

    long long max_id = -1, total = 0;
    for (int t = 0; t < T; ++t) {
        max_id = std::max(max_id, local_max[t]);
        total += (long long)local[t].size();
    }
    if (total == 0) {
        fprintf(stderr, "no edges parsed from %s\n", path.c_str());
        return false;
    }
    if (max_id >= 2147483647LL) {
        fprintf(stderr, "vertex id too large\n");
        return false;
    }

    // compact ids: used[id] -> new id
    std::vector<char> used((size_t)max_id + 1, 0);
    for (int t = 0; t < T; ++t) {
#pragma omp parallel for schedule(static)
        for (long long i = 0; i < (long long)local[t].size(); ++i) {
            used[local[t][i].first] = 1;
            used[local[t][i].second] = 1;
        }
    }
    std::vector<vid_t> newid((size_t)max_id + 1, -1);
    vid_t n = 0;
    for (long long id = 0; id <= max_id; ++id)
        if (used[id]) newid[id] = n++;

    std::vector<Edge> edges((size_t)total);
    long long off = 0;
    for (int t = 0; t < T; ++t) {
        const long long cnt = (long long)local[t].size();
#pragma omp parallel for schedule(static)
        for (long long i = 0; i < cnt; ++i)
            edges[off + i] = Edge(newid[local[t][i].first], newid[local[t][i].second]);
        off += cnt;
        std::vector<std::pair<long long, long long>>().swap(local[t]);  // free memory early
    }
    bool ok = build_csr_from_edges(n, edges, out);
    return ok;
}

// ---------------------------------------------------------------------------
// Binary cache format: 8-byte magic "BFSCSR01", int32 n, int32 m, row_offsets[n+1], col_indices[m]
// ---------------------------------------------------------------------------
static const char MAGIC[8] = {'B', 'F', 'S', 'C', 'S', 'R', '0', '1'};

bool save_binary(const CSRGraph& g, const std::string& path) {
    FILE* f = fopen(path.c_str(), "wb");
    if (!f) {
        perror(("fopen " + path).c_str());
        return false;
    }
    int32_t hdr[2] = {g.n, g.m};
    bool ok = fwrite(MAGIC, 1, 8, f) == 8 && fwrite(hdr, sizeof(int32_t), 2, f) == 2 &&
              fwrite(g.row_offsets.data(), sizeof(eid_t), (size_t)g.n + 1, f) == (size_t)g.n + 1 &&
              (g.m == 0 || fwrite(g.col_indices.data(), sizeof(vid_t), (size_t)g.m, f) == (size_t)g.m);
    fclose(f);
    return ok;
}

bool load_binary(const std::string& path, CSRGraph& out) {
    FILE* f = fopen(path.c_str(), "rb");
    if (!f) {
        perror(("fopen " + path).c_str());
        return false;
    }
    char magic[8];
    int32_t hdr[2];
    if (fread(magic, 1, 8, f) != 8 || memcmp(magic, MAGIC, 8) != 0 ||
        fread(hdr, sizeof(int32_t), 2, f) != 2) {
        fprintf(stderr, "%s: not a BFSCSR01 file\n", path.c_str());
        fclose(f);
        return false;
    }
    out.n = hdr[0];
    out.m = hdr[1];
    out.row_offsets.resize((size_t)out.n + 1);
    out.col_indices.resize((size_t)out.m);
    bool ok =
        fread(out.row_offsets.data(), sizeof(eid_t), (size_t)out.n + 1, f) == (size_t)out.n + 1 &&
        (out.m == 0 || fread(out.col_indices.data(), sizeof(vid_t), (size_t)out.m, f) == (size_t)out.m);
    fclose(f);
    return ok;
}

static std::string base_name(const std::string& path) {
    size_t s = path.find_last_of('/');
    std::string b = (s == std::string::npos) ? path : path.substr(s + 1);
    size_t d = b.find_last_of('.');
    return d == std::string::npos ? b : b.substr(0, d);
}

bool load_graph_auto(const std::string& path, CSRGraph& out) {
    bool ok;
    if (path.size() > 4 && path.compare(path.size() - 4, 4, ".csr") == 0)
        ok = load_binary(path, out);
    else
        ok = load_edge_list(path, out);
    if (ok) out.name = base_name(path);
    return ok;
}
