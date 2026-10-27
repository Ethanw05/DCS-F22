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

RaptorVehicle::EngineInputs vehicle_engine_inputs(bool left) {
    RaptorVehicle::EngineInputs input;
    input.throttle = ap_output.throttle_active ? ap_output.throttle :
        (left ? RAPTOR::left_throttle_input : RAPTOR::right_throttle_input);
    input.tas_mps = RAPTOR::V_scalar;
    input.health = left ? RAPTOR::left_engine_integrity : RAPTOR::right_engine_integrity;
    input.ground = RAPTOR::on_ground;
    input.powered = vehicle.power.essential;
    input.starter = vehicle.power.apu_running;
    input.feed = vehicle_feed(left);
    input.isolated = left ? vehicle.left_fire_isolated : vehicle.right_fire_isolated;
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
    engine.requested = false;
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
        RAPTOR::atmosphere_temperature, dt);
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
        requests.ground_power = vehicle_on(VehicleSignal::GroundPower);
        if (std::isfinite(sequence) && sequence >= 1.0 &&
            sequence == std::floor(sequence) && vehicle_on(VehicleSignal::RequestValid) &&
            vehicle_bus.read(VehicleSignal::PowerRequestSequence) == sequence) {
            vehicle.power.requests = requests;
            vehicle.power_requests_seen = true;
        }
    }
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

void vehicle_sample_hydraulic_sources() {
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
    if (vehicle_on(VehicleSignal::HydraulicDemandValid)) {
        hydraulics.left_load += RaptorVehicle::unit(vehicle_bus.read(VehicleSignal::LeftHydraulicLoad));
        hydraulics.right_load += RaptorVehicle::unit(vehicle_bus.read(VehicleSignal::RightHydraulicLoad));
    }
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
    engine.requested = engine.burning = false;
    engine.phase = RaptorVehicle::EnginePhase::ShuttingDown;
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

void vehicle_transfer_fuel(double dt) {
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

bool vehicle_command(int command, float value) {
    if (command < 11700 || command > 11729) return false;
    if (!std::isfinite(value)) return true;
    auto& config = vehicle.configuration;
    constexpr VehicleSignal controls[] = {
        VehicleSignal::LeftBleedRequest, VehicleSignal::RightBleedRequest,
        VehicleSignal::EcsRequest, VehicleSignal::DefogRequest, VehicleSignal::BackupManual};
    if (command >= 11707 && command <= 11711) {
        vehicle_bus.write(controls[static_cast<std::size_t>(command - 11707)], value > 0.5f ? 1.0 : 0.0);
        return true;
    }
    if (command == 11714) {
        const double current = RaptorVehicle::finite(vehicle_bus.read(VehicleSignal::BingoRequest));
        vehicle_bus.write(VehicleSignal::BingoRequest,
            std::clamp(current + static_cast<double>(value), 0.0, 12000.0));
        return true;
    }
    if (command == 11716 && value > 0.5f && RAPTOR::on_ground &&
        !vehicle.left_engine.burning && !vehicle.right_engine.burning) {
        hydraulics.left_inventory = hydraulics.right_inventory = 1.0;
        return true;
    }
    if (command == 11717 && value > 0.5f && RAPTOR::on_ground) {
        // Declared ground hand-pump/tow service, not a new normal brake source.
        hydraulics.brake_reserve = 1.0;
        return true;
    }
    if (command == 11718 && RAPTOR::on_ground && RAPTOR::ground_speed_knots < 1.0) {
        config.hydraulic_maintenance_transfer = value > 0.5f;
        return true;
    }
    if (command == 11700 && value > 0.5f)
        static_cast<void>(config.extend_alternate(vehicle.ses, RAPTOR::gear_switch));
    else if (command == 11701) config.steering_selected = value > 0.5f;
    else if (command == 11702) config.request_hook(value > 0.5f, vehicle.ses);
    else if (command == 11703 && value > 0.5f) vehicle.left_fire_isolated = true;
    else if (command == 11704 && value > 0.5f) vehicle.right_fire_isolated = true;
    else if (command == 11705 && value > 0.5f && vehicle.fire_bottle_available &&
             (vehicle.left_fire_isolated || vehicle.right_fire_isolated)) {
        vehicle.fire_bottle_available = false;
        vehicle.extinguishing_attempt = true;
        // A discharge command does not prove the fire was extinguished.
    } else if (command == 11706 && value > 0.5f && RAPTOR::on_ground &&
               !vehicle.left_engine.burning && !vehicle.right_engine.burning) {
        vehicle.ses.service();
        vehicle.environment.service_oxygen();
    }
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

void vehicle_publish_power() {
    const auto& power = vehicle.power;
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::Owner, 1.0},
        {VehicleSignal::MainPower, power.main ? 1.0 : 0.0},
        {VehicleSignal::BatteryPower, power.battery ? 1.0 : 0.0},
        {VehicleSignal::LeftGeneratorPower, power.left_generator ? 1.0 : 0.0},
        {VehicleSignal::RightGeneratorPower, power.right_generator ? 1.0 : 0.0},
        {VehicleSignal::BatterySoc, power.soc}, {VehicleSignal::DcVolts, power.volts},
        {VehicleSignal::EssentialPower, power.essential ? 1.0 : 0.0},
        {VehicleSignal::ElectricalValid, 1.0},
        {VehicleSignal::MissionPowerAvailable, power.left_generator || power.right_generator ||
            (power.requests.ground_power && RAPTOR::on_ground) ? 1.0 : 0.0},
        {VehicleSignal::MainSource, power.left_generator || power.right_generator ? 1.0 :
            (power.requests.ground_power && RAPTOR::on_ground ? 2.0 :
             (power.apu_running && RAPTOR::on_ground ? 3.0 : 0.0))},
        {VehicleSignal::ApuPower, power.apu_running ? 1.0 : 0.0},
        {VehicleSignal::ApuRpm, power.apu_spool * 4.0},
        {VehicleSignal::ApuReady, power.apu_running ? 1.0 : 0.0},
        {VehicleSignal::ApuHydraulics, power.apu_hydraulics ? 1.0 : 0.0},
        {VehicleSignal::ApuAir, power.conditioned_air ? 1.0 : 0.0},
        {VehicleSignal::ApuAbort, power.apu_abort ? 1.0 : 0.0},
        {VehicleSignal::ApuAutomaticShutdown, power.automatic_shutdown ? 1.0 : 0.0},
        {VehicleSignal::SesAir, vehicle.ses.air},
        {VehicleSignal::SesFuel, vehicle.ses.start_fuel}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish_air() {
    const auto& air = vehicle.air_sensor.measured;
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::AirValid, air.valid ? 1.0 : 0.0},
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
        {VehicleSignal::EnvironmentValid, environment.valid ? 1.0 : 0.0},
        {VehicleSignal::EquipmentTemperature, environment.equipment_c},
        {VehicleSignal::CoolantTemperature, environment.coolant_c},
        {VehicleSignal::FuelTemperature, environment.fuel_sink_c},
        {VehicleSignal::ThermalFault, environment.thermal_fault ? 1.0 : 0.0},
        {VehicleSignal::ConditionedAir, environment.conditioned_air ? 1.0 : 0.0},
        {VehicleSignal::Obogs, environment.obogs ? 1.0 : 0.0},
        {VehicleSignal::OxygenBackup, environment.backup ? 1.0 : 0.0},
        {VehicleSignal::OxygenReserve, environment.backup_reserve},
        {VehicleSignal::OxygenPressure, environment.oxygen_delivery_pa},
        {VehicleSignal::CanopyFog, environment.fog}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish_configuration() {
    const auto& config = vehicle.configuration;
    const bool gear_damaged = RAPTOR::element_integrity[8] <= 0.5 ||
        RAPTOR::element_integrity[15] <= 0.5 || RAPTOR::element_integrity[16] <= 0.5;
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::FcsMode, static_cast<double>(config.mode)},
        {VehicleSignal::SingleEngineApproach, config.single_engine_approach ? 1.0 : 0.0},
        {VehicleSignal::ApproachAoa, 12.0}, // retained historical reference; single-engine value unresolved
        {VehicleSignal::GearRejection, static_cast<double>(config.gear_rejection)},
        {VehicleSignal::AirDataReversion, vehicle.air_data_reversion ? 1.0 : 0.0},
        {VehicleSignal::ControlScheduleMach, vehicle.control_air.mach},
        {VehicleSignal::ControlScheduleEas, vehicle.control_air.eas_mps},
        {VehicleSignal::GearUnsafe, gear_damaged ||
            (RAPTOR::gear_pos > 0.001 && RAPTOR::gear_pos < 0.999) ? 1.0 : 0.0},
        {VehicleSignal::GearDownLocked, !gear_damaged && RAPTOR::gear_pos >= 0.999 ? 1.0 : 0.0},
        {VehicleSignal::GearUpLocked, RAPTOR::gear_pos <= 0.001 ? 1.0 : 0.0},
        {VehicleSignal::AlternateGear, config.alternate_gear ? 1.0 : 0.0},
        {VehicleSignal::HookPosition, config.hook_position},
        {VehicleSignal::SteeringSelected, config.steering_selected ? 1.0 : 0.0},
        {VehicleSignal::RefuelDoorPosition, config.refuel_door},
        {VehicleSignal::RefuelReady, config.refuel_door > 0.99 && !config.refuel_disconnect ? 1.0 : 0.0},
        {VehicleSignal::RefuelTransfer, config.refuel_transfer ? 1.0 : 0.0},
        {VehicleSignal::FireBottle, vehicle.fire_bottle_available ? 1.0 : 0.0},
        {VehicleSignal::LeftFireIsolated, vehicle.left_fire_isolated ? 1.0 : 0.0},
        {VehicleSignal::RightFireIsolated, vehicle.right_fire_isolated ? 1.0 : 0.0},
        {VehicleSignal::FormationIntensity, RAPTOR::form_light},
        {VehicleSignal::RefuelIntensity, RAPTOR::aar_light}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
}

void vehicle_publish() {
    vehicle_publish_power();
    vehicle_publish_air();
    vehicle_publish_environment();
    vehicle_publish_configuration();
    const double apu_flow = vehicle.apu_flow_kg_s;
    const double bingo = vehicle_bus.read(VehicleSignal::BingoRequest);
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::LeftEnginePhase, static_cast<double>(vehicle.left_engine.phase)},
        {VehicleSignal::RightEnginePhase, static_cast<double>(vehicle.right_engine.phase)},
        {VehicleSignal::LeftStartRejection, static_cast<double>(vehicle.left_engine.rejection)},
        {VehicleSignal::RightStartRejection, static_cast<double>(vehicle.right_engine.rejection)},
        {VehicleSignal::LeftFeedAvailable, vehicle_feed(true) ? 1.0 : 0.0},
        {VehicleSignal::RightFeedAvailable, vehicle_feed(false) ? 1.0 : 0.0},
        {VehicleSignal::TotalFlow, RAPTOR::left_fuel_rate + RAPTOR::right_fuel_rate + apu_flow},
        {VehicleSignal::ApuFlow, apu_flow},
        {VehicleSignal::MassOverflow, vehicle.mass.overflow ? 1.0 : 0.0},
        {VehicleSignal::FuelBingo, std::isfinite(bingo) && bingo > 0.0 && RAPTOR::total_fuel < bingo ? 1.0 : 0.0},
        {VehicleSignal::LeftFeedLow, vehicle.fuel.cells[1].quantity_kg < RaptorVehicle::FuelSystem::low_feed_kg ? 1.0 : 0.0},
        {VehicleSignal::RightFeedLow, vehicle.fuel.cells[2].quantity_kg < RaptorVehicle::FuelSystem::low_feed_kg ? 1.0 : 0.0},
        {VehicleSignal::LeftFeedQuantity, vehicle.fuel.cells[1].quantity_kg},
        {VehicleSignal::RightFeedQuantity, vehicle.fuel.cells[2].quantity_kg},
        {VehicleSignal::CommonFeedQuantity, vehicle.fuel.cells[0].quantity_kg},
        {VehicleSignal::FuelBoost, vehicle.fuel.boost},
        {VehicleSignal::FuelPressurization, vehicle.fuel.pressurization},
        {VehicleSignal::Generation, static_cast<double>(vehicle.generation)},
        {VehicleSignal::ClockKind, 1.0}, // spawn-relative RAPTOR clock, not World model time
        {VehicleSignal::ForceValid, vehicle.air_truth.valid ? 1.0 : 0.0},
        {VehicleSignal::Stamp, vehicle.time_s},
        {VehicleSignal::DroppedTime, vehicle.discarded_time_s},
        {VehicleSignal::BrakeReserve, hydraulics.brake_reserve},
        {VehicleSignal::UtilityAvailable, vehicle_utility_supply()},
        {VehicleSignal::ParkHeld, vehicle_on(VehicleSignal::ParkRequest) && RAPTOR::on_ground &&
            RAPTOR::left_brake_achieved > 0.95 && RAPTOR::right_brake_achieved > 0.95 ? 1.0 : 0.0},
        {VehicleSignal::LeftHydraulicInventory, hydraulics.left_inventory},
        {VehicleSignal::RightHydraulicInventory, hydraulics.right_inventory},
        {VehicleSignal::LeftBleedAvailable, vehicle.left_engine.burning &&
            !vehicle.left_fire_isolated && left_engine_instruments.core >= 0.59 &&
            (!vehicle.power_requests_seen || vehicle_on(VehicleSignal::LeftBleedRequest)) ? 1.0 : 0.0},
        {VehicleSignal::RightBleedAvailable, vehicle.right_engine.burning &&
            !vehicle.right_fire_isolated && right_engine_instruments.core >= 0.59 &&
            (!vehicle.power_requests_seen || vehicle_on(VehicleSignal::RightBleedRequest)) ? 1.0 : 0.0},
        {VehicleSignal::LeftBrakeTemperature, vehicle.left_brake.temperature_c},
        {VehicleSignal::RightBrakeTemperature, vehicle.right_brake.temperature_c},
        {VehicleSignal::LeftBrakeEnergy, vehicle.left_brake.energy_j},
        {VehicleSignal::RightBrakeEnergy, vehicle.right_brake.energy_j},
        {VehicleSignal::LeftWheelSpeedRaw, vehicle.left_brake.wheel_speed_raw},
        {VehicleSignal::RightWheelSpeedRaw, vehicle.right_brake.wheel_speed_raw},
        {VehicleSignal::BrakeEnergyEstimated, 1.0},
        {VehicleSignal::LeftFireDetected, vehicle.left_fire ? 1.0 : 0.0},
        {VehicleSignal::RightFireDetected, vehicle.right_fire ? 1.0 : 0.0},
        {VehicleSignal::FireDischarge, vehicle.extinguishing_attempt ? 1.0 : 0.0}};
    for (const auto& value : values) vehicle_bus.write(value.first, value.second);
    vehicle_bus.write(VehicleSignal::Valid, vehicle.alive ? 1.0 : 0.0);
}

void vehicle_publish_mass() {
    const std::pair<VehicleSignal, double> values[] = {
        {VehicleSignal::MassValid, vehicle.mass_valid ? 1.0 : 0.0},
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
    vehicle.left_brake.update(RAPTOR::left_brake_achieved, speed, ambient_c,
        RAPTOR::on_ground, dt);
    vehicle.right_brake.update(RAPTOR::right_brake_achieved, speed, ambient_c,
        RAPTOR::on_ground, dt);
    vehicle.left_fire = vehicle_on(VehicleSignal::LeftFireFault);
    vehicle.right_fire = vehicle_on(VehicleSignal::RightFireFault);
}

void vehicle_repair_injected_faults() {
    constexpr VehicleSignal faults[] = {
        VehicleSignal::BatteryFault, VehicleSignal::LeftGeneratorFault,
        VehicleSignal::RightGeneratorFault, VehicleSignal::ApuFault,
        VehicleSignal::LeftHydraulicFault, VehicleSignal::RightHydraulicFault,
        VehicleSignal::LeftFeedFault, VehicleSignal::RightFeedFault,
        VehicleSignal::TransferFault, VehicleSignal::AirDataHealth,
        VehicleSignal::EcsFault, VehicleSignal::CoolingFault, VehicleSignal::OxygenFault,
        VehicleSignal::LeftPumpOneFault, VehicleSignal::LeftPumpTwoFault,
        VehicleSignal::RightPumpOneFault, VehicleSignal::RightPumpTwoFault,
        VehicleSignal::LeftFireFault, VehicleSignal::RightFireFault};
    for (const auto fault : faults) vehicle_bus.write(fault, 0.0);
}
} // namespace
