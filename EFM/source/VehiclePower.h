#pragma once

#include "VehicleSystems.h"

namespace RaptorVehicle {
// All rates/capacities below are explicit simulation estimates, preserving the
// old electrical scale. F-22 functional evidence: VS02/04/05. No bus diagram
// or SES bottle capacity is claimed. Sources/consumers: vehicle-state-contract.
struct PowerRequests {
    bool battery = false;
    bool left_generator = false;
    bool right_generator = false;
    bool apu = false;
    bool ground_power = false;
};

struct PowerFaults {
    bool battery = false;
    bool left_generator = false;
    bool right_generator = false;
    bool apu = false;
};

struct StoredEnergy {
    double air = 1.0;
    double start_fuel = 1.0;
    bool consume(double air_units, double fuel_units) {
        if (air_units < 0.0 || fuel_units < 0.0 ||
            air < air_units || start_fuel < fuel_units) return false;
        air -= air_units;
        start_fuel -= fuel_units;
        return true;
    }
    void recharge(double dt, bool compressor_available, bool fuel_available) {
        if (compressor_available) air = slew(air, 1.0, 1.0 / 180.0, dt);
        if (fuel_available) start_fuel = slew(start_fuel, 1.0, 1.0 / 120.0, dt);
    }
    void service() { air = start_fuel = 1.0; }
};

struct Power {
    PowerRequests requests;
    double soc = 1.0;
    double volts = 0.0;
    double apu_spool = 0.0;
    double apu_autooff_s = 0.0;
    bool left_generator = false;
    bool right_generator = false;
    bool main = false;
    bool battery = false;
    bool essential = false;
    bool apu_running = false;
    bool apu_starting = false;
    bool apu_abort = false;
    bool apu_inhibit = false;
    bool apu_armed = true;
    bool automatic_shutdown = false;
    bool apu_hydraulics = false;
    bool conditioned_air = false;

    void reset(bool hot) {
        *this = {};
        requests.battery = requests.left_generator = requests.right_generator = hot;
        left_generator = right_generator = main = battery = essential = hot;
        volts = hot ? 28.0 : 0.0;
    }
    static bool generator(bool prior, bool selected, bool fault, double core) {
        if (!selected || fault || !std::isfinite(core) || core < 0.59) return false;
        return core >= 0.61 || prior;
    }
    bool electrical_start_available(const PowerFaults& faults) const {
        return main || (requests.battery && !faults.battery && soc > 0.02);
    }
    bool apu_interrupted(bool fuel_available, bool electrical_start, const PowerFaults& faults) const {
        return !fuel_available || faults.apu || (!apu_running && !electrical_start);
    }
    void arm_apu_start(bool electrical_start, bool fuel_available,
                       const PowerFaults& faults, StoredEnergy& ses) {
        if (requests.apu && apu_armed && !apu_inhibit && apu_spool <= 0.0) {
            apu_armed = false;
            if (!electrical_start || !fuel_available || faults.apu ||
                !ses.consume(0.12, 0.08)) apu_inhibit = true;
        }
    }
    bool apu_can_run(bool electrical_start, bool fuel_available, const PowerFaults& faults) const {
        return requests.apu && !apu_inhibit && !faults.apu && fuel_available &&
            (apu_running || electrical_start);
    }
    void update_apu_outputs(bool can_run, bool ground, double dt) {
        apu_abort = requests.apu && !can_run;
        apu_spool = slew(apu_spool, can_run ? 1.0 : 0.0, 1.0 / 9.6, dt);
        apu_starting = can_run && apu_spool < 0.95;
        apu_running = can_run && apu_spool >= 0.95;
        // Limited ground service, not an assumed full-flight generator.
        apu_hydraulics = apu_running;
        conditioned_air = apu_running && ground;
    }
    void advance_apu(double dt, bool ground, bool fuel_available,
                     const PowerFaults& faults, StoredEnergy& ses) {
        if (!requests.apu) {
            apu_inhibit = false;
            apu_armed = true;
            automatic_shutdown = false;
        }
        const bool electrical_start = electrical_start_available(faults);
        if (requests.apu && apu_spool > 0.0 &&
            apu_interrupted(fuel_available, electrical_start, faults))
            apu_inhibit = true;
        arm_apu_start(electrical_start, fuel_available, faults, ses);
        update_apu_outputs(apu_can_run(electrical_start, fuel_available, faults), ground, dt);
    }
    void update_generators(double left_core, double right_core, bool ground, const PowerFaults& faults) {
        left_generator = generator(left_generator, requests.left_generator,
                                   faults.left_generator, left_core);
        right_generator = generator(right_generator, requests.right_generator,
                                    faults.right_generator, right_core);
        main = left_generator || right_generator || (requests.ground_power && ground);
    }
    void update_terminals(const PowerFaults& faults) {
        battery = requests.battery && !faults.battery && (main || soc > 0.02);
        essential = main || battery;
        volts = main ? 28.0 : (battery ? 24.0 + 4.0 * soc : 0.0);
    }
    void advance_battery(double dt, const PowerFaults& faults) {
        double amps = 0.0;
        if (!faults.battery) {
            if (main) amps = -8.0;
            else if (requests.battery) amps = 18.0 + (apu_starting ? 80.0 : 0.0);
        }
        soc = unit(soc - amps * dt / (3600.0 * 12.0));
        update_terminals(faults);
    }
    void advance_autooff(double dt, double left_core, double right_core) {
        const bool qualified = requests.apu && apu_running &&
            left_generator && right_generator && left_core >= 0.67 && right_core >= 0.67;
        apu_autooff_s = qualified ? apu_autooff_s + dt : 0.0;
        if (apu_autooff_s >= 60.0) {
            apu_inhibit = true;
            automatic_shutdown = true;
            apu_autooff_s = 0.0;
        }
    }
    void recharge_ses(double dt, double left_core, double right_core,
                      bool fuel_available, StoredEnergy& ses) const {
        const bool compressor = (left_core >= 0.67 || right_core >= 0.67) && essential;
        ses.recharge(dt, compressor, fuel_available && essential &&
            (left_core >= 0.4 || right_core >= 0.4 || apu_running));
    }
    void update(double dt, double left_core, double right_core, bool ground,
                bool fuel_available, const PowerFaults& faults, StoredEnergy& ses) {
        update_generators(left_core, right_core, ground, faults);
        advance_apu(dt, ground, fuel_available, faults, ses);
        main = main || (apu_running && ground);
        advance_battery(dt, faults);
        advance_autooff(dt, left_core, right_core);
        recharge_ses(dt, left_core, right_core, fuel_available, ses);
    }
};
} // namespace RaptorVehicle
