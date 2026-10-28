#pragma once

#include "VehicleSystems.h"
#include <array>

namespace RaptorVehicle {
struct GroundContact {
    struct Wheel {
        double reaction_n = 0.0;
        double compression = 0.0;
        double stamp_s = -1.0;
    };
    std::array<Wheel, 3> wheels{};
    bool valid = false;
    bool loaded = false;
    static constexpr double maximum_age_s = 0.1;
    // Loose geometry rejection bound, not a squat-switch calibration. All
    // configured gear coordinates, stroke and tire radii fit inside 12 m.
    static constexpr double maximum_reach_m = 12.0;
    static constexpr double minimum_load_n = 100.0;

    void sample(std::size_t index, double compression, double fx, double fy,
                double fz, double now_s) {
        if (index >= wheels.size()) return;
        auto& wheel = wheels[index];
        wheel.stamp_s = -1.0;
        if (!std::isfinite(compression) || !bounded_three(fx, fy, fz, 2000000.0) ||
            !within(now_s, 0.0, 1e9)) return;
        wheel = {std::hypot(fx, fy, fz), compression, now_s};
    }
    bool fresh(const Wheel& wheel, double now_s) const {
        return wheel.stamp_s >= 0.0 && now_s >= wheel.stamp_s &&
            now_s - wheel.stamp_s <= maximum_age_s;
    }
    void update(const std::array<double, 3>& gear_positions, double clearance_m,
                bool surface_valid, double now_s) {
        valid = loaded = false;
        if (!within(now_s, 0.0, 1e9)) return;
        bool extended = false;
        for (const auto position : gear_positions) {
            if (!within(position, 0.0, 1.0)) return;
            extended = extended || position > .5;
        }
        if (!extended || (surface_valid && clearance_m > maximum_reach_m)) {
            valid = true;
            return;
        }
        for (std::size_t index = 0; index < wheels.size(); ++index) {
            if (gear_positions[index] <= .5) continue;
            const auto& wheel = wheels[index];
            if (!fresh(wheel, now_s)) continue;
            valid = true;
            loaded = loaded || wheel.reaction_n > minimum_load_n;
        }
        // Positive strut travel alone never establishes wheel loading. No
        // height-only contact fallback; unknown near-ground feedback is invalid.
    }
};
} // namespace RaptorVehicle
