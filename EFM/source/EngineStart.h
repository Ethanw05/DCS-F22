#pragma once

#include "VehicleSystems.h"

namespace RaptorVehicle {
enum class EnginePhase { Off = 0, Cranking, Lighting, Accelerating,
                         Running, ShuttingDown, Windmilling };
enum class StartRejection { None = 0, NoFuel, NoPower, NoStarter, Damaged, Isolated,
                            FaultLatched, PurgeRequired, TooHot, NoControl,
                            InvalidInput, WaitForRotor, ResetUnsafe };
enum class EngineFault { None = 0, NoLight, HungStart, HotStart, ControlLoss,
                         StarterDuty, InvalidInput };
enum class EngineControl { Normal = 0, Degraded, Unavailable };

// ED Viper supplies the motoring -> fuel/light-off workflow analogue. All
// numbers below are mod estimates, NOT F119 operating limits or procedures.
struct EngineStartProfile {
    static constexpr double fuel_admit_core = 0.2;
    static constexpr double self_sustaining_core = 0.4;
    static constexpr double no_light_s = 10.0;
    static constexpr double hung_start_s = 45.0;
    static constexpr double hot_start_c = 900.0;
    static constexpr double restart_below_c = 600.0;
    static constexpr double purge_s = 5.0;
    static constexpr double purge_core = 0.12;
    static constexpr double starter_duty_s = 60.0;
    static constexpr double starter_rest_s = 15.0;
    static constexpr double degraded_max_core = 0.95;
    static constexpr double hung_light_core = 0.35;
    static constexpr double hung_acceleration_core = 0.6;
    static constexpr double hot_start_extra_c = 1400.0;
};

struct EngineInputs {
    double throttle = 0.0;
    double tas_mps = 0.0;
    double health = 1.0;
    double temperature_c = 15.0;
    double spool_up_per_s = 0.1;
    double spool_down_per_s = 0.1;
    EngineControl control = EngineControl::Normal;
    bool ground = true;
    bool powered = false;
    bool starter = false;
    bool feed = false;
    bool isolated = false;
    bool starter_failed = false;
    bool ignition_failed = false;
    bool hung_start = false;
    bool hot_start = false;
    bool augmentation_failed = false;
};

inline bool valid_engine_inputs(const EngineInputs& input) {
    return within(input.throttle, 0.0, 1.0) && within(input.tas_mps, 0.0, 5000.0) &&
        within(input.health, 0.0, 1.0) && within(input.temperature_c, -200.0, 2500.0) &&
        within(input.spool_up_per_s, 0.0, 10.0) && within(input.spool_down_per_s, 0.0, 10.0) &&
        input.control >= EngineControl::Normal && input.control <= EngineControl::Unavailable;
}

struct EngineStartState {
    bool automatic = false;
    bool starter_selected = false;
    bool fuel_selected = false;
    bool ignition_selected = false;
    bool starter_engaged = false;
    bool fuel_valve = false;
    EngineFault fault = EngineFault::None;
    double unlit_s = 0.0;
    double combustion_start_s = 0.0;
    double purge_remaining_s = 0.0;
    double starter_duty_s = 0.0;
    double starter_rest_s = 0.0;

    void select_automatic() {
        automatic = starter_selected = fuel_selected = ignition_selected = true;
        unlit_s = combustion_start_s = 0.0;
    }
    void request_cutoff() {
        automatic = fuel_selected = ignition_selected = false;
    }
    void cutoff() {
        request_cutoff();
        fuel_valve = false;
    }
    void latch(EngineFault reason, bool purge) {
        if (fault == EngineFault::None) fault = reason;
        if (automatic) starter_selected = false;
        cutoff();
        if (purge) purge_remaining_s = EngineStartProfile::purge_s;
    }
    void advance_starter(double dt) {
        if (starter_engaged) {
            starter_duty_s += dt;
            starter_rest_s = 0.0;
        } else {
            starter_rest_s = std::min(EngineStartProfile::starter_rest_s, starter_rest_s + dt);
            if (starter_rest_s >= EngineStartProfile::starter_rest_s) starter_duty_s = 0.0;
        }
        if (starter_duty_s >= EngineStartProfile::starter_duty_s) {
            latch(EngineFault::StarterDuty, false);
            starter_selected = starter_engaged = false;
        }
    }
    void advance_purge(double core, double dt) {
        if (!fuel_valve && core >= EngineStartProfile::purge_core)
            purge_remaining_s = std::max(0.0, purge_remaining_s - dt);
    }
    void record_unlit_delivery(double delivered_kg) {
        // Unlit fuel is discharged overboard in this estimate, not stored as
        // invented engine mass. The exposure timer is a purge requirement.
        if (delivered_kg > 0.0) purge_remaining_s = EngineStartProfile::purge_s;
    }
};
} // namespace RaptorVehicle
