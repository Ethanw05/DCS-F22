#pragma once

#include <array>
#include <cstddef>
#include <limits>
#include <Cockpit/CockpitAPI_Declare.h>

namespace RaptorVehicle {
enum class Signal : std::size_t {
    RequestValid, BatteryRequest, LeftGeneratorRequest, RightGeneratorRequest,
    ApuRequest, GroundPower, BatteryFault, LeftGeneratorFault, RightGeneratorFault,
    ApuFault, LeftHydraulicFault, RightHydraulicFault, LeftFeedFault, RightFeedFault,
    TransferFault, AirDataHealth, AirDataBias, EcsFault, CoolingFault, OxygenFault,
    LeftBleedRequest, RightBleedRequest, EcsRequest, DefogRequest,
    CanopyValid, CanopyPosition, CanopyLocked, BackupManual, HistoricalOxygen,
    RefuelDoorRequest, RefuelDisconnectRequest, BingoRequest,
    Owner, Valid, Generation, Stamp, DroppedTime, BatterySoc, DcVolts,
    EssentialPower, ElectricalValid, MainPower, BatteryPower, LeftGeneratorPower,
    RightGeneratorPower, ApuPower, ApuRpm, ApuReady, ApuHydraulics, ApuAir,
    ApuAbort, SesAir, SesFuel, AirValid, AirStamp, Tas, Eas, Cas, Mach,
    StaticPressure, ImpactPressure, RawBodyAy, AirHealth,
    LeftEnginePhase, RightEnginePhase, LeftStartRejection, RightStartRejection,
    LeftFeedAvailable, RightFeedAvailable, TotalFlow, ApuFlow, MassOverflow,
    FuelBingo, LeftFeedLow, RightFeedLow, CabinPressure, CabinOverpressure,
    EnvironmentValid, EquipmentTemperature, CoolantTemperature, FuelTemperature,
    ThermalFault, ConditionedAir, Obogs, OxygenBackup, OxygenReserve,
    OxygenPressure, CanopyFog, FcsMode, SingleEngineApproach, ApproachAoa,
    GearRejection, GearUnsafe, AlternateGear, HookPosition, SteeringSelected,
    RefuelDoorPosition, RefuelReady, RefuelTransfer, FireBottle,
    LeftFireIsolated, RightFireIsolated, LeftFireFault, RightFireFault,
    FormationIntensity, RefuelIntensity, LeftPumpOneFault, LeftPumpTwoFault,
    RightPumpOneFault, RightPumpTwoFault, LeftPumpOne, LeftPumpTwo,
    RightPumpOne, RightPumpTwo, LeftHydraulicLoad, RightHydraulicLoad,
    HydraulicDemandValid, BrakeReserve, ApuAutomaticShutdown,
    LeftBrakeTemperature, RightBrakeTemperature, LeftBrakeEnergy, RightBrakeEnergy,
    LeftWheelSpeedRaw, RightWheelSpeedRaw, BrakeEnergyEstimated,
    LeftFireDetected, RightFireDetected, FireDischarge, MassValid, MassKg,
    CgX, CgY, CgZ, InertiaX, InertiaY, InertiaZ, GearDownLocked, GearUpLocked,
    LeftHydraulicInventory, RightHydraulicInventory, MissionPowerAvailable,
    MainSource, LeftBleedAvailable, RightBleedAvailable, LeftFeedQuantity,
    RightFeedQuantity, CommonFeedQuantity, FuelBoost, FuelPressurization,
    ParkRequest, ParkHeld, PowerRequestSequence, AirDataReversion,
    ControlScheduleMach, ControlScheduleEas, UtilityAvailable, ClockKind,
    ForceValid,
    EngineControlSchema, LeftStarterFault, RightStarterFault,
    LeftIgnitionFault, RightIgnitionFault, LeftHungStartFault,
    RightHungStartFault, LeftHotStartFault, RightHotStartFault,
    LeftControlDegradedFault, RightControlDegradedFault, LeftControlFailedFault,
    RightControlFailedFault, LeftAugmentationFault, RightAugmentationFault,
    LeftStarterSelected, RightStarterSelected, LeftStarterEngaged,
    RightStarterEngaged, LeftFuelSelected, RightFuelSelected,
    LeftFuelValve, RightFuelValve, LeftIgnitionSelected,
    RightIgnitionSelected, LeftStartFault, RightStartFault,
    LeftEngineControl, RightEngineControl, LeftPurgeSeconds,
    RightPurgeSeconds, LeftStartElapsed, RightStartElapsed,
    LeftAugmentationAvailable, RightAugmentationAvailable,
    LeftControlAvailable, RightControlAvailable,
    LeftStartResetReady, RightStartResetReady,
    EngineIndicationSchema, LeftEngineFlow, RightEngineFlow,
    HydraulicDemandSchema, HydraulicDemandGeneration, HydraulicDemandStamp,
    HydraulicDemandSequence, FuelInventoryValid, LeftTankInstalled, RightTankInstalled,
    LeftBrakeEffectiveness, RightBrakeEffectiveness, LeftTireTemperature,
    RightTireTemperature, LeftTireFailed, RightTireFailed, FuelInventoryStamp,
    GroundClearance, SurfaceValid, WheelZeroCompression, WheelOneCompression,
    WheelTwoCompression, WheelZeroReaction, WheelOneReaction, WheelTwoReaction,
    WheelZeroAge, WheelOneAge, WheelTwoAge, Invulnerable, DamageCallbacks,
    LastDamageCell, LastDamageIntegrity, Destroyed, Count
};

inline constexpr std::array<const char*, static_cast<std::size_t>(Signal::Count)> signal_names = {
    "F22_POWER_REQUEST_VALID", "F22_BATTERY_REQUEST", "F22_L_GEN_REQUEST", "F22_R_GEN_REQUEST",
    "F22_APU_REQUEST", "GROUND_POWER", "BATTERY_FAILURE", "L_GEN_FAILURE", "R_GEN_FAILURE",
    "APU_FAILURE", "L_HYD_FAILURE", "R_HYD_FAILURE", "F22_L_FEED_FAILURE", "F22_R_FEED_FAILURE",
    "F22_TRANSFER_FAILURE", "F22_AIRDATA_HEALTH_REQUEST", "F22_AIRDATA_CAS_BIAS_MPS",
    "F22_ECS_FAILURE", "F22_COOLING_FAILURE", "F22_OXYGEN_FAILURE",
    "F22_L_BLEED_REQUEST", "F22_R_BLEED_REQUEST", "F22_ECS_REQUEST", "F22_DEFOG_REQUEST",
    "F22_CANOPY_PROVIDER_VALID", "F22_CANOPY_POSITION", "F22_CANOPY_LOCKED",
    "F22_OXYGEN_BACKUP_REQUEST", "F22_OXYGEN_HISTORICAL",
    "F22_REFUEL_DOOR_REQUEST", "F22_REFUEL_DISCONNECT_REQUEST", "F22_BINGO_KG_REQUEST",
    "EFM_POWER_OWNER", "EFM_PHYSICAL_VALID", "EFM_PHYSICAL_GENERATION", "EFM_PHYSICAL_STAMP",
    "EFM_PHYSICAL_DROPPED_TIME_S", "F22_BATTERY_SOC", "F22_DC_VOLTS", "F22_ESSENTIAL_POWER",
    "F22_ELECTRICAL_VALID", "MAIN_POWER", "BATTERY_POWER", "L_GEN_POWER", "R_GEN_POWER",
    "APU_POWER", "APU_RPM_STATE", "APU_READY", "EFM_APU_HYD_AVAILABLE", "EFM_APU_AIR_AVAILABLE",
    "EFM_APU_ABORT", "EFM_SES_AIR", "EFM_SES_FUEL", "EFM_AIRDATA_VALID", "EFM_AIRDATA_STAMP",
    "EFM_AIRDATA_TAS_MPS", "EFM_AIRDATA_EAS_MPS", "EFM_AIRDATA_CAS_MPS", "EFM_AIRDATA_MACH",
    "EFM_AIRDATA_STATIC_PA", "EFM_AIRDATA_IMPACT_PA", "EFM_BODY_AY_MPS2", "EFM_AIRDATA_HEALTH",
    "EFM_L_ENGINE_PHASE", "EFM_R_ENGINE_PHASE", "EFM_L_START_REJECTION", "EFM_R_START_REJECTION",
    "EFM_L_FEED_AVAILABLE", "EFM_R_FEED_AVAILABLE", "EFM_TOTAL_FUEL_FLOW_KG_S", "EFM_APU_FLOW_KG_S",
    "EFM_MASS_LEDGER_OVERFLOW", "EFM_FUEL_BINGO", "EFM_L_FEED_LOW", "EFM_R_FEED_LOW",
    "EFM_CABIN_ABSOLUTE_PA", "EFM_CABIN_OVERPRESSURE_PA", "EFM_ENVIRONMENT_VALID",
    "EFM_EQUIPMENT_TEMP_C", "EFM_COOLANT_TEMP_C", "EFM_FUEL_TEMP_C", "EFM_THERMAL_FAULT",
    "EFM_CONDITIONED_AIR_AVAILABLE", "EFM_OBOGS_AVAILABLE", "EFM_OXYGEN_BACKUP_ACTIVE",
    "EFM_OXYGEN_RESERVE", "EFM_OXYGEN_DELIVERY_PA", "EFM_CANOPY_FOG",
    "EFM_FCS_CONFIGURATION", "EFM_SINGLE_ENGINE_APPROACH", "EFM_APPROACH_AOA_DEG",
    "EFM_GEAR_REJECTION", "EFM_GEAR_UNSAFE", "EFM_ALTERNATE_GEAR", "EFM_HOOK_POSITION",
    "EFM_NWS_SELECTED", "EFM_REFUEL_DOOR_POSITION", "EFM_REFUEL_READY", "EFM_REFUEL_TRANSFER",
    "EFM_FIRE_BOTTLE_AVAILABLE", "EFM_L_FIRE_ISOLATED", "EFM_R_FIRE_ISOLATED",
    "F22_L_ENGINE_FIRE", "F22_R_ENGINE_FIRE", "EFM_FORMATION_INTENSITY", "EFM_REFUEL_INTENSITY",
    "F22_L_HYD_PUMP_1_FAILURE", "F22_L_HYD_PUMP_2_FAILURE", "F22_R_HYD_PUMP_1_FAILURE",
    "F22_R_HYD_PUMP_2_FAILURE", "EFM_L_HYD_PUMP_1", "EFM_L_HYD_PUMP_2", "EFM_R_HYD_PUMP_1",
    "EFM_R_HYD_PUMP_2", "F22_L_HYD_LOAD", "F22_R_HYD_LOAD", "F22_HYD_DEMAND_VALID", "EFM_BRAKE_RESERVE",
    "EFM_APU_AUTO_SHUTDOWN", "EFM_L_BRAKE_TEMP_EST_C", "EFM_R_BRAKE_TEMP_EST_C",
    "EFM_L_BRAKE_WORK_UPPER_J", "EFM_R_BRAKE_WORK_UPPER_J", "EFM_L_WHEEL_SPEED_RAW",
    "EFM_R_WHEEL_SPEED_RAW", "EFM_BRAKE_ENERGY_ESTIMATED", "EFM_L_FIRE_DETECTED",
    "EFM_R_FIRE_DETECTED", "EFM_FIRE_DISCHARGE_ATTEMPT", "EFM_MASS_VALID", "EFM_MASS_KG",
    "EFM_CG_X_M", "EFM_CG_Y_M", "EFM_CG_Z_M", "EFM_INERTIA_X_KGM2", "EFM_INERTIA_Y_KGM2",
    "EFM_INERTIA_Z_KGM2", "EFM_GEAR_DOWN_LOCKED", "EFM_GEAR_UP_LOCKED",
    "EFM_L_HYD_INVENTORY", "EFM_R_HYD_INVENTORY", "EFM_MISSION_POWER_AVAILABLE",
    "EFM_MAIN_POWER_SOURCE", "EFM_L_BLEED_AVAILABLE", "EFM_R_BLEED_AVAILABLE",
    "EFM_L_FEED_KG", "EFM_R_FEED_KG", "EFM_COMMON_FEED_KG", "EFM_FUEL_BOOST",
    "EFM_FUEL_PRESSURIZATION", "F22_PARK_REQUEST", "EFM_PARK_HELD", "F22_POWER_REQUEST_SEQUENCE",
    "EFM_FCS_AIRDATA_REVERSION", "EFM_FCS_SCHEDULE_MACH", "EFM_FCS_SCHEDULE_EAS_MPS",
    "EFM_UTILITY_AVAILABLE", "EFM_PHYSICAL_CLOCK_KIND", "EFM_FORCE_VALID",
    "EFM_ENGINE_CONTROL_SCHEMA", "F22_L_STARTER_FAILURE", "F22_R_STARTER_FAILURE",
    "F22_L_IGNITION_FAILURE", "F22_R_IGNITION_FAILURE", "F22_L_HUNG_START_FAILURE",
    "F22_R_HUNG_START_FAILURE", "F22_L_HOT_START_FAILURE", "F22_R_HOT_START_FAILURE",
    "F22_L_CONTROL_DEGRADED_FAILURE", "F22_R_CONTROL_DEGRADED_FAILURE", "F22_L_CONTROL_FAILED_FAILURE",
    "F22_R_CONTROL_FAILED_FAILURE", "F22_L_AUGMENTATION_FAILURE", "F22_R_AUGMENTATION_FAILURE",
    "EFM_L_STARTER_SELECTED", "EFM_R_STARTER_SELECTED", "EFM_L_STARTER_ENGAGED",
    "EFM_R_STARTER_ENGAGED", "EFM_L_FUEL_SELECTED", "EFM_R_FUEL_SELECTED",
    "EFM_L_FUEL_VALVE", "EFM_R_FUEL_VALVE", "EFM_L_IGNITION_SELECTED",
    "EFM_R_IGNITION_SELECTED", "EFM_L_START_FAULT", "EFM_R_START_FAULT",
    "EFM_L_ENGINE_CONTROL", "EFM_R_ENGINE_CONTROL", "EFM_L_PURGE_S",
    "EFM_R_PURGE_S", "EFM_L_START_ELAPSED_S", "EFM_R_START_ELAPSED_S",
    "EFM_L_AUG_AVAILABLE", "EFM_R_AUG_AVAILABLE",
    "EFM_L_CONTROL_AVAILABLE", "EFM_R_CONTROL_AVAILABLE",
    "EFM_L_START_RESET_READY", "EFM_R_START_RESET_READY",
    "EFM_ENGINE_INDICATION_SCHEMA", "EFM_ENGINE_LEFT_FLOW_KG_S", "EFM_ENGINE_RIGHT_FLOW_KG_S",
    "F22_HYD_DEMAND_SCHEMA", "F22_HYD_DEMAND_GENERATION", "F22_HYD_DEMAND_STAMP",
    "F22_HYD_DEMAND_SEQUENCE", "F22_FUEL_INVENTORY_VALID", "F22_LEFT_TANK_INSTALLED",
    "F22_RIGHT_TANK_INSTALLED", "EFM_L_BRAKE_EFFECTIVENESS", "EFM_R_BRAKE_EFFECTIVENESS",
    "EFM_L_TIRE_TEMP_EST_C", "EFM_R_TIRE_TEMP_EST_C", "EFM_L_TIRE_FAILED", "EFM_R_TIRE_FAILED",
    "F22_FUEL_INVENTORY_STAMP", "EFM_GROUND_CLEARANCE_M", "EFM_SURFACE_VALID",
    "EFM_WHEEL_0_COMPRESSION", "EFM_WHEEL_1_COMPRESSION", "EFM_WHEEL_2_COMPRESSION",
    "EFM_WHEEL_0_REACTION_N", "EFM_WHEEL_1_REACTION_N", "EFM_WHEEL_2_REACTION_N",
    "EFM_WHEEL_0_FEEDBACK_AGE_S", "EFM_WHEEL_1_FEEDBACK_AGE_S", "EFM_WHEEL_2_FEEDBACK_AGE_S",
    "EFM_INVULNERABLE", "EFM_DAMAGE_CALLBACKS", "EFM_LAST_DAMAGE_CELL",
    "EFM_LAST_DAMAGE_INTEGRITY", "EFM_DESTROYED"
};
static_assert([] {
    for (const auto* name : signal_names) if (name == nullptr) return false;
    return true;
}(), "Every vehicle signal must have a registered name");

class VehicleBus {
public:
    void initialize(EDPARAM& api) {
        api_ = &api;
        const auto get = api.ed_param_api.pfn_ed_cockpit_get_parameter_handle;
        for (std::size_t index = 0; index < handles_.size(); ++index)
            handles_[index] = get ? get(signal_names[index]) : nullptr;
    }
    double read(Signal signal) const {
        const auto index = static_cast<std::size_t>(signal);
        double value = std::numeric_limits<double>::quiet_NaN();
        if (index >= handles_.size() || !api_ || !handles_[index]) return value;
        const auto get = api_->ed_param_api.pfn_ed_cockpit_parameter_value_to_number;
        if (!get || !get(handles_[index], value, false))
            return std::numeric_limits<double>::quiet_NaN();
        return value;
    }
    void write(Signal signal, double value) const {
        const auto index = static_cast<std::size_t>(signal);
        if (index >= handles_.size() || !api_ || !handles_[index]) return;
        const auto set = api_->ed_param_api.pfn_ed_cockpit_update_parameter_with_number;
        if (set) set(handles_[index], value);
    }
private:
    EDPARAM* api_ = nullptr; // borrowed, lives in the EFM CockpitManager
    std::array<void*, signal_names.size()> handles_{};
};
} // namespace RaptorVehicle
