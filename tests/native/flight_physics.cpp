// R-FLT-010/011/015, D-R-FLT-004: numerical identities and declared model limits.
#include "flight_assert.h"
#include "AirData.h"
#include "HighAlpha.h"
#include "VehicleEnvironment.h"
#include "VehicleConfiguration.h"
#include "VehicleSystems.h"
#include <array>
#include <iostream>
#include <limits>

namespace {
void air_and_saturation() {
    for (double speed : {0.0, 100.0, 340.293988, 680.587976}) {
        const auto frame = RaptorAirData::calculate(speed, 340.293988, 1.225, 101325, 2);
        flight_require(frame.valid && flight_close(frame.cas_mps, speed, 1e-5) &&
            flight_close(frame.eas_mps, speed) && flight_close(frame.mach, speed / 340.293988),
            "Sea-level CAS/EAS/TAS identity failed");
    }
    for (double pressure : {0.0, -1.0, std::numeric_limits<double>::quiet_NaN()})
        flight_require(!RaptorAirData::calculate(200, 300, .4, pressure, 1).valid,
            "Invalid pressure authenticated air data");
    for (double pitch : {-1.0, -.6, 0.0, .6, 1.0}) {
        double left = 0, right = 0;
        RaptorVehicle::Configuration::allocate(pitch, 1, left, right);
        flight_require(flight_close((left + right) * .5, pitch) &&
            std::abs(left) <= 1 && std::abs(right) <= 1, "Roll saturation stole pitch priority");
    }
}
void high_alpha_continuity() {
    for (double angle : {15.0, 20.0, 60.0, 65.0}) {
        const auto before = RaptorAero::VortexLiftCorrection(angle - 1e-6);
        const auto after = RaptorAero::VortexLiftCorrection(angle + 1e-6);
        flight_require(std::abs(before - after) < 1e-6, "High-alpha endpoint discontinuity");
        flight_require(flight_close(RaptorAero::VortexLiftCorrection(angle),
            RaptorAero::VortexLiftCorrection(-angle)), "High-alpha correction lost signed symmetry");
    }
    flight_require(RaptorAero::VortexLiftCorrection(std::numeric_limits<double>::quiet_NaN()) == 0,
        "Nonfinite alpha escaped numerical regularization");
}
RaptorVehicle::Environment thermal_run(double dt, double fuel, bool cooling_failed) {
    RaptorVehicle::Environment result;
    RaptorVehicle::EnvironmentInputs input;
    input.atmosphere_valid = input.kinematics_valid = input.canopy_valid = true;
    input.powered = input.left_bleed = true;
    input.cooling_failed = cooling_failed;
    input.internal_fuel_kg = fuel;
    input.tas_mps = 150;
    const auto count = static_cast<unsigned>(std::round(600 / dt));
    for (unsigned step = 0; step < count; ++step) result.update(input, dt);
    return result;
}
void thermal_and_hydraulic_sensitivity() {
    const auto reference = thermal_run(.005, 5000, false);
    for (double dt : {.01, .02, .1}) {
        const auto result = thermal_run(dt, 5000, false);
        flight_require(std::abs(result.equipment_c - reference.equipment_c) < .01 * std::abs(reference.equipment_c),
            "Thermal timestep refinement failed declared one-percent tolerance");
    }
    flight_require(thermal_run(.02, 5000, true).equipment_c > reference.equipment_c,
        "Cooling failure did not change the actual thermal owner");
    flight_require(std::isfinite(thermal_run(.02, 0, false).coolant_c), "Empty fuel sink poisoned thermal state");
    RaptorVehicle::Hydraulics hydraulics;
    hydraulics.reset(true);
    for (unsigned step = 0; step < 100; ++step)
        hydraulics.update(.7, .7, 1, 1, true, false, 0, 0, .02);
    flight_require(hydraulics.left() == 0 && hydraulics.right() > 0 && hydraulics.shared() > 0,
        "One hydraulic circuit removed independent redundant control supply");
    const double inventory = hydraulics.left_inventory;
    hydraulics.update(.7, .7, 1, 1, true, false, 0, 0, -1);
    flight_require(hydraulics.left_inventory == inventory, "Negative dt created hydraulic inventory");
}
}
int main() {
    try {
        air_and_saturation(); high_alpha_continuity(); thermal_and_hydraulic_sensitivity();
        std::cout << "Air-data, saturation, continuity and thermal/hydraulic sensitivity passed; aircraft calibration not assessed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
