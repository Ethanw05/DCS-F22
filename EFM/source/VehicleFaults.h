#pragma once

#include "VehicleSignals.h"

namespace RaptorVehicle {
struct PlannedFault {
    const char* id;
    Signal channel;
};
inline constexpr PlannedFault planned_faults[] = {
    {"f22_battery", Signal::BatteryFault},
    {"f22_left_generator", Signal::LeftGeneratorFault},
    {"f22_right_generator", Signal::RightGeneratorFault},
    {"f22_apu", Signal::ApuFault},
    {"f22_left_hydraulics", Signal::LeftHydraulicFault},
    {"f22_right_hydraulics", Signal::RightHydraulicFault},
    {"f22_left_feed", Signal::LeftFeedFault},
    {"f22_right_feed", Signal::RightFeedFault},
    {"f22_fuel_transfer", Signal::TransferFault},
    {"f22_air_data", Signal::AirDataHealth},
    {"f22_ecs", Signal::EcsFault},
    {"f22_cooling", Signal::CoolingFault},
    {"f22_oxygen", Signal::OxygenFault},
    {"f22_left_hyd_pump_1", Signal::LeftPumpOneFault},
    {"f22_left_hyd_pump_2", Signal::LeftPumpTwoFault},
    {"f22_right_hyd_pump_1", Signal::RightPumpOneFault},
    {"f22_right_hyd_pump_2", Signal::RightPumpTwoFault},
    {"f22_left_engine_fire", Signal::LeftFireFault},
    {"f22_right_engine_fire", Signal::RightFireFault}
};

inline bool fault_name_equal(const char* candidate, const char* expected) {
    if (!candidate || !expected) return false;
    for (std::size_t index = 0; index < 32; ++index) {
        if (candidate[index] != expected[index]) return false;
        if (expected[index] == '\0') return true;
    }
    return false;
}
} // namespace RaptorVehicle
