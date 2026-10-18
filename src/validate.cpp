// src/validate.cpp -- OWNER: Member 1
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <omp.h>
#include "validate.h"

ValidationResult compare_levels(const std::vector<int>& ref, const std::vector<int>& got) {
    ValidationResult r;
    if (ref.size() != got.size()) {
        r.ok = false;
        r.msg = "size mismatch: ref " + std::to_string(ref.size()) + " vs got " +
                std::to_string(got.size());
        return r;
    }
    long long bad = 0, first = (long long)ref.size();
    const long long n = (long long)ref.size();
#pragma omp parallel for reduction(+ : bad) reduction(min : first) schedule(static)
    for (long long i = 0; i < n; ++i)
        if (ref[i] != got[i]) {
            ++bad;
            if (i < first) first = i;
        }
    r.mismatches = bad;
    if (bad > 0) {
        r.ok = false;
        r.first_bad = first;
        r.expected = ref[first];
        r.got = got[first];
        r.msg = std::to_string(bad) + " mismatches; first at vertex " + std::to_string(first) +
                " expected " + std::to_string(ref[first]) + " got " + std::to_string(got[first]);
    }
    return r;
}

ValidationResult validate_levels_structural(const CSRGraph& g, vid_t src, const std::vector<int>& lv) {
    ValidationResult r;
    if ((long long)lv.size() != g.n) {
        r.ok = false;
        r.msg = "wrong levels size";
        return r;
    }
    if (lv[src] != 0) {
        r.ok = false;
        r.msg = "source level is not 0";
        return r;
    }
    long long bad = 0, first = g.n;
#pragma omp parallel for reduction(+ : bad) reduction(min : first) schedule(dynamic, 4096)
    for (long long u = 0; u < g.n; ++u) {
        int lu = lv[u];
        bool err = false;
        if (lu < -1) err = true;
        bool has_parent = (lu <= 0);  // source or unreached need no parent
        for (eid_t e = g.row_offsets[u]; e < g.row_offsets[u + 1] && !err; ++e) {
            int lw = lv[g.col_indices[e]];
            if (lu == -1 && lw != -1)
                err = true;  // unreached vertex adjacent to reached one
            else if (lu >= 0) {
                if (lw == -1)
                    err = true;  // reached vertex adjacent to unreached one
                else if (std::abs(lu - lw) > 1)
                    err = true;  // edge spans > 1 level
                else if (lw == lu - 1)
                    has_parent = true;
            }
        }
        if (!err && !has_parent) err = true;  // reached, level>0, no neighbour one level lower
        if (u != src && lu == 0) err = true;  // only the source may have level 0
        if (err) {
            ++bad;
            if (u < first) first = u;
        }
    }
    r.mismatches = bad;
    if (bad > 0) {
        r.ok = false;
        r.first_bad = first;
        r.msg = std::to_string(bad) + " structural violations; first at vertex " + std::to_string(first);
    }
    return r;
}

long long count_traversed_edges(const CSRGraph& g, const std::vector<int>& lv) {
    long long sum = 0;
#pragma omp parallel for reduction(+ : sum) schedule(static)
    for (long long u = 0; u < g.n; ++u)
        if (lv[u] >= 0) sum += g.row_offsets[u + 1] - g.row_offsets[u];
    return sum;
}

int count_levels(const std::vector<int>& lv) {
    int mx = -1;
#pragma omp parallel for reduction(max : mx) schedule(static)
    for (long long i = 0; i < (long long)lv.size(); ++i) mx = std::max(mx, lv[i]);
    return mx + 1;
}
