#pragma once

#include <algorithm>
#include <cmath>

namespace RaptorVehicle {
// Estimated continuation of the existing mod deck, not recovered F119 data.
// Declare 0..2.4 Mach as the table envelope; continue the last nonzero dry/AB
// anchor with bounded exponential decay rather than interpolating a sentinel
// zero into a complete loss of running-engine thrust. Above 2.4 hold the edge.
inline double continue_thrust(double interpolated_n, double mach,
                              double anchor_mach, double anchor_n) {
    if (!std::isfinite(mach) || !std::isfinite(interpolated_n)) return 0.0;
    if (mach <= anchor_mach) return std::max(0.0, interpolated_n);
    const double distance = std::clamp(mach, anchor_mach, 2.4) - anchor_mach;
    return anchor_n * std::exp(-distance);
}
} // namespace RaptorVehicle
