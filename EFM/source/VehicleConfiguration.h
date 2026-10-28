#pragma once

#include "VehicleSystems.h"
#include "VehiclePower.h"
#include "LandingGear.h"

namespace RaptorVehicle {
enum class FlightConfiguration { Cruise = 0, PowerApproach = 1, Refuel = 2 };
enum class GearRejection { None = 0, WeightOnWheels, Overspeed, NoSupply, AlternateLatched, InvalidAirData };

struct Configuration {
    LandingGear gear;
    FlightConfiguration mode = FlightConfiguration::Cruise;
    GearRejection gear_rejection = GearRejection::None;
    double hook_position = 0.0;
    double refuel_door = 0.0;
    bool hook_request = false;
    bool alternate_gear = false;
    bool steering_selected = true;
    bool single_engine_approach = false;
    bool refuel_request = false;
    bool refuel_disconnect = false;
    bool refuel_transfer = false;
    bool hydraulic_maintenance_transfer = false;
    double last_transfer_s = -100.0;

    bool request_gear(bool down, bool wow, double eas_knots, bool& selected) {
        gear_rejection = GearRejection::None;
        if (!down && wow) gear_rejection = GearRejection::WeightOnWheels;
        else if (!down && alternate_gear) gear_rejection = GearRejection::AlternateLatched;
        else if (down && !std::isfinite(eas_knots)) gear_rejection = GearRejection::InvalidAirData;
        else if (down && eas_knots > 275.0)
            gear_rejection = GearRejection::Overspeed;
        if (gear_rejection != GearRejection::None) return false;
        selected = down;
        return true;
    }
    bool extend_alternate(StoredEnergy& ses, bool& selected) {
        if (alternate_gear) return true;
        if (!ses.consume(0.25, 0.0)) {
            gear_rejection = GearRejection::NoSupply;
            return false;
        }
        alternate_gear = selected = true;
        gear_rejection = GearRejection::None;
        return true;
    }
    void request_hook(bool down, StoredEnergy& ses) {
        if (down == hook_request) return;
        if (ses.consume(0.05, 0.0)) hook_request = down;
    }
    void update(double dt, double gear_position, bool left_running, bool right_running,
                double authority, double stamp_s) {
        if (!within(dt, 0.0, 1.0) || dt == 0.0 ||
            !within(gear_position, 0.0, 1.0) || !within(authority, 0.0, 1.0) ||
            !within(stamp_s, 0.0, 1e9)) return;
        refuel_door = slew(refuel_door, refuel_request ? 1.0 : 0.0, 0.5 * authority, dt);
        hook_position = slew(hook_position, hook_request ? 1.0 : 0.0, 0.4, dt);
        // Declared simulation policy uses achieved door, never request alone.
        mode = refuel_door > 0.99 ? FlightConfiguration::Refuel :
            (gear_position > 0.5 ? FlightConfiguration::PowerApproach : FlightConfiguration::Cruise);
        single_engine_approach = mode == FlightConfiguration::PowerApproach &&
            (left_running != right_running);
        const double transfer_age_s = stamp_s - last_transfer_s;
        refuel_transfer = within(transfer_age_s, 0.0, 0.5) && transfer_age_s < 0.5;
    }
    double steering_authority(double speed_mps, double hydraulic) const {
        if (!steering_selected) return 0.0;
        // Continuous estimate preserves low-speed authority, fades at 100 kt.
        return unit(hydraulic) * (1.0 - unit(speed_mps / 51.4444));
    }
    double cruise_brake_mix(double achieved_brake) const {
        return mode == FlightConfiguration::Cruise ? unit(achieved_brake) : 0.0;
    }
    static void allocate(double pitch, double roll, double& left, double& right) {
        pitch = std::clamp(finite(pitch), -1.0, 1.0);
        const double residual = 1.0 - std::abs(pitch);
        roll = std::clamp(finite(roll), -residual, residual);
        left = pitch - roll;
        right = pitch + roll;
    }
};
} // namespace RaptorVehicle
