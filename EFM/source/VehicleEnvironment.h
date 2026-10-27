#pragma once

#include "VehicleSystems.h"

namespace RaptorVehicle {
struct EnvironmentInputs {
    double ambient_pa = 101325.0;
    double ambient_k = 288.15;
    double tas_mps = 0.0;
    double internal_fuel_kg = 0.0;
    double canopy_position = 0.0; // native host position, not another actuator
    bool canopy_locked = true;
    bool powered = false;
    bool left_bleed = false;
    bool right_bleed = false;
    bool apu_air = false;
    bool ecs_failed = false;
    bool cooling_failed = false;
    bool oxygen_failed = false;
    bool bleed_selected = true;
    bool defog_selected = false;
    bool backup_manual = false;
    bool modern_abos = true;
};

// Reduced-order estimate. VS03/05 establish coupled cooling/bleed/cabin paths;
// VS06 establishes automatic backup function, not reserve size or thresholds.
struct Environment {
    double cabin_overpressure_pa = 0.0;
    double cabin_absolute_pa = 101325.0;
    double equipment_c = 25.0;
    double coolant_c = 20.0;
    double fuel_sink_c = 15.0;
    double backup_reserve = 1.0;
    double oxygen_delivery_pa = 0.0;
    double fog = 0.0;
    bool conditioned_air = false;
    bool obogs = false;
    bool backup = false;
    bool thermal_fault = false;
    bool valid = false;
    bool primary_seen = false;

    void reset(bool hot) {
        *this = {};
        obogs = hot;
        primary_seen = hot;
        oxygen_delivery_pa = hot ? 101000.0 : 0.0;
    }
    void update_cooling(const EnvironmentInputs& input, double dt) {
        const double ambient_c = input.ambient_k - 273.15;
        const double ram = unit(input.tas_mps / 150.0);
        const double refrigeration = conditioned_air && !input.cooling_failed ? 1.0 : 0.0;
        const double sink = unit(input.internal_fuel_kg / 8200.0);
        // Estimated kJ/K capacities and kW conductances, explicit energy balance.
        const double equipment_heat_kw = input.powered ? 12.0 : 0.0;
        const double transfer_kw = 0.8 * (equipment_c - coolant_c);
        const double fuel_kw = 0.15 * sink * (coolant_c - fuel_sink_c);
        const double air_kw = (0.05 + 0.3 * ram + refrigeration) * (coolant_c - ambient_c);
        equipment_c += (equipment_heat_kw - transfer_kw) * dt / 150.0;
        coolant_c += (transfer_kw - fuel_kw - air_kw) * dt / 250.0;
        fuel_sink_c += fuel_kw * dt / (50.0 + 2.0 * input.internal_fuel_kg);
        if (equipment_c >= 85.0) thermal_fault = true;
        else if (equipment_c < 75.0) thermal_fault = false;
    }
    static bool valid_inputs(const EnvironmentInputs& input) {
        return std::isfinite(input.ambient_pa) && input.ambient_pa > 0.0 &&
            std::isfinite(input.ambient_k) && input.ambient_k > 100.0 &&
            std::isfinite(input.canopy_position);
    }
    static bool source_available(const EnvironmentInputs& input) {
        return input.powered && input.bleed_selected && !input.ecs_failed &&
            (input.left_bleed || input.right_bleed || input.apu_air);
    }
    void update_cabin(const EnvironmentInputs& input, double dt) {
        const bool sealed = input.canopy_locked && input.canopy_position < 0.01;
        // Estimated regulation target: at most 35 kPa differential, with an
        // approximately 75 kPa cabin target. Never interpret SAB inlet psi as cabin.
        const double target_pa = conditioned_air && sealed ?
            std::clamp(75000.0 - input.ambient_pa, 0.0, 35000.0) : 0.0;
        cabin_overpressure_pa = lag(cabin_overpressure_pa, target_pa, sealed ? 8.0 : 1.0, dt);
        cabin_absolute_pa = input.ambient_pa + cabin_overpressure_pa;
    }
    void update_oxygen(const EnvironmentInputs& input, double dt) {
        obogs = conditioned_air && !input.oxygen_failed;
        primary_seen = primary_seen || obogs;
        backup = !obogs && backup_reserve > 0.0 &&
            ((input.modern_abos && primary_seen) || input.backup_manual);
        if (backup) backup_reserve = std::max(0.0, backup_reserve - dt / 600.0);
        // Preserve the healthy SDK pressure baseline pending an actual host test.
        // The reserve duration is an estimate, not an ABOS hardware capacity.
        oxygen_delivery_pa = obogs || backup ? 101000.0 : 0.0;
    }
    void update_fog(const EnvironmentInputs& input, double dt) {
        const bool sealed = input.canopy_locked && input.canopy_position < 0.01;
        const double fog_target = input.ambient_k < 283.15 && sealed &&
            !(conditioned_air && input.defog_selected) ? 1.0 : 0.0;
        fog = lag(fog, fog_target, fog_target > fog ? 180.0 : 30.0, dt);
    }
    void update(const EnvironmentInputs& input, double dt) {
        valid = valid_inputs(input);
        if (!valid) {
            obogs = backup = conditioned_air = false;
            oxygen_delivery_pa = 0.0;
            return;
        }
        conditioned_air = source_available(input);
        update_cabin(input, dt);
        update_oxygen(input, dt);
        update_cooling(input, dt);
        update_fog(input, dt);
    }
    void service_oxygen() { backup_reserve = 1.0; }
};
} // namespace RaptorVehicle
