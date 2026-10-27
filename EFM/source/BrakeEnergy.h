#pragma once

#include "VehicleSystems.h"

namespace RaptorVehicle {
// Diagnostic energy budget only until native brake heat/fade ownership and
// wheel-speed semantics are characterized. It must not add another anti-skid
// loop or a second dissipative force. Estimated demand torque gives an upper
// bound; it is not measured wheel work when native anti-skid reduces torque.
struct BrakeEnergy {
    double energy_j = 0.0;
    double temperature_c = 15.0;
    double wheel_speed_raw = 0.0;
    bool wheel_sample_valid = false;
    void update(double demand, double ground_speed_mps, double ambient_c,
                bool loaded, double dt) {
        const double torque_nm = loaded ? 24000.0 * unit(demand) : 0.0;
        const double power_w = torque_nm * std::abs(finite(ground_speed_mps)) / 0.605;
        const double heat_loss_w = 60.0 * (temperature_c - ambient_c);
        energy_j = std::max(0.0, energy_j + power_w * dt);
        temperature_c += (power_w - heat_loss_w) * dt / 80000.0;
    }
};
} // namespace RaptorVehicle
