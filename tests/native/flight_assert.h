#pragma once
#include <algorithm>
#include <cmath>
#include <stdexcept>

inline void flight_require(bool value, const char* description) {
    if (!value) throw std::runtime_error(description);
}
inline bool flight_close(double actual, double expected, double absolute = 1e-8) {
    return std::isfinite(actual) && std::abs(actual - expected) <=
        std::max(absolute, std::abs(expected) * 1e-12);
}
