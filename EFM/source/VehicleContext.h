#pragma once

#include "AirData.h"
#include "EngineController.h"
#include "VehicleConfiguration.h"
#include "VehicleEnvironment.h"
#include "VehicleLedger.h"
#include "BrakeEnergy.h"
#include "FuelSystem.h"
#include "VehicleDemand.h"

namespace RaptorVehicle {
// One object per EFM instance. Producer: ed_fm_simulate, simulation thread.
// Cockpit exports are copied after the completed step; render never advances it.
struct VehicleContext {
    Power power;
    StoredEnergy ses;
    Environment environment;
    Configuration configuration;
    EngineController left_engine;
    EngineController right_engine;
    RaptorAirData::Frame air_truth;
    RaptorAirData::Sensor air_sensor;
    RaptorAirData::Frame control_air;
    MassLedger mass;
    DamageLedger damage;
    FuelSystem fuel;
    UtilityDemand utility_demand;
    BrakeEnergy left_brake;
    BrakeEnergy right_brake;
    double raw_body_ay_mps2 = 0.0;
    double time_s = 0.0;
    double discarded_time_s = 0.0;
    double achieved_speedbrake = 0.0;
    double apu_flow_kg_s = 0.0;
    // The inherited wing coefficients use offsets from the spawn CG, not
    // absolute EDM-origin coordinates. Capture that calibration once; later
    // fuel/store CG changes must retain their moment effect.
    double wing_reference_x_m = 0.0;
    double wing_reference_y_m = 0.0;
    unsigned generation = 0;
    bool atmosphere_valid = false;
    bool motion_valid = false;
    bool world_motion_valid = false;
    bool mass_valid = false;
    bool wing_reference_valid = false;
    bool air_data_reversion = true;
    bool power_requests_seen = false;
    bool left_fire_isolated = false;
    bool right_fire_isolated = false;
    bool fire_bottle_available = true;
    bool left_fire = false;
    bool right_fire = false;
    bool extinguishing_attempt = false;
    bool alive = true;

    void reset(bool hot, double initial_spool = 0.67) {
        const unsigned next_generation = generation + 1;
        *this = {};
        generation = next_generation;
        power.reset(hot);
        environment.reset(hot);
        left_engine.reset(hot, initial_spool);
        right_engine.reset(hot, initial_spool);
    }
    void repair_equipment() {
        left_fire_isolated = right_fire_isolated = false;
        left_fire = right_fire = false;
        extinguishing_attempt = false;
        fire_bottle_available = true;
        damage.clear();
        left_brake.repair_tire();
        right_brake.repair_tire();
        // Repair is not refueling, reserve servicing, cooling, or engine start.
    }
};
} // namespace RaptorVehicle
