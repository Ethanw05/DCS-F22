#include "../EFM/source/EngineController.h"
#include <cassert>
#include <cmath>
#include <crtdbg.h>
#include <iostream>
#include <limits>

using namespace RaptorVehicle;
namespace {
struct EngineFixture {
    EngineController engine;
    Engine instruments;
    EngineInputs input;
    double delivered_kg = 0.0;
    double peak_c = 15.0;
    EngineFixture(bool hot = false) {
        engine.reset(hot);
        instruments.reset(hot ? .67 : 0.0, 288.15);
        input.powered = input.starter = input.feed = true;
    }
    void ticks(int count) {
        assert(count >= 0 && count <= 20000);
        for (int index=0;index<count;++index) {
            input.temperature_c = instruments.temperature_c;
            engine.update(input,.01);
            const double kg = engine.fuel_flow_kg_s(1.0,0.0) * .01;
            engine.delivered_fuel(kg);
            delivered_kg += kg;
            instruments.update(engine.spool,engine.burning,engine.augmentation_fraction(),
                288.15,.01,engine.extra_start_heat_c,engine.start_state.starter_engaged);
            peak_c = std::max(peak_c,instruments.temperature_c);
            assert(std::isfinite(kg) && kg >= 0.0);
            if (!engine.burning) assert(engine.thrust_n(6000,110000,155000) == 0.0);
        }
    }
    void purge_and_reset() {
        engine.select_fuel(false);
        engine.select_starter(false);
        ticks(1600); // rest protects the finite starter duty before another crank
        engine.select_starter(true);
        ticks(1800);
        assert(engine.start_state.purge_remaining_s == 0.0);
        engine.select_starter(false);
        input.temperature_c = instruments.temperature_c;
        assert(engine.reset_fault(input));
        assert(!engine.burning && !engine.start_state.fuel_valve);
    }
};

void dry_crank_and_manual_start() {
    EngineFixture f;
    f.input.feed = false;
    f.engine.select_starter(true); f.ticks(1500);
    assert(f.engine.phase == EnginePhase::Cranking && f.engine.spool == .2);
    assert(f.delivered_kg == 0.0 && !f.engine.burning);
    f.engine.select_ignition(true); f.engine.select_fuel(true); f.ticks(10);
    assert(!f.engine.start_state.fuel_valve && f.engine.rejection == StartRejection::NoFuel);
    f.input.feed = true; f.ticks(1900);
    assert(f.engine.spool > .4 && f.engine.burning);
    f.engine.select_starter(false); f.engine.select_ignition(false); f.ticks(1600);
    assert(f.engine.phase == EnginePhase::Running && f.delivered_kg > 1.0);
    f.input.feed = false; f.ticks(1);
    assert(!f.engine.burning && !f.engine.requested);
    f.input.feed = true; f.ticks(20);
    assert(!f.engine.burning); // restored feed does not reopen a tripped fuel selection
}

void no_light_and_purge() {
    EngineFixture f;
    f.input.ignition_failed = true;
    assert(f.engine.start(f.input)); f.ticks(2500);
    assert(f.engine.start_state.fault == EngineFault::NoLight && !f.engine.burning);
    assert(f.delivered_kg > .2 && f.engine.start_state.purge_remaining_s > 0.0);
    const double before = f.delivered_kg;
    f.input.ignition_failed = false; f.ticks(100);
    assert(f.delivered_kg == before && !f.engine.start(f.input));
    assert(!f.engine.reset_fault(f.input));
    f.purge_and_reset();
    assert(f.engine.start(f.input)); f.ticks(4500);
    assert(f.engine.phase == EnginePhase::Running);
}

void hung_and_hot_start() {
    EngineFixture hung;
    hung.input.hung_start = true;
    assert(hung.engine.start(hung.input));
    for (int index=0;index<70;++index) {
        // Repeated saved start commands must not restart the detection timer.
        static_cast<void>(hung.engine.start(hung.input)); hung.ticks(100);
    }
    assert(hung.engine.start_state.fault == EngineFault::HungStart && !hung.engine.burning);
    hung.input.hung_start = false; hung.purge_and_reset();
    EngineFixture hot;
    hot.input.hot_start = true;
    assert(hot.engine.start(hot.input)); hot.ticks(2500);
    assert(hot.peak_c >= EngineStartProfile::hot_start_c);
    assert(hot.engine.start_state.fault == EngineFault::HotStart && !hot.engine.burning);
    assert(!hot.engine.reset_fault(hot.input));
    hot.input.hot_start = false; hot.purge_and_reset();
    assert(hot.engine.start(hot.input)); hot.ticks(4500);
    assert(hot.engine.phase == EnginePhase::Running && hot.engine.start_state.fault == EngineFault::None);
    EngineFixture warm(true);
    warm.engine.stop(); warm.ticks(1); warm.input.hung_start = true;
    assert(warm.engine.start(warm.input)); warm.ticks(5000);
    assert(warm.engine.start_state.fault == EngineFault::HungStart);
}

void control_and_augmentation() {
    EngineFixture f(true);
    f.input.throttle = 1.0; f.ticks(1500);
    assert(f.engine.augmentation_fraction() > .99);
    f.input.control = EngineControl::Degraded; f.ticks(1);
    assert(f.engine.burning && f.engine.augmentation_fraction() == 0.0);
    assert(f.engine.vector_authority() == .5);
    f.ticks(300);
    assert(f.engine.spool <= EngineStartProfile::degraded_max_core);
    f.input.control = EngineControl::Normal; f.ticks(500);
    assert(f.engine.augmentation_fraction() > .99);
    f.input.augmentation_failed = true; f.ticks(1);
    assert(f.engine.burning && f.engine.augmentation_fraction() == 0.0 && f.engine.vector_authority() == 1.0);
    f.ticks(200);
    assert(f.instruments.nozzle_pct == 0.0 && f.engine.spool > 1.09);
    f.input.control = EngineControl::Unavailable; f.ticks(1);
    assert(f.engine.start_state.fault == EngineFault::ControlLoss && !f.engine.burning);
    assert(f.engine.vector_authority() == 0.0 && !f.engine.reset_fault(f.input));
    f.input.control = EngineControl::Normal; f.ticks(1500);
    assert(!f.engine.burning);
    f.purge_and_reset();
}

void source_loss_duty_and_invalidity() {
    EngineFixture f;
    assert(f.engine.start(f.input)); f.ticks(500);
    f.input.powered = false; f.ticks(1);
    assert(!f.engine.requested && !f.engine.burning);
    f.input.powered = true; f.ticks(100);
    assert(!f.engine.burning && !f.engine.start_state.fuel_selected);
    f.engine.select_starter(true); f.ticks(6100);
    assert(f.engine.start_state.fault == EngineFault::StarterDuty && !f.engine.start_state.starter_engaged);
    const double spool = f.engine.spool, duty = f.engine.start_state.starter_duty_s;
    f.engine.update(f.input,std::numeric_limits<double>::quiet_NaN());
    assert(f.engine.spool == spool && f.engine.start_state.starter_duty_s == duty);
    f.input.temperature_c = std::numeric_limits<double>::quiet_NaN();
    f.engine.update(f.input,.01);
    assert(!f.engine.burning && !f.engine.reset_fault(f.input));
}

void windmill_relight_and_start_interlock() {
    EngineFixture f;
    f.input.ground = false; f.input.tas_mps = 200; f.input.starter = false;
    assert(!f.engine.start(f.input)); f.ticks(1500);
    assert(f.engine.spool >= .15 && f.engine.start(f.input));
    f.ticks(4000);
    assert(f.engine.phase == EnginePhase::Running && !f.engine.start_state.starter_engaged);
    EngineFixture cold;
    cold.engine.select_fuel(true); cold.engine.select_ignition(true); cold.ticks(100);
    assert(!cold.engine.start_state.fuel_valve && cold.delivered_kg == 0.0);
    assert(cold.engine.rejection == StartRejection::WaitForRotor);
    cold.engine.spool = .5; cold.input.powered = false; cold.ticks(1);
    assert(!cold.engine.start_state.fuel_valve && cold.delivered_kg == 0.0);
    assert(cold.engine.rejection == StartRejection::NoPower);
}
} // namespace

int main() {
    _set_abort_behavior(0,_WRITE_ABORT_MSG | _CALL_REPORTFAULT);
    _CrtSetReportMode(_CRT_ASSERT,_CRTDBG_MODE_FILE);
    _CrtSetReportFile(_CRT_ASSERT,_CRTDBG_FILE_STDERR);
    dry_crank_and_manual_start(); no_light_and_purge(); hung_and_hot_start();
    control_and_augmentation(); source_loss_duty_and_invalidity(); windmill_relight_and_start_interlock();
    std::cout << "engine workflow: dry/manual/automatic start, delivered fuel, faults, purge/control/recovery PASS\n";
}
