#pragma once

#include "EngineStart.h"

namespace RaptorVehicle {
struct EngineController {
    EnginePhase phase = EnginePhase::Off;
    StartRejection rejection = StartRejection::None;
    EngineControl control = EngineControl::Normal;
    EngineStartState start_state;
    double spool = 0.0;
    double phase_time_s = 0.0;
    double augmentation = 0.0;
    double extra_start_heat_c = 0.0;
    bool requested = false;
    bool burning = false;
    bool augmentation_available = false;
    bool control_available = false;
    bool reset_ready = false;

    void reset(bool hot, double initial_spool = 0.67) {
        *this = {};
        if (hot) {
            phase = EnginePhase::Running;
            spool = initial_spool;
            requested = burning = true;
            control_available = augmentation_available = true;
            start_state.fuel_selected = start_state.ignition_selected = true;
            start_state.fuel_valve = true;
        }
    }
    bool windmill_relight(const EngineInputs& input) const {
        return !input.ground && spool >= 0.15 && input.tas_mps >= 90.0;
    }
    StartRejection mechanical_guard(const EngineInputs& input) const {
        if (!valid_engine_inputs(input)) return StartRejection::InvalidInput;
        if (input.health <= 0.3) return StartRejection::Damaged;
        if (input.isolated) return StartRejection::Isolated;
        if (!input.powered) return StartRejection::NoPower;
        return StartRejection::None;
    }
    StartRejection combustion_guard(const EngineInputs& input) const {
        if (input.control == EngineControl::Unavailable) return StartRejection::NoControl;
        if (!input.powered && !burning) return StartRejection::NoPower;
        if (start_state.fault != EngineFault::None) return StartRejection::FaultLatched;
        if (!input.feed) return StartRejection::NoFuel;
        if (start_state.purge_remaining_s > 0.0) return StartRejection::PurgeRequired;
        if (input.temperature_c >= EngineStartProfile::restart_below_c) return StartRejection::TooHot;
        return StartRejection::None;
    }
    bool starter_available(const EngineInputs& input) const {
        return input.powered && input.starter && !input.starter_failed &&
            input.health > 0.3 && !input.isolated;
    }
    StartRejection start_guard(const EngineInputs& input) const {
        const auto mechanical = mechanical_guard(input);
        if (mechanical != StartRejection::None) return mechanical;
        const auto combustion = combustion_guard(input);
        if (combustion != StartRejection::None) return combustion;
        if (!starter_available(input) && spool < EngineStartProfile::self_sustaining_core &&
            !windmill_relight(input)) return StartRejection::NoStarter;
        return StartRejection::None;
    }
    bool active_start_attempt() const {
        return starting() && (start_state.fuel_valve || (requested && start_state.automatic));
    }
    bool start(const EngineInputs& input) {
        if (phase == EnginePhase::Running && burning) return true;
        rejection = start_guard(input);
        if (rejection != StartRejection::None) return false;
        if (active_start_attempt()) return true;
        requested = true;
        start_state.select_automatic();
        if (!starting()) phase = spool >= EngineStartProfile::fuel_admit_core ?
            EnginePhase::Lighting : EnginePhase::Cranking;
        phase_time_s = 0.0;
        return true;
    }
    void stop() {
        requested = false;
        start_state.request_cutoff();
        start_state.starter_selected = false;
    }
    void select_starter(bool selected) {
        start_state.automatic = false;
        start_state.starter_selected = selected;
    }
    void select_fuel(bool selected) {
        start_state.automatic = false;
        start_state.fuel_selected = requested = selected;
    }
    void select_ignition(bool selected) {
        start_state.automatic = false;
        start_state.ignition_selected = selected;
    }
    bool reset_sources_healthy(const EngineInputs& input) const {
        return mechanical_guard(input) == StartRejection::None && !input.starter_failed &&
            !input.ignition_failed && !input.hung_start && !input.hot_start &&
            input.control != EngineControl::Unavailable;
    }
    bool reset_configuration_safe(const EngineInputs& input) const {
        return !burning && !start_state.fuel_selected && !start_state.starter_selected &&
            start_state.purge_remaining_s <= 0.0 &&
            start_state.starter_duty_s < EngineStartProfile::starter_duty_s &&
            input.temperature_c < EngineStartProfile::restart_below_c;
    }
    bool reset_fault(const EngineInputs& input) {
        if (!reset_sources_healthy(input) || !reset_configuration_safe(input)) {
            rejection = StartRejection::ResetUnsafe;
            return false;
        }
        start_state.fault = EngineFault::None;
        reset_ready = false;
        start_state.unlit_s = start_state.combustion_start_s = 0.0;
        rejection = StartRejection::None;
        return true;
    }
    void trip(EngineFault fault, bool purge) {
        start_state.latch(fault, purge);
        requested = burning = false;
        reset_ready = false;
        augmentation = 0.0;
        phase = EnginePhase::ShuttingDown;
    }
    void abort_run(StartRejection reason) {
        rejection = reason;
        if (start_state.automatic) start_state.starter_selected = false;
        start_state.cutoff();
        requested = burning = false;
        augmentation = 0.0;
        phase = EnginePhase::ShuttingDown;
    }
    void lose_feed() { abort_run(StartRejection::NoFuel); }
    void qualify_starter(const EngineInputs& input) {
        start_state.starter_engaged = start_state.starter_selected && starter_available(input) &&
            spool < EngineStartProfile::self_sustaining_core;
        if (start_state.starter_selected && !start_state.starter_engaged &&
            spool < EngineStartProfile::self_sustaining_core) {
            rejection = mechanical_guard(input);
            if (rejection == StartRejection::None) rejection = StartRejection::NoStarter;
        }
    }
    void qualify_control(const EngineInputs& input) {
        control = input.control;
        // Estimated running-engine self supply preserves separation from the
        // aircraft bus. No production F119 electrical topology is claimed.
        control_available = control != EngineControl::Unavailable && (input.powered || burning);
        augmentation_available = control_available && control == EngineControl::Normal && !input.augmentation_failed;
    }
    void guard_automatic_start(const EngineInputs& input) {
        if (!start_state.automatic || !starting()) return;
        const auto reason = mechanical_guard(input);
        if (reason != StartRejection::None) abort_run(reason);
        else if (!start_assistance(input)) abort_run(StartRejection::NoStarter);
    }
    void enforce_sources(const EngineInputs& input) {
        qualify_control(input);
        if (input.control == EngineControl::Unavailable) trip(EngineFault::ControlLoss, false);
        if (input.health <= 0.3 || input.isolated) stop();
        if ((start_state.fuel_valve || start_state.automatic) && !input.feed) lose_feed();
        qualify_starter(input);
        guard_automatic_start(input);
    }
    void advance_running(const EngineInputs& input, double dt) {
        double target = 0.67 + unit(input.throttle) * 0.43;
        if (control == EngineControl::Degraded)
            target = std::min(target, EngineStartProfile::degraded_max_core);
        spool = slew(spool, target, target > spool ?
            input.spool_up_per_s : input.spool_down_per_s, dt);
        const double ramp_s = installed_thrust(1.65, 1.1, input.tas_mps);
        const bool augment = augmentation_available && spool >= 1.035 && target > 1.035;
        augmentation = slew(augmentation, augment ? 1.0 : 0.0, 1.0 / ramp_s, dt);
        if (!augmentation_available) augmentation = 0.0;
    }
    void advance_unpowered(const EngineInputs& input, double dt) {
        const double windmill = input.ground ? 0.0 : 0.3 * unit(input.tas_mps / 250.0);
        const double target = start_state.starter_engaged ? EngineStartProfile::fuel_admit_core : windmill;
        const double up = start_state.starter_engaged ? 0.2 / 11.0 : 0.03;
        spool = slew(spool, target, spool > target ? 0.041 : up, dt);
        phase = start_state.starter_engaged ? EnginePhase::Cranking :
            (spool <= 0.0 ? EnginePhase::Off : EnginePhase::Windmilling);
        augmentation = 0.0;
    }
    bool starting() const {
        return phase == EnginePhase::Cranking || phase == EnginePhase::Lighting ||
            phase == EnginePhase::Accelerating;
    }
    bool rotor_can_light(const EngineInputs& input) const {
        return spool >= EngineStartProfile::fuel_admit_core || windmill_relight(input);
    }
    bool start_assistance(const EngineInputs& input) const {
        return start_state.starter_engaged || windmill_relight(input) ||
            spool >= EngineStartProfile::self_sustaining_core;
    }
    void qualify_valve(const EngineInputs& input) {
        if (!start_state.fuel_selected || start_state.fault != EngineFault::None) {
            start_state.fuel_valve = false;
            return;
        }
        if (start_state.fuel_valve) return; // live source loss was handled above
        rejection = combustion_guard(input);
        if (rejection == StartRejection::None && !rotor_can_light(input))
            rejection = StartRejection::WaitForRotor;
        start_state.fuel_valve = rejection == StartRejection::None && start_assistance(input);
        if (start_state.fuel_valve) start_state.unlit_s = start_state.combustion_start_s = 0.0;
    }
    void advance_lighting(const EngineInputs& input, double dt) {
        if (!burning) return;
        phase_time_s += dt;
        const double target = input.hung_start ? EngineStartProfile::hung_light_core : 0.4;
        spool = slew(spool, target, 0.2 / 18.0, dt);
        if (spool >= 0.4) {
            phase = EnginePhase::Accelerating;
            phase_time_s = 0.0;
        }
    }
    void advance_acceleration(const EngineInputs& input, double dt) {
        const double target = input.hung_start ? EngineStartProfile::hung_acceleration_core : 0.67;
        spool = slew(spool, target, 0.27 / 15.0, dt);
        if (spool >= 0.67) {
            phase = EnginePhase::Running;
            phase_time_s = 0.0;
            if (start_state.automatic) start_state.starter_selected = false;
            start_state.starter_engaged = false;
            start_state.automatic = false;
        }
    }
    void advance_start(const EngineInputs& input, double dt) {
        if (!start_assistance(input)) { abort_run(StartRejection::NoStarter); return; }
        if (phase == EnginePhase::Accelerating) advance_acceleration(input, dt);
        else advance_lighting(input, dt);
    }
    bool entering_light_phase(bool was_burning) const {
        return phase == EnginePhase::Cranking ||
            (!starting() && (phase != EnginePhase::Running || !was_burning));
    }
    void qualify_combustion(const EngineInputs& input) {
        const bool was_burning = burning;
        const bool ignition = start_state.ignition_selected && !input.ignition_failed && input.powered;
        burning = start_state.fuel_valve && (was_burning || ignition);
        if (start_state.fuel_valve && entering_light_phase(was_burning)) {
            phase = spool >= 0.4 && burning ? EnginePhase::Accelerating : EnginePhase::Lighting;
            phase_time_s = 0.0;
        }
    }
    EngineFault diagnosed_start_fault(const EngineInputs& input, bool admitted) const {
        if (start_state.unlit_s >= EngineStartProfile::no_light_s) return EngineFault::NoLight;
        if (!admitted) return EngineFault::None;
        if (input.temperature_c >= EngineStartProfile::hot_start_c) return EngineFault::HotStart;
        if (start_state.combustion_start_s >= EngineStartProfile::hung_start_s) return EngineFault::HungStart;
        return EngineFault::None;
    }
    void monitor_start(const EngineInputs& input, double dt) {
        const bool admitted = start_state.fuel_valve && phase != EnginePhase::Running;
        start_state.unlit_s = admitted && !burning ? start_state.unlit_s + dt : 0.0;
        if (admitted && burning) start_state.combustion_start_s += dt;
        const auto fault = diagnosed_start_fault(input, admitted);
        if (fault != EngineFault::None) trip(fault, true);
        extra_start_heat_c = admitted && burning && input.hot_start ? EngineStartProfile::hot_start_extra_c : 0.0;
    }
    void update(const EngineInputs& input, double dt) {
        if (!within(dt, 0.0, 1.0) || dt == 0.0) return;
        if (!valid_engine_inputs(input)) {
            trip(EngineFault::InvalidInput, false);
            control_available = augmentation_available = false;
            return;
        }
        enforce_sources(input);
        start_state.advance_starter(dt);
        qualify_valve(input);
        qualify_combustion(input);
        if (phase == EnginePhase::Running && burning) advance_running(input, dt);
        else if (start_state.fuel_valve) advance_start(input, dt);
        else advance_unpowered(input, dt);
        start_state.advance_purge(spool, dt);
        monitor_start(input, dt);
        qualify_control(input);
        reset_ready = start_state.fault != EngineFault::None &&
            reset_sources_healthy(input) && reset_configuration_safe(input);
    }
    void delivered_fuel(double kg) {
        if (!burning && start_state.fuel_valve) start_state.record_unlit_delivery(kg);
    }
    double vector_authority() const {
        if (!control_available) return 0.0;
        return control == EngineControl::Degraded ? 0.5 : 1.0;
    }
    double augmentation_fraction() const {
        const double fraction = unit((spool - 1.03) / 0.07);
        return burning && augmentation_available ? fraction * fraction * augmentation : 0.0;
    }
    double fuel_flow_kg_s(double density_ratio, double mach) const {
        if (!start_state.fuel_valve) return 0.0;
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
