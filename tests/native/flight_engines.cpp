// R-FLT-008/009/012 and D-R-FLT-004. State/consent and achieved-authority oracle.
#include "flight_assert.h"
#include "EngineController.h"
#include "LandingGear.h"
#include "GroundContact.h"
#include "TrimControl.h"
#include "VehicleContext.h"
#include <iostream>
#include <limits>

namespace {
using namespace RaptorVehicle;
EngineInputs source() {
    EngineInputs input;
    input.powered = input.starter = input.feed = true;
    input.spool_up_per_s = input.spool_down_per_s = .1;
    return input;
}
void advance(EngineController& engine, const EngineInputs& input, double duration, double dt = .02) {
    const auto count = static_cast<unsigned>(std::round(duration / dt));
    flight_require(count <= 120000, "Engine test work exceeded declared bound");
    for (unsigned step = 0; step < count; ++step) {
        engine.update(input, dt);
        engine.delivered_fuel(engine.fuel_flow_kg_s(1, 0) * dt);
        flight_require(std::isfinite(engine.spool) && engine.spool >= 0 && engine.spool <= 1.1,
            "Engine spool escaped finite envelope");
    }
}
void start_and_feed_loss() {
    auto input = source();
    EngineController engine;
    flight_require(engine.start(input), "Qualified automatic start refused");
    advance(engine, input, 50);
    flight_require(engine.burning && engine.phase == EnginePhase::Running, "Healthy start failed to achieve running");
    flight_require(engine.fuel_flow_kg_s(1, 0) > 0 && engine.thrust_n(6000, 100000, 150000) > 0,
        "Running engine did not deliver fuel/thrust");
    input.feed = false; advance(engine, input, .02);
    flight_require(!engine.burning && !engine.start_state.fuel_valve && !engine.requested,
        "Feed loss retained combustion consent");
    flight_require(engine.thrust_n(6000, 100000, 150000) == 0, "Unlit engine retained thrust");
    input.feed = true; advance(engine, input, 2);
    flight_require(!engine.burning && !engine.requested, "Feed restoration replayed old start");
    flight_require(engine.start(input), "Fresh restart consent refused after feed restoration");
    advance(engine, input, 50);
    flight_require(engine.burning, "Fresh restart did not restore combustion");
}
void manual_and_control() {
    auto input = source();
    EngineController engine;
    engine.select_starter(true);
    advance(engine, input, 12);
    flight_require(engine.spool > .1 && !engine.burning && !engine.start_state.fuel_valve,
        "Dry crank admitted fuel without pilot consent");
    engine.select_fuel(true); engine.select_ignition(true);
    advance(engine, input, 40);
    flight_require(engine.phase == EnginePhase::Running && engine.burning, "Manual start did not run");
    input.control = EngineControl::Degraded; input.throttle = 1;
    advance(engine, input, 10);
    flight_require(engine.burning && engine.spool <= .95 && engine.vector_authority() == .5 &&
        engine.augmentation_fraction() == 0, "Degraded control did not restrict achieved authority");
    input.control = EngineControl::Unavailable; advance(engine, input, .02);
    flight_require(!engine.burning && engine.start_state.fault == EngineFault::ControlLoss,
        "Lost control retained combustion");
    input.control = EngineControl::Normal; advance(engine, input, 1);
    flight_require(!engine.burning, "Restored control replayed combustion");
    engine.stop(); engine.select_starter(false); advance(engine, input, 1);
    flight_require(engine.reset_fault(input), "Safe explicit controller reset refused");
    flight_require(!engine.burning && !engine.requested, "Controller reset started engine");
}
void no_light_and_reset() {
    auto input = source();
    input.ignition_failed = true;
    EngineController engine;
    flight_require(engine.start(input), "No-light test did not admit qualified motoring");
    advance(engine, input, 30);
    flight_require(engine.start_state.fault == EngineFault::NoLight && !engine.burning &&
        engine.start_state.purge_remaining_s > 0, "No-light delivery failed to require purge");
    input.ignition_failed = false;
    flight_require(!engine.reset_fault(input), "Reset bypassed required purge");
    engine.stop(); engine.select_starter(true);
    // The rotor must first reaccelerate to the declared purge-speed guard.
    // Elapsed wall time alone cannot complete a purge from a stopped rotor.
    advance(engine, input, 20);
    flight_require(engine.start_state.purge_remaining_s == 0 && !engine.start_state.fuel_valve,
        "Fuel-off motoring did not complete purge");
    engine.select_starter(false); advance(engine, input, 16);
    flight_require(engine.reset_fault(input) && !engine.burning, "Safe reset failed or replayed start");
}
void invalid_and_convergence() {
    const double nan = std::numeric_limits<double>::quiet_NaN();
    for (unsigned field = 0; field < 4; ++field) {
        auto input = source();
        if (field == 0) input.throttle = nan;
        if (field == 1) input.health = -1;
        if (field == 2) input.temperature_c = nan;
        if (field == 3) input.spool_up_per_s = nan;
        EngineController engine; engine.reset(true);
        engine.update(input, .02);
        flight_require(!engine.burning && !engine.control_available &&
            engine.start_state.fault == EngineFault::InvalidInput, "Invalid engine source remained admitted");
    }
    double reference = 0;
    for (double dt : {.005, .01, .02, .1}) {
        auto input = source(); input.throttle = 1;
        EngineController engine; engine.reset(true);
        advance(engine, input, 60, dt);
        const double flow = engine.fuel_flow_kg_s(1, 0);
        if (reference == 0) reference = flow;
        flight_require(std::abs(flow - reference) <= .01 * reference,
            "Steady engine fuel failed declared timestep convergence tolerance");
    }
}
void achieved_gear_and_contact() {
    LandingGear gear;
    gear.reset(true);
    gear.update(.02, false, 0, {1, 1, 1});
    flight_require(gear.down_locked(), "Pressure loss erased achieved down locks");
    gear.update(.02, true, 1, {1, 0, 1});
    flight_require(gear.legs[0].down_locked() && !gear.legs[1].down_locked() &&
        gear.legs[2].down_locked() && gear.unsafe(), "One damaged leg invalidated the wrong lock");
    gear.reset(false);
    for (unsigned step = 0; step < 100; ++step) gear.update(.02, true, 1, {1, 0, 1});
    flight_require(gear.legs[1].position == 0 && gear.legs[0].position > 0,
        "Damaged leg moved with healthy legs");
    GroundContact contact;
    contact.sample(0, .1, 0, 5000, 0, 1);
    contact.update({1, 0, 0}, 0, true, 1);
    flight_require(contact.valid && contact.loaded, "One deployed loaded leg was ignored");
    contact.update({1, 0, 0}, 0, true, 1.2);
    flight_require(!contact.valid && !contact.loaded, "Stale contact remained authoritative");
}
void trim_and_repair() {
    RaptorTrim::Controller trim;
    trim.command(95); trim.update(1, true);
    flight_require(trim.pitch > 0, "Held trim did not advance");
    trim.command(215); const double achieved = trim.pitch; trim.update(1, true);
    flight_require(trim.pitch == achieved, "Released trim continued moving");
    trim.command(97);
    flight_require(trim.pitch == 0 && trim.roll == 0 && trim.yaw == 0 && !trim.pitch_busy(),
        "Trim reset retained an input history");
    VehicleContext vehicle; vehicle.reset(true);
    vehicle.fuel.set_internal(3000); vehicle.ses.air = .2;
    vehicle.environment.backup_reserve = .3;
    vehicle.left_brake.temperature_c = 700; vehicle.left_brake.tire_failed = true;
    vehicle.left_engine.stop(); vehicle.left_engine.burning = false;
    vehicle.repair_equipment();
    flight_require(vehicle.fuel.internal_kg() == 3000 && vehicle.ses.air == .2 &&
        vehicle.environment.backup_reserve == .3 && vehicle.left_brake.temperature_c == 700 &&
        !vehicle.left_engine.burning && !vehicle.left_brake.tire_failed,
        "Equipment repair changed resources, heat or engine consent");
}
}
int main() {
    try {
        start_and_feed_loss(); manual_and_control(); no_light_and_reset();
        invalid_and_convergence(); achieved_gear_and_contact(); trim_and_repair();
        std::cout << "Engine, FCS/trim, achieved gear/contact and repair cases passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
