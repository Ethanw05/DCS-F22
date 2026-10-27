#pragma once

#include <algorithm>
#include <cmath>

// Bounded simulation approximations, NOT a production F-22/F119 equipment deck.
// The EFM owns these states. Displays consume them; they must not integrate a
// second hydraulic, oil, thermal or actuator model from RPM/draw arguments.
namespace RaptorVehicle {
constexpr double pi = 3.14159265358979323846;
constexpr double radians(double deg) { return deg * pi / 180.0; }
constexpr double degrees(double rad) { return rad * 180.0 / pi; }
constexpr double hydraulic_nominal_psi = 3950.0; // preserves mod display scale
constexpr double fan_reference_rpm = 12000.0;   // estimated API unit anchor
constexpr double core_reference_rpm = 16000.0;  // estimated API unit anchor
constexpr double external_tank_capacity_kg = 605.0 * 3.785 * 0.81482;

inline double finite(double x, double fallback = 0.0) {
    return std::isfinite(x) ? x : fallback;
}
// Computational input bounds, not aircraft operating limitations.
inline bool within(double value, double lower, double upper) {
    return std::isfinite(value) && value >= lower && value <= upper;
}
inline bool bounded_three(double first, double second, double third, double magnitude) {
    return within(first, -magnitude, magnitude) && within(second, -magnitude, magnitude) &&
        within(third, -magnitude, magnitude);
}
inline double unit(double x) { return std::clamp(finite(x), 0.0, 1.0); }
inline double slew(double current, double target, double rate, double dt) {
    const double step = std::max(0.0, finite(rate)) * std::max(0.0, finite(dt));
    current = finite(current); target = finite(target);
    return current + std::clamp(target - current, -step, step);
}
inline double lag(double current, double target, double tau, double dt) {
    return current + (target - current) * -std::expm1(-std::max(0.0, finite(dt)) / tau);
}

// A schedule restricts the commanded envelope, not the physical ability to
// center. Maintain a 20 deg/s neutral-return rate even when scheduled slew=0.
// Hydraulic failure, in contrast, really can leave a nozzle in place.
inline double nozzle(double current, double command, double envelope_rad,
                     double scheduled_rate, double hydraulic, double dt) {
    const double envelope = std::clamp(finite(envelope_rad), 0.0, radians(20));
    const double target = std::clamp(finite(command), -1.0, 1.0) * envelope;
    const bool centering = std::abs(target) < std::abs(current) || target * current < 0;
    const double rate = std::clamp(std::max(finite(scheduled_rate), centering ? radians(20) : 0.0),
                                   0.0, radians(40));
    return slew(current, target, rate * unit(hydraulic), dt);
}

struct Engine {
    double fan = 0, core = 0, temperature_c = 15, oil_psi = 0, nozzle_pct = 100;
    static double heat_target(double spool) {
        // Estimated display envelope: 450 C idle / 730 C dry / 850 C AB at
        // 15 C ambient. These are useful mod states, not measured F119 EGT.
        return spool <= .67 ? 435 * unit((spool - .2) / .47) :
            435 + 280 * unit((spool - .67) / .355);
    }
    static double fan_target(double core) {
        core = std::clamp(finite(core), 0.0, 1.1);
        return core <= .67 ? core * (.55 / .67) : .55 + (core - .67) * (.55 / .43);
    }
    void reset(double spool, double ambient_k) {
        core = std::clamp(finite(spool), 0.0, 1.1); fan = fan_target(core);
        const double ambient_c = finite(ambient_k, 288.15) - 273.15;
        temperature_c = ambient_c + (core > .4 ? heat_target(core) : 0);
        oil_psi = core > .2 ? std::min(270.0, core * 270.0) : 0;
        nozzle_pct = nozzle_target(core);
    }
    static double nozzle_target(double spool) {
        if (spool <= .70) return 100;
        if (spool <= .90) return (0.90 - spool) / .20 * 100;
        return unit((spool - 1.035) / .065) * 100;
    }
    void update(double spool, bool burning, double ab_fraction, double ambient_k, double dt,
                double extra_start_heat_c = 0.0, bool motoring = false) {
        spool = std::clamp(finite(spool), 0.0, 1.1);
        core = lag(core, spool, .35, dt);
        fan = lag(fan, fan_target(spool), .8, dt);
        const double ambient_c = finite(ambient_k, 288.15) - 273.15;
        const double hot = burning ? heat_target(spool) + 120 * unit(ab_fraction) +
            std::clamp(finite(extra_start_heat_c), 0.0, 1600.0) : 0.0;
        const double thermal_lag_s = burning ? 4.0 : (motoring ? 8.0 : 22.0);
        temperature_c = lag(temperature_c, ambient_c + hot, thermal_lag_s, dt);
        oil_psi = lag(oil_psi, spool > .2 ? std::min(270.0, spool * 270.0) : 0, 1.5, dt);
        // Above the dry-area schedule, achieved augmentation drives the area
        // command. Failed augmentation cannot retain an AB-only area request.
        const double area = spool > .90 ? 100.0 * unit(ab_fraction) : nozzle_target(spool);
        nozzle_pct = slew(nozzle_pct, area, 60, dt);
    }
    double raw_fan_rpm() const { return fan * fan_reference_rpm; }
    double raw_core_rpm() const { return core * core_reference_rpm; }
};

struct Hydraulics {
    double left_psi = 0, right_psi = 0, brake_reserve = 0;
    double left_capacity = 1.0, right_capacity = 1.0;
    double left_load = 0.0, right_load = 0.0;
    double previous_brake_demand = 0.0;
    double left_inventory = 1.0, right_inventory = 1.0;
    bool apu_source = false;
    void reset(bool hot) {
        left_psi = right_psi = hot ? hydraulic_nominal_psi : 0;
        brake_reserve = hot ? 1 : 0;
        previous_brake_demand = 0.0;
        left_inventory = right_inventory = 1.0;
    }
    static double advance(double pressure, double spool, double health, bool failed, double dt) {
        // Engine-driven pumps build from 20 to 60% core speed. Failure dumps
        // pressure; shutdown leaks it down over 8 s. These are mod estimates.
        const double pump = unit((spool - .2) / .4) * unit(health);
        const double target = failed ? 0 : hydraulic_nominal_psi * pump;
        const double rate = failed ? 2500 : (target > pressure ? 2200 : 500);
        return slew(pressure, target, rate, dt);
    }
    void update(double left_spool, double right_spool, double left_health,
                double right_health, bool left_failed, bool right_failed,
                double brake_demand, double speed_mps, double dt) {
        const double left_source = std::max(unit((left_spool - .2) / .4) * left_capacity * unit(left_health),
                                            apu_source ? 0.65 : 0.0);
        const double right_source = std::max(unit((right_spool - .2) / .4) * right_capacity * unit(right_health),
                                             apu_source ? 0.65 : 0.0);
        // Circuit failure represents the existing dump/leak abstraction, while
        // individual pump failures do not consume fluid. Rates are estimates.
        if (left_failed) left_inventory = std::max(0.0, left_inventory - 0.01 * dt);
        if (right_failed) right_inventory = std::max(0.0, right_inventory - 0.01 * dt);
        left_psi = advance_loaded(left_psi, left_inventory > 0.1 ? left_source : 0.0, left_load, left_failed, dt);
        right_psi = advance_loaded(right_psi, right_inventory > 0.1 ? right_source : 0.0, right_load, right_failed, dt);
        const double supply = shared();
        if (supply > brake_reserve) brake_reserve = slew(brake_reserve, supply, .4, dt);
        else {
            // Stored pressure supports a finite number of braking applications;
            // holding the parking brake at rest does not consume the reserve.
            // Fluid use follows applications; rolling energy belongs to the
            // wheel/thermal owner. A held parking brake is not a heater/pump.
            const double application = std::max(0.0, unit(brake_demand) - previous_brake_demand);
            brake_reserve = std::max(0.0, brake_reserve - 0.05 * application - 0.0005 * dt);
        }
        previous_brake_demand = unit(brake_demand);
        static_cast<void>(speed_mps); // retained source-compatible legacy signature
    }
    static double advance_loaded(double pressure, double capacity, double load, bool failed, double dt) {
        if (failed) return slew(pressure, 0.0, 2500.0, dt);
        const double target = capacity > 0.01 ?
            std::max(0.0, hydraulic_nominal_psi - 350.0 * unit(load) / capacity) : 0.0;
        const double rate = target > pressure ? 2200.0 * capacity : 500.0;
        return slew(pressure, target, rate, dt);
    }
    double left() const { return unit((left_psi - 500) / (hydraulic_nominal_psi - 500)); }
    double right() const { return unit((right_psi - 500) / (hydraulic_nominal_psi - 500)); }
    // Redundant flight-control feed is an explicitly simplified cross-feed.
    double shared() const { return std::max(left(), right()); }
    double brakes() const { return std::max(shared(), unit(brake_reserve)); }
};

// A shared aerodynamic scale is retained until flight data justify retuning.
// Blend the existing ground/flight engine tables by airspeed, never WOW, so
// crossing the suspension contact threshold cannot jump installed thrust.
inline double installed_thrust(double static_n, double table_n, double tas_mps) {
    const double t = unit(tas_mps / 100.0);
    const double blend = t * t * (3 - 2 * t);
    return static_n + (table_n - static_n) * blend;
}
inline double relative_thrust(double thrust, double reference) {
    return reference > 1 ? std::clamp(finite(thrust) / reference, 0.0, 2.0) : 0;
}
inline double normalized_brake(double axis) { return unit((finite(axis, -1) + 1) * .5); }
} // namespace RaptorVehicle
