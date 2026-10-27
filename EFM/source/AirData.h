#pragma once

#include <cmath>
#include <limits>

// SI perfect-gas air data. SFTE handbook sections 4.1/4.4; no F-22
// sensor accuracy or production schedule is implied by these relationships.
namespace RaptorAirData {
constexpr double sea_pressure_pa = 101325.0;
constexpr double sea_density_kg_m3 = 1.225;
constexpr double sea_sound_mps = 340.293988;
constexpr double invalid = std::numeric_limits<double>::quiet_NaN();

inline double pitot_ratio(double mach) {
    if (!std::isfinite(mach) || mach < 0.0 || mach > 10.0) return invalid;
    const double squared = mach * mach;
    if (mach <= 1.0) return std::pow(1.0 + 0.2 * squared, 3.5);
    return std::pow(1.2 * squared, 3.5) *
        std::pow(2.4 / (2.8 * squared - 0.4), 2.5);
}

inline double calibrated_speed(double tas_mps, double sound_mps, double pressure_pa) {
    if (!std::isfinite(tas_mps) || !std::isfinite(sound_mps) ||
        !std::isfinite(pressure_pa) || tas_mps < 0.0 ||
        sound_mps < 100.0 || pressure_pa <= 0.0) return invalid;
    const double impact_pa = pressure_pa * (pitot_ratio(tas_mps / sound_mps) - 1.0);
    if (!std::isfinite(impact_pa) || impact_pa < 0.0) return invalid;
    double low = 0.0;
    double high = 10.0;
    if (impact_pa > sea_pressure_pa * (pitot_ratio(high) - 1.0)) return invalid;
    for (int iteration = 0; iteration < 45; ++iteration) {
        const double middle = (low + high) * 0.5;
        if (sea_pressure_pa * (pitot_ratio(middle) - 1.0) < impact_pa) low = middle;
        else high = middle;
    }
    return (low + high) * 0.5 * sea_sound_mps;
}

struct Frame {
    double tas_mps = invalid;
    double eas_mps = invalid;
    double cas_mps = invalid;
    double mach = invalid;
    double static_pa = invalid;
    double impact_pa = invalid;
    double dynamic_pa = invalid;
    double stamp_s = 0.0;
    bool valid = false;
};

inline Frame calculate(double tas_mps, double sound_mps, double density_kg_m3,
                       double pressure_pa, double stamp_s) {
    Frame result;
    result.stamp_s = stamp_s;
    const double cas_mps = calibrated_speed(tas_mps, sound_mps, pressure_pa);
    if (!std::isfinite(cas_mps) || !std::isfinite(density_kg_m3) ||
        density_kg_m3 <= 0.0 || !std::isfinite(stamp_s)) return result;
    result.tas_mps = tas_mps;
    result.eas_mps = tas_mps * std::sqrt(density_kg_m3 / sea_density_kg_m3);
    result.cas_mps = cas_mps;
    result.mach = tas_mps / sound_mps;
    result.static_pa = pressure_pa;
    result.impact_pa = pressure_pa * (pitot_ratio(result.mach) - 1.0);
    result.dynamic_pa = 0.5 * density_kg_m3 * tas_mps * tas_mps;
    result.valid = true;
    return result;
}

enum class Health { Healthy = 0, Invalid = 1, Frozen = 2, Biased = 3 };

struct Sensor {
    Frame measured;
    Health health = Health::Invalid;
    void update(const Frame& truth, Health requested, double bias_mps) {
        health = requested;
        if (requested == Health::Frozen && measured.valid) return;
        measured = truth;
        if (requested == Health::Invalid || !truth.valid) {
            measured.valid = false;
            return;
        }
        if (requested == Health::Biased) {
            if (!std::isfinite(bias_mps)) {
                measured.valid = false;
                return;
            }
            measured.cas_mps = std::fmax(0.0, truth.cas_mps + bias_mps);
        }
        // A freeze before the first valid sample cannot invent a measurement.
        if (requested == Health::Frozen) measured.valid = false;
    }
};
} // namespace RaptorAirData
