#pragma once

#include "VehicleSystems.h"

namespace RaptorVehicle {
enum class EnginePhase { Off = 0, Cranking, Lighting, Accelerating,
                         Running, ShuttingDown, Windmilling };
enum class StartRejection { None = 0, NoFuel, NoPower, NoStarter, Damaged, Isolated };

struct EngineInputs {
    double throttle = 0.0;
    double tas_mps = 0.0;
    double health = 1.0;
    double spool_up_per_s = 0.1;
    double spool_down_per_s = 0.1;
    bool ground = true;
    bool powered = false;
    bool starter = false;
    bool feed = false;
    bool isolated = false;
};

struct EngineController {
    EnginePhase phase = EnginePhase::Off;
    StartRejection rejection = StartRejection::None;
    double spool = 0.0;
    double phase_time_s = 0.0;
    double augmentation = 0.0;
    bool requested = false;
    bool burning = false;

    void reset(bool hot, double initial_spool = 0.67) {
        *this = {};
        if (hot) {
            phase = EnginePhase::Running;
            spool = initial_spool;
            requested = burning = true;
        }
    }
    StartRejection start_guard(const EngineInputs& input) const {
        if (input.health <= 0.3) return StartRejection::Damaged;
        if (input.isolated) return StartRejection::Isolated;
        if (!input.powered) return StartRejection::NoPower;
        if (!input.feed) return StartRejection::NoFuel;
        if (!input.starter && (input.ground || spool < 0.15 || input.tas_mps < 90.0))
            return StartRejection::NoStarter;
        return StartRejection::None;
    }
    bool start(const EngineInputs& input) {
        rejection = start_guard(input);
        if (rejection != StartRejection::None) return false;
        requested = true;
        if (phase == EnginePhase::Running || phase == EnginePhase::Cranking ||
            phase == EnginePhase::Lighting || phase == EnginePhase::Accelerating) return true;
        // A windmilling relight skips the unneeded stationary-rotor crank.
        phase = spool >= 0.2 ? EnginePhase::Lighting : EnginePhase::Cranking;
        phase_time_s = 0.0;
        return true;
    }
    void advance_start(const EngineInputs& input, double dt) {
        if (start_guard(input) != StartRejection::None) {
            rejection = start_guard(input);
            requested = false;
            phase = EnginePhase::ShuttingDown;
            return;
        }
        phase_time_s += dt;
        if (phase == EnginePhase::Cranking) {
            spool = slew(spool, 0.2, 0.2 / 11.0, dt);
            if (spool >= 0.2) { phase = EnginePhase::Lighting; phase_time_s = 0.0; }
        } else if (phase == EnginePhase::Lighting) {
            spool = slew(spool, 0.4, 0.2 / 18.0, dt);
            if (spool >= 0.4) { phase = EnginePhase::Accelerating; phase_time_s = 0.0; }
        } else {
            spool = slew(spool, 0.67, 0.27 / 15.0, dt);
            if (spool >= 0.67) { phase = EnginePhase::Running; phase_time_s = 0.0; }
        }
    }
    void update(const EngineInputs& input, double dt) {
        if (!input.feed || input.health <= 0.3 || input.isolated) requested = false;
        if (!requested && phase != EnginePhase::Off && phase != EnginePhase::Windmilling)
            phase = EnginePhase::ShuttingDown;
        if (phase == EnginePhase::Running) {
            const double target = 0.67 + unit(input.throttle) * 0.43;
            spool = slew(spool, target, target > spool ?
                         input.spool_up_per_s : input.spool_down_per_s, dt);
            const double ramp_s = installed_thrust(1.65, 1.1, input.tas_mps);
            augmentation = slew(augmentation,
                spool >= 1.035 && target > 1.035 ? 1.0 : 0.0, 1.0 / ramp_s, dt);
        } else if (phase == EnginePhase::Cranking || phase == EnginePhase::Lighting ||
                   phase == EnginePhase::Accelerating) {
            advance_start(input, dt);
            augmentation = 0.0;
        } else {
            const double windmill = input.ground ? 0.0 : 0.3 * unit(input.tas_mps / 250.0);
            spool = slew(spool, windmill, spool > windmill ? 0.041 : 0.03, dt);
            phase = spool <= 0.0 ? EnginePhase::Off :
                (std::abs(spool - windmill) < 0.001 ? EnginePhase::Windmilling : phase);
            augmentation = 0.0;
        }
        burning = requested && input.feed && !input.isolated &&
            (phase == EnginePhase::Lighting || phase == EnginePhase::Accelerating ||
             phase == EnginePhase::Running);
    }
    double augmentation_fraction() const {
        const double fraction = unit((spool - 1.03) / 0.07);
        return burning ? fraction * fraction * augmentation : 0.0;
    }
    double fuel_flow_kg_s(double density_ratio, double mach) const {
        if (!burning) return 0.0;
        const double main = spool < 0.67 ? 0.126 * unit(spool / 0.67) :
            0.126 + (1.5 - 0.126) * unit((spool - 0.67) / 0.355);
        return (main + 5.0 * augmentation_fraction()) *
            std::max(0.0, finite(density_ratio)) * (1.0 + 0.5 * std::max(0.0, finite(mach)));
    }
    double thrust_n(double idle_n, double dry_n, double augmented_n) const {
        if (!burning) return 0.0;
        if (spool < 0.67) return idle_n * unit(spool / 0.67);
        const double fraction = unit((spool - 0.67) / 0.355);
        return idle_n + (dry_n - idle_n) * fraction * fraction +
            std::max(0.0, augmented_n - dry_n) * augmentation_fraction();
    }
};
} // namespace RaptorVehicle
