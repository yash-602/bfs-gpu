// include/types.h -- OWNER: Member 1 (frozen contract)
#pragma once
#include <cstdint>

typedef int32_t vid_t;  // vertex id          (graphs must have n < 2^31)
typedef int32_t eid_t;  // CSR edge offset    (graphs must have m < 2^31 stored entries)

static const int CONTRACT_VERSION = 1;  // bump only through the 'change the contract' procedure

static const int UNVISITED = -1;  // value of levels[v] when v has not been reached

static const int WARP_SZ = 32;
