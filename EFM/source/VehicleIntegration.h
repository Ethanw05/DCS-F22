#pragma once

// Included by RAPTOR.cpp after its legacy declarations. This focused physical
// adapter does not own navigation, radar, payload, native canopy or escape.
namespace {
using VehicleSignal = RaptorVehicle::Signal;

bool vehicle_on(VehicleSignal signal) {
    const double value = vehicle_bus.read(signal);
    return std::isfinite(value) && value >= 0.5;
}

bool vehicle_fault(VehicleSignal signal) {
    const double value = vehicle_bus.read(signal);
    return !std::isfinite(value) || value >= 0.5;
}

bool vehicle_feed(bool left) {
    const auto fault = left ? VehicleSignal::LeftFeedFault : VehicleSignal::RightFeedFault;
    return vehicle.fuel.feed_available(left, vehicle_fault(fault));
}

bool vehicle_force_valid() {
    return vehicle.air_truth.valid && vehicle.mass_valid && vehicle.wing_reference_valid;
}

void vehicle_capture_wing_reference() {
    if (vehicle.wing_reference_valid || !vehicle.mass_valid) return;
    // Sample in the first physics step, after the host's mass callbacks.
    // This is a spawn-reference calibration of the existing coefficient deck,
    // not recovered production F-22 geometry or a moving force location.
    vehicle.wing_reference_x_m = RAPTOR::center_of_mass.x;
    vehicle.wing_reference_y_m = RAPTOR::center_of_mass.y;
    vehicle.wing_reference_valid = true;
}

void vehicle_engine_failures(bool left, RaptorVehicle::EngineInputs& input) {
    constexpr VehicleSignal left_faults[] = {
        VehicleSignal::LeftStarterFault, VehicleSignal::LeftIgnitionFault,
        VehicleSignal::LeftHungStartFault, VehicleSignal::LeftHotStartFault,
        VehicleSignal::LeftControlDegradedFault, VehicleSignal::LeftControlFailedFault,
        VehicleSignal::LeftAugmentationFault};
    constexpr VehicleSignal right_faults[] = {
        VehicleSignal::RightStarterFault, VehicleSignal::RightIgnitionFault,
        VehicleSignal::RightHungStartFault, VehicleSignal::RightHotStartFault,
        VehicleSignal::RightControlDegradedFault, VehicleSignal::RightControlFailedFault,
        VehicleSignal::RightAugmentationFault};
    const auto* faults = left ? left_faults : right_faults;
    input.starter_failed = vehicle_fault(faults[0]);
    input.ignition_failed = vehicle_fault(faults[1]);
    input.hung_start = vehicle_fault(faults[2]);
    input.hot_start = vehicle_fault(faults[3]);
    input.control = vehicle_fault(faults[5]) ? RaptorVehicle::EngineControl::Unavailable :
        (vehicle_fault(faults[4]) ? RaptorVehicle::EngineControl::Degraded : RaptorVehicle::EngineControl::Normal);
    input.augmentation_failed = vehicle_fault(faults[6]);
}

RaptorVehicle::EngineInputs vehicle_engine_inputs(bool left) {
    RaptorVehicle::EngineInputs input;
    input.throttle = ap_output.throttle_active ? ap_output.throttle :
        (left ? RAPTOR::left_throttle_input : RAPTOR::right_throttle_input);
    input.tas_mps = RAPTOR::V_scalar;
    input.health = left ? RAPTOR::left_engine_integrity : RAPTOR::right_engine_integrity;
    input.temperature_c = left ? left_engine_instruments.temperature_c : right_engine_instruments.temperature_c;
    input.ground = RAPTOR::on_ground;
    input.powered = vehicle.power.essential;
    input.starter = vehicle.power.apu_running;
    input.feed = vehicle_feed(left);
    input.isolated = left ? vehicle.left_fire_isolated : vehicle.right_fire_isolated;
    vehicle_engine_failures(left, input);
    return input;
}

void vehicle_start_engine(bool left) {
    auto& engine = left ? vehicle.left_engine : vehicle.right_engine;
    const bool accepted = engine.start(vehicle_engine_inputs(left));
    if (accepted) {
        if (left) RAPTOR::left_engine_switch = true;
        else RAPTOR::right_engine_switch = true;
    }
}

void vehicle_stop_engine(bool left) {
    auto& engine = left ? vehicle.left_engine : vehicle.right_engine;
    engine.stop();
    if (left) RAPTOR::left_engine_switch = false;
    else RAPTOR::right_engine_switch = false;
}

void vehicle_advance_engine(bool left, double idle_n, double dry_n, double ab_n,
                            double up_rate, double down_rate, double dt) {
    auto& engine = left ? vehicle.left_engine : vehicle.right_engine;
    auto input = vehicle_engine_inputs(left);
    input.spool_up_per_s = up_rate;
    input.spool_down_per_s = down_rate;
    engine.update(input, dt);
    auto& instruments = left ? left_engine_instruments : right_engine_instruments;
    instruments.update(engine.spool, engine.burning, engine.augmentation_fraction(),
        RAPTOR::atmosphere_temperature, dt, engine.extra_start_heat_c, engine.start_state.starter_engaged);
    auto& state = left ? RAPTOR::left_engine_state : RAPTOR::right_engine_state;
    state = engine.phase == RaptorVehicle::EnginePhase::Running ? RAPTOR::RUNNING :
        (engine.phase == RaptorVehicle::EnginePhase::Off ? RAPTOR::OFF :
         (engine.burning || engine.phase == RaptorVehicle::EnginePhase::Cranking ?
          RAPTOR::STARTING : RAPTOR::SHUTDOWN));
    const double scale = std::max(0.0, RAPTOR::atmosphere_density / 1.225) * input.health;
    const double thrust_n = engine.thrust_n(idle_n, dry_n, ab_n) * scale;
    if (left) {
        RAPTOR::left_engine_switch = engine.requested;
        RAPTOR::left_throttle_output = RAPTOR::left_engine_power_readout = engine.spool;
        RAPTOR::left_thrust_force = thrust_n;
        RAPTOR::left_ab_timer = engine.augmentation;
        RAPTOR::left_engine_phase = std::fmod(RAPTOR::left_engine_phase +
            instruments.raw_fan_rpm() / 60.0 * dt, 1.0);
    } else {
        RAPTOR::right_engine_switch = engine.requested;
        RAPTOR::right_throttle_output = RAPTOR::right_engine_power_readout = engine.spool;
        RAPTOR::right_thrust_force = thrust_n;
        RAPTOR::right_ab_timer = engine.augmentation;
        RAPTOR::right_engine_phase = std::fmod(RAPTOR::right_engine_phase +
            instruments.raw_fan_rpm() / 60.0 * dt, 1.0);
    }
}

void vehicle_sample_power(double dt) {
    if (vehicle_on(VehicleSignal::RequestValid)) {
        const double sequence = vehicle_bus.read(VehicleSignal::PowerRequestSequence);
        auto requests = vehicle.power.requests;
        requests.battery = vehicle_on(VehicleSignal::BatteryRequest);
        requests.left_generator = vehicle_on(VehicleSignal::LeftGeneratorRequest);
        requests.right_generator = vehicle_on(VehicleSignal::RightGeneratorRequest);
        requests.apu = vehicle_on(VehicleSignal::ApuRequest);
        if (std::isfinite(sequence) && sequence >= 1.0 &&
            sequence == std::floor(sequence) && vehicle_on(VehicleSignal::RequestValid) &&
            vehicle_bus.read(VehicleSignal::PowerRequestSequence) == sequence) {
            vehicle.power.requests = requests;
            vehicle.power_requests_seen = true;
        }
    }
    // GPU connection is a live external source, not a retained pilot request.
    // An incomplete switch transaction must never hold a removed GPU online.
    vehicle.power.requests.ground_power = vehicle_on(VehicleSignal::GroundPower);
    RaptorVehicle::PowerFaults faults;
    faults.battery = vehicle_fault(VehicleSignal::BatteryFault);
    faults.left_generator = vehicle_fault(VehicleSignal::LeftGeneratorFault) || vehicle.left_fire_isolated;
    faults.right_generator = vehicle_fault(VehicleSignal::RightGeneratorFault) || vehicle.right_fire_isolated;
    faults.apu = vehicle_fault(VehicleSignal::ApuFault);
    vehicle.power.update(dt, left_engine_instruments.core, right_engine_instruments.core,
        RAPTOR::on_ground, vehicle.fuel.cells[0].quantity_kg > RaptorVehicle::FuelSystem::unusable_feed_kg,
        faults, vehicle.ses);
    vehicle_bus.write(VehicleSignal::MainPower, vehicle.power.main ? 1.0 : 0.0);
    vehicle_bus.write(VehicleSignal::BatteryPower, vehicle.power.battery ? 1.0 : 0.0);
}

void vehicle_sample_utility_demand() {
    vehicle.utility_demand = {};
    if (vehicle_bus.read(VehicleSignal::HydraulicDemandValid) != 1.0) return;
    const double sequence = vehicle_bus.read(VehicleSignal::HydraulicDemandSequence);
    const double schema = vehicle_bus.read(VehicleSignal::HydraulicDemandSchema);
    const double generation = vehicle_bus.read(VehicleSignal::HydraulicDemandGeneration);
    const double stamp = vehicle_bus.read(VehicleSignal::HydraulicDemandStamp);
    const double left = vehicle_bus.read(VehicleSignal::LeftHydraulicLoad);
    const double right = vehicle_bus.read(VehicleSignal::RightHydraulicLoad);
    const double inventory = vehicle_bus.read(VehicleSignal::FuelInventoryValid);
    const double left_tank = vehicle_bus.read(VehicleSignal::LeftTankInstalled);
    const double right_tank = vehicle_bus.read(VehicleSignal::RightTankInstalled);
    const double inventory_stamp = vehicle_bus.read(VehicleSignal::FuelInventoryStamp);
    if (vehicle_bus.read(VehicleSignal::HydraulicDemandValid) != 1.0 ||
        !RaptorVehicle::UtilityDemand::sequence_valid(sequence,
            vehicle_bus.read(VehicleSignal::HydraulicDemandSequence))) return;
    if (!RaptorVehicle::UtilityDemand::epoch_valid(schema, generation,
            vehicle.generation, stamp, vehicle.time_s) ||
        !RaptorVehicle::within(left, 0.0, 1.0) || !RaptorVehicle::within(right, 0.0, 1.0)) return;
    auto& demand = vehicle.utility_demand;
    demand.left = left;
    demand.right = right;
    demand.inventory_valid = inventory == 1.0 &&
        RaptorVehicle::within(inventory_stamp, 0.0, vehicle.time_s + 0.05) &&
        vehicle.time_s - inventory_stamp <= 0.5 &&
        (left_tank == 0.0 || left_tank == 1.0) && (right_tank == 0.0 || right_tank == 1.0);
    demand.inventory_stamp_s = inventory_stamp;
    demand.left_tank = left_tank == 1.0;
    demand.right_tank = right_tank == 1.0;
}

void vehicle_sample_hydraulic_sources() {
    vehicle_sample_utility_demand();
    const bool left_one = !vehicle_fault(VehicleSignal::LeftPumpOneFault);
    const bool left_two = !vehicle_fault(VehicleSignal::LeftPumpTwoFault);
    const bool right_one = !vehicle_fault(VehicleSignal::RightPumpOneFault);
    const bool right_two = !vehicle_fault(VehicleSignal::RightPumpTwoFault);
    hydraulics.left_capacity = (left_one ? 0.5 : 0.0) + (left_two ? 0.5 : 0.0);
    hydraulics.right_capacity = (right_one ? 0.5 : 0.0) + (right_two ? 0.5 : 0.0);
    hydraulics.apu_source = vehicle.power.apu_hydraulics;
    // Provider demand is normalized 0..1; stale/missing demand adapter does not
    // invent bay/gun activity. Local moving gear/surfaces add bounded demand.
    const double local_load = (std::abs(RAPTOR::gear_pos - (RAPTOR::gear_switch ? 1.0 : 0.0)) > 0.01 ? 0.2 : 0.0);
    hydraulics.left_load = local_load;
    hydraulics.right_load = local_load;
    const bool maintenance = vehicle.configuration.hydraulic_maintenance_transfer &&
        RAPTOR::on_ground && hydraulics.left() > hydraulics.right();
    hydraulics.left_load += vehicle.utility_demand.left + (maintenance ? vehicle.utility_demand.right : 0.0);
    hydraulics.right_load += maintenance ? 0.0 : vehicle.utility_demand.right;
    const double left_pump = RaptorVehicle::unit((left_engine_instruments.core - 0.2) / 0.4);
    const double right_pump = RaptorVehicle::unit((right_engine_instruments.core - 0.2) / 0.4);
    vehicle_bus.write(VehicleSignal::LeftPumpOne, left_one ? left_pump : 0.0);
    vehicle_bus.write(VehicleSignal::LeftPumpTwo, left_two ? left_pump : 0.0);
    vehicle_bus.write(VehicleSignal::RightPumpOne, right_one ? right_pump : 0.0);
    vehicle_bus.write(VehicleSignal::RightPumpTwo, right_two ? right_pump : 0.0);
}

void vehicle_qualify_fuel_delivery(bool left, double requested_kg, double delivered_kg) {
    if (requested_kg <= 0.0 || delivered_kg >= requested_kg - 1e-12) return;
    auto& engine = left ? vehicle.left_engine : vehicle.right_engine;
    engine.lose_feed();
    const double fraction = RaptorVehicle::unit(delivered_kg / requested_kg);
    if (left) {
        RAPTOR::left_thrust_force *= fraction;
        RAPTOR::left_engine_state = RAPTOR::SHUTDOWN;
        RAPTOR::left_engine_switch = false;
    } else {
        RAPTOR::right_thrust_force *= fraction;
        RAPTOR::right_engine_state = RAPTOR::SHUTDOWN;
        RAPTOR::right_engine_switch = false;
    }
}

void vehicle_reconcile_external_tanks() {
    // Map known wing inventory by physical side, not by guessing whether the
    // SDK station identifier uses Lua's zero-based or database's one-based IDs.
    if (!vehicle.utility_demand.inventory_valid) return;
    for (auto it = RAPTOR::external_fuel_stations.begin(); it != RAPTOR::external_fuel_stations.end();) {
        const auto position = RAPTOR::external_fuel_positions.find(it->first);
        const auto callback = RAPTOR::external_fuel_callback_stamp.find(it->first);
        const bool observation_current = callback != RAPTOR::external_fuel_callback_stamp.end() &&
            vehicle.utility_demand.inventory_stamp_s > callback->second;
        if (!observation_current || position == RAPTOR::external_fuel_positions.end() || std::abs(position->second.z) < 0.1) {
            ++it;
            continue;
        }
        const bool installed = position->second.z < 0.0 ?
            vehicle.utility_demand.left_tank : vehicle.utility_demand.right_tank;
        if (installed) {
            RAPTOR::external_tank_refill_allowed[it->first] = true;
            ++it;
        } else {
            // Store removal mass belongs to DCS. Never queue its fuel a second time.
            RAPTOR::external_fuel -= it->second;
            RAPTOR::external_tank_refill_allowed.erase(it->first);
            RAPTOR::external_fuel_callback_stamp.erase(it->first);
            RAPTOR::external_fuel_positions.erase(it->first);
            it = RAPTOR::external_fuel_stations.erase(it);
        }
    }
    RAPTOR::external_fuel = std::max(0.0, RAPTOR::external_fuel);
    RAPTOR::external_tanks_equipped = !RAPTOR::external_fuel_stations.empty();
    RAPTOR::total_fuel = RAPTOR::internal_fuel + RAPTOR::external_fuel;
}

bool vehicle_tank_refill_allowed(int station) {
    const auto found = RAPTOR::external_tank_refill_allowed.find(station);
    if (found == RAPTOR::external_tank_refill_allowed.end() || !found->second ||
        !vehicle.utility_demand.inventory_valid) return false;
    const auto position = RAPTOR::external_fuel_positions.find(station);
    const auto callback = RAPTOR::external_fuel_callback_stamp.find(station);
    if (position == RAPTOR::external_fuel_positions.end() ||
        callback == RAPTOR::external_fuel_callback_stamp.end() ||
        vehicle.utility_demand.inventory_stamp_s <= callback->second) return false;
    return position->second.z < -0.1 ? vehicle.utility_demand.left_tank :
        position->second.z > 0.1 && vehicle.utility_demand.right_tank;
}

void vehicle_transfer_fuel(double dt) {
    vehicle_reconcile_external_tanks();
    const bool bleed = vehicle.left_engine.burning || vehicle.right_engine.burning ||
        vehicle.power.conditioned_air;
    vehicle.fuel.update_supply(hydraulics.shared(), bleed, vehicle.power.essential, dt);
    if (RAPTOR::infinite_fuel || vehicle_fault(VehicleSignal::TransferFault)) return;
    const double budget_kg = RaptorVehicle::FuelSystem::transfer_rate_kg_s *
        vehicle.fuel.boost * vehicle.fuel.pressurization * dt;
    const double available_external = RAPTOR::external_fuel;
    double moved_external = 0.0;
    for (auto& [station, quantity] : RAPTOR::external_fuel_stations) {
        const auto position = RAPTOR::external_fuel_positions.find(station);
        if (position == RAPTOR::external_fuel_positions.end()) continue;
        const auto& pos = position->second;
        const double share = available_external > 0.0 ? quantity / available_external : 0.0;
        const double moved = vehicle.fuel.transfer_external(quantity, {pos.x, pos.y, pos.z},
            budget_kg * share, vehicle.mass);
        quantity -= moved;
        moved_external += moved;
    }
    vehicle.fuel.transfer_internal(std::max(0.0, budget_kg - moved_external), vehicle.mass);
    RAPTOR::external_fuel = std::max(0.0, RAPTOR::external_fuel - moved_external);
    RAPTOR::internal_fuel = vehicle.fuel.internal_kg();
    RAPTOR::total_fuel = RAPTOR::internal_fuel + RAPTOR::external_fuel;
}

void vehicle_sample_air() {
    const double tas = std::hypot(RAPTOR::body_air_velocity.x,
        RAPTOR::body_air_velocity.y, RAPTOR::body_air_velocity.z);
    vehicle.air_truth = RaptorAirData::calculate(tas, RAPTOR::speed_of_sound,
        RAPTOR::atmosphere_density, RAPTOR::hud_static_pressure_pa, vehicle.time_s);
    vehicle.air_truth.valid = vehicle.air_truth.valid && vehicle.atmosphere_valid &&
        vehicle.motion_valid && vehicle.world_motion_valid;
    const double requested = vehicle_bus.read(VehicleSignal::AirDataHealth);
    auto health = RaptorAirData::Health::Invalid;
    if (std::isfinite(requested) && requested >= 0.0 && requested <= 3.0 &&
        std::floor(requested) == requested)
        health = static_cast<RaptorAirData::Health>(static_cast<int>(requested));
    vehicle.air_sensor.update(vehicle.air_truth, health,
        vehicle_bus.read(VehicleSignal::AirDataBias));
    vehicle.air_data_reversion = !vehicle.air_sensor.measured.valid ||
        health != RaptorAirData::Health::Healthy;
    if (!vehicle.air_data_reversion) vehicle.control_air = vehicle.air_sensor.measured;
    else if (!vehicle.control_air.valid) {
        // Explicit estimated seed only when no qualified schedule has existed.
        // It is never exported as a healthy sensor measurement.
        vehicle.control_air = RaptorAirData::calculate(200.0, 340.293988,
            1.225, 101325.0, 0.0);
    }
}

void vehicle_sample_environment(double dt) {
    RaptorVehicle::EnvironmentInputs input;
    input.ambient_pa = RAPTOR::hud_static_pressure_pa;
    input.ambient_k = RAPTOR::atmosphere_temperature;
    input.tas_mps = RAPTOR::V_scalar;
    input.internal_fuel_kg = RAPTOR::internal_fuel;
    input.powered = vehicle.power.essential;
    input.left_bleed = left_engine_instruments.core >= 0.59 &&
        vehicle.left_engine.burning && !vehicle.left_fire_isolated;
    input.right_bleed = right_engine_instruments.core >= 0.59 &&
        vehicle.right_engine.burning && !vehicle.right_fire_isolated;
    if (vehicle.power_requests_seen) {
        input.left_bleed = input.left_bleed && vehicle_on(VehicleSignal::LeftBleedRequest);
        input.right_bleed = input.right_bleed && vehicle_on(VehicleSignal::RightBleedRequest);
        input.bleed_selected = vehicle_on(VehicleSignal::EcsRequest);
    }
    input.apu_air = vehicle.power.conditioned_air;
    input.ecs_failed = vehicle_fault(VehicleSignal::EcsFault);
    input.cooling_failed = vehicle_fault(VehicleSignal::CoolingFault);
    input.oxygen_failed = vehicle_fault(VehicleSignal::OxygenFault);
    input.defog_selected = vehicle_on(VehicleSignal::DefogRequest);
    input.backup_manual = vehicle_on(VehicleSignal::BackupManual);
    input.modern_abos = !vehicle_on(VehicleSignal::HistoricalOxygen);
    if (vehicle_on(VehicleSignal::CanopyValid)) {
        input.canopy_position = vehicle_bus.read(VehicleSignal::CanopyPosition);
        input.canopy_locked = vehicle_on(VehicleSignal::CanopyLocked);
    } else {
        // Withdraw cabin authority until the native adapter supplies seal data.
        input.canopy_position = 1.0;
        input.canopy_locked = false;
    }
    vehicle.environment.update(input, dt);
}

void vehicle_configuration_command(int command, float value) {
    auto& config = vehicle.configuration;
    if (command == 11700 && value > 0.5f)
        static_cast<void>(config.extend_alternate(vehicle.ses, RAPTOR::gear_switch));
    else if (command == 11701) config.steering_selected = value > 0.5f;
    else if (command == 11702) config.request_hook(value > 0.5f, vehicle.ses);
}

void vehicle_engine_command(int command, float value) {
    const bool left = command % 2 == 1;
    auto& engine = left ? vehicle.left_engine : vehicle.right_engine;
    const bool selected = value > 0.5f;
    switch ((command - 11719) / 2) {
    case 0: engine.select_starter(selected); break;
    case 1: engine.select_fuel(selected); break;
    case 2: engine.select_ignition(selected); break;
    case 3:
        if (selected) static_cast<void>(engine.reset_fault(vehicle_engine_inputs(left)));
        break;
    default: break;
    }
}

void vehicle_fire_command(int command, float value) {
    if (value <= 0.5f) return;
    if (command == 11703) vehicle.left_fire_isolated = true;
    else if (command == 11704) vehicle.right_fire_isolated = true;
    else if (command == 11705 && vehicle.fire_bottle_available &&
             (vehicle.left_fire_isolated || vehicle.right_fire_isolated)) {
        vehicle.fire_bottle_available = false;
        vehicle.extinguishing_attempt = true;
        // A discharge command does not prove the fire was extinguished.
    }
}

void vehicle_service_command(int command, float value) {
    if (value <= 0.5f || !RAPTOR::on_ground) return;
    if (command == 11717) {
        // Ground hand-pump/tow service, not a new normal brake source.
        hydraulics.brake_reserve = 1.0;
        return;
    }
    if (vehicle.left_engine.burning || vehicle.right_engine.burning) return;
    if (command == 11706) {
        vehicle.ses.service();
        vehicle.environment.service_oxygen();
    } else if (command == 11716) {
        hydraulics.left_inventory = hydraulics.right_inventory = 1.0;
    }
}

void vehicle_maintenance_command(float value) {
    if (RAPTOR::on_ground && RAPTOR::ground_speed_knots < 1.0)
        vehicle.configuration.hydraulic_maintenance_transfer = value > 0.5f;
}

void vehicle_parameter_command(int command, float value) {
    constexpr VehicleSignal controls[] = {
        VehicleSignal::LeftBleedRequest, VehicleSignal::RightBleedRequest,
        VehicleSignal::EcsRequest, VehicleSignal::DefogRequest, VehicleSignal::BackupManual};
    if (command >= 11707 && command <= 11711) {
        vehicle_bus.write(controls[static_cast<std::size_t>(command - 11707)], value > 0.5f ? 1.0 : 0.0);
    } else if (command == 11714) {
        const double current = RaptorVehicle::finite(vehicle_bus.read(VehicleSignal::BingoRequest));
        vehicle_bus.write(VehicleSignal::BingoRequest,
            std::clamp(current + static_cast<double>(value), 0.0, 12000.0));
    } else if (command == 11718) vehicle_maintenance_command(value);
    else vehicle_service_command(command, value);
}

bool vehicle_command(int command, float value) {
    if (command < 11700 || command > 11729) return false;
    if (!std::isfinite(value)) return true;
    if (command <= 11702) vehicle_configuration_command(command, value);
    else if (command <= 11705) vehicle_fire_command(command, value);
    else if (command >= 11719 && command <= 11726) vehicle_engine_command(command, value);
    else vehicle_parameter_command(command, value);
    return true;
}

void vehicle_update_configuration(double dt) {
    auto& config = vehicle.configuration;
    config.refuel_request = vehicle_on(VehicleSignal::RefuelDoorRequest);
    config.refuel_disconnect = vehicle_on(VehicleSignal::RefuelDisconnectRequest);
    if (!RAPTOR::on_ground) config.hydraulic_maintenance_transfer = false;
    config.update(dt, RAPTOR::gear_pos, vehicle.left_engine.burning,
        vehicle.right_engine.burning, actuator_available, vehicle.time_s);
}

double vehicle_utility_supply() {
    // Right logical circuit represents System 2 as a declared mapping estimate.
    // The source establishes normal utilities vs ground maintenance transfer,
    // not a complete left/right production schematic.
    if (!vehicle.power.essential || RAPTOR::is_destroyed) return 0.0;
    return vehicle.configuration.hydraulic_maintenance_transfer && RAPTOR::on_ground ?
        hydraulics.shared() : hydraulics.right();
}

double vehicle_status(bool available) {
    return static_cast<double>(available);
}

double vehicle_main_source() {
    const auto& power = vehicle.power;
    if (power.left_generator || power.right_generator) return 1.0;
    if (power.requests.ground_power && RAPTOR::on_ground) return 2.0;
    if (power.apu_running && RAPTOR::on_ground) return 3.0;
    return 0.0;
}

void vehicle_publish_power() {
    const auto& power = vehicle.power;
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::Owner, 1.0},
        {VehicleSignal::MainPower, vehicle_status(power.main)},
        {VehicleSignal::BatteryPower, vehicle_status(power.battery)},
        {VehicleSignal::LeftGeneratorPower, vehicle_status(power.left_generator)},
        {VehicleSignal::RightGeneratorPower, vehicle_status(power.right_generator)},
        {VehicleSignal::BatterySoc, power.soc}, {VehicleSignal::DcVolts, power.volts},
        {VehicleSignal::EssentialPower, vehicle_status(power.essential)},
        {VehicleSignal::ElectricalValid, 1.0},
        {VehicleSignal::MissionPowerAvailable, vehicle_status(power.left_generator || power.right_generator ||
            (power.requests.ground_power && RAPTOR::on_ground))},
        {VehicleSignal::MainSource, vehicle_main_source()},
        {VehicleSignal::ApuPower, vehicle_status(power.apu_running)},
        {VehicleSignal::ApuRpm, power.apu_spool * 4.0},
        {VehicleSignal::ApuReady, vehicle_status(power.apu_running)},
        {VehicleSignal::ApuHydraulics, vehicle_status(power.apu_hydraulics)},
        {VehicleSignal::ApuAir, vehicle_status(power.conditioned_air)},
        {VehicleSignal::ApuAbort, vehicle_status(power.apu_abort)},
        {VehicleSignal::ApuAutomaticShutdown, vehicle_status(power.automatic_shutdown)},
        {VehicleSignal::SesAir, vehicle.ses.air},
        {VehicleSignal::SesFuel, vehicle.ses.start_fuel}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish_air() {
    const auto& air = vehicle.air_sensor.measured;
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::AirValid, vehicle_status(air.valid)},
        {VehicleSignal::AirStamp, air.stamp_s}, {VehicleSignal::Tas, air.tas_mps},
        {VehicleSignal::Eas, air.eas_mps}, {VehicleSignal::Cas, air.cas_mps},
        {VehicleSignal::Mach, air.mach}, {VehicleSignal::StaticPressure, air.static_pa},
        {VehicleSignal::ImpactPressure, air.impact_pa},
        {VehicleSignal::RawBodyAy, vehicle.raw_body_ay_mps2},
        {VehicleSignal::AirHealth, static_cast<double>(vehicle.air_sensor.health)}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish_environment() {
    const auto& environment = vehicle.environment;
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::CabinPressure, environment.cabin_absolute_pa},
        {VehicleSignal::CabinOverpressure, environment.cabin_overpressure_pa},
        {VehicleSignal::EnvironmentValid, vehicle_status(environment.valid)},
        {VehicleSignal::EquipmentTemperature, environment.equipment_c},
        {VehicleSignal::CoolantTemperature, environment.coolant_c},
        {VehicleSignal::FuelTemperature, environment.fuel_sink_c},
        {VehicleSignal::ThermalFault, vehicle_status(environment.thermal_fault)},
        {VehicleSignal::ConditionedAir, vehicle_status(environment.conditioned_air)},
        {VehicleSignal::Obogs, vehicle_status(environment.obogs)},
        {VehicleSignal::OxygenBackup, vehicle_status(environment.backup)},
        {VehicleSignal::OxygenReserve, environment.backup_reserve},
        {VehicleSignal::OxygenPressure, environment.oxygen_delivery_pa},
        {VehicleSignal::CanopyFog, environment.fog}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish_configuration() {
    const auto& config = vehicle.configuration;
    const auto& wheels = vehicle.ground_contact.wheels;
    const auto age = [](const RaptorVehicle::GroundContact::Wheel& wheel) {
        return wheel.stamp_s < 0.0 ? -1.0 : vehicle.time_s - wheel.stamp_s;
    };
    const bool gear_damaged = RAPTOR::element_integrity[8] <= 0.5 ||
        RAPTOR::element_integrity[15] <= 0.5 || RAPTOR::element_integrity[16] <= 0.5;
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::GroundClearance, RAPTOR::altitude_AGL},
        {VehicleSignal::SurfaceValid, vehicle_status(vehicle.surface_valid)},
        {VehicleSignal::Invulnerable, vehicle_status(RAPTOR::invincible)},
        {VehicleSignal::DamageCallbacks, static_cast<double>(vehicle.damage_callbacks)},
        {VehicleSignal::LastDamageCell, static_cast<double>(vehicle.last_damage_cell)},
        {VehicleSignal::LastDamageIntegrity, vehicle.last_damage_integrity},
        {VehicleSignal::Destroyed, vehicle_status(RAPTOR::is_destroyed)},
        {VehicleSignal::WheelZeroCompression, wheels[0].compression},
        {VehicleSignal::WheelOneCompression, wheels[1].compression},
        {VehicleSignal::WheelTwoCompression, wheels[2].compression},
        {VehicleSignal::WheelZeroReaction, wheels[0].reaction_n},
        {VehicleSignal::WheelOneReaction, wheels[1].reaction_n},
        {VehicleSignal::WheelTwoReaction, wheels[2].reaction_n},
        {VehicleSignal::WheelZeroAge, age(wheels[0])},
        {VehicleSignal::WheelOneAge, age(wheels[1])},
        {VehicleSignal::WheelTwoAge, age(wheels[2])},
        {VehicleSignal::FcsMode, static_cast<double>(config.mode)},
        {VehicleSignal::SingleEngineApproach, vehicle_status(config.single_engine_approach)},
        {VehicleSignal::ApproachAoa, 12.0}, // retained historical reference; single-engine value unresolved
        {VehicleSignal::GearRejection, static_cast<double>(config.gear_rejection)},
        {VehicleSignal::AirDataReversion, vehicle_status(vehicle.air_data_reversion)},
        {VehicleSignal::ControlScheduleMach, vehicle.control_air.mach},
        {VehicleSignal::ControlScheduleEas, vehicle.control_air.eas_mps},
        {VehicleSignal::GearUnsafe, vehicle_status(gear_damaged ||
            (RAPTOR::gear_pos > 0.001 && RAPTOR::gear_pos < 0.999))},
        {VehicleSignal::GearDownLocked, vehicle_status(!gear_damaged && RAPTOR::gear_pos >= 0.999)},
        {VehicleSignal::GearUpLocked, vehicle_status(RAPTOR::gear_pos <= 0.001)},
        {VehicleSignal::AlternateGear, vehicle_status(config.alternate_gear)},
        {VehicleSignal::HookPosition, config.hook_position},
        {VehicleSignal::SteeringSelected, vehicle_status(config.steering_selected)},
        {VehicleSignal::RefuelDoorPosition, config.refuel_door},
        {VehicleSignal::RefuelReady, vehicle_status(config.refuel_door > 0.99 && !config.refuel_disconnect)},
        {VehicleSignal::RefuelTransfer, vehicle_status(config.refuel_transfer)},
        {VehicleSignal::FireBottle, vehicle_status(vehicle.fire_bottle_available)},
        {VehicleSignal::LeftFireIsolated, vehicle_status(vehicle.left_fire_isolated)},
        {VehicleSignal::RightFireIsolated, vehicle_status(vehicle.right_fire_isolated)},
        {VehicleSignal::FormationIntensity, RAPTOR::form_light},
        {VehicleSignal::RefuelIntensity, RAPTOR::aar_light}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish_fuel() {
    const double apu_flow = vehicle.apu_flow_kg_s;
    const double bingo = vehicle_bus.read(VehicleSignal::BingoRequest);
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::LeftEnginePhase, static_cast<double>(vehicle.left_engine.phase)},
        {VehicleSignal::RightEnginePhase, static_cast<double>(vehicle.right_engine.phase)},
        {VehicleSignal::LeftStartRejection, static_cast<double>(vehicle.left_engine.rejection)},
        {VehicleSignal::RightStartRejection, static_cast<double>(vehicle.right_engine.rejection)},
        {VehicleSignal::LeftFeedAvailable, vehicle_status(vehicle_feed(true))},
        {VehicleSignal::RightFeedAvailable, vehicle_status(vehicle_feed(false))},
        {VehicleSignal::TotalFlow, RAPTOR::left_fuel_rate + RAPTOR::right_fuel_rate + apu_flow},
        {VehicleSignal::ApuFlow, apu_flow},
        {VehicleSignal::EngineIndicationSchema, 1.0},
        {VehicleSignal::LeftEngineFlow, RAPTOR::left_fuel_rate_kg_s},
        {VehicleSignal::RightEngineFlow, RAPTOR::right_fuel_rate_kg_s},
        {VehicleSignal::MassOverflow, vehicle_status(vehicle.mass.overflow)},
        {VehicleSignal::FuelBingo, vehicle_status(std::isfinite(bingo) && bingo > 0.0 && RAPTOR::total_fuel < bingo)},
        {VehicleSignal::LeftFeedLow, vehicle_status(vehicle.fuel.cells[1].quantity_kg < RaptorVehicle::FuelSystem::low_feed_kg)},
        {VehicleSignal::RightFeedLow, vehicle_status(vehicle.fuel.cells[2].quantity_kg < RaptorVehicle::FuelSystem::low_feed_kg)},
        {VehicleSignal::LeftFeedQuantity, vehicle.fuel.cells[1].quantity_kg},
        {VehicleSignal::RightFeedQuantity, vehicle.fuel.cells[2].quantity_kg},
        {VehicleSignal::CommonFeedQuantity, vehicle.fuel.cells[0].quantity_kg},
        {VehicleSignal::FuelBoost, vehicle.fuel.boost},
        {VehicleSignal::FuelPressurization, vehicle.fuel.pressurization}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish_services() {
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::BrakeReserve, hydraulics.brake_reserve},
        {VehicleSignal::UtilityAvailable, vehicle_utility_supply()},
        {VehicleSignal::ParkHeld, vehicle_status(vehicle_on(VehicleSignal::ParkRequest) && RAPTOR::on_ground &&
            RAPTOR::left_brake_achieved > 0.95 && RAPTOR::right_brake_achieved > 0.95)},
        {VehicleSignal::LeftHydraulicInventory, hydraulics.left_inventory},
        {VehicleSignal::RightHydraulicInventory, hydraulics.right_inventory},
        {VehicleSignal::LeftBleedAvailable, vehicle_status(vehicle.left_engine.burning &&
            !vehicle.left_fire_isolated && left_engine_instruments.core >= 0.59 &&
            (!vehicle.power_requests_seen || vehicle_on(VehicleSignal::LeftBleedRequest)))},
        {VehicleSignal::RightBleedAvailable, vehicle_status(vehicle.right_engine.burning &&
            !vehicle.right_fire_isolated && right_engine_instruments.core >= 0.59 &&
            (!vehicle.power_requests_seen || vehicle_on(VehicleSignal::RightBleedRequest)))},
        {VehicleSignal::LeftBrakeTemperature, vehicle.left_brake.temperature_c},
        {VehicleSignal::RightBrakeTemperature, vehicle.right_brake.temperature_c},
        {VehicleSignal::LeftBrakeEnergy, vehicle.left_brake.energy_j},
        {VehicleSignal::RightBrakeEnergy, vehicle.right_brake.energy_j},
        {VehicleSignal::LeftWheelSpeedRaw, vehicle.left_brake.wheel_speed_raw},
        {VehicleSignal::RightWheelSpeedRaw, vehicle.right_brake.wheel_speed_raw},
        {VehicleSignal::BrakeEnergyEstimated, 1.0},
        {VehicleSignal::LeftBrakeEffectiveness, vehicle.left_brake.effectiveness()},
        {VehicleSignal::RightBrakeEffectiveness, vehicle.right_brake.effectiveness()},
        {VehicleSignal::LeftTireTemperature, vehicle.left_brake.tire_temperature_c},
        {VehicleSignal::RightTireTemperature, vehicle.right_brake.tire_temperature_c},
        {VehicleSignal::LeftTireFailed, vehicle_status(vehicle.left_brake.tire_failed)},
        {VehicleSignal::RightTireFailed, vehicle_status(vehicle.right_brake.tire_failed)},
        {VehicleSignal::LeftFireDetected, vehicle_status(vehicle.left_fire)},
        {VehicleSignal::RightFireDetected, vehicle_status(vehicle.right_fire)},
        {VehicleSignal::FireDischarge, vehicle_status(vehicle.extinguishing_attempt)}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish_left_engine_controls() {
    const auto& engine = vehicle.left_engine;
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::LeftStarterSelected, vehicle_status(engine.start_state.starter_selected)},
        {VehicleSignal::LeftStarterEngaged, vehicle_status(engine.start_state.starter_engaged)},
        {VehicleSignal::LeftFuelSelected, vehicle_status(engine.start_state.fuel_selected)},
        {VehicleSignal::LeftFuelValve, vehicle_status(engine.start_state.fuel_valve)},
        {VehicleSignal::LeftIgnitionSelected, vehicle_status(engine.start_state.ignition_selected)},
        {VehicleSignal::LeftStartFault, static_cast<double>(engine.start_state.fault)},
        {VehicleSignal::LeftEngineControl, static_cast<double>(engine.control)},
        {VehicleSignal::LeftPurgeSeconds, static_cast<double>(engine.start_state.purge_remaining_s)},
        {VehicleSignal::LeftStartElapsed, static_cast<double>(engine.start_state.combustion_start_s)},
        {VehicleSignal::LeftAugmentationAvailable, vehicle_status(engine.augmentation_available)},
        {VehicleSignal::LeftControlAvailable, vehicle_status(engine.control_available)},
        {VehicleSignal::LeftStartResetReady, vehicle_status(engine.reset_ready)}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish_right_engine_controls() {
    const auto& engine = vehicle.right_engine;
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::RightStarterSelected, vehicle_status(engine.start_state.starter_selected)},
        {VehicleSignal::RightStarterEngaged, vehicle_status(engine.start_state.starter_engaged)},
        {VehicleSignal::RightFuelSelected, vehicle_status(engine.start_state.fuel_selected)},
        {VehicleSignal::RightFuelValve, vehicle_status(engine.start_state.fuel_valve)},
        {VehicleSignal::RightIgnitionSelected, vehicle_status(engine.start_state.ignition_selected)},
        {VehicleSignal::RightStartFault, static_cast<double>(engine.start_state.fault)},
        {VehicleSignal::RightEngineControl, static_cast<double>(engine.control)},
        {VehicleSignal::RightPurgeSeconds, static_cast<double>(engine.start_state.purge_remaining_s)},
        {VehicleSignal::RightStartElapsed, static_cast<double>(engine.start_state.combustion_start_s)},
        {VehicleSignal::RightAugmentationAvailable, vehicle_status(engine.augmentation_available)},
        {VehicleSignal::RightControlAvailable, vehicle_status(engine.control_available)},
        {VehicleSignal::RightStartResetReady, vehicle_status(engine.reset_ready)}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish_engine_controls() {
    vehicle_publish_left_engine_controls();
    vehicle_publish_right_engine_controls();
    vehicle_bus.write(VehicleSignal::EngineControlSchema, 1.0);
}

void vehicle_publish() {
    vehicle_publish_power();
    vehicle_publish_air();
    vehicle_publish_environment();
    vehicle_publish_configuration();
    vehicle_publish_fuel();
    vehicle_publish_services();
    vehicle_publish_engine_controls();
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::Generation, static_cast<double>(vehicle.generation)},
        {VehicleSignal::ClockKind, 1.0}, // spawn-relative RAPTOR clock, not World model time
        {VehicleSignal::ForceValid, vehicle_status(vehicle_force_valid())},
        {VehicleSignal::Stamp, vehicle.time_s},
        {VehicleSignal::DroppedTime, vehicle.discarded_time_s}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
    vehicle_bus.write(VehicleSignal::Valid, vehicle_status(vehicle.alive));
}

void vehicle_publish_mass() {
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::MassValid, vehicle_status(vehicle.mass_valid)},
        {VehicleSignal::MassKg, RAPTOR::current_mass},
        {VehicleSignal::CgX, RAPTOR::center_of_mass.x},
        {VehicleSignal::CgY, RAPTOR::center_of_mass.y},
        {VehicleSignal::CgZ, RAPTOR::center_of_mass.z},
        {VehicleSignal::InertiaX, RAPTOR::current_inertia.x},
        {VehicleSignal::InertiaY, RAPTOR::current_inertia.y},
        {VehicleSignal::InertiaZ, RAPTOR::current_inertia.z}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_update_brake_energy(double dt) {
    const double speed = RAPTOR::ground_speed_knots / 1.943844492;
    const double ambient_c = RAPTOR::atmosphere_temperature - 273.15;
    const auto update = [speed, ambient_c, dt](RaptorVehicle::BrakeEnergy& brake, double demand) {
        const bool loaded = RAPTOR::on_ground && brake.contact_fresh(vehicle.time_s);
        brake.update(demand, speed, ambient_c, loaded, dt);
        const auto& point = brake.contact_m;
        const double longitudinal = RAPTOR::body_ground_velocity.x +
            RAPTOR::yaw_rate * (point[2] - RAPTOR::center_of_mass.z) -
            RAPTOR::pitch_rate * (point[1] - RAPTOR::center_of_mass.y);
        const double resistance = brake.extra_rolling_force(longitudinal, loaded);
        add_local_force(Vec3(resistance, 0.0, 0.0), Vec3(point[0], point[1], point[2]));
    };
    update(vehicle.left_brake, RAPTOR::left_brake_achieved);
    update(vehicle.right_brake, RAPTOR::right_brake_achieved);
    vehicle.left_fire = vehicle_on(VehicleSignal::LeftFireFault);
    vehicle.right_fire = vehicle_on(VehicleSignal::RightFireFault);
}

void vehicle_repair_injected_faults() {
    for (const auto& fault : RaptorVehicle::planned_faults) vehicle_bus.write(fault.channel, 0.0);
}
} // namespace
