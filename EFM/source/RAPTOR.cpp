#include "CommandRouting.h"
#include "NativeGunSight.h"
/*    Grinnelli Designs F-22A Raptor
    Copyright (C) 2025, Branden Hooper

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see https://www.gnu.org/licenses.
*/

// RAPTOR.cpp : External flight model for Grinnelli Designs F-22A 
#include <math.h>
#include <cmath>
#include <stdio.h>
#include <string>
#include <algorithm>
#include <iostream>
#include <stack>
#include <queue>
#include <vector>

#define EXPORT_ED_FM_PHYSICS_IMP extern "C" __declspec(dllexport)
#include <FM/wHumanCustomPhysicsAPI_ImplementationDeclare.h>
#include <Cockpit/CockpitAPI_Declare.h>

#include "Utility.h"
#include "HighAlpha.h"
#include "Autopilot.h"
#include "NativeNavigation.h"
#include "NativeSidewinder.h"
#include "NativeAesaRadar.h"
#include "NativeMWS.h"
#include "NativeGroundRadar.h"
#include "NativeGroundVideo.h"
#include "NativeAGWeapons.h"
#include "NativeAltimetry.h"
#include "NativeDatalink.h"
#include "Inputs.h"
#include "VehicleSystems.h"
#include "TrimControl.h"
#include "RAPTOR.h"
#include "VehicleContext.h"
#include "ThrustDeck.h"
#include "VehicleSignals.h"
#include "VehicleFaults.h"

#define EXPORT __declspec(dllexport)

static CockpitManager cockpit_manager;
static RaptorAP::Controller autopilot;
static RaptorAP::Output ap_output;
static RaptorVehicle::Engine left_engine_instruments, right_engine_instruments;
static RaptorVehicle::Hydraulics hydraulics;
static double actuator_available = 0;
static RaptorVehicle::VehicleContext vehicle;
static RaptorVehicle::VehicleBus vehicle_bus;
void add_local_force(const Vec3& force, const Vec3& position);
#include "VehicleIntegration.h"
// Read-only diagnostics: never used as flight-control inputs.
struct TrimTelemetry {
    double events[8]{}; // left, right, up, down, reset, rudder L/R, stop
    double last_command=0, last_value=0, last_stamp=0;
    double inhibit=0, stick=0, damping=0, raw=0, q=0;
};
static TrimTelemetry trim_telemetry;
static RaptorTrim::Controller trim_control;
static RaptorAP::Frame ap_frame() {
    RaptorAP::Frame f;
    f.pitch=RAPTOR::pitch;f.roll=RAPTOR::roll;f.heading=-RAPTOR::heading;
    f.alt=RAPTOR::altitude_ASL;f.agl=RAPTOR::altitude_AGL;f.vs=RAPTOR::velocity_world.y;
    f.tas=RAPTOR::V_scalar;f.ias=vehicle.air_sensor.measured.cas_mps;
    f.mach=vehicle.air_sensor.measured.mach;f.aoa=RAPTOR::aoa;f.gs=std::hypot(RAPTOR::velocity_world.x,RAPTOR::velocity_world.z);
    f.track=std::atan2(RAPTOR::velocity_world.z,RAPTOR::velocity_world.x);
    f.pilot_pitch=RAPTOR::pitch_analog?RAPTOR::pitch_input:RAPTOR::pitch_discrete;
    f.pilot_roll=RAPTOR::roll_analog?RAPTOR::roll_input:RAPTOR::roll_discrete;
    f.left_throttle=RAPTOR::left_throttle_input;f.right_throttle=RAPTOR::right_throttle_input;
    f.time=RAPTOR::fm_clock;f.ground=RAPTOR::on_ground;f.gear=RAPTOR::gear_switch||RAPTOR::gear_pos>.05;
    f.powered=RAPTOR::left_engine_state==RAPTOR::RUNNING||RAPTOR::right_engine_state==RAPTOR::RUNNING;
    f.healthy=!RAPTOR::is_destroyed&&RAPTOR::tail_integrity>.5&&RAPTOR::left_wing_integrity>.5&&RAPTOR::right_wing_integrity>.5;
    f.healthy = f.healthy && vehicle.air_sensor.measured.valid &&
        vehicle.air_sensor.health == RaptorAirData::Health::Healthy;
    cockpit_manager.navigationFrame(f);
    return f;
}

void add_local_force(const Vec3& Force, const Vec3& Force_pos) {
    RAPTOR::common_force.x += Force.x;
    RAPTOR::common_force.y += Force.y;
    RAPTOR::common_force.z += Force.z;
    Vec3 delta_pos(Force_pos.x - RAPTOR::center_of_mass.x, Force_pos.y - RAPTOR::center_of_mass.y, Force_pos.z - RAPTOR::center_of_mass.z);
    Vec3 delta_moment = cross(delta_pos, Force);
    RAPTOR::common_moment.x += delta_moment.x;
    RAPTOR::common_moment.y += delta_moment.y;
    RAPTOR::common_moment.z += delta_moment.z;
}

void add_local_moment(const Vec3& Moment) {
    RAPTOR::common_moment.x += Moment.x;
    RAPTOR::common_moment.y += Moment.y;
    RAPTOR::common_moment.z += Moment.z;
}

void ed_fm_add_local_force(double& x, double& y, double& z, double& pos_x, double& pos_y, double& pos_z) {
    x = RAPTOR::common_force.x;
    y = RAPTOR::common_force.y;
    z = RAPTOR::common_force.z;
    pos_x = RAPTOR::center_of_mass.x;
    pos_y = RAPTOR::center_of_mass.y;
    pos_z = RAPTOR::center_of_mass.z;
}

void ed_fm_add_local_moment(double& x, double& y, double& z) {
    x = RAPTOR::common_moment.x;
    y = RAPTOR::common_moment.y;
    z = RAPTOR::common_moment.z;
}

void simulate_fuel_consumption(double dt) {
    const double density_ratio = RAPTOR::atmosphere_density / 1.225;
    const double left_request = vehicle.left_engine.fuel_flow_kg_s(density_ratio, RAPTOR::mach) * dt;
    const double right_request = vehicle.right_engine.fuel_flow_kg_s(density_ratio, RAPTOR::mach) * dt;
    // Estimated APU service plus pneumatic starter load; no production fuel deck.
    const double starter_load = static_cast<double>(vehicle.left_engine.start_state.starter_engaged) +
        static_cast<double>(vehicle.right_engine.start_state.starter_engaged);
    const double apu_request = vehicle.power.apu_running || vehicle.power.apu_starting ?
        (0.04 + 0.015 * starter_load) * dt : 0.0;
    const double left_delivered = vehicle.fuel.burn(1, left_request, RAPTOR::infinite_fuel, vehicle.mass);
    const double right_delivered = vehicle.fuel.burn(2, right_request, RAPTOR::infinite_fuel, vehicle.mass);
    const double apu_delivered = vehicle.fuel.burn(0, apu_request, RAPTOR::infinite_fuel, vehicle.mass);
    vehicle.left_engine.delivered_fuel(left_delivered);
    vehicle.right_engine.delivered_fuel(right_delivered);
    vehicle.apu_flow_kg_s = apu_delivered / dt;
    if (apu_delivered < apu_request - 1e-12) {
        vehicle.power.apu_inhibit = true;
        vehicle_sample_power(0.0);
    }
    RAPTOR::left_fuel_rate = RAPTOR::left_fuel_rate_kg_s = left_delivered / dt;
    RAPTOR::right_fuel_rate = RAPTOR::right_fuel_rate_kg_s = right_delivered / dt;
    vehicle_qualify_fuel_delivery(true, left_request, left_delivered);
    vehicle_qualify_fuel_delivery(false, right_request, right_delivered);
    RAPTOR::fuel_consumption_since_last_time = RAPTOR::infinite_fuel ? 0.0 :
        left_delivered + right_delivered + apu_delivered;
    RAPTOR::internal_fuel = vehicle.fuel.internal_kg();
    RAPTOR::total_fuel = RAPTOR::internal_fuel + RAPTOR::external_fuel;
}

void reset_fm_state() {
    RAPTOR::fm_clock = 0.0;
    RAPTOR::sim_initialised = false;
    vehicle.fuel.set_internal(RAPTOR::internal_fuel);
    trim_telemetry = {};
    trim_control = {};
    RAPTOR::suspension_compression.fill(0.0);
    autopilot.reset(); ap_output={};
    RAPTOR::suspension_feedback_available = false;
    vehicle.mass.clear();
    vehicle.damage.clear();
    for (auto& [station, stamp] : RAPTOR::external_fuel_callback_stamp) stamp = 0.0;
    // Host fuel callbacks may precede spawn callbacks; release owns removal.
    RAPTOR::total_fuel = RAPTOR::internal_fuel + RAPTOR::external_fuel;
    RAPTOR::left_fuel_rate = RAPTOR::right_fuel_rate = 0.0;
    RAPTOR::left_fuel_rate_kg_s = RAPTOR::right_fuel_rate_kg_s = 0.0;
    RAPTOR::pitch_input = RAPTOR::roll_input = RAPTOR::yaw_input = 0.0;
    RAPTOR::pitch_discrete = RAPTOR::roll_discrete = RAPTOR::yaw_discrete = 0.0;
    RAPTOR::pitch_analog = RAPTOR::roll_analog = RAPTOR::yaw_analog = true;
    RAPTOR::left_elevon_command = RAPTOR::right_elevon_command = 0.0;
    RAPTOR::left_elevon_angle = RAPTOR::right_elevon_angle = 0.0;
    RAPTOR::last_elevator_cmd = RAPTOR::last_aileron_cmd = RAPTOR::last_rudder_cmd = 0.0;
    RAPTOR::tv_angle = RAPTOR::left_tv_angle = RAPTOR::right_tv_angle = 0.0;
    RAPTOR::left_aileron_angle = RAPTOR::right_aileron_angle = RAPTOR::rudder_angle = 0.0;
    RAPTOR::left_rudder_angle = RAPTOR::right_rudder_angle = 0.0;
    RAPTOR::wheel_brake = RAPTOR::left_brake_request = RAPTOR::right_brake_request = 0.0;
    RAPTOR::left_brake_achieved = RAPTOR::right_brake_achieved = 0.0;
    RAPTOR::flap_override = -1;
    RAPTOR::body_air_velocity = Vec3();
    RAPTOR::body_ground_velocity = Vec3();
    RAPTOR::airbrake_pos = RAPTOR::flaps_pos = RAPTOR::slats_pos = 0;
    RAPTOR::takeoff_trim_cmd = 0;
    hydraulics.reset(false);
    actuator_available = 0;
    left_engine_instruments.reset(0, RAPTOR::atmosphere_temperature);
    right_engine_instruments.reset(0, RAPTOR::atmosphere_temperature);
    RAPTOR::pitch_trim = RAPTOR::roll_trim = RAPTOR::yaw_trim = 0.0;
    RAPTOR::beta_integral = 0.0;
    RAPTOR::aileron_animation_command = 0.0;

    RAPTOR::left_engine_state = RAPTOR::OFF;
    RAPTOR::right_engine_state = RAPTOR::OFF;
    RAPTOR::left_engine_switch = RAPTOR::right_engine_switch = false;
    RAPTOR::left_throttle_input = RAPTOR::right_throttle_input = 0.0;
    RAPTOR::left_throttle_output = RAPTOR::right_throttle_output = RAPTOR::idle_rpm;
    RAPTOR::left_engine_power_readout = RAPTOR::right_engine_power_readout = 0.0;
    RAPTOR::left_thrust_force = RAPTOR::right_thrust_force = 0.0;
    RAPTOR::left_ab_timer = RAPTOR::right_ab_timer = 0.0;
    RAPTOR::left_engine_phase = 0.0;
    RAPTOR::right_engine_phase = 0.0;

    RAPTOR::ref_roll = RAPTOR::ref_heading = 0.0;
    RAPTOR::roll_error_i = RAPTOR::yaw_error_i = 0.0;

    RAPTOR::velocity_world = Vec3(0, 0, 0);
    RAPTOR::airspeed = Vec3(0, 0, 0);
    RAPTOR::pitch_rate = RAPTOR::roll_rate = RAPTOR::yaw_rate = 0.0;
    RAPTOR::aoa = RAPTOR::aos = RAPTOR::alpha = RAPTOR::beta = 0.0;
    RAPTOR::pitch = RAPTOR::roll = RAPTOR::heading = 0.0;
    RAPTOR::g = 0.0;
    RAPTOR::V_scalar = 0.0;
    RAPTOR::mach = 0.0;

    RAPTOR::left_wing_integrity = RAPTOR::right_wing_integrity = RAPTOR::tail_integrity = RAPTOR::left_elevon_integrity = RAPTOR::right_elevon_integrity = 1.0;
    RAPTOR::left_engine_integrity = RAPTOR::right_engine_integrity = 1.0;
    RAPTOR::fuel_consumption_since_last_time = 0.0;

    RAPTOR::fm_clock = 0.0;
    RAPTOR::sim_initialised = false;
    RAPTOR::shake_amplitude = 0.0;
    RAPTOR::on_ground = false;

    RAPTOR::last_yaw_input = 0.0;
    RAPTOR::last_tv_cmd = 0.0;
    RAPTOR::last_pitch_input = 0.0;
    RAPTOR::smoothed_pitch_discrete = 0.0;
    RAPTOR::smoothed_roll_discrete = 0.0;

    RAPTOR::autotrim_elevator_cmd = 0.0;
    RAPTOR::is_destroyed = false;
    RAPTOR::destruction_events_pushed = false;
}

static void simulate_vehicle_step(double dt) {
    if (!std::isfinite(dt) || dt <= 0.0) return;
    RAPTOR::fm_clock += dt;
    vehicle.time_s = RAPTOR::fm_clock;
    vehicle_sample_air();
    RAPTOR::common_force = Vec3();
    RAPTOR::common_moment = Vec3();

    const double input_slew_rate = 1.33;
    RAPTOR::smoothed_pitch_discrete = slew_rate_limit(RAPTOR::smoothed_pitch_discrete, RAPTOR::pitch_discrete, input_slew_rate, dt);
    RAPTOR::smoothed_roll_discrete = slew_rate_limit(RAPTOR::smoothed_roll_discrete, RAPTOR::roll_discrete, input_slew_rate, dt);
    RAPTOR::smoothed_yaw_discrete = slew_rate_limit(RAPTOR::smoothed_yaw_discrete, RAPTOR::yaw_discrete, input_slew_rate, dt);

    if (RAPTOR::is_destroyed) {
        if (!RAPTOR::destruction_events_pushed) {
            static_cast<void>(vehicle.damage.add(static_cast<int>(DamageElement::WingOutLeft), RAPTOR::element_integrity[static_cast<size_t>(DamageElement::WingOutLeft)]));
            static_cast<void>(vehicle.damage.add(static_cast<int>(DamageElement::WingOutRight), RAPTOR::element_integrity[static_cast<size_t>(DamageElement::WingOutRight)]));
            static_cast<void>(vehicle.damage.add(static_cast<int>(DamageElement::Tail), RAPTOR::element_integrity[static_cast<size_t>(DamageElement::Tail)]));
            static_cast<void>(vehicle.damage.add(static_cast<int>(DamageElement::Engine1), RAPTOR::element_integrity[static_cast<size_t>(DamageElement::Engine1)]));
            static_cast<void>(vehicle.damage.add(static_cast<int>(DamageElement::Engine2), RAPTOR::element_integrity[static_cast<size_t>(DamageElement::Engine2)]));
            static_cast<void>(vehicle.damage.add(static_cast<int>(DamageElement::WingInLeft), RAPTOR::element_integrity[static_cast<size_t>(DamageElement::WingInLeft)]));
            static_cast<void>(vehicle.damage.add(static_cast<int>(DamageElement::WingInRight), RAPTOR::element_integrity[static_cast<size_t>(DamageElement::WingInRight)]));
            RAPTOR::destruction_events_pushed = true;
        }
        RAPTOR::common_force = Vec3(0.0, 0.0, 0.0);
        RAPTOR::common_moment = Vec3(0.0, 0.0, 0.0);
        RAPTOR::left_engine_power_readout = 0.0;
        RAPTOR::right_engine_power_readout = 0.0;
        RAPTOR::left_engine_integrity = 0.0;
        RAPTOR::right_engine_integrity = 0.0;
        RAPTOR::left_thrust_force = 0.0;
        RAPTOR::right_thrust_force = 0.0;
        RAPTOR::left_throttle_input = 0.0;
        RAPTOR::right_throttle_input = 0.0;
        RAPTOR::left_engine_state = RAPTOR::SHUTDOWN;
        RAPTOR::right_engine_state = RAPTOR::SHUTDOWN;
        RAPTOR::left_engine_switch = false;
        RAPTOR::right_engine_switch = false;
        RAPTOR::pitch_input = RAPTOR::roll_input = RAPTOR::yaw_input = 0.0;
        RAPTOR::left_elevon_command = RAPTOR::right_elevon_command = 0.0;
        RAPTOR::aileron_command = RAPTOR::rudder_command = 0.0;
        RAPTOR::left_ab_timer = 0.0;
        RAPTOR::right_ab_timer = 0.0;
        RAPTOR::V_scalar = 0.0;
        RAPTOR::pitch_rate = RAPTOR::roll_rate = RAPTOR::yaw_rate = 0.0;
    }

    // The EFM owns bus availability, pressure and achieved effectors.
    // A healthy engine must not bypass a failed bus.
    vehicle_sample_power(dt);
    vehicle_sample_hydraulic_sources();
    const bool control_power = vehicle.power.essential;
    const double brake_demand = std::max({RAPTOR::wheel_brake, RAPTOR::left_brake_request, RAPTOR::right_brake_request});
    hydraulics.update(left_engine_instruments.core, right_engine_instruments.core,
        RAPTOR::left_engine_integrity, RAPTOR::right_engine_integrity,
        vehicle_fault(VehicleSignal::LeftHydraulicFault),
        vehicle_fault(VehicleSignal::RightHydraulicFault),
        brake_demand, std::hypot(RAPTOR::velocity_world.x, RAPTOR::velocity_world.z), dt);
    actuator_available = control_power && !RAPTOR::is_destroyed ? hydraulics.shared() : 0;
    vehicle_transfer_fuel(dt);
    RAPTOR::left_brake_achieved = std::max(RAPTOR::wheel_brake, RAPTOR::left_brake_request) *
        hydraulics.brakes() * vehicle.left_brake.effectiveness();
    RAPTOR::right_brake_achieved = std::max(RAPTOR::wheel_brake, RAPTOR::right_brake_request) *
        hydraulics.brakes() * vehicle.right_brake.effectiveness();
    trim_control.update(dt,control_power && !RAPTOR::is_destroyed);
    RAPTOR::pitch_trim=trim_control.pitch;
    RAPTOR::roll_trim=trim_control.roll;
    RAPTOR::yaw_trim=trim_control.yaw;
    RAPTOR::manual_trim_applied=trim_control.pitch_busy();


    RAPTOR::gear_pos = limit(actuator_timed(RAPTOR::gear_pos, RAPTOR::gear_switch, -0.25, 0.25,
        dt * (vehicle.configuration.alternate_gear ? 1.0 : vehicle_utility_supply())), 0, 1);
    // Primary contact signal is DCS suspension feedback, not gear/height alone.
    // The 2-m fallback is only for versions where feedback is not supplied.
    bool wheels_loaded = false;
    for (double compression : RAPTOR::suspension_compression)
        wheels_loaded = wheels_loaded || compression > 0.001;
    RAPTOR::on_ground = RAPTOR::gear_pos > 0.5 &&
        (RAPTOR::suspension_feedback_available ? wheels_loaded :
         (RAPTOR::altitude_AGL < 2.0 && RAPTOR::mach < 0.3));
    RAPTOR::ground_speed_knots =
        std::hypot(RAPTOR::velocity_world.x, RAPTOR::velocity_world.z) * 1.943844492;
    RAPTOR::airbrake_pos = limit(actuator_timed(RAPTOR::airbrake_pos, RAPTOR::airbrake_switch, -0.6666666667, 0.6666666667, dt * actuator_available), 0, 1);
    double slat_target = vehicle.air_data_reversion ? RAPTOR::slats_pos :
        ((RAPTOR::mach < 0.8) ? (RAPTOR::alpha - 10.0) / 10.0 : 0.0);
    RAPTOR::slats_pos = limit(actuator_timed(RAPTOR::slats_pos, slat_target, -0.5, 0.5, dt * actuator_available), 0, 1);

    RAPTOR::airspeed.x = RAPTOR::velocity_world.x - RAPTOR::wind.x;
    RAPTOR::airspeed.y = RAPTOR::velocity_world.y - RAPTOR::wind.y;
    RAPTOR::airspeed.z = RAPTOR::velocity_world.z - RAPTOR::wind.z;
    RAPTOR::V_scalar = sqrt(RAPTOR::airspeed.x * RAPTOR::airspeed.x + RAPTOR::airspeed.y * RAPTOR::airspeed.y + RAPTOR::airspeed.z * RAPTOR::airspeed.z);
    RAPTOR::mach = RAPTOR::V_scalar / RAPTOR::speed_of_sound;

    vehicle_update_configuration(dt);
    double aoa = RAPTOR::alpha;
    double x_offset;

    double x_offset_normal;
    if (aoa <= 3.5) {
        x_offset_normal = -0.8;
    }
    else if (aoa >= 20.0) {
        x_offset_normal = -0.5;
    }
    else {
        double t = (aoa - 3.5) / (20.0 - 3.5);
        x_offset_normal = -0.8 + t * (-0.5 - (-0.8));
    }

    x_offset = x_offset_normal;

    vehicle_capture_wing_reference();
    const double wing_x = vehicle.wing_reference_x_m + x_offset;
    const double wing_y = vehicle.wing_reference_y_m + 0.5;
    RAPTOR::left_wing_pos = Vec3(wing_x, wing_y, -RAPTOR::wingspan / 2);
    RAPTOR::right_wing_pos = Vec3(wing_x, wing_y, RAPTOR::wingspan / 2);

    double ias_ms = vehicle.air_truth.valid ? vehicle.air_truth.eas_mps : 0.0;
    double ias_knots = ias_ms * 1.94384;

    const double automatic_flap_target = vehicle.air_data_reversion ? RAPTOR::flaps_pos :
        (RAPTOR::on_ground ? (RAPTOR::ground_speed_knots >= 45.0 ? 1 : 0) :
         (RAPTOR::gear_pos > .5 && ias_knots < 250.0 ? 1 : 0));
    const double requested_flap = RAPTOR::flap_override < 0 ? automatic_flap_target : RAPTOR::flap_override;
    const double flap_target = std::max(requested_flap,
        0.3 * vehicle.configuration.cruise_brake_mix(RAPTOR::airbrake_pos));
    RAPTOR::flaps_pos = limit(actuator_timed(RAPTOR::flaps_pos, flap_target,
        -1.0, .8333333333, dt * actuator_available), 0, 1);

    if (RAPTOR::g >= 6) {
        RAPTOR::g_assist_pos = limit(actuator_timed(RAPTOR::g_assist_pos, 1.0, -1.3333333333, 1.1666666667, dt), 0.0, 1.0);
    }
    else {
        RAPTOR::g_assist_pos = limit(actuator_timed(RAPTOR::g_assist_pos, 0.0, -1.1666666667, 1.0, dt), 0.0, 1.0);
    }

    double CyAlpha_ = lerp(FM_DATA::mach_table.data(), FM_DATA::Cya, FM_DATA::mach_table.size(), RAPTOR::mach);
    double CyMax_ = lerp(FM_DATA::mach_table.data(), FM_DATA::CyMax, FM_DATA::mach_table.size(), RAPTOR::mach);

    // Smooth the original high-alpha vortex *proxy* at both endpoints.
    // The existing peak/width are retained until measured coefficient data exist.
    CyMax_ += RaptorAero::VortexLiftCorrection(RAPTOR::alpha);

    CyMax_ += (FM_DATA::cy_flap * RAPTOR::slats_pos);
    double Cy = CyAlpha_ * RAPTOR::alpha;
    if (Cy > CyMax_) Cy = CyMax_;
    if (Cy < -CyMax_) Cy = -CyMax_;

    if (fabs(RAPTOR::alpha) >= 90.0) {
        double aoa_excess = fabs(RAPTOR::alpha) - 90.0;
        double lift_reduction = 1.0 - (aoa_excess / 60.0) * 0.9;
        lift_reduction = limit(lift_reduction, 0.1, 1.0);
        Cy *= lift_reduction;
    }

    double CyBeta_ = lerp(FM_DATA::beta_table, FM_DATA::Cy_beta, sizeof(FM_DATA::beta_table) / sizeof(double), fabs(RAPTOR::beta));
    if (RAPTOR::alpha > 30.0) CyBeta_ *= 1.5;
    double Cy_tail = (0.5 * CyAlpha_ + FM_DATA::Czbe) * RAPTOR::beta + (RAPTOR::beta < 0 ? -CyBeta_ : CyBeta_);

    double Cx0_ = lerp(FM_DATA::mach_table.data(), FM_DATA::cx0, FM_DATA::mach_table.size(), RAPTOR::mach);
    double wave_drag_factor = 1.0 + 0.85 * std::max(0.0, (RAPTOR::mach - 0.9) / 0.3) * (1.0 - std::min(1.0, (RAPTOR::mach - 1.2) / 1.0)) * std::max(0.0, 1.0 - RAPTOR::altitude_ASL / 9144.0);
    double Drag = Cx0_ * wave_drag_factor + (FM_DATA::cx_brk * 1.2 * vehicle.achieved_speedbrake) + (FM_DATA::cx_flap * RAPTOR::flaps_pos) + (FM_DATA::cx_gear * RAPTOR::gear_pos);

    double AoA_drag = lerp(FM_DATA::AoA_table, FM_DATA::AoA_drag_factor, sizeof(FM_DATA::AoA_table) / sizeof(double), fabs(RAPTOR::alpha));
    Drag += AoA_drag;

    double gear_drag_penalty = 0.0;
    if (RAPTOR::gear_pos > 0.0) {
        double ias_ms = ias_knots * 0.514444;
        double base_gear_drag_coeff = 0.005;
        double speed_factor = (ias_ms / 100.0) * (ias_ms / 100.0);
        gear_drag_penalty = base_gear_drag_coeff * speed_factor * RAPTOR::gear_pos;
        Drag += gear_drag_penalty;
    }

    double q = 0.5 * RAPTOR::atmosphere_density * RAPTOR::V_scalar * RAPTOR::V_scalar;
    double Lift = Cy + FM_DATA::Cy0 + (FM_DATA::cy_flap * RAPTOR::flaps_pos);
    double aos_effect = (fabs(RAPTOR::aos) < 0.05) ? 0 : sin(RAPTOR::aos / 2);

    // Drag opposes the actual body-axis relative wind continuously, including
    // backward flight. Do not flip a scalar sign at an arbitrary AoA boundary.
    const double body_speed = std::sqrt(RAPTOR::body_air_velocity.x * RAPTOR::body_air_velocity.x +
        RAPTOR::body_air_velocity.y * RAPTOR::body_air_velocity.y + RAPTOR::body_air_velocity.z * RAPTOR::body_air_velocity.z);
    const double drag_scale = body_speed > .01 ? -std::max(0.0, Drag) * q * RAPTOR::S / (2 * body_speed) : 0;
    const Vec3 drag_half(RAPTOR::body_air_velocity.x * drag_scale,
        RAPTOR::body_air_velocity.y * drag_scale, RAPTOR::body_air_velocity.z * drag_scale);
    Vec3 left_wing_forces(drag_half.x * RAPTOR::left_wing_integrity,
        (drag_half.y + Lift * (-aos_effect / 2 + 1) * q * (RAPTOR::S / 2)) * RAPTOR::left_wing_integrity,
        (drag_half.z + Cy_tail * q * (RAPTOR::S / 2)) * RAPTOR::left_wing_integrity);
    Vec3 right_wing_forces(drag_half.x * RAPTOR::right_wing_integrity,
        (drag_half.y + Lift * (aos_effect / 2 + 1) * q * (RAPTOR::S / 2)) * RAPTOR::right_wing_integrity,
        (drag_half.z - Cy_tail * q * (RAPTOR::S / 2)) * RAPTOR::right_wing_integrity);

    add_local_force(left_wing_forces, RAPTOR::left_wing_pos);
    add_local_force(right_wing_forces, RAPTOR::right_wing_pos);

    Vec3 tail_force(-Cy_tail * sin(RAPTOR::aoa) * (RAPTOR::S / 2) * q * RAPTOR::tail_integrity,
        0, -Cy_tail * cos(RAPTOR::aoa) * q * (RAPTOR::S / 2) * RAPTOR::tail_integrity);
    add_local_force(tail_force, RAPTOR::tail_pos);

    ap_output=autopilot.update(ap_frame(),dt);
    const double fbw_scale = 1.0;
    const double max_rate = 40.0;
    double beta_gain = (vehicle.control_air.mach > 0.9) ? std::clamp(0.1 * (vehicle.control_air.mach - 0.9) / 0.3, 0.0, 0.1) : 0.0;
    double pitch_cmd_source = RAPTOR::pitch_analog ? RAPTOR::pitch_input : RAPTOR::smoothed_pitch_discrete;
    double roll_cmd_source = RAPTOR::roll_analog ? RAPTOR::roll_input : RAPTOR::smoothed_roll_discrete;
    double yaw_cmd_source = RAPTOR::yaw_analog ? RAPTOR::yaw_input : RAPTOR::smoothed_yaw_discrete;

    double aileron_scale = 1.0;
    if (vehicle.control_air.mach > 0.75) {
        if (vehicle.control_air.mach < 1.25) {
            aileron_scale = 1.0 - ((vehicle.control_air.mach - 0.75) / (1.25 - 0.75)) * (1.0 - 0.3);
        }
        else {
            aileron_scale = 0.3;
        }
    }
    RAPTOR::aileron_animation_command = limit(roll_cmd_source * fabs(roll_cmd_source) * aileron_scale, -1.0, 1.0);

    if (RAPTOR::fm_clock < 0.1) {
        RAPTOR::left_elevon_command = RAPTOR::right_elevon_command = 0.0;
        RAPTOR::aileron_command = RAPTOR::rudder_command = 0.0;
    }
    else {
        double Kd_pitch = lerp(FM_DATA::mach_table.data(), FM_DATA::Kd_pitch, FM_DATA::mach_table.size(), vehicle.control_air.mach);
        double Kd_roll = lerp(FM_DATA::mach_table.data(), FM_DATA::Kd_roll, FM_DATA::mach_table.size(), vehicle.control_air.mach);
        double Kd_yaw = lerp(FM_DATA::mach_table.data(), FM_DATA::Kd_yaw, FM_DATA::mach_table.size(), vehicle.control_air.mach);

        double pitch_sensitivity = 1.0;
        double tv_sensitivity = 1.2;
        double max_deflection_rate = 2.27;

        if (vehicle.control_air.mach >= 0.67) {
            double mach_diff = vehicle.control_air.mach - 0.67;
            pitch_sensitivity = 1.0 - 0.229 * mach_diff * mach_diff;
            pitch_sensitivity = limit(pitch_sensitivity, 0.3, 1.0);
        }

        if (vehicle.control_air.mach >= 0.67) {
            double mach_diff = vehicle.control_air.mach - 0.67;
            if (vehicle.control_air.mach >= 1.2) {
                tv_sensitivity = 0.0;
            }
            else {
                double range = 1.2 - 0.67;
                tv_sensitivity = 1.0 - (1.0 / (range * range)) * mach_diff * mach_diff;
                tv_sensitivity = limit(tv_sensitivity, 0.0, 1.0);
            }
        }

        double elevator_rate = lerp(FM_DATA::mach_table.data(), FM_DATA::elevator_rate_table, FM_DATA::mach_table.size(), vehicle.control_air.mach);
        double tv_rate = std::min(
            lerp(FM_DATA::mach_table.data(), FM_DATA::thrust_vector_rate, FM_DATA::mach_table.size(), vehicle.control_air.mach),
            RAPTOR::rad(40.0)); // YF-22-era no-load hardware bound, not a production control schedule

        double max_elevator_deflection = lerp(FM_DATA::mach_table.data(), FM_DATA::max_elevator_deflection, FM_DATA::mach_table.size(), vehicle.control_air.mach);
        double max_tv_deflection = lerp(FM_DATA::mach_table.data(), FM_DATA::max_thrust_vector_deflection, FM_DATA::mach_table.size(), vehicle.control_air.mach);
        if (RAPTOR::on_ground == true) {
            max_tv_deflection = 0;
        }

        const double takeoff_trim_value = 0.25;
        const double takeoff_trim_rate = 0.05;

        double ias_ms = vehicle.control_air.eas_mps;
        double ias_knots = ias_ms * 1.94384;

        double pitch_cmd_source = RAPTOR::pitch_analog ? RAPTOR::pitch_input : RAPTOR::smoothed_pitch_discrete;
        bool takeoff_trim_enabled = RAPTOR::on_ground &&
            ias_knots < 170.0 &&
            RAPTOR::pitch_trim == 0.0 &&
            fabs(pitch_cmd_source) < 0.05;

        double target_takeoff_trim = takeoff_trim_enabled ? takeoff_trim_value : 0.0;

        double trim_error = target_takeoff_trim - RAPTOR::takeoff_trim_cmd;
        RAPTOR::takeoff_trim_cmd += limit(trim_error, -takeoff_trim_rate * dt, takeoff_trim_rate * dt);

        const double autotrim_gain = 0.06;
        const double autotrim_max_cmd = 0.28;
        const double autotrim_rate_limit = 0.06;
        const double autotrim_fade_rate = 0.1;
        const double ref_q = 0.5 * 1.225 * 200.0 * 200.0;
        const double input_deadzone = 0.025;

        bool autotrim_disabled = vehicle.air_data_reversion || (autopilot.vertical != RaptorAP::Off && !autopilot.override_held) || RAPTOR::on_ground ||
            fabs(RAPTOR::roll) > 1.2217 ||
            RAPTOR::manual_trim_applied ||
            RAPTOR::alpha >= 9.0 ||
            ias_knots < 160.0;

        trim_telemetry.inhibit =
            ((autopilot.vertical != RaptorAP::Off && !autopilot.override_held) ? 1 : 0) |
            (RAPTOR::on_ground ? 2 : 0) |
            (fabs(RAPTOR::roll)>1.2217 ? 4 : 0) |
            (RAPTOR::manual_trim_applied ? 8 : 0) |
            (RAPTOR::alpha>=9.0 ? 16 : 0) |
            (ias_knots<160.0 ? 32 : 0);
        if (!autotrim_disabled) {
            RAPTOR::autotrim_active = true;
            double pitch_rate_deg_s = RAPTOR::pitch_rate * RAPTOR::rad_to_deg;
            double q = 0.5 * RAPTOR::atmosphere_density * RAPTOR::V_scalar * RAPTOR::V_scalar;
            double q_scale = (q > 100.0) ? ref_q / q : 1.0;
            double pitch_cmd_source = RAPTOR::pitch_analog ? RAPTOR::pitch_input : RAPTOR::smoothed_pitch_discrete;

            double pitch_rate_error = 0.0;
            if (pitch_cmd_source < -input_deadzone) {
                if (pitch_rate_deg_s >= 0.0) {
                    pitch_rate_error = 0.0 - pitch_rate_deg_s;
                }
            }
            else if (pitch_cmd_source > input_deadzone) {
                if (pitch_rate_deg_s <= 0.0) {
                    pitch_rate_error = 0.0 - pitch_rate_deg_s;
                }
            }
            else {
                pitch_rate_error = 0.0 - pitch_rate_deg_s;
            }

            double delta_cmd = pitch_rate_error * autotrim_gain * q_scale;
            delta_cmd = limit(delta_cmd, -autotrim_rate_limit * dt, autotrim_rate_limit * dt);
            RAPTOR::autotrim_elevator_cmd = limit(RAPTOR::autotrim_elevator_cmd + delta_cmd, -autotrim_max_cmd, autotrim_max_cmd);
        }
        else {
            RAPTOR::autotrim_active = false;
            // Keep the established equilibrium correction while the pilot slews
            // trim and during the brief release handoff. Never move it to manual
            // trim or erase it merely because a trim command was received.
            if (RAPTOR::manual_trim_applied || vehicle.air_data_reversion) {
                // Frozen; ordinary automatic stabilization resumes after release.
            }
            else if (RAPTOR::autotrim_elevator_cmd > 0) {
                RAPTOR::autotrim_elevator_cmd = std::max(RAPTOR::autotrim_elevator_cmd - autotrim_fade_rate * dt, 0.0);
            }
            else if (RAPTOR::autotrim_elevator_cmd < 0) {
                RAPTOR::autotrim_elevator_cmd = std::min(RAPTOR::autotrim_elevator_cmd + autotrim_fade_rate * dt, 0.0);
            }
        }

        if (fabs(roll_cmd_source) < 0.05) {
            Kd_roll = 0.75;
        }

        double elevator_cmd = (pitch_cmd_source * fabs(pitch_cmd_source) * 1.1) * pitch_sensitivity;
        elevator_cmd += -RAPTOR::pitch_rate * Kd_pitch;
        elevator_cmd += RAPTOR::pitch_trim;
        elevator_cmd += RAPTOR::autotrim_elevator_cmd;
        elevator_cmd += RAPTOR::takeoff_trim_cmd;
        elevator_cmd += ap_output.elevator;
        trim_telemetry.stick=(pitch_cmd_source * fabs(pitch_cmd_source) * 1.1) * pitch_sensitivity;
        trim_telemetry.damping=-RAPTOR::pitch_rate * Kd_pitch;
        trim_telemetry.raw=elevator_cmd;
        trim_telemetry.q=0.5*RAPTOR::atmosphere_density*RAPTOR::V_scalar*RAPTOR::V_scalar;
        elevator_cmd = limit(elevator_cmd, -1.0, 1.0);

        const double g_reduction_factor = 0.1;

        if (RAPTOR::g > RAPTOR::g_limit_positive && elevator_cmd > 0.0) {
            double g_excess = RAPTOR::g - RAPTOR::g_limit_positive;
            elevator_cmd -= g_excess * g_reduction_factor;
            elevator_cmd = std::max(elevator_cmd, 0.0);
        }
        else if (RAPTOR::g < RAPTOR::g_limit_negative && elevator_cmd < 0.0) {
            double g_excess = RAPTOR::g_limit_negative - RAPTOR::g;
            elevator_cmd += g_excess * g_reduction_factor;
            elevator_cmd = std::min(elevator_cmd, 0.0);
        }

        elevator_cmd = limit(RAPTOR::last_elevator_cmd + limit(elevator_cmd - RAPTOR::last_elevator_cmd, -max_rate * dt, max_rate * dt), -1.0, 1.0);
        RAPTOR::last_elevator_cmd = elevator_cmd;

        double roll_cmd = roll_cmd_source * fabs(roll_cmd_source);
        double roll_damping = -RAPTOR::roll_rate * Kd_roll;
        roll_cmd += roll_damping + RAPTOR::roll_trim + ap_output.aileron;
        RAPTOR::aileron_command = limit(RAPTOR::last_aileron_cmd + limit(roll_cmd - RAPTOR::last_aileron_cmd, -FM_DATA::max_aileron_rate * dt, FM_DATA::max_aileron_rate * dt), -1.0, 1.0);
        RAPTOR::last_aileron_cmd = RAPTOR::aileron_command;

        RaptorVehicle::Configuration::allocate(elevator_cmd, RAPTOR::aileron_command,
            RAPTOR::left_elevon_command, RAPTOR::right_elevon_command);
        RAPTOR::last_elevator_cmd = elevator_cmd;

        double target_left_elevon_angle = -RAPTOR::left_elevon_command * RAPTOR::rad(max_elevator_deflection);
        double target_right_elevon_angle = -RAPTOR::right_elevon_command * RAPTOR::rad(max_elevator_deflection);
        double elevon_step = elevator_rate * dt * actuator_available;

        if (RAPTOR::left_elevon_angle < target_left_elevon_angle) {
            RAPTOR::left_elevon_angle = std::min<double>(RAPTOR::left_elevon_angle + elevon_step, target_left_elevon_angle);
        }
        else if (RAPTOR::left_elevon_angle > target_left_elevon_angle) {
            RAPTOR::left_elevon_angle = std::max<double>(RAPTOR::left_elevon_angle - elevon_step, target_left_elevon_angle);
        }

        if (RAPTOR::right_elevon_angle < target_right_elevon_angle) {
            RAPTOR::right_elevon_angle = std::min<double>(RAPTOR::right_elevon_angle + elevon_step, target_right_elevon_angle);
        }
        else if (RAPTOR::right_elevon_angle > target_right_elevon_angle) {
            RAPTOR::right_elevon_angle = std::max<double>(RAPTOR::right_elevon_angle - elevon_step, target_right_elevon_angle);
        }

        double tv_pitch_cmd = (pitch_cmd_source * fabs(pitch_cmd_source) * 1.1) * tv_sensitivity;

        if (RAPTOR::alpha > 70.0) tv_pitch_cmd -= (RAPTOR::alpha - 70.0) * 0.0285;
        if (RAPTOR::alpha < -40.0) tv_pitch_cmd += (-RAPTOR::alpha - 40.0) * 0.033;

        if (RAPTOR::gear_pos == 1.0) {
            if (RAPTOR::alpha > 15.0) tv_pitch_cmd -= (RAPTOR::alpha - 15.0) * 0.1;
            if (RAPTOR::alpha < -15.0) tv_pitch_cmd += (-RAPTOR::alpha - 12.0) * 0.1;
        }

        tv_pitch_cmd += -RAPTOR::pitch_rate;

        double tv_command = limit(RAPTOR::last_tv_cmd + limit(tv_pitch_cmd - RAPTOR::last_tv_cmd, -max_rate * dt, max_rate * dt), -1.0, 1.0);
        RAPTOR::last_tv_cmd = tv_command;

        const double nozzle_envelope = RAPTOR::rad(max_tv_deflection);
        const double left_nozzle_supply = control_power && !RAPTOR::is_destroyed ?
            hydraulics.left() * vehicle.left_engine.vector_authority() : 0.0;
        const double right_nozzle_supply = control_power && !RAPTOR::is_destroyed ?
            hydraulics.right() * vehicle.right_engine.vector_authority() : 0.0;
        RAPTOR::left_tv_angle = RaptorVehicle::nozzle(RAPTOR::left_tv_angle,
            -tv_command, nozzle_envelope, tv_rate, left_nozzle_supply, dt);
        RAPTOR::right_tv_angle = RaptorVehicle::nozzle(RAPTOR::right_tv_angle,
            -tv_command, nozzle_envelope, tv_rate, right_nozzle_supply, dt);
        RAPTOR::tv_angle = (RAPTOR::left_tv_angle + RAPTOR::right_tv_angle) * .5;

        double yaw_cmd;
        const double beta_integral_gain = 0.06;
        const double beta_integral_limit = 0.01;
        const double beta_integral_decay = 0.07;

        double adverse_yaw_cmd = 0.0;
        if (fabs(yaw_cmd_source) < 0.01) {
            double adverse_yaw_gain = 0.3 * (1.0 - std::min(vehicle.control_air.mach, 1.0));
            adverse_yaw_cmd = RAPTOR::aileron_command * adverse_yaw_gain * (q / (q + 10000.0));
            adverse_yaw_cmd = limit(adverse_yaw_cmd, -0.3, 0.3);
        }
        if (fabs(yaw_cmd_source) < 0.01) {
            yaw_cmd = -RAPTOR::yaw_rate * Kd_yaw - std::clamp(RAPTOR::beta, -3.0, 3.0) * std::clamp(RAPTOR::last_yaw_input, 0.0, 0.3);
            yaw_cmd -= beta_gain * RAPTOR::beta;
            yaw_cmd += adverse_yaw_cmd;

            if (fabs(RAPTOR::beta) < 3.0 && !RAPTOR::on_ground && fabs(RAPTOR::rudder_command) < 0.9) {
                RAPTOR::beta_integral += RAPTOR::beta * beta_integral_gain * dt;
                RAPTOR::beta_integral = limit(RAPTOR::beta_integral, -beta_integral_limit, beta_integral_limit);
            }
            else {
                RAPTOR::beta_integral *= std::exp(-beta_integral_decay * dt);
            }
            yaw_cmd -= RAPTOR::beta_integral;

            if (RAPTOR::alpha > 10.0) {
                double pitch_yaw_coupling = -RAPTOR::pitch_rate * 0.11 * (RAPTOR::alpha / lerp(FM_DATA::mach_table.data(), FM_DATA::Aldop, FM_DATA::mach_table.size(), vehicle.control_air.mach));
                yaw_cmd += limit(pitch_yaw_coupling, -0.5, 0.5);
            }
            RAPTOR::last_yaw_input -= dt / 0.5;
            if (RAPTOR::last_yaw_input < 0.0) RAPTOR::last_yaw_input = 0.0;
        }
        else {
            yaw_cmd = 0.5 * yaw_cmd_source * sqrt(fabs(yaw_cmd_source)) - RAPTOR::yaw_rate * Kd_yaw;
            yaw_cmd -= beta_gain * RAPTOR::beta * 0.5;
            yaw_cmd += adverse_yaw_cmd * 0.5;
            RAPTOR::beta_integral *= std::exp(-beta_integral_decay * dt);
            RAPTOR::last_yaw_input = 0.5 * fabs(yaw_cmd_source);
        }

        yaw_cmd += RAPTOR::yaw_trim;
        RAPTOR::rudder_command = limit(RAPTOR::last_rudder_cmd + limit(yaw_cmd - RAPTOR::last_rudder_cmd, -max_rate * dt, max_rate * dt), -1.0, 1.0);
        RAPTOR::last_rudder_cmd = RAPTOR::rudder_command;

        double elevon_force_magnitude = q * RAPTOR::S * 0.20;
        
        double aoa_abs = fabs(RAPTOR::alpha);
        double elevon_aoa_scale = 1.0;
        if (aoa_abs > 30.0) {
            elevon_aoa_scale = 1.0 - (0.9 * (aoa_abs - 30.0) / (60.0 - 30.0));
            elevon_aoa_scale = limit(elevon_aoa_scale, 0.1, 1.0);
        }

        add_local_force(Vec3(0, RAPTOR::left_elevon_angle * elevon_force_magnitude * elevon_aoa_scale * RAPTOR::left_elevon_integrity, 0), RAPTOR::left_elevon_pos);
        add_local_force(Vec3(0, RAPTOR::right_elevon_angle * elevon_force_magnitude * elevon_aoa_scale * RAPTOR::right_elevon_integrity, 0), RAPTOR::right_elevon_pos);

        // Forces and drawing use achieved angles, never an independent
        // animation-rate integrator. Rates retain the existing mod command limit.
        const double surface_rate = FM_DATA::max_aileron_rate * RAPTOR::rad(30) * actuator_available;
        const double brake_mix = vehicle.configuration.cruise_brake_mix(RAPTOR::airbrake_pos);
        const double aileron_brake = -RAPTOR::rad(5.0) * brake_mix;
        RAPTOR::left_aileron_angle = RaptorVehicle::slew(RAPTOR::left_aileron_angle,
            limit(RAPTOR::aileron_command * RAPTOR::rad(30) + aileron_brake,
                -RAPTOR::rad(30), RAPTOR::rad(30)), surface_rate, dt);
        RAPTOR::right_aileron_angle = RaptorVehicle::slew(RAPTOR::right_aileron_angle,
            limit(-RAPTOR::aileron_command * RAPTOR::rad(30) + aileron_brake,
                -RAPTOR::rad(30), RAPTOR::rad(30)), surface_rate, dt);
        const double rudder_max = RAPTOR::rad(25 + (vehicle.control_air.mach < .5 ? 5 : 0));
        const double rudder_brake = RAPTOR::rad(15.0) * RAPTOR::airbrake_pos;
        const double rudder_rate = RAPTOR::rad(80.0) * actuator_available;
        RAPTOR::left_rudder_angle = RaptorVehicle::slew(RAPTOR::left_rudder_angle,
            limit(RAPTOR::rudder_command * rudder_max + rudder_brake, -rudder_max, rudder_max), rudder_rate, dt);
        RAPTOR::right_rudder_angle = RaptorVehicle::slew(RAPTOR::right_rudder_angle,
            limit(RAPTOR::rudder_command * rudder_max - rudder_brake, -rudder_max, rudder_max), rudder_rate, dt);
        RAPTOR::rudder_angle = 0.5 * (RAPTOR::left_rudder_angle + RAPTOR::right_rudder_angle);
        const double left_rudder_health = RAPTOR::element_integrity[53];
        const double right_rudder_health = RAPTOR::element_integrity[54];
        const double rudder_health = 0.5 * (left_rudder_health + right_rudder_health);
        vehicle.achieved_speedbrake = RaptorVehicle::unit(std::abs(
            RAPTOR::left_rudder_angle - RAPTOR::right_rudder_angle) / RAPTOR::rad(30.0)) * rudder_health;
        double aileron_deflection = RAPTOR::left_aileron_angle;
        add_local_force(Vec3(0, aileron_deflection * q * RAPTOR::S * 0.25 * RAPTOR::element_integrity[25], 0), RAPTOR::left_aileron_pos);
        add_local_force(Vec3(0, RAPTOR::right_aileron_angle * q * RAPTOR::S * 0.25 * RAPTOR::element_integrity[26], 0), RAPTOR::right_aileron_pos);
        // Preserve the healthy aggregate gain, but weight each achieved surface
        // before summing so damage cannot hide the surviving rudder's sideforce.
        double rudder_deflection = 0.5 * (RAPTOR::left_rudder_angle * left_rudder_health +
            RAPTOR::right_rudder_angle * right_rudder_health);
        if (RAPTOR::is_destroyed == true) { rudder_deflection = 0.0; }
        add_local_force(Vec3(0, 0, rudder_deflection * q * RAPTOR::S * 0.3), RAPTOR::rudder_pos);

    }

    double idle_thrust = lerp(FM_DATA::mach_table.data(), FM_DATA::idle_thrust.data(), FM_DATA::mach_table.size(), RAPTOR::mach);
    double max_dry_thrust_base = lerp(FM_DATA::mach_table.data(), FM_DATA::max_thrust.data(), FM_DATA::mach_table.size(), RAPTOR::mach);
    double max_ab_thrust_base = lerp(FM_DATA::mach_table.data(), FM_DATA::ab_thrust.data(), FM_DATA::mach_table.size(), RAPTOR::mach);

    max_dry_thrust_base = RaptorVehicle::continue_thrust(max_dry_thrust_base, RAPTOR::mach, 1.8, 230000.0);
    max_ab_thrust_base = RaptorVehicle::continue_thrust(max_ab_thrust_base, RAPTOR::mach, 2.2, 536500.0);
    const double static_max_dry_thrust = 112654.0;
    const double static_max_ab_thrust = 155688.0;

    double max_dry_thrust = RaptorVehicle::installed_thrust(static_max_dry_thrust, max_dry_thrust_base, RAPTOR::V_scalar);
    double max_ab_thrust = RaptorVehicle::installed_thrust(static_max_ab_thrust, max_ab_thrust_base, RAPTOR::V_scalar);


    const double spool_up_rate_air = 0.1285;
    const double spool_down_rate_air = 0.122;
    const double spool_up_rate_ground = 0.079;
    const double spool_down_rate_ground = 0.0813;

    double spool_up_rate = RaptorVehicle::installed_thrust(spool_up_rate_ground, spool_up_rate_air, RAPTOR::V_scalar);
    double spool_down_rate = RaptorVehicle::installed_thrust(spool_down_rate_ground, spool_down_rate_air, RAPTOR::V_scalar);

    RAPTOR::left_throttle_input = limit(RAPTOR::left_throttle_input, 0, 1);
    RAPTOR::right_throttle_input = limit(RAPTOR::right_throttle_input, 0, 1);

    double thrust_alt_factor = RAPTOR::atmosphere_density / 1.225;
    RAPTOR::max_dry_left_thrust = max_dry_thrust * thrust_alt_factor * RAPTOR::left_engine_integrity;
    RAPTOR::max_dry_right_thrust = max_dry_thrust * thrust_alt_factor * RAPTOR::right_engine_integrity;
    RAPTOR::max_available_left_thrust = max_ab_thrust * thrust_alt_factor * RAPTOR::left_engine_integrity;
    RAPTOR::max_available_right_thrust = max_ab_thrust * thrust_alt_factor * RAPTOR::right_engine_integrity;

    vehicle_advance_engine(true, idle_thrust, max_dry_thrust, max_ab_thrust,
        spool_up_rate, spool_down_rate, dt);
    vehicle_advance_engine(false, idle_thrust, max_dry_thrust, max_ab_thrust,
        spool_up_rate, spool_down_rate, dt);

    simulate_fuel_consumption(dt);
    // Apply current-frame engine thrust as a rotated net vector (magnitude conserved).
    if (!RAPTOR::is_destroyed) {
        add_local_force(Vec3(RAPTOR::left_thrust_force * cos(RAPTOR::left_tv_angle), RAPTOR::left_thrust_force * sin(RAPTOR::left_tv_angle), 0.0), RAPTOR::left_engine_pos);
        add_local_force(Vec3(RAPTOR::right_thrust_force * cos(RAPTOR::right_tv_angle), RAPTOR::right_thrust_force * sin(RAPTOR::right_tv_angle), 0.0), RAPTOR::right_engine_pos);
    }
    vehicle_sample_environment(dt);
    vehicle_update_brake_energy(dt);

    double roll_yaw_moment = -(RAPTOR::roll_rate / 2) * (q + 1e5 * 0.5);
    add_local_moment(Vec3(0, roll_yaw_moment, 0));
    double OmxMax_ = lerp(FM_DATA::mach_table.data(), FM_DATA::OmxMax, FM_DATA::mach_table.size(), RAPTOR::mach);
    double roll_rate_ratio = std::fabs(RAPTOR::roll_rate) / (OmxMax_ + 0.1);
    double clamped_ratio = std::clamp(roll_rate_ratio, 0.0001, 2.0);
    double amplified_ratio = std::pow(clamped_ratio, 6);
    double dynamic_pressure_term = 2.0 * q + 50000.0;
    double scaling_factor = amplified_ratio * dynamic_pressure_term;
    double clamped_scaling = std::clamp(scaling_factor, -1e7, 1e7);
    double roll_rate_limiter = -RAPTOR::roll_rate * clamped_scaling;

    add_local_moment(Vec3(roll_rate_limiter, 0, 0));
    double yaw_rate_limiter = -(RAPTOR::yaw_rate + RAPTOR::aos) * (q + 1e5 * 0.5);
    add_local_moment(Vec3(0, yaw_rate_limiter, 0));

    RAPTOR::shake_amplitude = 0;
    RAPTOR::shake_amplitude += limit((FM_DATA::cx_brk + 1) * RAPTOR::airbrake_pos * RAPTOR::mach, 0, 2) / 6;
    if (!RAPTOR::on_ground) {
        if (fabs(RAPTOR::alpha) > 90) RAPTOR::shake_amplitude += (fabs(RAPTOR::alpha) - 90) / 100;
        if (fabs(RAPTOR::beta) > 10) RAPTOR::shake_amplitude += (fabs(RAPTOR::beta) - 10) / 100;
        if (fabs(RAPTOR::g) > 9.5) RAPTOR::shake_amplitude += (fabs(RAPTOR::g) - 9.5) / 100;
        if (RAPTOR::mach > 2.31) RAPTOR::shake_amplitude += (RAPTOR::mach - 2.31) / 2;
    }

    if (!vehicle_force_valid() || RAPTOR::is_destroyed) {
        // Missing/invalid physical producer: explicit zero-force fallback plus
        // EFM_FORCE_VALID=0, rather than NaNs crossing the host boundary.
        RAPTOR::common_force = Vec3();
        RAPTOR::common_moment = Vec3();
    }
    RAPTOR::sim_initialised = true;
    cockpit_manager.update(dt);
}

void ed_fm_simulate(double dt) {
    if (!vehicle.alive || !std::isfinite(dt) || dt <= 0.0) return;
    // At most 50 x 20 ms per callback. Excess time is visible, never an
    // unbounded catch-up loop or an implicit seconds-long actuator jump.
    const double accepted_dt = std::min(dt, 1.0);
    vehicle.discarded_time_s += dt - accepted_dt;
    const unsigned count = static_cast<unsigned>(std::ceil(accepted_dt / 0.02));
    const double step = accepted_dt / static_cast<double>(count);
    for (unsigned index = 0; index < count; ++index) simulate_vehicle_step(step);
}

void ed_fm_set_atmosphere(double h, double t, double a, double ro, double p, double wind_vx, double wind_vy, double wind_vz) {
    RAPTOR::wind = Vec3(RaptorVehicle::finite(wind_vx), RaptorVehicle::finite(wind_vy),
        RaptorVehicle::finite(wind_vz));
    vehicle.atmosphere_valid = RaptorVehicle::within(p, 1.0, 2000000.0) &&
        RaptorVehicle::within(ro, 0.000001, 100.0) && RaptorVehicle::within(a, 100.0, 1000.0) &&
        RaptorVehicle::within(t, 100.0, 1000.0) && RaptorVehicle::within(h, -10000.0, 100000.0) &&
        RaptorVehicle::bounded_three(wind_vx, wind_vy, wind_vz, 5000.0);
    if (!vehicle.atmosphere_valid) {
        RAPTOR::atmosphere_density = 0.0;
        RAPTOR::speed_of_sound = 340.293988;
        RAPTOR::hud_static_pressure_pa = 101325.0;
        RAPTOR::atmosphere_temperature = 288.15;
        return;
    }
    RAPTOR::hud_static_pressure_pa = RaptorVehicle::finite(p, 101325.0);
    RAPTOR::atmosphere_density = std::max(0.0, RaptorVehicle::finite(ro));
    RAPTOR::speed_of_sound = std::max(100.0, RaptorVehicle::finite(a, 340.293988));
    RAPTOR::altitude_ASL = RaptorVehicle::finite(h);
    RAPTOR::engine_alt_effect = RAPTOR::atmosphere_density / 1.225;
    RAPTOR::atmosphere_temperature = RaptorVehicle::finite(t, 288.15);
}

void ed_fm_suspension_feedback(int idx, const ed_fm_suspension_info* info) {
    if (info == nullptr || idx < 0 || idx >= 3) return;
    if (!std::isfinite(info->struct_compression)) return;
    if (idx == 1 || idx == 2) {
        auto& brake = idx == 1 ? vehicle.left_brake : vehicle.right_brake;
        brake.wheel_sample_valid = std::isfinite(info->wheel_speed_X);
        brake.wheel_speed_raw = RaptorVehicle::finite(info->wheel_speed_X);
        const bool contact_valid = RaptorVehicle::bounded_three(info->acting_force[0],
            info->acting_force[1], info->acting_force[2], 2000000.0) &&
            RaptorVehicle::bounded_three(info->acting_force_point[0],
                info->acting_force_point[1], info->acting_force_point[2], 20.0);
        brake.contact_stamp_s = contact_valid ? vehicle.time_s : -1.0;
        // Reaction magnitude bounds the heat envelope; no undocumented wheel
        // speed conversion or assumption about the force vector's frame.
        brake.normal_force_n = contact_valid && info->struct_compression > 0.001 ?
            std::hypot(info->acting_force[0], info->acting_force[1], info->acting_force[2]) : 0.0;
        if (contact_valid) std::copy_n(info->acting_force_point, 3, brake.contact_m.begin());
    }
    RAPTOR::suspension_feedback_available = true;
    RAPTOR::suspension_compression[static_cast<size_t>(idx)] =
        std::max(0.0, info->struct_compression);
}

void ed_fm_set_surface(double h, double h_obj, unsigned surface_type, double normal_x, double normal_y, double normal_z) {
    RAPTOR::altitude_AGL = RAPTOR::altitude_ASL - (h + h_obj * 0.5);
}

void ed_fm_set_current_mass_state(double mass, double center_of_mass_x, double center_of_mass_y, double center_of_mass_z, double moment_of_inertia_x, double moment_of_inertia_y, double moment_of_inertia_z)
{
    vehicle.mass_valid = RaptorVehicle::within(mass, 1.0, 10000000.0) &&
        RaptorVehicle::bounded_three(center_of_mass_x, center_of_mass_y, center_of_mass_z, 100.0) &&
        RaptorVehicle::within(moment_of_inertia_x, 0.0, 1e14) &&
        RaptorVehicle::within(moment_of_inertia_y, 0.0, 1e14) &&
        RaptorVehicle::within(moment_of_inertia_z, 0.0, 1e14);
    if (!vehicle.mass_valid) return;
    RAPTOR::current_mass = mass;
    RAPTOR::current_inertia = Vec3(moment_of_inertia_x, moment_of_inertia_y, moment_of_inertia_z);
    RAPTOR::center_of_mass.x = center_of_mass_x;
    RAPTOR::center_of_mass.y = center_of_mass_y;
    RAPTOR::center_of_mass.z = center_of_mass_z;

}

void ed_fm_set_current_state(double ax, double ay, double az, double vx, double vy, double vz, double px, double py, double pz,
    double omegadotx, double omegadoty, double omegadotz, double omegax, double omegay, double omegaz,
    double quaternion_x, double quaternion_y, double quaternion_z, double quaternion_w) {
    vehicle.world_motion_valid = RaptorVehicle::bounded_three(vx, vy, vz, 5000.0) &&
        RaptorVehicle::bounded_three(px, py, pz, 10000000.0) &&
        RaptorVehicle::bounded_three(quaternion_x, quaternion_y, quaternion_z, 1.1) &&
        RaptorVehicle::within(quaternion_w, -1.1, 1.1);
    if (!vehicle.world_motion_valid) {
        RAPTOR::velocity_world = Vec3();
        return;
    }
    RAPTOR::velocity_world = Vec3(RaptorVehicle::finite(vx), RaptorVehicle::finite(vy),
        RaptorVehicle::finite(vz));
    NativeGroundVideo::set_aircraft(px,py,pz,vx,vy,vz,quaternion_x,quaternion_y,quaternion_z,quaternion_w);
}

void ed_fm_set_current_state_body_axis(double ax, double ay, double az, double vx, double vy, double vz, double wind_vx, double wind_vy, double wind_vz,
    double omegadotx, double omegadoty, double omegadotz, double omegax, double omegay, double omegaz,
    double yaw, double pitch, double roll, double common_angle_of_attack, double common_angle_of_slide) {
    vehicle.motion_valid = RaptorVehicle::bounded_three(vx, vy, vz, 5000.0) &&
        RaptorVehicle::bounded_three(wind_vx, wind_vy, wind_vz, 5000.0) &&
        RaptorVehicle::bounded_three(omegax, omegay, omegaz, 100.0) &&
        RaptorVehicle::bounded_three(yaw, pitch, roll, 4.0 * RaptorVehicle::pi) &&
        RaptorVehicle::within(common_angle_of_attack, -4.0 * RaptorVehicle::pi, 4.0 * RaptorVehicle::pi) &&
        RaptorVehicle::within(common_angle_of_slide, -4.0 * RaptorVehicle::pi, 4.0 * RaptorVehicle::pi) &&
        RaptorVehicle::within(ay, -10000.0, 10000.0);
    if (!vehicle.motion_valid) {
        RAPTOR::body_air_velocity = Vec3();
        RAPTOR::aoa = RAPTOR::alpha = RAPTOR::aos = RAPTOR::beta = 0.0;
        RAPTOR::pitch_rate = RAPTOR::roll_rate = RAPTOR::yaw_rate = 0.0;
        return;
    }
    vehicle.raw_body_ay_mps2 = ay;
    RAPTOR::body_ground_velocity = Vec3(RaptorVehicle::finite(vx),
        RaptorVehicle::finite(vy), RaptorVehicle::finite(vz));
    RAPTOR::body_air_velocity = Vec3(RaptorVehicle::finite(vx - wind_vx),
        RaptorVehicle::finite(vy - wind_vy), RaptorVehicle::finite(vz - wind_vz));
    RAPTOR::aoa = RaptorVehicle::finite(common_angle_of_attack);
    RAPTOR::alpha = RAPTOR::aoa * RAPTOR::rad_to_deg;
    RAPTOR::aos = RaptorVehicle::finite(common_angle_of_slide);
    RAPTOR::beta = RAPTOR::aos * RAPTOR::rad_to_deg;
    RAPTOR::g = (RaptorVehicle::finite(ay) / 9.81) + 1; // retained pending host gravity convention test
    RAPTOR::pitch = RaptorVehicle::finite(pitch);
    RAPTOR::roll = RaptorVehicle::finite(roll);
    RAPTOR::heading = RaptorVehicle::finite(yaw);
    RAPTOR::roll_rate = RaptorVehicle::finite(omegax);
    RAPTOR::yaw_rate = RaptorVehicle::finite(omegay);
    RAPTOR::pitch_rate = RaptorVehicle::finite(omegaz);
}

void ed_fm_set_command(int command, float value) {
    if (!std::isfinite(value) || !vehicle.alive) return;
    if (vehicle_command(command, value)) return;
    if (command == 11800) { cockpit_manager.commitGuidanceEntry(value); return; }
    // Cockpit-scheduled work continues during active pause, independently of
    // physics integration. The Lua device supplies its fixed activity period.
    if (command == 10851) { cockpit_manager.updateGun(); return; }
    if (command == 10850) {
        cockpit_manager.updateCombat(static_cast<double>(value));
        return;
    }
    if (const int afcs_command = RaptorCommands::afcs(command)) {
        if (value > 0 || afcs_command == 428 ||
            (afcs_command >= 11620 && afcs_command <= 11625)) {
            autopilot.command(afcs_command, ap_frame(), value);
        }
        return;
    }
    if ((command>=93 && command<=99) || command==215) {
        const int index=command==215 ? 7 : command-93;
        trim_telemetry.events[index] += 1;
        trim_telemetry.last_command=command;
        trim_telemetry.last_value=value;
        trim_telemetry.last_stamp=RAPTOR::fm_clock;
    }
    if (command>=93 && command<=99) autopilot.disconnect(3);
    double ias_ms = vehicle.air_data_reversion ? RaptorAirData::invalid : vehicle.air_sensor.measured.eas_mps;
    double ias_knots_local = ias_ms * 1.94384;
    switch (command) {
    case JoystickPitch:
        RAPTOR::pitch_input = limit(value, -1, 1);
        RAPTOR::pitch_analog = true;
        RAPTOR::pitch_discrete = 0;
        break;
    case PitchUp: RAPTOR::pitch_discrete = 1; RAPTOR::pitch_analog = false; break;
    case PitchUpStop:
        if (!RAPTOR::pitch_analog && RAPTOR::pitch_discrete > 0) RAPTOR::pitch_discrete = 0;
        break;
    case PitchDown: RAPTOR::pitch_discrete = -1; RAPTOR::pitch_analog = false; break;
    case PitchDownStop:
        if (!RAPTOR::pitch_analog && RAPTOR::pitch_discrete < 0) RAPTOR::pitch_discrete = 0;
        break;
    case trimUp:
    case trimDown:
    case trimStop:
        trim_control.command(command);
        break;
    case resetTrim:
        trim_control.command(command);
        RAPTOR::pitch_trim = RAPTOR::roll_trim = RAPTOR::yaw_trim = 0;
        RAPTOR::manual_trim_applied = false;
        break;

    case JoystickRoll:
        RAPTOR::roll_input = limit(value, -1, 1);
        RAPTOR::roll_analog = true;
        RAPTOR::roll_discrete = 0;
        break;
    case RollLeft: RAPTOR::roll_discrete = -1; RAPTOR::roll_analog = false; break;
    case RollLeftStop:
        // Release only the matching keyboard request. A late release must
        // not replace a held joystick axis with a zero discrete command.
        if (!RAPTOR::roll_analog && RAPTOR::roll_discrete < 0) RAPTOR::roll_discrete = 0;
        break;
    case RollRight: RAPTOR::roll_discrete = 1; RAPTOR::roll_analog = false; break;
    case RollRightStop:
        if (!RAPTOR::roll_analog && RAPTOR::roll_discrete > 0) RAPTOR::roll_discrete = 0;
        break;
    case trimLeft: trim_control.command(command); break;
    case trimRight: trim_control.command(command); break;
    case PedalYaw: RAPTOR::yaw_input = limit(-value, -1, 1); RAPTOR::yaw_discrete = 0; RAPTOR::yaw_analog = true; break;
    case rudderleft: RAPTOR::yaw_discrete = 1; RAPTOR::yaw_analog = false; break;
    case rudderleftstop:
        if (!RAPTOR::yaw_analog && RAPTOR::yaw_discrete > 0) RAPTOR::yaw_discrete = 0;
        break;
    case rudderright: RAPTOR::yaw_discrete = -1; RAPTOR::yaw_analog = false; break;
    case rudderrightstop:
        if (!RAPTOR::yaw_analog && RAPTOR::yaw_discrete < 0) RAPTOR::yaw_discrete = 0;
        break;
    case ruddertrimLeft: trim_control.command(command); break;
    case ruddertrimRight: trim_control.command(command); break;
    case EnginesOn: vehicle_start_engine(true); vehicle_start_engine(false); break;
    case LeftEngineOn: vehicle_start_engine(true); break;
    case RightEngineOn: vehicle_start_engine(false); break;
    case EnginesOff: vehicle_stop_engine(true); vehicle_stop_engine(false); break;
    case LeftEngineOff: vehicle_stop_engine(true); break;
    case RightEngineOff: vehicle_stop_engine(false); break;

    case ThrottleAxis:
        RAPTOR::left_throttle_input = RAPTOR::right_throttle_input = limit(-value + 1, 0, 2) / 2;
        break;
    case ThrottleAxisLeft:
        RAPTOR::left_throttle_input = limit(-value + 1, 0, 2) / 2;
        break;
    case ThrottleAxisRight:
        RAPTOR::right_throttle_input = limit(-value + 1, 0, 2) / 2;
        break;
    case ThrottleIncrease: RAPTOR::left_throttle_input += 0.0075; RAPTOR::right_throttle_input += 0.0075; break;
    case ThrottleLeftUp: RAPTOR::left_throttle_input += 0.0075; break;
    case ThrottleRightUp: RAPTOR::right_throttle_input += 0.0075; break;
    case ThrottleDecrease: RAPTOR::left_throttle_input -= 0.0075; RAPTOR::right_throttle_input -= 0.0075; break;
    case ThrottleLeftDown: RAPTOR::left_throttle_input -= 0.0075; break;
    case ThrottleRightDown: RAPTOR::right_throttle_input -= 0.0075; break;
    case AirBrakes: RAPTOR::airbrake_switch = !RAPTOR::airbrake_switch; break;
    case AirBrakesOff: RAPTOR::airbrake_switch = false; break;
    case AirBrakesOn: RAPTOR::airbrake_switch = true; break;
    case flapsToggle: RAPTOR::flap_override = RAPTOR::flap_override < 0 ? 1 : -1; break;
    case flapsDown: RAPTOR::flap_override = 1; break;
    case flapsUp: RAPTOR::flap_override = 0; break;
    case gearToggle:
    case gearDown:
    case gearUp: {
        const bool down = command == gearToggle ? !RAPTOR::gear_switch : command == gearDown;
        static_cast<void>(vehicle.configuration.request_gear(down, RAPTOR::on_ground,
            ias_knots_local, RAPTOR::gear_switch));
        break;
    }
    case LeftBrakeDemand: RAPTOR::left_brake_request = RaptorVehicle::unit(value); break;
    case RightBrakeDemand: RAPTOR::right_brake_request = RaptorVehicle::unit(value); break;
    case WheelBrakeOn:  RAPTOR::wheel_brake = 1; break;
    case WheelBrakeOff: RAPTOR::wheel_brake = 0; break;

    }
}

bool ed_fm_change_mass(double& delta_mass, double& delta_mass_pos_x, double& delta_mass_pos_y, double& delta_mass_pos_z,
    double& delta_mass_moment_of_inertia_x, double& delta_mass_moment_of_inertia_y, double& delta_mass_moment_of_inertia_z)
{
    RaptorVehicle::MassTransaction transaction;
    if (!vehicle.mass.pop(transaction)) return false;
    delta_mass = transaction.kg;
    delta_mass_pos_x = transaction.x_m;
    delta_mass_pos_y = transaction.y_m;
    delta_mass_pos_z = transaction.z_m;
    // DCS inertia ownership is not yet experimentally characterized.
    delta_mass_moment_of_inertia_x = delta_mass_moment_of_inertia_y = delta_mass_moment_of_inertia_z = 0.0;
    return true;
}

void ed_fm_set_internal_fuel(double fuel) {
    if (!std::isfinite(fuel) || fuel < 0.0) return;
    vehicle.fuel.set_internal(std::min(fuel, RAPTOR::max_internal_fuel));
    RAPTOR::internal_fuel = vehicle.fuel.internal_kg();
    RAPTOR::total_fuel = RAPTOR::internal_fuel + RAPTOR::external_fuel;
}

double ed_fm_get_internal_fuel() {
    return RAPTOR::internal_fuel;
}

void ed_fm_set_external_fuel(int station, double fuel, double x, double y, double z) {
    // Quantity is not installation identity. Removal comes from current native
    // wing inventory. The host owns absolute loadout mass changes, not this ledger.
    if (station < 0 || station >= 16 || !std::isfinite(fuel) || fuel < 0.0 ||
        !RaptorVehicle::bounded_three(x, y, z, 20.0)) return;
    const bool known = RAPTOR::external_fuel_stations.contains(station);
    if (!known && fuel == 0.0 && std::abs(z) < 0.1) return;
    if (RAPTOR::external_fuel_stations.find(station) ==
        RAPTOR::external_fuel_stations.end() && RAPTOR::external_fuel_stations.size() >= 16) return;
    fuel = std::clamp(fuel, 0.0, RaptorVehicle::external_tank_capacity_kg);
    RAPTOR::external_fuel_stations[station] = fuel;
    RAPTOR::external_fuel_callback_stamp[station] = vehicle.time_s;
    if (!known || fuel > 0.0) {
        RAPTOR::external_fuel_positions[station] = Vec3(x, y, z);
    }
    if (!known || fuel > 0.0) RAPTOR::external_tank_refill_allowed[station] = fuel > 0.0;
    RAPTOR::external_tanks_equipped = !RAPTOR::external_fuel_stations.empty();
    RAPTOR::external_fuel = 0.0;
    for (const auto& [station_id, quantity] : RAPTOR::external_fuel_stations)
        RAPTOR::external_fuel += std::max(0.0, quantity);
    RAPTOR::total_fuel = RAPTOR::internal_fuel + RAPTOR::external_fuel;
}

double ed_fm_get_external_fuel() {
    return RAPTOR::external_fuel;
}

void ed_fm_set_fc3_cockpit_draw_args_v2(float* data, size_t size) {
    cockpit_manager.updateDrawArgs(data, size);
}

void ed_fm_set_draw_args_v2(float* data, size_t size) {
    // Highest aircraft draw-argument index used here is 623; reject short buffers.
    if (data == nullptr || size <= 623) return;
    data[0] = (float)limit(RAPTOR::gear_pos, 0, 1);
    data[3] = (float)limit(RAPTOR::gear_pos, 0, 1);
    data[5] = (float)limit(RAPTOR::gear_pos, 0, 1);
    data[15] = (float)limit(RAPTOR::right_elevon_angle / -RAPTOR::rad(18.0), -1.0, 1.0);
    data[16] = (float)limit(RAPTOR::left_elevon_angle / -RAPTOR::rad(18.0), -1.0, 1.0);
    // Fixed physical scale: schedule changes cannot teleport the drawing.
    data[622] = (float)limit(-RAPTOR::left_tv_angle / RAPTOR::rad(20), -1, 1);
    data[623] = (float)limit(-RAPTOR::right_tv_angle / RAPTOR::rad(20), -1, 1);
    data[17] = static_cast<float>(limit(RAPTOR::left_rudder_angle / RAPTOR::rad(30), -1, 1));
    data[18] = static_cast<float>(limit(RAPTOR::right_rudder_angle / RAPTOR::rad(30), -1, 1));
    data[25] = static_cast<float>(vehicle.configuration.hook_position);
    data[21] = (float)limit(RAPTOR::airbrake_pos, 0, 1);
    data[182] = (float)limit(RAPTOR::airbrake_pos, 0, 1);
    data[184] = (float)limit(RAPTOR::airbrake_pos, 0, 1);

    // Render achieved states. Draw frequency is not an actuator timestep.
    data[9] = data[10] = (float)RAPTOR::flaps_pos;
    data[11] = (float)limit(RAPTOR::left_aileron_angle / RAPTOR::rad(30), -1, 1);
    data[12] = (float)limit(RAPTOR::right_aileron_angle / RAPTOR::rad(30), -1, 1);

    float lef_flap = (float)limit((RAPTOR::flaps_pos + RAPTOR::slats_pos) / 2.0, 0.0, 1.0);
    data[603] = lef_flap;

    if (RAPTOR::left_engine_state == RAPTOR::OFF) {
        data[29] = 0.0f;
    }
    else if (RAPTOR::left_engine_state == RAPTOR::RUNNING && RAPTOR::left_ab_timer > 0.95) {
        data[29] = 1.0f;
    }
    else {
        data[29] = 0.0f;
    }

    if (RAPTOR::right_engine_state == RAPTOR::OFF) {
        data[28] = 0.0f;
    }
    else if (RAPTOR::right_engine_state == RAPTOR::RUNNING && RAPTOR::right_ab_timer > 0.95) {
        data[28] = 1.0f;
    }
    else {
        data[28] = 0.0f;
    }

    if (RAPTOR::left_engine_state == RAPTOR::OFF) {
        data[611] = 1.0f;
    }
    else {
        float rpm = static_cast<float>(RAPTOR::left_engine_power_readout);
        if (rpm >= 0.67f) {
            data[611] = 0.0f;
        }
        else {
            data[611] = (0.67f - rpm) / (0.67f - 0.0f);
        }
    }
    data[611] = static_cast<float>(limit(data[611], 0.0f, 1.0f));

    data[90] = (float)RaptorVehicle::unit(left_engine_instruments.nozzle_pct / 100.0);

    if (RAPTOR::right_engine_state == RAPTOR::OFF) {
        data[610] = 1.0f;
    }
    else {
        float rpm = static_cast<float>(RAPTOR::right_engine_power_readout);
        if (rpm >= 0.67f) {
            data[610] = 0.0f;
        }
        else {
            data[610] = (0.67f - rpm) / (0.67f - 0.0f);
        }
    }
    data[610] = static_cast<float>(limit(data[610], 0.0f, 1.0f));

    data[89] = (float)RaptorVehicle::unit(right_engine_instruments.nozzle_pct / 100.0);

    if (size > 325) {
        if (RAPTOR::right_engine_state == RAPTOR::OFF) {
            data[324] = 0.0;
        }
        else {
            data[324] = static_cast<float>(RAPTOR::right_engine_phase);
        }

        if (RAPTOR::left_engine_state == RAPTOR::OFF) {
            data[325] = 0.0;
        }
        else {
            data[325] = static_cast<float>(RAPTOR::left_engine_phase);
        }
    }

    data[604] = RAPTOR::taxi_lights ? 1.0f : 0.0f;
    data[605] = RAPTOR::landing_lights ? 1.0f : 0.0f;
    data[606] = static_cast<float>(RAPTOR::form_light);
    data[607] = RAPTOR::nav_white ? (RAPTOR::nav_white_blink ? (RAPTOR::nav_white_timer < 0.1f ? 1.0f : 0.0f) : 1.0f) : 0.0f;
    data[608] = RAPTOR::anti_collision ? (RAPTOR::anti_collision_blink ? (RAPTOR::anti_collision_timer < 0.1f ? 1.0f : 0.0f) : 1.0f) : 0.0f;
    data[609] = static_cast<float>(RAPTOR::aar_light);
    data[612] = RAPTOR::nav_lights ? 1.0f : 0.0f;
    data[613] = RAPTOR::nav_lights ? 1.0f : 0.0f;

    data[114] = RAPTOR::is_destroyed ? 1.0f : 0.0f;
}

void ed_fm_configure(const char* cfg_path) {
    if (!RAPTOR::sim_initialised) {
        cockpit_manager.initialize();
        RAPTOR::left_wing_pos = Vec3(-0.8, 0.5, -RAPTOR::wingspan / 2);
        RAPTOR::right_wing_pos = Vec3(-0.8, 0.5, RAPTOR::wingspan / 2);
        RAPTOR::tail_pos = Vec3(-0.7, 0.0, 0.0);
        RAPTOR::left_elevon_pos = Vec3(-RAPTOR::length / 2, 0.0, -RAPTOR::wingspan * 0.25);
        RAPTOR::right_elevon_pos = Vec3(-RAPTOR::length / 2, 0.0, RAPTOR::wingspan * 0.25);
        RAPTOR::left_aileron_pos = Vec3(0.0, 0.0, -RAPTOR::wingspan * 0.5);
        RAPTOR::right_aileron_pos = Vec3(0.0, 0.0, RAPTOR::wingspan * 0.5);
        RAPTOR::rudder_pos = Vec3(-RAPTOR::length / 2, RAPTOR::height / 2, 0);
        RAPTOR::left_engine_pos = Vec3(-3.793, 0.0, -0.716);
        RAPTOR::right_engine_pos = Vec3(-3.793, 0.0, 0.716);
        RAPTOR::left_elevon_command = RAPTOR::right_elevon_command = 0.0;
        RAPTOR::left_elevon_angle = RAPTOR::right_elevon_angle = 0.0;
        RAPTOR::aileron_command = RAPTOR::last_aileron_cmd = 0.0;
        RAPTOR::rudder_command = RAPTOR::last_rudder_cmd = 0.0;
        RAPTOR::roll_error_i = RAPTOR::yaw_error_i = 0.0;
        RAPTOR::last_yaw_input = 0.0;
        RAPTOR::tv_angle = RAPTOR::left_tv_angle = RAPTOR::right_tv_angle = 0.0;
        RAPTOR::left_aileron_angle = RAPTOR::right_aileron_angle = RAPTOR::rudder_angle = 0.0;
    RAPTOR::left_rudder_angle = RAPTOR::right_rudder_angle = 0.0;
        RAPTOR::last_tv_cmd = 0.0;
        RAPTOR::last_pitch_input = 0.0;
        RAPTOR::idle_rpm = 0.675;
    }
}

double ed_fm_get_param(unsigned index) {
    if (!vehicle.alive) return 0.0;
    switch (index) {
    case ED_FM_SUSPENSION_0_WHEEL_YAW: {
        if (!RAPTOR::on_ground || RAPTOR::gear_pos < 0.99) return 0.0;
        const double yaw_source = RAPTOR::yaw_analog ? RAPTOR::yaw_input : RAPTOR::yaw_discrete;
        return limit(yaw_source, -1.0, 1.0) * RAPTOR::rad(60.0) *
            vehicle.configuration.steering_authority(RAPTOR::ground_speed_knots / 1.943844492, actuator_available);
    }
    case ED_FM_SUSPENSION_0_RELATIVE_BRAKE_MOMENT: return 0; // unbraked nosewheel
    case ED_FM_SUSPENSION_1_RELATIVE_BRAKE_MOMENT: return RAPTOR::left_brake_achieved;
    case ED_FM_SUSPENSION_2_RELATIVE_BRAKE_MOMENT: return RAPTOR::right_brake_achieved;
    case ED_FM_ANTI_SKID_ENABLE: return true;
    case ED_FM_FC3_STICK_PITCH: return limit(RAPTOR::pitch_input / 2, -1.0, 1.0);
    case ED_FM_FC3_STICK_ROLL: return limit(RAPTOR::roll_input, -1.0, 1.0);
    case ED_FM_FC3_RUDDER_PEDALS: return limit(-RAPTOR::yaw_input, -1.0, 1.0);
    case ED_FM_FC3_THROTTLE_LEFT: return RAPTOR::left_throttle_output;
    case ED_FM_FC3_THROTTLE_RIGHT: return RAPTOR::right_throttle_output;
    case ED_FM_FUEL_INTERNAL_FUEL: return RAPTOR::internal_fuel;
    case ED_FM_FUEL_TOTAL_FUEL: return RAPTOR::total_fuel;
    case ED_FM_OXYGEN_SUPPLY: return 101000.0; // retain ABI baseline pending host response test
    case ED_FM_COCKPIT_PRESSURIZATION_OVER_EXTERNAL:
        return vehicle_on(VehicleSignal::CanopyValid) && vehicle.environment.valid ?
            vehicle.environment.cabin_overpressure_pa : 0.0;
    case ED_FM_INTERRUPT_REFUEL: return vehicle.configuration.refuel_disconnect ? 1.0 : 0.0;
    case ED_FM_FLOW_VELOCITY: return 10.0;

    case ED_FM_SUSPENSION_0_GEAR_POST_STATE:
    case ED_FM_SUSPENSION_1_GEAR_POST_STATE:
    case ED_FM_SUSPENSION_2_GEAR_POST_STATE: return RAPTOR::gear_pos;

    case ED_FM_ENGINE_0_RPM: return vehicle.power.apu_spool * 50000.0; // estimated shaft-speed anchor
    case ED_FM_ENGINE_0_RELATED_RPM: return vehicle.power.apu_spool;
    case ED_FM_ENGINE_0_THRUST: return 0;
    case ED_FM_ENGINE_0_RELATED_THRUST: return 0;

    case ED_FM_ENGINE_1_CORE_RPM: return left_engine_instruments.raw_core_rpm();
    case ED_FM_ENGINE_1_RPM: return left_engine_instruments.raw_fan_rpm();
    case ED_FM_ENGINE_1_FAN_PHASE: return RAPTOR::left_engine_phase * 2.0 * RaptorVehicle::pi;
    case ED_FM_ENGINE_1_COMBUSTION: return vehicle.left_engine.burning ? 1.0 : 0.0;
    case ED_FM_ENGINE_1_RELATED_THRUST: return RaptorVehicle::relative_thrust(RAPTOR::left_thrust_force, RAPTOR::max_dry_left_thrust);
    case ED_FM_ENGINE_1_CORE_RELATED_THRUST:
        return RaptorVehicle::relative_thrust(RAPTOR::left_thrust_force * (RAPTOR::left_throttle_output > 1.025 ? .6 : .7), RAPTOR::max_dry_left_thrust * .7);
    case ED_FM_ENGINE_1_RELATED_RPM: return left_engine_instruments.fan;
    case ED_FM_ENGINE_1_CORE_RELATED_RPM: return left_engine_instruments.core;
    case ED_FM_ENGINE_1_CORE_THRUST: return RAPTOR::left_thrust_force * (RAPTOR::left_throttle_output > 1.025 ? 0.6 : 0.7);
    case ED_FM_ENGINE_1_THRUST: return RAPTOR::left_thrust_force;
    case ED_FM_ENGINE_1_TEMPERATURE: return left_engine_instruments.temperature_c;
    case ED_FM_ENGINE_1_OIL_PRESSURE: return left_engine_instruments.oil_psi * 6894.757293; // API: Pa
    case ED_FM_ENGINE_1_FUEL_FLOW: return (RAPTOR::left_fuel_rate_kg_s);

    case ED_FM_ENGINE_2_CORE_RPM: return right_engine_instruments.raw_core_rpm();
    case ED_FM_ENGINE_2_RPM: return right_engine_instruments.raw_fan_rpm();
    case ED_FM_ENGINE_2_FAN_PHASE: return RAPTOR::right_engine_phase * 2.0 * RaptorVehicle::pi;
    case ED_FM_ENGINE_2_COMBUSTION: return vehicle.right_engine.burning ? 1.0 : 0.0;
    case ED_FM_ENGINE_2_RELATED_THRUST: return RaptorVehicle::relative_thrust(RAPTOR::right_thrust_force, RAPTOR::max_dry_right_thrust);
    case ED_FM_ENGINE_2_CORE_RELATED_THRUST:
        return RaptorVehicle::relative_thrust(RAPTOR::right_thrust_force * (RAPTOR::right_throttle_output > 1.025 ? .6 : .7), RAPTOR::max_dry_right_thrust * .7);
    case ED_FM_ENGINE_2_RELATED_RPM: return right_engine_instruments.fan;
    case ED_FM_ENGINE_2_CORE_RELATED_RPM: return right_engine_instruments.core;
    case ED_FM_ENGINE_2_CORE_THRUST: return RAPTOR::right_thrust_force * (RAPTOR::right_throttle_output > 1.025 ? 0.6 : 0.7);
    case ED_FM_ENGINE_2_THRUST: return RAPTOR::right_thrust_force;
    case ED_FM_ENGINE_2_TEMPERATURE: return right_engine_instruments.temperature_c;
    case ED_FM_ENGINE_2_OIL_PRESSURE: return right_engine_instruments.oil_psi * 6894.757293; // API: Pa
    case ED_FM_ENGINE_2_FUEL_FLOW: return (RAPTOR::right_fuel_rate_kg_s);

    case ED_FM_STICK_FORCE_CENTRAL_PITCH: return 0.0;
    case ED_FM_STICK_FORCE_FACTOR_PITCH: return 1.0;
    case ED_FM_STICK_FORCE_CENTRAL_ROLL: return 0.0;
    case ED_FM_STICK_FORCE_FACTOR_ROLL: return 1.0;
    case ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER: {
        double space = std::max(0.0, RAPTOR::max_internal_fuel - RAPTOR::internal_fuel);
        for (const auto& [station, quantity] : RAPTOR::external_fuel_stations)
            if (vehicle_tank_refill_allowed(station))
                space += std::max(0.0, RaptorVehicle::external_tank_capacity_kg - quantity);
        return space > .01 ? 1.0 : 0.0;
    }
    }
    return 0;
}

void ed_fm_refueling_add_fuel(double fuel) {
    if (!vehicle.alive || !std::isfinite(fuel) || fuel <= 0.0) return;
    double accepted_total = 0.0;
    const double accepted = vehicle.fuel.accept_internal(fuel, vehicle.mass);
    RAPTOR::internal_fuel = vehicle.fuel.internal_kg();
    accepted_total += accepted;
    double remainder = std::max(0.0, fuel - accepted_total);
    for (auto& [station, quantity] : RAPTOR::external_fuel_stations) {
        if (!vehicle_tank_refill_allowed(station)) continue;
        const double added = std::min(remainder,
            std::max(0.0, RaptorVehicle::external_tank_capacity_kg - quantity));
        const auto position = RAPTOR::external_fuel_positions.find(station);
        if (position == RAPTOR::external_fuel_positions.end()) continue;
        const auto& pos = position->second;
        if (vehicle.mass.add(-added, pos.x, pos.y, pos.z)) {
            quantity += added;
            remainder -= added;
            accepted_total += added;
        }
    }
    RAPTOR::external_fuel = 0.0;
    for (const auto& [station, quantity] : RAPTOR::external_fuel_stations)
        RAPTOR::external_fuel += quantity;
    RAPTOR::total_fuel = RAPTOR::internal_fuel + RAPTOR::external_fuel;
    if (accepted_total > 0.0) vehicle.configuration.last_transfer_s = vehicle.time_s;
}

void ed_fm_unlimited_fuel(bool value) { RAPTOR::infinite_fuel = value; }
void ed_fm_set_easy_flight(bool value) { RAPTOR::easy_flight = value; }
void ed_fm_set_immortal(bool value) { RAPTOR::invincible = value; }

void ed_fm_on_damage(int Element, double element_integrity_factor) {
    if (!vehicle.alive || Element < 0 || Element >= 137 || !std::isfinite(element_integrity_factor)) return;
    element_integrity_factor = RaptorVehicle::unit(element_integrity_factor);
    if (RAPTOR::invincible) return;
    RAPTOR::element_integrity[Element] = element_integrity_factor;
    static_cast<void>(vehicle.damage.add(Element, element_integrity_factor));
    if (!RAPTOR::invincible) {
        NativeAesaRadar::damage(Element, element_integrity_factor);
        RAPTOR::left_wing_integrity = RAPTOR::element_integrity[static_cast<size_t>(DamageElement::WingOutLeft)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::WingCentreLeft)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::WingInLeft)];
        RAPTOR::right_wing_integrity = RAPTOR::element_integrity[static_cast<size_t>(DamageElement::WingOutRight)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::WingCentreRight)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::WingInRight)];
        RAPTOR::tail_integrity = RAPTOR::element_integrity[static_cast<size_t>(DamageElement::RudderLeft)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::RudderRight)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::Tail)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::TailLeft)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::TailRight)];
        RAPTOR::left_engine_integrity = RAPTOR::element_integrity[static_cast<size_t>(DamageElement::NacelleLeftBottom)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::NacelleLeft)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::Engine1)];
        RAPTOR::right_engine_integrity = RAPTOR::element_integrity[static_cast<size_t>(DamageElement::NacelleRightBottom)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::NacelleRight)] *
            RAPTOR::element_integrity[static_cast<size_t>(DamageElement::Engine2)];

        RAPTOR::left_elevon_integrity = RAPTOR::element_integrity[45] * RAPTOR::element_integrity[47];
        RAPTOR::right_elevon_integrity = RAPTOR::element_integrity[46] * RAPTOR::element_integrity[48];
        const bool both_engines_lost = RAPTOR::left_engine_integrity <= 0.2 && RAPTOR::right_engine_integrity <= 0.2;
        const bool either_wing_lost = RAPTOR::left_wing_integrity <= 0.2 || RAPTOR::right_wing_integrity <= 0.2;
        if (both_engines_lost && either_wing_lost && RAPTOR::tail_integrity <= 0.2) {
            RAPTOR::is_destroyed = true;
        }

    }
}

void ed_fm_on_planned_failure(const char* failure) {
    if (!vehicle.alive) return;
    for (const auto& fault : RaptorVehicle::planned_faults) {
        if (RaptorVehicle::fault_name_equal(failure, fault.id)) {
            vehicle_bus.write(fault.channel, 1.0);
            return;
        }
    }
}

bool ed_fm_need_to_be_repaired() {
    if (vehicle.left_brake.tire_failed || vehicle.right_brake.tire_failed) return true;
    if (vehicle.left_fire_isolated || vehicle.right_fire_isolated || RAPTOR::is_destroyed) return true;
    for (const double integrity : RAPTOR::element_integrity)
        if (integrity < 0.999) return true;
    for (const auto& fault : RaptorVehicle::planned_faults)
        if (vehicle_on(fault.channel)) return true;
    return false;
}

void ed_fm_repair() {
    vehicle.repair_equipment();
    vehicle_repair_injected_faults();
    NativeAesaRadar::repair();
    for (int i = 0; i < 137; i++) RAPTOR::element_integrity[i] = 1.0;
    RAPTOR::left_wing_integrity = RAPTOR::right_wing_integrity = RAPTOR::tail_integrity = 1.0;
    RAPTOR::left_elevon_integrity = RAPTOR::right_elevon_integrity = 1.0;
    RAPTOR::left_engine_integrity = RAPTOR::right_engine_integrity = 1.0;
    RAPTOR::is_destroyed = false;
    RAPTOR::destruction_events_pushed = false;
    vehicle.damage.clear();
}

bool ed_fm_pop_simulation_event(ed_fm_simulation_event& out) {

    RaptorVehicle::DamageNotice event;
    if (vehicle.damage.pop(event)) {
        out.event_type = ED_FM_EVENT_STRUCTURE_DAMAGE;
        out.event_params[0] = static_cast<double>(event.element);
        out.event_params[1] = event.integrity;
        out.event_message[0] = '\0';
        return true;
    }
    out.event_type = ED_FM_EVENT_INVALID;
    return false;
}

bool ed_fm_push_simulation_event(const ed_fm_simulation_event& in) {

    return false;
}

void ed_fm_cold_start() {
    vehicle.reset(false);
    reset_fm_state();
    RAPTOR::on_ground = true;
    RAPTOR::sim_initialised = false;
    RAPTOR::gear_switch = true;
    RAPTOR::gear_pos = 1;
    RAPTOR::airbrake_switch = false;
    RAPTOR::left_engine_switch = false;
    RAPTOR::right_engine_switch = false;
    RAPTOR::left_engine_state = RAPTOR::OFF;
    RAPTOR::right_engine_state = RAPTOR::OFF;
    RAPTOR::left_throttle_input = RAPTOR::right_throttle_input = 0.0;
    RAPTOR::left_throttle_output = RAPTOR::right_throttle_output = 0.0;
    RAPTOR::left_engine_power_readout = RAPTOR::right_engine_power_readout = 0.0;
    RAPTOR::left_ab_timer = RAPTOR::right_ab_timer = 0.0;
    RAPTOR::left_engine_start_timer = RAPTOR::right_engine_start_timer = 0.0;
    RAPTOR::left_engine_phase = 0.0;
    RAPTOR::right_engine_phase = 0.0;
    RAPTOR::total_fuel = RAPTOR::internal_fuel + RAPTOR::external_fuel;
    RAPTOR::pitch_input = RAPTOR::roll_input = RAPTOR::yaw_input = 0.0;
    RAPTOR::left_elevon_command = RAPTOR::right_elevon_command = RAPTOR::aileron_command = RAPTOR::rudder_command = 0.0;
    RAPTOR::left_engine_integrity = RAPTOR::right_engine_integrity = 1.0;
    RAPTOR::manual_trim_applied = false;
    ed_fm_repair();
    vehicle.damage.clear();
    cockpit_manager.initialize();
}

void ed_fm_hot_start() {
    vehicle.reset(true);
    reset_fm_state();
    RAPTOR::on_ground = true;
    RAPTOR::gear_switch = true;
    RAPTOR::gear_pos = 1;
    RAPTOR::flaps_pos = 0;
    RAPTOR::airbrake_switch = false;
    RAPTOR::left_engine_switch = RAPTOR::right_engine_switch = true;
    RAPTOR::left_engine_state = RAPTOR::RUNNING;
    RAPTOR::right_engine_state = RAPTOR::RUNNING;
    RAPTOR::left_throttle_input = RAPTOR::right_throttle_input = 0.0;
    RAPTOR::left_throttle_output = RAPTOR::right_throttle_output = 0.67;
    RAPTOR::left_engine_power_readout = RAPTOR::right_engine_power_readout = 0.67;
    RAPTOR::left_engine_phase = 0.0;
    RAPTOR::right_engine_phase = 0.0;
    RAPTOR::left_ab_timer = RAPTOR::right_ab_timer = 0.0;
    RAPTOR::left_engine_start_timer = RAPTOR::right_engine_start_timer = 0.0;
    RAPTOR::total_fuel = RAPTOR::internal_fuel + RAPTOR::external_fuel;
    RAPTOR::left_engine_integrity = RAPTOR::right_engine_integrity = 1.0;
    RAPTOR::velocity_world = Vec3(0, 0, 0);
    RAPTOR::pitch_rate = RAPTOR::roll_rate = RAPTOR::yaw_rate = 0.0;
    RAPTOR::pitch = RAPTOR::roll = RAPTOR::heading = 0.0;
    RAPTOR::manual_trim_applied = false;
    ed_fm_repair();
    vehicle.damage.clear();
    hydraulics.reset(true);
    vehicle.fuel.boost = vehicle.fuel.pressurization = 1.0;
    left_engine_instruments.reset(RAPTOR::left_throttle_output, RAPTOR::atmosphere_temperature);
    right_engine_instruments.reset(RAPTOR::right_throttle_output, RAPTOR::atmosphere_temperature);
    cockpit_manager.initialize();

}

void ed_fm_hot_start_in_air() {
    vehicle.reset(true, 0.70);
    reset_fm_state();
    RAPTOR::on_ground = false;
    RAPTOR::gear_switch = false;
    RAPTOR::gear_pos = 0;
    RAPTOR::flaps_pos = 0;
    RAPTOR::airbrake_switch = false;
    RAPTOR::left_engine_switch = RAPTOR::right_engine_switch = true;
    RAPTOR::left_engine_state = RAPTOR::RUNNING;
    RAPTOR::right_engine_state = RAPTOR::RUNNING;
    RAPTOR::left_throttle_input = RAPTOR::left_throttle_output = 0.70;
    RAPTOR::right_throttle_input = RAPTOR::right_throttle_output = 0.70;
    RAPTOR::left_engine_power_readout = RAPTOR::right_engine_power_readout = 0.70;
    RAPTOR::left_ab_timer = RAPTOR::right_ab_timer = 0.0;
    RAPTOR::left_engine_start_timer = RAPTOR::right_engine_start_timer = 0.0;
    RAPTOR::left_engine_phase = 0.0;
    RAPTOR::right_engine_phase = 0.0;
    RAPTOR::total_fuel = RAPTOR::internal_fuel + RAPTOR::external_fuel;
    RAPTOR::left_engine_integrity = RAPTOR::right_engine_integrity = 1.0;
    RAPTOR::velocity_world = Vec3(0, 0, 0);
    RAPTOR::pitch_rate = RAPTOR::roll_rate = RAPTOR::yaw_rate = 0.0;
    RAPTOR::pitch = RAPTOR::roll = RAPTOR::heading = 0.0;
    RAPTOR::autotrim_active = true;
    RAPTOR::manual_trim_applied = false;
    ed_fm_repair();
    vehicle.damage.clear();
    hydraulics.reset(true);
    vehicle.fuel.boost = vehicle.fuel.pressurization = 1.0;
    left_engine_instruments.reset(RAPTOR::left_throttle_output, RAPTOR::atmosphere_temperature);
    right_engine_instruments.reset(RAPTOR::right_throttle_output, RAPTOR::atmosphere_temperature);
    cockpit_manager.initialize();
}

void ed_fm_release() {
    vehicle.alive = false;
    vehicle.mass.clear();
    RAPTOR::common_force = Vec3();
    RAPTOR::common_moment = Vec3();
    cockpit_manager.invalidatePhysical();
    RAPTOR::external_fuel_stations.clear();
    RAPTOR::external_fuel_positions.clear();
    RAPTOR::external_tank_refill_allowed.clear();
    RAPTOR::external_fuel_callback_stamp.clear();
    RAPTOR::external_fuel = 0.0;
    RAPTOR::internal_fuel = RAPTOR::total_fuel = 0.0;
    vehicle.fuel.set_internal(0.0);
    RAPTOR::external_tanks_equipped = false;
    NativeDatalink::reset();
    NativeAltimetry::reset();
    NativeNavigation::reset();
    NativeMWS::reset();
    NativeGroundRadar::reset();
    NativeAGWeapons::reset();
    cockpit_manager.resetWeaponFeedback();
    RAPTOR::fm_clock = 0;
    RAPTOR::sim_initialised = false;
    ed_fm_repair();
}

double ed_fm_get_shake_amplitude() {
    return RAPTOR::shake_amplitude;
}

bool ed_fm_add_local_force_component(double& x, double& y, double& z, double& pos_x, double& pos_y, double& pos_z) { return false; }
bool ed_fm_add_global_force_component(double& x, double& y, double& z, double& pos_x, double& pos_y, double& pos_z) { return false; }
bool ed_fm_add_local_moment_component(double& x, double& y, double& z) { return false; }
bool ed_fm_add_global_moment_component(double& x, double& y, double& z) { return false; }
bool ed_fm_enable_debug_info() { return false; }

bool ed_fm_LERX_vortex_update(unsigned idx, LERX_vortex& out) {
    if (idx > 1) {
        return false; 
    }

    float vortex_strength = 0.0f;
    if (fabs(RAPTOR::alpha) >= 8.0f && RAPTOR::mach < 1.65f) { 
        vortex_strength = 0.72f * exp(-pow(RAPTOR::alpha - 35.0f, 2) / (2 * 600.0f));
        if (RAPTOR::alpha > 70.0f) {
            vortex_strength = 0.0f;
        }
        float aoa_factor = (fabs(RAPTOR::alpha) - 8.0f) / (15.0f - 8.0f);
        aoa_factor = std::max(0.0f, std::min(aoa_factor, 0.85f));
        vortex_strength *= aoa_factor;
        float humidity_factor = RAPTOR::atmosphere_density / 1.225f;
        vortex_strength *= (1.0f + humidity_factor * 0.5f);
        vortex_strength *= std::min(static_cast<float>(RAPTOR::V_scalar / 100.0), 1.0f);
        vortex_strength *= 0.70f;
    }

    if (vortex_strength <= 0.01f) {
        out.spline = nullptr;
        out.spline_points_count = 0;
        return true;
    }

    const unsigned num_points = 10;
    static std::vector<LERX_vortex_spline_point> spline_points(num_points);

    float start_x = RAPTOR::left_wing_pos.x + 6.0f;
    float start_z = (idx == 0) ? -1.2f : 1.2f;
    float start_y = RAPTOR::left_wing_pos.y + 0.025f;

    for (unsigned i = 0; i < num_points; ++i) {
        auto& point = spline_points[i];
        float t = static_cast<float>(i) / (num_points - 1);

        point.pos[0] = start_x - t * 8.0f;
        point.pos[1] = start_y + t * (idx == 0 ? 0.75f : 0.75f);
        point.pos[2] = start_z + t * 0.0f; 

        point.vel[0] = -RAPTOR::V_scalar * (1.0f - t);
        point.vel[1] = 0.0f;
        point.vel[2] = 0.0f;

        point.radius = 0.22f + 0.42f * sinf(t * 3.14159f);

        point.opacity = vortex_strength * (1.0f - t);
    }

    out.opacity = vortex_strength;
    out.explosion_start = 9.0f; 
    out.spline = spline_points.data();
    out.spline_points_count = num_points;
    out.spline_point_size_in_bytes = sizeof(LERX_vortex_spline_point);
    out.version = 1; 

    return true; 
}

//########################################################################################################
//########################################################################################################
//########################################################################################################

    // ----- Cockpit Logic -----

inline float limit(float value, float min_val, float max_val) {
    if (value < min_val) return min_val;
    if (value > max_val) return max_val;
    return value;
}

CockpitManager::CockpitManager() {
    draw_args_[709] = 0.0f;
    draw_args_[712] = 0.0f;
    draw_args_[713] = 0.0f;
    draw_args_[714] = 0.0f;
    draw_args_[715] = 0.0f;
}

void CockpitManager::initialize() {
    navigation_snapshot_.initialize(param_api_);
    vehicle_bus.initialize(param_api_);
    vehicle_bus.write(VehicleSignal::Owner, 1.0);
    vehicle_bus.write(VehicleSignal::Valid, 0.0);
    vehicle_bus.write(VehicleSignal::AirValid, 0.0);
    vehicle_bus.write(VehicleSignal::RequestValid, 0.0);
    vehicle_repair_injected_faults();
    NativeSidewinder::start_feedback();
    NativeDatalink::reset();
    NativeAltimetry::reset();
    NativeNavigation::reset();
    NativeMWS::reset();
    NativeGroundRadar::reset();
    NativeAGWeapons::reset();
    NativeGunSight::reset();
    const char* hud_names[] = {"EFM_HUD_VALID", "EFM_HUD_VN", "EFM_HUD_VE", "EFM_HUD_VU",
        "EFM_HUD_WN", "EFM_HUD_WE", "EFM_HUD_WU", "EFM_HUD_TAS",
        "EFM_HUD_SOUND", "EFM_HUD_PRESSURE", "EFM_ENGINE_VALID",
        "EFM_ENGINE_LEFT_RPM_PCT", "EFM_ENGINE_RIGHT_RPM_PCT",
        "EFM_GROUND_VALID", "EFM_WEIGHT_ON_WHEELS", "F22_AP_ACTIVE", "F22_AP_ROLL_MODE", "F22_AP_PITCH_MODE", "F22_AP_AT",
        "F22_AP_MACH_HOLD", "F22_AP_HEADING", "F22_AP_ALT", "F22_AP_VS", "F22_AP_SPEED", "F22_AP_MACH",
        "F22_ENTRY_GUIDANCE_REQUEST", "F22_ENTRY_GUIDANCE_ACTIVE",
        "F22_ENTRY_GUIDANCE_COMMAND", "F22_ENTRY_GUIDANCE_VALUE",
        "F22_ENTRY_GUIDANCE_ACK_REQUEST", "F22_ENTRY_GUIDANCE_RESULT", "F22_ENTRY_GUIDANCE_ACK_VALUE",
        "F22_AP_NAV_OVERRIDE", "F22_AP_LIMITED", "F22_AT_REASON", "F22_AT_FEEDBACK_UNTIL",
        "F22_ALT_RADAR_VALID", "F22_ALT_RADAR_STAMP", "F22_ALT_RADAR_FT",
        "F22_AP_REASON", "F22_AP_OVERRIDE", "F22_AP_READY", "F22_AP_CLOCK", "F22_AP_RALT",
        "EFM_FCS_INTEGRITY_VALID", "EFM_FCS_DAMAGED", "F22_ALT_PRESSURE_REQUEST_VALID",
        "EFM_VEHICLE_VALID", "EFM_HYD_LEFT_PSI", "EFM_HYD_RIGHT_PSI", "EFM_ACTUATOR_AVAILABLE",
        "EFM_ENGINE_LEFT_TEMP_C", "EFM_ENGINE_RIGHT_TEMP_C", "EFM_ENGINE_LEFT_OIL_PSI", "EFM_ENGINE_RIGHT_OIL_PSI",
        "EFM_ENGINE_LEFT_NOZZLE_PCT", "EFM_ENGINE_RIGHT_NOZZLE_PCT", "EFM_TVC_LEFT_DEG", "EFM_TVC_RIGHT_DEG",
        "EFM_ENGINE_LEFT_THRUST_N", "EFM_ENGINE_RIGHT_THRUST_N", "EFM_ENGINE_LEFT_THRUST_PCT", "EFM_ENGINE_RIGHT_THRUST_PCT",
        "EFM_TRIM_VALID","EFM_TRIM_CLOCK","EFM_TRIM_IAS_KTS","EFM_TRIM_TAS_MPS","EFM_TRIM_MACH","EFM_TRIM_ALT_M","EFM_TRIM_AOA_DEG","EFM_TRIM_PITCH_DEG","EFM_TRIM_ROLL_DEG","EFM_TRIM_Q_DEGPS","EFM_TRIM_P_DEGPS","EFM_TRIM_NZ","EFM_TRIM_STICK","EFM_TRIM_PITCH","EFM_TRIM_ROLL","EFM_TRIM_YAW","EFM_TRIM_AUTO","EFM_TRIM_AUTO_ACTIVE","EFM_TRIM_AUTO_INHIBIT","EFM_TRIM_MANUAL","EFM_TRIM_TAKEOFF","EFM_TRIM_STICK_TERM","EFM_TRIM_DAMP_TERM","EFM_TRIM_RAW","EFM_TRIM_ELEVATOR","EFM_TRIM_LEFT_DEG","EFM_TRIM_RIGHT_DEG","EFM_TRIM_Q_PA","EFM_TRIM_EVENT_LEFT","EFM_TRIM_EVENT_RIGHT","EFM_TRIM_EVENT_UP","EFM_TRIM_EVENT_DOWN","EFM_TRIM_EVENT_RESET","EFM_TRIM_EVENT_RUDDER_LEFT","EFM_TRIM_EVENT_RUDDER_RIGHT","EFM_TRIM_EVENT_STOP","EFM_TRIM_LAST_COMMAND","EFM_TRIM_LAST_VALUE","EFM_TRIM_LAST_STAMP",
        "L_HYD_FAILURE", "R_HYD_FAILURE", "APU_RPM_STATE"};
    for (const char* name : hud_names) param_handles_[name] = param_api_.getParamHandle(name);
    param_api_.setParamNumber(param_handles_["EFM_FCS_INTEGRITY_VALID"],0);
    param_api_.setParamNumber(param_handles_["EFM_VEHICLE_VALID"],0);
    param_handles_["APU_POWER"] = param_api_.getParamHandle("APU_POWER");
    param_handles_["BATTERY_POWER"] = param_api_.getParamHandle("BATTERY_POWER");
    param_handles_["MAIN_POWER"] = param_api_.getParamHandle("MAIN_POWER");
    param_handles_["WoW"] = param_api_.getParamHandle("WoW");
    param_handles_["AAR"] = param_api_.getParamHandle("AAR");
    param_handles_["N_GEAR_LIGHT"] = param_api_.getParamHandle("N_GEAR_LIGHT");
    param_handles_["R_GEAR_LIGHT"] = param_api_.getParamHandle("R_GEAR_LIGHT");
    param_handles_["L_GEAR_LIGHT"] = param_api_.getParamHandle("L_GEAR_LIGHT");
    param_handles_["TAXI_SWITCH"] = param_api_.getParamHandle("TAXI_SWITCH");
    param_handles_["NAV_LIGHT_SWITCH"] = param_api_.getParamHandle("NAV_LIGHT_SWITCH");
    param_handles_["FORM_KNOB"] = param_api_.getParamHandle("FORM_KNOB");
    param_handles_["AAR_KNOB"] = param_api_.getParamHandle("AAR_KNOB");
    param_handles_["AAR_READY"] = param_api_.getParamHandle("AAR_READY");
    param_handles_["EFM_INTERNAL_FUEL_KG"] = param_api_.getParamHandle("EFM_INTERNAL_FUEL_KG");
    param_handles_["EFM_EXTERNAL_FUEL_KG"] = param_api_.getParamHandle("EFM_EXTERNAL_FUEL_KG");


    draw_args_[709] = static_cast<float>(getParameter("TAXI_SWITCH", 0.0));
    draw_args_[712] = static_cast<float>(getParameter("AAR", 0.0));
    draw_args_[713] = static_cast<float>(getParameter("AAR_KNOB", 0.0));
    draw_args_[714] = static_cast<float>(getParameter("FORM_KNOB", 0.0));
    draw_args_[715] = static_cast<float>(getParameter("NAV_LIGHT_SWITCH", 0.0));


    param_api_.setParamNumber(param_handles_["MAIN_POWER"], (RAPTOR::left_engine_state == RAPTOR::RUNNING || RAPTOR::right_engine_state == RAPTOR::RUNNING) ? 1.0 : 0.0);
    param_api_.setParamNumber(param_handles_["BATTERY_POWER"], (RAPTOR::left_engine_switch || RAPTOR::right_engine_switch) ? 1.0 : 0.0);
}

void CockpitManager::invalidatePhysical() {
    constexpr VehicleSignal signals[] = {
        VehicleSignal::Valid, VehicleSignal::AirValid, VehicleSignal::ElectricalValid,
        VehicleSignal::EnvironmentValid, VehicleSignal::MassValid, VehicleSignal::ForceValid,
        VehicleSignal::MainPower, VehicleSignal::BatteryPower, VehicleSignal::EssentialPower,
        VehicleSignal::LeftGeneratorPower, VehicleSignal::RightGeneratorPower,
        VehicleSignal::ApuPower, VehicleSignal::ApuReady, VehicleSignal::ApuHydraulics,
        VehicleSignal::ApuAir, VehicleSignal::MissionPowerAvailable,
        VehicleSignal::UtilityAvailable, VehicleSignal::ConditionedAir,
        VehicleSignal::Obogs, VehicleSignal::OxygenBackup,
        VehicleSignal::FormationIntensity, VehicleSignal::RefuelIntensity};
    for (const auto signal : signals) vehicle_bus.write(signal, 0.0);
    constexpr const char* legacy[] = {
        "EFM_HUD_VALID", "EFM_GROUND_VALID", "EFM_ENGINE_VALID",
        "EFM_VEHICLE_VALID", "EFM_TRIM_VALID", "EFM_FCS_INTEGRITY_VALID"};
    const auto write = param_api_.ed_param_api.pfn_ed_cockpit_update_parameter_with_number;
    if (!write) return;
    for (const auto* name : legacy) {
        const auto entry = param_handles_.find(name);
        if (entry != param_handles_.end() && entry->second) write(entry->second, 0.0);
    }
}

void CockpitManager::navigationFrame(RaptorAP::Frame& f) {
    double indicated = 0;
    f.baro_valid = NativeAltimetry::altitude(indicated);
    f.alt = f.baro_valid ? indicated : NAN;
    double model_time = 0;
    const double radar_stamp = getParameter("F22_ALT_RADAR_STAMP");
    const double radar_ft = getParameter("F22_ALT_RADAR_FT");
    f.radar_valid = NativeAltimetry::model_time(model_time) &&
        getParameter("F22_ALT_RADAR_VALID") > .5 && std::isfinite(radar_stamp) &&
        model_time >= radar_stamp && model_time - radar_stamp <= .2 &&
        std::isfinite(radar_ft) && radar_ft >= 0 && radar_ft < 65616.8;
    f.agl = f.radar_valid ? radar_ft / 3.280839895 : NAN;
    f.powered = f.powered && getParameter("MAIN_POWER") > .5;
    const auto navigation=navigation_snapshot_.read(param_api_);
    f.nav_valid=navigation.valid;f.nav_track=navigation.track;
    f.nav_time=navigation.time;f.nav_arrived=navigation.terminal;
}

void CockpitManager::updateGun() {
    NativeGunSight::update(param_api_);
    NativeAGWeapons::update(param_api_);
}

void CockpitManager::updateCombat(double dt) {
    NativeDatalink::update(param_api_);
    const auto& sensed = vehicle.air_sensor.measured;
    const double sensed_age = RAPTOR::fm_clock - sensed.stamp_s;
    const bool primary_pressure = sensed.valid && sensed_age >= 0 && sensed_age <= .25 &&
        vehicle.air_sensor.health != RaptorAirData::Health::Invalid;
    NativeAltimetry::update(param_api_, sensed.static_pa, RAPTOR::sim_initialised && primary_pressure);
    // Generic independently failed standby sensor shares the atmosphere, not
    // the primary ADC's failure state. This is a declared simulation backup.
    NativeAltimetry::update_standby(param_api_, RAPTOR::hud_static_pressure_pa,
        RAPTOR::sim_initialised);
    NativeSidewinder::update(param_api_, dt);
    NativeMWS::update(param_api_);
    NativeGroundRadar::update(param_api_);
    NativeNavigation::update(param_api_);
}

void CockpitManager::resetWeaponFeedback() {
    NativeSidewinder::reset(&param_api_);
}

void CockpitManager::update(double dt) {
    vehicle_bus.write(VehicleSignal::Valid, 0.0);
    const std::pair<const char*,double> trim_parameters[]={
        {"EFM_TRIM_VALID",1.},
        {"EFM_TRIM_CLOCK",RAPTOR::fm_clock},
        {"EFM_TRIM_IAS_KTS",RAPTOR::V_scalar*sqrt(RAPTOR::atmosphere_density/1.225)*1.943844492},
        {"EFM_TRIM_TAS_MPS",RAPTOR::V_scalar},
        {"EFM_TRIM_MACH",RAPTOR::mach},
        {"EFM_TRIM_ALT_M",RAPTOR::altitude_ASL},
        {"EFM_TRIM_AOA_DEG",RAPTOR::alpha},
        {"EFM_TRIM_PITCH_DEG",RAPTOR::pitch*RAPTOR::rad_to_deg},
        {"EFM_TRIM_ROLL_DEG",RAPTOR::roll*RAPTOR::rad_to_deg},
        {"EFM_TRIM_Q_DEGPS",RAPTOR::pitch_rate*RAPTOR::rad_to_deg},
        {"EFM_TRIM_P_DEGPS",RAPTOR::roll_rate*RAPTOR::rad_to_deg},
        {"EFM_TRIM_NZ",RAPTOR::g},
        {"EFM_TRIM_STICK",RAPTOR::pitch_analog?RAPTOR::pitch_input:RAPTOR::smoothed_pitch_discrete},
        {"EFM_TRIM_PITCH",RAPTOR::pitch_trim},
        {"EFM_TRIM_ROLL",RAPTOR::roll_trim},
        {"EFM_TRIM_YAW",RAPTOR::yaw_trim},
        {"EFM_TRIM_AUTO",RAPTOR::autotrim_elevator_cmd},
        {"EFM_TRIM_AUTO_ACTIVE",RAPTOR::autotrim_active?1.:0.},
        {"EFM_TRIM_AUTO_INHIBIT",trim_telemetry.inhibit},
        {"EFM_TRIM_MANUAL",RAPTOR::manual_trim_applied?1.:0.},
        {"EFM_TRIM_TAKEOFF",RAPTOR::takeoff_trim_cmd},
        {"EFM_TRIM_STICK_TERM",trim_telemetry.stick},
        {"EFM_TRIM_DAMP_TERM",trim_telemetry.damping},
        {"EFM_TRIM_RAW",trim_telemetry.raw},
        {"EFM_TRIM_ELEVATOR",RAPTOR::last_elevator_cmd},
        {"EFM_TRIM_LEFT_DEG",RAPTOR::left_elevon_angle*RAPTOR::rad_to_deg},
        {"EFM_TRIM_RIGHT_DEG",RAPTOR::right_elevon_angle*RAPTOR::rad_to_deg},
        {"EFM_TRIM_Q_PA",trim_telemetry.q},
        {"EFM_TRIM_EVENT_LEFT",trim_telemetry.events[0]},
        {"EFM_TRIM_EVENT_RIGHT",trim_telemetry.events[1]},
        {"EFM_TRIM_EVENT_UP",trim_telemetry.events[2]},
        {"EFM_TRIM_EVENT_DOWN",trim_telemetry.events[3]},
        {"EFM_TRIM_EVENT_RESET",trim_telemetry.events[4]},
        {"EFM_TRIM_EVENT_RUDDER_LEFT",trim_telemetry.events[5]},
        {"EFM_TRIM_EVENT_RUDDER_RIGHT",trim_telemetry.events[6]},
        {"EFM_TRIM_EVENT_STOP",trim_telemetry.events[7]},
        {"EFM_TRIM_LAST_COMMAND",trim_telemetry.last_command},
        {"EFM_TRIM_LAST_VALUE",trim_telemetry.last_value},
        {"EFM_TRIM_LAST_STAMP",trim_telemetry.last_stamp}};
    for(const auto& [name,value]:trim_parameters)param_api_.setParamNumber(param_handles_[name],value);

    const auto frame=ap_frame();
    const std::pair<const char*,double> ap_parameters[]={
        {"F22_AP_ACTIVE",autopilot.active()?1.:0.},{"F22_AP_ROLL_MODE",double(autopilot.lateral)},
        {"F22_AP_PITCH_MODE",double(autopilot.vertical)},{"F22_AP_AT",autopilot.at?1.:0.},
        {"F22_AP_MACH_HOLD",autopilot.mach_hold?1.:0.},{"F22_AP_HEADING",std::fmod(autopilot.selected_heading/RaptorAP::rad+360.,360.)},
        {"F22_AP_ALT",autopilot.selected_alt*3.280839895},{"F22_AP_VS",autopilot.selected_vs*196.850394},
        {"F22_AP_SPEED",autopilot.selected_speed*1.943844492},{"F22_AP_MACH",autopilot.selected_mach},
        {"F22_AP_REASON",double(autopilot.reason)},{"F22_AP_OVERRIDE",autopilot.override_held?1.:0.},
        {"F22_AP_NAV_OVERRIDE",autopilot.nav_override?1.:0.},
        {"F22_AP_LIMITED",(autopilot.pitch_limited||autopilot.roll_limited||autopilot.at_limited)?1.:0.},
        {"F22_AT_REASON",double(autopilot.at_reason)},{"F22_AT_FEEDBACK_UNTIL",autopilot.at_feedback_until},
        {"F22_AP_READY",frame.eligible()?1.:0.},{"F22_AP_CLOCK",RAPTOR::fm_clock},
        {"F22_AP_RALT",autopilot.captured_agl*3.280839895},
        {"EFM_FCS_INTEGRITY_VALID",1.},
        {"EFM_FCS_DAMAGED",(!RAPTOR::is_destroyed&&(RAPTOR::tail_integrity<=.5||RAPTOR::left_wing_integrity<=.5||RAPTOR::right_wing_integrity<=.5))?1.:0.}};
    for(const auto& [name,value]:ap_parameters)param_api_.setParamNumber(param_handles_[name],value);
    // Shared base-sensor WOW does not reflect this custom FM reliably.
    // Publish suspension-derived contact separately; Lua owns the legacy WoW bus.
    param_api_.setParamNumber(param_handles_["EFM_WEIGHT_ON_WHEELS"], RAPTOR::on_ground ? 1.0 : 0.0);
    param_api_.setParamNumber(param_handles_["EFM_GROUND_VALID"], 1.0);
    // Explicit percent units for our electrical system, independent of the
    // inherited aircraft's base-sensor RPM interpretation.
    param_api_.setParamNumber(param_handles_["EFM_ENGINE_LEFT_RPM_PCT"], left_engine_instruments.core * 100.0);
    param_api_.setParamNumber(param_handles_["EFM_ENGINE_RIGHT_RPM_PCT"], right_engine_instruments.core * 100.0);
    param_api_.setParamNumber(param_handles_["EFM_ENGINE_VALID"], 1.0);
    const std::pair<const char*,double> vehicle_parameters[] = {
        {"EFM_HYD_LEFT_PSI",hydraulics.left_psi},{"EFM_HYD_RIGHT_PSI",hydraulics.right_psi},
        {"EFM_ACTUATOR_AVAILABLE",actuator_available},
        {"EFM_ENGINE_LEFT_TEMP_C",left_engine_instruments.temperature_c},{"EFM_ENGINE_RIGHT_TEMP_C",right_engine_instruments.temperature_c},
        {"EFM_ENGINE_LEFT_OIL_PSI",left_engine_instruments.oil_psi},{"EFM_ENGINE_RIGHT_OIL_PSI",right_engine_instruments.oil_psi},
        {"EFM_ENGINE_LEFT_NOZZLE_PCT",left_engine_instruments.nozzle_pct},{"EFM_ENGINE_RIGHT_NOZZLE_PCT",right_engine_instruments.nozzle_pct},
        {"EFM_TVC_LEFT_DEG",RaptorVehicle::degrees(RAPTOR::left_tv_angle)},{"EFM_TVC_RIGHT_DEG",RaptorVehicle::degrees(RAPTOR::right_tv_angle)},
        {"EFM_ENGINE_LEFT_THRUST_N",RAPTOR::left_thrust_force},{"EFM_ENGINE_RIGHT_THRUST_N",RAPTOR::right_thrust_force},
        {"EFM_ENGINE_LEFT_THRUST_PCT",100*RaptorVehicle::unit(RaptorVehicle::relative_thrust(RAPTOR::left_thrust_force,RAPTOR::max_available_left_thrust))},
        {"EFM_ENGINE_RIGHT_THRUST_PCT",100*RaptorVehicle::unit(RaptorVehicle::relative_thrust(RAPTOR::right_thrust_force,RAPTOR::max_available_right_thrust))}};
    for(const auto& [name,value]:vehicle_parameters)param_api_.setParamNumber(param_handles_[name],value);
    param_api_.setParamNumber(param_handles_["EFM_VEHICLE_VALID"], 1.0);
    // DCS global axes: x=north, y=up, z=east; SI units throughout.
    param_api_.setParamNumber(param_handles_["EFM_HUD_VN"], RAPTOR::velocity_world.x);
    param_api_.setParamNumber(param_handles_["EFM_HUD_VE"], RAPTOR::velocity_world.z);
    param_api_.setParamNumber(param_handles_["EFM_HUD_VU"], RAPTOR::velocity_world.y);
    param_api_.setParamNumber(param_handles_["EFM_HUD_WN"], RAPTOR::wind.x);
    param_api_.setParamNumber(param_handles_["EFM_HUD_WE"], RAPTOR::wind.z);
    param_api_.setParamNumber(param_handles_["EFM_HUD_WU"], RAPTOR::wind.y);
    param_api_.setParamNumber(param_handles_["EFM_HUD_TAS"], RAPTOR::V_scalar);
    param_api_.setParamNumber(param_handles_["EFM_HUD_SOUND"], RAPTOR::speed_of_sound);
    param_api_.setParamNumber(param_handles_["EFM_HUD_PRESSURE"], RAPTOR::hud_static_pressure_pa);
    param_api_.setParamNumber(param_handles_["EFM_HUD_VALID"], 1.0);
    // EFM is the authoritative source; no fabricated 'full internal' subtraction.
    param_api_.setParamNumber(param_handles_["EFM_INTERNAL_FUEL_KG"], RAPTOR::internal_fuel);
    param_api_.setParamNumber(param_handles_["EFM_EXTERNAL_FUEL_KG"], RAPTOR::external_fuel);
    updateGearLights(dt);
    updateTaxiLandingLights(dt);
    updateAARLight(dt);
    updateFormationLights(dt);
    updateNavAntiCollisionLights(dt);
    vehicle_publish_mass();
    vehicle_publish();
}

void CockpitManager::updateDrawArgs(float* data, size_t size) {
    auto setArg = [&](int index, float value) {
        if (index >= 0 && static_cast<size_t>(index) < size) {
            data[index] = value;
        }
        };

    setArg(709, static_cast<float>(getParameter("TAXI_SWITCH", 0.0)));
    setArg(712, static_cast<float>(getParameter("AAR", 0.0)));
    setArg(713, static_cast<float>(getParameter("AAR_KNOB", 0.0)));
    setArg(714, static_cast<float>(getParameter("FORM_KNOB", 0.0)));
    setArg(715, static_cast<float>(getParameter("NAV_LIGHT_SWITCH", 0.0)));
}

double CockpitManager::getParameter(const std::string& name, double fallback_value) {
    if (!RAPTOR::sim_initialised) {
        bool engines_on = (RAPTOR::left_engine_state == RAPTOR::RUNNING || RAPTOR::right_engine_state == RAPTOR::RUNNING);
        if (name == "NAV_LIGHT_SWITCH") {
            if (engines_on) {
                if (name == "NAV_LIGHT_SWITCH") return 0.3;
            }
            return 0.0;
        }
        if (name == "TAXI_SWITCH") {
            if (engines_on && RAPTOR::gear_pos == 1.0) {
                if (name == "NAV_LIGHT_SWITCH") return 0.3;
                if (name == "TAXI_SWITCH") return RAPTOR::gear_pos == 1.0 ? -1.0 : 0.0;
            }
            return 0.0;
        }
    }
    auto it = param_handles_.find(name);
    if (it == param_handles_.end()) {
        return fallback_value;
    }

    double result = param_api_.getParamNumber(it->second);
    if (result != result) {
        if (name == "WoW") {
            return RAPTOR::on_ground ? 1.0 : 0.0;
        }
        else if (name == "MAIN_POWER" || name == "BATTERY_POWER") return 0.0;
        return fallback_value;
    }
    return result;
}

void CockpitManager::updateGearLights(double dt) {
    double battery_power = getParameter("BATTERY_POWER");
    double nose_gear = RAPTOR::gear_pos;
    double right_gear = RAPTOR::gear_pos;
    double left_gear = RAPTOR::gear_pos;

    double nose_gear_light = (nose_gear >= 1.0 && battery_power >= 1.0) ? 1.0 : 0.0;
    double right_gear_light = (right_gear >= 1.0 && battery_power >= 1.0) ? 1.0 : 0.0;
    double left_gear_light = (left_gear >= 1.0 && battery_power >= 1.0) ? 1.0 : 0.0;

    param_api_.setParamNumber(param_handles_["N_GEAR_LIGHT"], nose_gear_light);
    param_api_.setParamNumber(param_handles_["R_GEAR_LIGHT"], right_gear_light);
    param_api_.setParamNumber(param_handles_["L_GEAR_LIGHT"], left_gear_light);
}

void CockpitManager::commitGuidanceEntry(double sequence) {
    constexpr double maximum_sequence = 16777215.;
    if (!std::isfinite(sequence) || sequence < 1 || sequence > maximum_sequence ||
        sequence != std::floor(sequence) || getParameter("F22_ENTRY_GUIDANCE_ACTIVE") != 1 ||
        getParameter("F22_ENTRY_GUIDANCE_REQUEST") != sequence ||
        getParameter("F22_ENTRY_GUIDANCE_ACK_REQUEST") >= sequence) return;
    const double requested = getParameter("F22_ENTRY_GUIDANCE_COMMAND");
    const double value = getParameter("F22_ENTRY_GUIDANCE_VALUE");
    const bool valid_command = std::isfinite(requested) && requested >= 11010 &&
        requested <= 11015 && requested == std::floor(requested);
    const int command = valid_command ? static_cast<int>(requested) : 0;
    const bool accepted = getParameter("MAIN_POWER") > .5 &&
        RaptorCommands::target_valid(command, value);
    double committed = 0;
    if (accepted) {
        autopilot.command(11620 + command - 11010, ap_frame(), value);
        switch (command) {
        case 11010: committed = autopilot.selected_heading / RaptorAP::rad; break;
        case 11011: committed = autopilot.selected_alt * 3.280839895; break;
        case 11012: committed = autopilot.selected_vs * 196.850394; break;
        case 11013: committed = autopilot.selected_speed * 1.943844492; break;
        case 11014: committed = autopilot.selected_mach; break;
        case 11015: committed = autopilot.captured_agl * 3.280839895; break;
        default: break;
        }
    }
    const auto ack_value = param_handles_.find("F22_ENTRY_GUIDANCE_ACK_VALUE");
    const auto result = param_handles_.find("F22_ENTRY_GUIDANCE_RESULT");
    const auto ack_request = param_handles_.find("F22_ENTRY_GUIDANCE_ACK_REQUEST");
    if (ack_value == param_handles_.end() || result == param_handles_.end() ||
        ack_request == param_handles_.end()) return;
    param_api_.setParamNumber(ack_value->second, committed);
    param_api_.setParamNumber(result->second, accepted ? 1. : 2.);
    param_api_.setParamNumber(ack_request->second, sequence);
}

void CockpitManager::updateTaxiLandingLights(double dt) {
    double taxi_switch = getParameter("TAXI_SWITCH");
    double main_power = getParameter("MAIN_POWER");
    double nose_gear = RAPTOR::gear_pos;

    RAPTOR::taxi_lights = false;
    RAPTOR::landing_lights = false;

    if (taxi_switch == -1.0 && main_power >= 1.0 && nose_gear >= 1.0) {
        RAPTOR::taxi_lights = true;
    }
    else if (taxi_switch == 1.0 && main_power >= 1.0 && nose_gear >= 1.0) {
        RAPTOR::landing_lights = true;
    }
}

void CockpitManager::updateAARLight(double dt) {
    double aar = getParameter("AAR");
    double aar_knob = getParameter("AAR_KNOB");
    double main_power = getParameter("MAIN_POWER");
    double aar_ready = getParameter("AAR_READY");

    RAPTOR::aar_light = aar >= 1.0 && aar_ready >= 1.0 && main_power >= 1.0 ? RaptorVehicle::unit(aar_knob) : 0.0;
}

void CockpitManager::updateFormationLights(double dt) {
    double form_knob = getParameter("FORM_KNOB");
    double main_power = getParameter("MAIN_POWER");

    RAPTOR::form_light = main_power >= 1.0 ? RaptorVehicle::unit(form_knob) : 0.0;
}

void CockpitManager::updateNavAntiCollisionLights(double dt) {
    double light_switch = getParameter("NAV_LIGHT_SWITCH");
    double main_power = getParameter("MAIN_POWER");

    static double flash_timer = 0.0;
    flash_timer += dt;
    if (flash_timer >= 1.50) {
        flash_timer = 0.0;
    }
    RAPTOR::nav_white_timer = flash_timer;
    RAPTOR::anti_collision_timer = flash_timer;
    float flash_on = (flash_timer > 0.25) ? 1.0f : 0.0f;

    RAPTOR::nav_white = false;
    RAPTOR::anti_collision = false;
    RAPTOR::nav_lights = false;
    RAPTOR::nav_white_blink = false;
    RAPTOR::anti_collision_blink = false;

    if (main_power < 1.0 || light_switch <= 0.0) {
        flash_timer = 0.0;
        RAPTOR::nav_white_timer = 0.0;
        RAPTOR::anti_collision_timer = 0.0;
        return;
    }

    if (light_switch < 0.15) {
        RAPTOR::nav_white = true;
        RAPTOR::anti_collision = true;
        RAPTOR::nav_white_blink = true;
        RAPTOR::anti_collision_blink = true;
    }
    else if (light_switch < 0.25) {
        RAPTOR::nav_white = true;
        RAPTOR::anti_collision = true;
        RAPTOR::nav_lights = true;
        RAPTOR::anti_collision_blink = true;
    }
    else if (light_switch < 0.35) {
        RAPTOR::nav_white = true;
        RAPTOR::nav_lights = true;
        RAPTOR::nav_white_blink = true;
    }
    else {
        RAPTOR::nav_white = true;
        RAPTOR::nav_lights = true;
    }
}
