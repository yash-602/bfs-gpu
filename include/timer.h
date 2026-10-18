// include/timer.h -- OWNER: Member 1 (frozen contract)
#pragma once
#include <chrono>

// Host wall-clock timer (steady clock). Used for ALL timing in the project.
struct WallTimer {
    std::chrono::steady_clock::time_point t0;
    WallTimer() { reset(); }
    void reset() { t0 = std::chrono::steady_clock::now(); }
    double ms() const {
        return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
    }
};
