// R-FLT-004/006/007, D-R-FLT-002/003. Independent conservation and refusal oracle.
#include "flight_assert.h"
#include "FuelSystem.h"
#include "VehiclePower.h"
#include "VehicleEnvironment.h"
#include "VehicleConfiguration.h"
#include "BrakeEnergy.h"
#include <array>
#include <iostream>
#include <limits>

namespace {
using namespace RaptorVehicle;
using Totals = std::array<double, 4>;
Totals inventory(const FuelSystem& fuel, double external) {
    Totals result{external, 4 * external, 0, 2 * external};
    for (const auto& cell : fuel.cells) {
        result[0] += cell.quantity_kg;
        for (std::size_t axis = 0; axis < 3; ++axis)
            result[axis + 1] += cell.quantity_kg * cell.position_m[axis];
        flight_require(cell.quantity_kg >= 0 && cell.quantity_kg <= cell.capacity_kg,
            "Fuel cell escaped its finite capacity");
    }
    return result;
}
Totals drain(MassLedger& ledger) {
    Totals result{};
    MassTransaction transaction;
    unsigned count = 0;
    while (ledger.pop(transaction)) {
        flight_require(++count <= 64, "Mass ledger exceeded its declared capacity");
        result[0] += transaction.kg;
        result[1] += transaction.kg * transaction.x_m;
        result[2] += transaction.kg * transaction.y_m;
        result[3] += transaction.kg * transaction.z_m;
    }
    return result;
}
void conservation_campaign() {
    FuelSystem fuel;
    fuel.set_internal(4100);
    MassLedger ledger;
    double external = 600, expected_mass = 4700;
    unsigned random = 1729;
    double maximum_error = 0;
    for (unsigned event = 0; event < 20000; ++event) {
        const auto before = inventory(fuel, external);
        random = 1664525u * random + 1013904223u;
        const double request = static_cast<double>((random >> 8) % 1000) / 127.0;
        switch (event % 4) {
        case 0: expected_mass -= fuel.burn(event % 3, request, false, ledger); break;
        case 1: expected_mass += fuel.accept_internal(request, ledger); break;
        case 2: fuel.transfer_internal(request, ledger); break;
        default: external -= fuel.transfer_external(external, {4, 0, 2}, request, ledger); break;
        }
        const auto after = inventory(fuel, external);
        const auto removed = drain(ledger);
        for (std::size_t field = 0; field < 4; ++field) {
            const double error = std::abs(before[field] - after[field] - removed[field]);
            maximum_error = std::max(maximum_error, error);
            flight_require(error < 1e-8, "Fuel mass/first moment disagrees with host ledger");
        }
        flight_require(flight_close(after[0], expected_mass), "Independent running fuel ledger failed");
    }
    std::cout << "Fuel:20000events, max mass/moment identity error=" << maximum_error << '\n';
}
void capacity_refusal() {
    FuelSystem fuel;
    fuel.set_internal(4100);
    const auto before = inventory(fuel, 0);
    MassLedger ledger;
    for (unsigned i = 0; i < 64; ++i)
        flight_require(ledger.add(1, 100 + i, 0, 0), "Cannot fill ledger to declared bound");
    flight_require(fuel.burn(1, 10, false, ledger) == 0, "Full ledger removed unreported fuel");
    fuel.transfer_internal(40, ledger);
    flight_require(inventory(fuel, 0) == before, "Refused transfer changed half its resource state");
    flight_require(!ledger.transfer(1, {1000, 0, 0}, {1001, 0, 0}), "Full ledger accepted paired transfer");
    const auto unchanged = drain(ledger);
    flight_require(unchanged[0] == 64 && unchanged[1] == 64 * 100 + 63 * 64 / 2,
        "Refused paired transaction partially changed ledger");
    flight_require(fuel.burn(1, 10, false, ledger) == 10, "Freed capacity did not admit a fresh burn");
    flight_require(drain(ledger)[0] == 10, "Recovered burn was not charged once");
}
void stored_energy() {
    const double nan = std::numeric_limits<double>::quiet_NaN();
    for (double bad : {nan, std::numeric_limits<double>::infinity(), -1.0, 1.1}) {
        for (bool air_request : {false, true}) {
            StoredEnergy ses;
            flight_require(!ses.consume(air_request ? bad : 0, air_request ? 0 : bad),
                "Invalid stored-energy request accepted");
            flight_require(ses.air == 1 && ses.start_fuel == 1, "Rejected request changed a reserve");
        }
    }
    StoredEnergy ses;
    flight_require(ses.consume(1, 1), "Exact finite reserve exhaustion refused");
    flight_require(ses.air == 0 && ses.start_fuel == 0 && !ses.consume(.01, 0),
        "Exhausted reserve created another action");
    ses.recharge(1, false, false);
    flight_require(ses.air == 0 && ses.start_fuel == 0, "Absent source recharged SES");
    ses.recharge(1, true, true);
    flight_require(ses.air > 0 && ses.start_fuel > 0, "Qualified source could not recharge SES");
}
void source_loss_and_zero_time() {
    Power power;
    StoredEnergy ses;
    PowerFaults faults;
    power.requests.battery = power.requests.apu = true;
    for (unsigned i = 0; i < 600; ++i) power.update(.02, 0, 0, true, true, faults, ses);
    flight_require(power.apu_running && power.main && power.apu_hydraulics,
        "Finite ground APU did not supply its declared services");
    faults.apu = true;
    power.update(.02, 0, 0, true, true, faults, ses);
    faults.apu = false;
    for (unsigned i = 0; i < 600; ++i) power.update(.02, 0, 0, true, true, faults, ses);
    flight_require(!power.apu_running && power.apu_inhibit, "Source restoration replayed old APU consent");
    const auto before = power;
    for (double dt : {0.0, -1.0, std::numeric_limits<double>::quiet_NaN()}) {
        power.update(dt, .7, .7, true, true, faults, ses);
        flight_require(power.soc == before.soc && power.apu_spool == before.apu_spool &&
            power.apu_inhibit == before.apu_inhibit, "Invalid/zero dt advanced source state");
    }
    power.requests.apu = false; power.update(.02, 0, 0, true, true, faults, ses);
    power.requests.apu = true;
    for (unsigned i = 0; i < 600; ++i) power.update(.02, 0, 0, true, true, faults, ses);
    flight_require(power.apu_running, "Fresh APU consent did not recover qualified service");
}
void oxygen_endpoint() {
    Environment environment;
    environment.reset(true);
    EnvironmentInputs input;
    input.atmosphere_valid = input.kinematics_valid = true;
    input.oxygen_failed = true;
    environment.backup_reserve = .02 / 600;
    environment.update(input, .02);
    flight_require(environment.backup_reserve == 0 && !environment.backup &&
        environment.oxygen_delivery_pa == 0, "Exhaustion endpoint retained oxygen authority");
    environment.service_oxygen();
    input.atmosphere_valid = false;
    environment.update(input, .02);
    flight_require(!environment.valid && environment.backup && environment.backup_reserve < 1,
        "Independent backup oxygen failed with environment provenance");
    const double reserve = environment.backup_reserve;
    environment.update(input, 0);
    flight_require(environment.backup_reserve == reserve, "Zero time consumed oxygen");
}
void transfer_clock_and_brakes() {
    Configuration config;
    config.last_transfer_s = 5;
    config.update(.02, 0, true, true, 1, 4);
    flight_require(!config.refuel_transfer, "Future transfer survived clock rollback");
    config.update(.02, 0, true, true, 1, 5.2);
    flight_require(config.refuel_transfer, "Recent actual transfer was lost");
    config.update(.02, 0, true, true, 1, 5.5);
    flight_require(!config.refuel_transfer, "Expired transfer remained active");
    BrakeEnergy brake;
    brake.normal_force_n = 100000;
    brake.update(1, 50, 15, true, .02);
    const double work = brake.energy_j;
    brake.update(1, 50, 15, false, .02);
    brake.update(1, 0, 15, true, .02);
    flight_require(brake.energy_j == work && work > 0, "Stale/unloaded/resting wheel invented brake work");
    brake.tire_failed = true;
    const double heat = brake.temperature_c;
    brake.repair_tire();
    flight_require(!brake.tire_failed && brake.temperature_c == heat, "Repair cooled brake disc");
}
}
int main() {
    try {
        conservation_campaign(); capacity_refusal(); stored_energy();
        source_loss_and_zero_time(); oxygen_endpoint(); transfer_clock_and_brakes();
        std::cout << "Finite resource normal/limit/refusal/failure/recovery cases passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
