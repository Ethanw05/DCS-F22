#include "../EFM/source/VehicleContext.h"
#include "../EFM/source/ThrustDeck.h"
#include <cassert>
#include <iostream>
#include <limits>
#include <crtdbg.h>

namespace {
void air_data_contract() {
    for (const double mach : {0.0, 0.3, 0.9, 1.0, 1.01, 1.5, 2.4}) {
        const auto frame = RaptorAirData::calculate(mach * RaptorAirData::sea_sound_mps,
            RaptorAirData::sea_sound_mps, 1.225, 101325.0, 10.0);
        assert(frame.valid);
        assert(std::abs(frame.cas_mps - frame.tas_mps) < 1e-8);
        assert(std::abs(frame.eas_mps - frame.tas_mps) < 1e-8);
    }
    const auto high = RaptorAirData::calculate(300.0, 295.0, 0.4135, 22632.0, 11.0);
    assert(high.valid && high.eas_mps < high.cas_mps && high.cas_mps < high.tas_mps);
    assert(!RaptorAirData::calculate(100, 0, 1.225, 101325, 0).valid);
    assert(!RaptorAirData::calculate(100, 340, -1, 101325, 0).valid);
    assert(!RaptorAirData::calculate(100, 340, 1.225, -1, 0).valid);
    RaptorAirData::Sensor sensor;
    sensor.update(high, RaptorAirData::Health::Healthy, 0);
    auto next = RaptorAirData::calculate(350.0, 295.0, 0.4135, 22632.0, 12.0);
    sensor.update(next, RaptorAirData::Health::Frozen, 0);
    assert(sensor.measured.stamp_s == 11.0 && sensor.measured.cas_mps == high.cas_mps);
    sensor.update(next, RaptorAirData::Health::Invalid, 0);
    assert(!sensor.measured.valid && next.valid);
    sensor.update(next, RaptorAirData::Health::Biased, 20.0);
    assert(sensor.measured.valid && sensor.measured.cas_mps == next.cas_mps + 20.0);
    assert(next.cas_mps != sensor.measured.cas_mps);
}

void mass_and_damage_capacity() {
    RaptorVehicle::MassLedger ledger;
    for (int index = 0; index < 10000; ++index) assert(ledger.add(0.01, -0.16, 0, 0));
    assert(ledger.add(-50, -0.16, 0, 0));
    RaptorVehicle::MassTransaction change;
    assert(ledger.pop(change) && std::abs(change.kg - 50.0) < 1e-8);
    assert(!ledger.pop(change));
    for (std::size_t index = 0; index < ledger.capacity; ++index)
        assert(ledger.add(1, static_cast<double>(index), 0, 0));
    assert(!ledger.add(1, 1000, 0, 0) && ledger.overflow);
    ledger.clear();
    assert(!ledger.overflow && !ledger.add(std::numeric_limits<double>::quiet_NaN(), 0, 0, 0));
    RaptorVehicle::DamageLedger damage;
    assert(!damage.add(-1, 0) && !damage.add(137, 0));
    for (int index = 0; index < 10000; ++index) assert(damage.add(25, 0.25));
    RaptorVehicle::DamageNotice notice;
    assert(damage.pop(notice) && notice.element == 25 && notice.integrity == 0.25);
    assert(!damage.pop(notice));
}

void power_and_start_chain() {
    RaptorVehicle::Power power;
    RaptorVehicle::StoredEnergy ses;
    RaptorVehicle::PowerFaults faults;
    power.reset(false);
    power.requests.battery = power.requests.apu = true;
    for (int index = 0; index < 1000; ++index) power.update(.01, 0, 0, true, true, faults, ses);
    assert(power.apu_running && power.main && power.conditioned_air && power.apu_hydraulics);
    assert(ses.air < 1.0 && ses.start_fuel < 1.0 && power.soc < 1.0);
    RaptorVehicle::EngineController engine;
    RaptorVehicle::EngineInputs input;
    input.feed = true;
    assert(!engine.start(input) && engine.rejection == RaptorVehicle::StartRejection::NoPower);
    input.powered = true;
    assert(!engine.start(input) && engine.rejection == RaptorVehicle::StartRejection::NoStarter);
    input.starter = power.apu_running;
    assert(engine.start(input));
    double start_burn = 0;
    for (int index = 0; index < 4500; ++index) {
        engine.update(input, .01);
        start_burn += engine.fuel_flow_kg_s(1, 0) * .01;
    }
    assert(engine.phase == RaptorVehicle::EnginePhase::Running && start_burn > 1.0);
    input.feed = false;
    engine.update(input, .01);
    assert(!engine.burning && !engine.requested && engine.thrust_n(6000, 110000, 155000) == 0);
    input.feed = true;
    engine.update(input, .01);
    assert(!engine.burning); // fuel restoration is not automatic start consent
    faults.apu = true;
    power.update(.01, 0, 0, true, true, faults, ses);
    assert(!power.apu_running && power.apu_abort && !power.main);
    power.reset(true);
    power.requests.apu = true;
    power.apu_spool = 1;
    power.apu_armed = false;
    faults = {};
    power.update(20, .67, .67, true, true, faults, ses);
    faults.right_generator = true;
    power.update(30, .67, .67, true, true, faults, ses);
    assert(power.apu_autooff_s == 0 && !power.automatic_shutdown);
    faults.right_generator = false;
    power.update(59, .67, .67, true, true, faults, ses);
    assert(!power.automatic_shutdown);
    power.update(1, .67, .67, true, true, faults, ses);
    assert(power.automatic_shutdown);
    power.reset(false);
    power.requests.battery = true;
    for (int index = 0; index < 2500; ++index) power.update(1, 0, 0, true, true, faults, ses);
    assert(power.soc == 0 && !power.essential && power.volts == 0);
    power.requests.ground_power = true;
    power.update(120, 0, 0, true, true, faults, ses);
    assert(power.main && power.soc > 0);
}

void finite_utilities_and_repair() {
    RaptorVehicle::Environment environment;
    RaptorVehicle::EnvironmentInputs input;
    environment.reset(false);
    environment.update(input, 60);
    assert(environment.backup_reserve == 1 && !environment.backup);
    input.powered = input.left_bleed = true;
    input.ambient_pa = 25000;
    for (int index = 0; index < 1000; ++index) environment.update(input, .02);
    assert(environment.obogs && environment.cabin_overpressure_pa > 30000);
    input.left_bleed = false;
    environment.update(input, .1);
    assert(environment.backup && !environment.obogs && environment.backup_reserve < 1);
    for (int index = 0; index < 30001; ++index) environment.update(input, .02);
    environment.update(input, .02);
    assert(environment.backup_reserve == 0 && !environment.backup && environment.oxygen_delivery_pa == 0);
    input.left_bleed = true;
    environment.update(input, .02);
    assert(environment.obogs && environment.backup_reserve == 0);
    RaptorVehicle::StoredEnergy ses;
    RaptorVehicle::Configuration config;
    bool gear = true;
    assert(!config.request_gear(false, true, 0, gear) && gear);
    assert(config.request_gear(false, false, 80, gear) && !gear);
    assert(!config.request_gear(true, false, 280, gear));
    assert(config.extend_alternate(ses, gear) && gear && ses.air == .75);
    assert(config.extend_alternate(ses, gear) && ses.air == .75);
    assert(!config.request_gear(false, false, 200, gear));
    double left = 0, right = 0;
    config.allocate(.8, 1, left, right);
    assert(std::abs((left + right) * .5 - .8) < 1e-12 && left >= -1 && right <= 1);
    RaptorVehicle::VehicleContext context;
    context.power.soc = .2;
    context.environment.backup_reserve = .3;
    context.ses.air = .4;
    context.left_brake.temperature_c = 250;
    context.left_fire_isolated = true;
    context.repair_equipment();
    assert(context.power.soc == .2 && context.environment.backup_reserve == .3 && context.ses.air == .4);
    assert(context.left_brake.temperature_c == 250 && !context.left_fire_isolated && !context.left_engine.requested);
    assert(RaptorVehicle::continue_thrust(0, 2.4, 1.8, 230000) > 100000);
    assert(RaptorVehicle::continue_thrust(0, 3.0, 1.8, 230000) ==
        RaptorVehicle::continue_thrust(0, 2.4, 1.8, 230000));
}

void feed_transfer_conservation() {
    RaptorVehicle::FuelSystem fuel;
    RaptorVehicle::MassLedger ledger;
    fuel.set_internal(8200);
    assert(fuel.internal_kg() == 8200);
    fuel.boost = 1;
    assert(fuel.feed_available(true, false) && !fuel.feed_available(true, true));
    const double first_burn = fuel.burn(1, 100, false, ledger);
    assert(first_burn == 100 && fuel.internal_kg() == 8100);
    fuel.transfer_internal(40, ledger);
    assert(std::abs(fuel.internal_kg() - 8100) < 1e-8 && fuel.cells[1].quantity_kg > 1400);
    RaptorVehicle::MassTransaction entry;
    double mass_kg = 0;
    for (int index = 0; index < 65; ++index) {
        if (!ledger.pop(entry)) break;
        mass_kg += entry.kg;
    }
    assert(std::abs(mass_kg - 100) < 1e-8);
    fuel.cells[1].quantity_kg = RaptorVehicle::FuelSystem::unusable_feed_kg;
    assert(fuel.internal_kg() > 6000 && !fuel.feed_available(true, false));
    assert(fuel.burn(1, 10, false, ledger) == 0);
    fuel.transfer_internal(40, ledger);
    assert(fuel.feed_available(true, false));
    const double before = fuel.internal_kg();
    assert(fuel.burn(1, 100, true, ledger) == 100 && fuel.internal_kg() == before);
    ledger.clear();
    const double external = fuel.transfer_external(100, {0,0,-3}, 40, ledger);
    assert(external > 0 && std::abs(fuel.internal_kg() - before - external) < 1e-8);
    double net_transfer = 0;
    for (int index = 0; index < 65; ++index) {
        if (!ledger.pop(entry)) break;
        net_transfer += entry.kg;
    }
    assert(std::abs(net_transfer) < 1e-8);
    fuel.set_internal(0);
    assert(fuel.accept_internal(10000, ledger) == 8200 && fuel.internal_kg() == 8200);
    assert(fuel.accept_internal(1, ledger) == 0);
}

void independent_oxygen_sources() {
    RaptorVehicle::Environment environment;
    RaptorVehicle::EnvironmentInputs input;
    environment.reset(true);
    input.powered = input.left_bleed = true;
    environment.update(input, .02);
    assert(environment.obogs && !environment.backup);
    input.backup_manual = true;
    environment.update(input, .02);
    assert(environment.obogs && environment.backup && environment.backup_reserve < 1.0);
    input.backup_manual = false;
    input.canopy_position = std::numeric_limits<double>::quiet_NaN();
    environment.update(input, .02);
    assert(!environment.valid && environment.obogs && !environment.backup);
    input.ambient_pa = std::numeric_limits<double>::quiet_NaN();
    const double reserve = environment.backup_reserve;
    environment.update(input, .02);
    assert(!environment.valid && !environment.obogs && environment.backup);
    assert(environment.backup_reserve < reserve && environment.oxygen_delivery_pa == 101000.0);
    const double after = environment.backup_reserve;
    environment.update(input, std::numeric_limits<double>::quiet_NaN());
    assert(environment.backup_reserve == after);
}

void brake_heat_fade_and_tires() {
    RaptorVehicle::BrakeEnergy brake;
    brake.normal_force_n = 150000;
    brake.update(1, 0, 25, true, .01);
    assert(brake.energy_j == 0 && brake.temperature_c == 25);
    brake.update(1, 70, 25, false, .01);
    assert(brake.energy_j == 0); // airborne/unloaded pedal is not a heater
    for (int index=0; index<3000; ++index)
        brake.update(brake.effectiveness(), 70, 25, true, .01);
    assert(brake.temperature_c > 450 && brake.effectiveness() < 1);
    const double disc = brake.temperature_c, tire = brake.tire_temperature_c;
    const double work = brake.energy_j;
    for (int index=0; index<30000; ++index) brake.update(0, 0, 25, true, .01);
    assert(brake.energy_j == work && brake.temperature_c < disc);
    assert(brake.tire_temperature_c > tire && brake.tire_failed);
    assert(brake.extra_rolling_force(30,true) < 0);
    assert(brake.extra_rolling_force(-30,true) > 0);
    assert(brake.extra_rolling_force(0,true) == 0);
    assert(brake.extra_rolling_force(30,false) == 0);
    const double remaining = brake.temperature_c;
    brake.update(1, 100, 25, true, std::numeric_limits<double>::quiet_NaN());
    assert(brake.temperature_c == remaining);
    RaptorVehicle::VehicleContext vehicle;
    vehicle.left_brake = brake;
    vehicle.repair_equipment();
    assert(!vehicle.left_brake.tire_failed && vehicle.left_brake.temperature_c == remaining);
    brake.contact_stamp_s = 10;
    assert(brake.contact_fresh(10.05) && !brake.contact_fresh(10.11));
}

void fuel_transaction_boundaries() {
    RaptorVehicle::FuelSystem fuel;
    RaptorVehicle::MassLedger ledger;
    const double invalid = std::numeric_limits<double>::quiet_NaN();
    fuel.set_internal(4000);
    for (double amount : {-100.0, invalid, std::numeric_limits<double>::infinity()}) {
        if (!std::isfinite(amount) || amount<0) fuel.set_internal(amount);
        assert(fuel.accept_internal(amount,ledger) == 0);
        assert(fuel.transfer_external(100,{0,0,-3},amount,ledger) == 0);
        fuel.transfer_internal(amount,ledger);
        assert(fuel.internal_kg() == 4000);
    }
    assert(!ledger.transfer(-1,{0,0,0},{1,0,0}));
    RaptorVehicle::MassTransaction entry;
    assert(!ledger.pop(entry));
    // Canceled locations do not permanently exhaust the fixed transaction queue.
    for (int index=0; index<1000; ++index) {
        assert(ledger.add(1,index,0,0));
        assert(ledger.add(-1,index,0,0));
    }
    assert(!ledger.pop(entry));
    const double huge = std::numeric_limits<double>::max();
    assert(ledger.add(huge,0,0,0) && !ledger.add(huge,0,0,0));
    assert(ledger.pop(entry) && entry.kg == huge);
    for (int index=0; index<64; ++index) assert(ledger.add(1,100+index,0,0));
    assert(fuel.accept_internal(100,ledger) == 0 && fuel.internal_kg() == 4000);
    assert(fuel.transfer_external(100,{0,0,-3},100,ledger) == 0);
    assert(fuel.internal_kg() == 4000);
    ledger.clear();
    assert(fuel.accept_internal(100,ledger) == 100 && fuel.internal_kg() == 4100);
}
} // namespace

int main() {
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
    _CrtSetReportMode(_CRT_ASSERT, _CRTDBG_MODE_FILE);
    _CrtSetReportFile(_CRT_ASSERT, _CRTDBG_FILE_STDERR);
    air_data_contract();
    mass_and_damage_capacity();
    power_and_start_chain();
    finite_utilities_and_repair();
    feed_transfer_conservation();
    independent_oxygen_sources();
    brake_heat_fade_and_tires();
    fuel_transaction_boundaries();
    std::cout << "physical contract: SI air data, bounded conservation, causal start, finite supplies, repair scopes OK\n";
}
