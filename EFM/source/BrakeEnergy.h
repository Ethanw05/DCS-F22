#pragma once

#include "VehicleSystems.h"
#include <array>

namespace RaptorVehicle {
// Reduced-order MOD ESTIMATE, not an F-22 thermal deck. DCS retains contact,
// baseline rolling friction and anti-skid. We derate its requested wheel torque,
// never add aerodynamic stopping assistance. Work is a conservative commanded
// torque/contact-load envelope, not measured anti-skid work. Raw wheel speed
// remains diagnostic until the host's undocumented units are qualified.
struct BrakeEnergy {
    static constexpr double torque_nm = 24000.0;
    static constexpr double radius_m = 0.605;
    static constexpr double disc_capacity_j_k = 60000.0;
    static constexpr double tire_capacity_j_k = 30000.0;
    double energy_j = 0.0;
    double temperature_c = 15.0;
    double tire_temperature_c = 15.0;
    double ambient_temperature_c = 15.0;
    double wheel_speed_raw = 0.0;
    double normal_force_n = 0.0;
    double contact_stamp_s = -1.0;
    std::array<double, 3> contact_m{};
    bool wheel_sample_valid = false;
    bool initialized = false;
    bool tire_failed = false;

    bool contact_fresh(double now_s) const {
        return contact_stamp_s >= 0.0 && now_s >= contact_stamp_s &&
            now_s - contact_stamp_s <= 0.1 && normal_force_n > 1.0;
    }
    double effectiveness() const {
        // Estimated gradual fade: full through 450 C, 25% at/above 1000 C.
        const double fade = 1.0 - 0.75 * unit((temperature_c - 450.0) / 550.0);
        return fade * (tire_failed ? 0.35 : 1.0);
    }
    void update(double demand, double speed_mps, double ambient_c,
                bool loaded, double dt) {
        if (!within(dt, 0.0, 0.1) || !within(ambient_c, -100.0, 100.0) ||
            !within(speed_mps, -500.0, 500.0)) return;
        if (!initialized) {
            temperature_c = tire_temperature_c = ambient_c;
            initialized = true;
        }
        ambient_temperature_c = ambient_c;
        const double speed = std::abs(speed_mps);
        const double braking_n = std::min(torque_nm * unit(demand) / radius_m,
            std::max(0.0, normal_force_n));
        const double power_w = loaded ? braking_n * speed : 0.0;
        const double soak_w = 80.0 * (temperature_c - tire_temperature_c);
        const double cooling_w = (50.0 + 3.0 * speed) * (temperature_c - ambient_c);
        const double tire_cooling_w = (20.0 + speed) * (tire_temperature_c - ambient_c);
        energy_j += power_w * dt;
        temperature_c += (power_w - soak_w - cooling_w) * dt / disc_capacity_j_k;
        tire_temperature_c += (soak_w - tire_cooling_w) * dt / tire_capacity_j_k;
        // Estimated heat damage/fuse threshold; cooling cannot repair a tire.
        tire_failed = tire_failed || tire_temperature_c >= 200.0;
    }
    double extra_rolling_force(double longitudinal_mps, bool loaded) const {
        if (!tire_failed || !loaded) return 0.0;
        // Incremental failed-tire resistance only, zero at rest. Native healthy
        // tire friction stays DCS-owned; no native flat-tire mesh is claimed.
        return -0.06 * normal_force_n * std::tanh(longitudinal_mps / 0.5);
    }
    void repair_tire() {
        if (tire_failed) tire_temperature_c = ambient_temperature_c;
        tire_failed = false; // replacement does not cool the brake disc
    }
};
} // namespace RaptorVehicle
