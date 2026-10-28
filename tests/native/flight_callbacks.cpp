// R-FLT-001/013 and D-R-INT-001. Independent source-admission and history oracle.
// This executable loads an external test DLL; it cannot attach to running DCS.
#include <Windows.h>
#include <FM/wHumanCustomPhysicsAPI.h>
#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
void require(bool value, const char* description) {
    if (!value) throw std::runtime_error(description);
}
bool close_to(double actual, double expected, double tolerance = 1e-6) {
    return std::isfinite(actual) && std::abs(actual - expected) <=
        std::max(tolerance, 1e-9 * std::abs(expected));
}
struct Module {
    HMODULE value;
    explicit Module(const char* path) : value(LoadLibraryA(path)) {
        require(value != nullptr, "Cannot load explicitly supplied external module");
    }
    ~Module() { if (value) FreeLibrary(value); }
    Module(const Module&) = delete;
    Module& operator=(const Module&) = delete;
    template<class Function> Function symbol(const char* name) const {
        const auto address = GetProcAddress(value, name);
        require(address != nullptr, name);
        return std::bit_cast<Function>(address);
    }
};
using Void = void(*)();
using Scalar = void(*)(double);
using Atmosphere = void(*)(double, double, double, double, double, double, double, double);
using State = void(*)(double, double, double, double, double, double, double, double,
    double, double, double, double, double, double, double, double, double, double, double);
using Body = void(*)(double, double, double, double, double, double, double, double,
    double, double, double, double, double, double, double, double, double, double, double, double);
using Mass = void(*)(double, double, double, double, double, double, double);
using Surface = void(*)(double, double, unsigned, double, double, double);
using Command = void(*)(int, float);
using Draw = void(*)(float*, std::size_t);
using Put = void(*)(const char*, double);
using Get = double(*)(const char*);

struct Port {
    const Module& efm;
    Put put;
    Get get;
    Void clear;
    Scalar clock;
    Scalar simulate;
    Atmosphere atmosphere;
    State world;
    Body body;
    Mass mass;
    Surface surface;
    Command command;
    Draw draw;
    double now = 10000.0;
    explicit Port(const Module& aircraft, const Module& cockpit, const Module& world_module)
        : efm(aircraft), put(cockpit.symbol<Put>("flight_set_number")),
          get(cockpit.symbol<Get>("flight_get_number")),
          clear(cockpit.symbol<Void>("flight_clear")),
          clock(world_module.symbol<Scalar>("flight_set_model_time")),
          simulate(efm.symbol<Scalar>("ed_fm_simulate")),
          atmosphere(efm.symbol<Atmosphere>("ed_fm_set_atmosphere")),
          world(efm.symbol<State>("ed_fm_set_current_state")),
          body(efm.symbol<Body>("ed_fm_set_current_state_body_axis")),
          mass(efm.symbol<Mass>("ed_fm_set_current_mass_state")),
          surface(efm.symbol<Surface>("ed_fm_set_surface")),
          command(efm.symbol<Command>("ed_fm_set_command")),
          draw(efm.symbol<Draw>("ed_fm_set_draw_args_v2")) {}

    void motion(double north = 200.0) {
        world(0, 0, 0, north, 0, 0, 0, 10000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1);
        body(0, 9.80665, 0, 200, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    }
    void healthy_atmosphere() { atmosphere(10000, 223, 300, .4135, 26436, 0, 0, 0); }
    void spawn(const char* kind, bool release = true) {
        if (release) {
            efm.symbol<Void>("ed_fm_release")();
            clear();
        }
        now = 10000.0;
        clock(now);
        efm.symbol<Scalar>("ed_fm_set_internal_fuel")(5000);
        efm.symbol<Void>(kind)();
        efm.symbol<void(*)(const char*)>("ed_fm_configure")(".");
        put("F22_AIRDATA_HEALTH_REQUEST", 0);
        put("F22_AIRDATA_CAS_BIAS_MPS", 0);
        put("F22_CANOPY_PROVIDER_VALID", 1);
        put("F22_CANOPY_POSITION", 0);
        put("F22_CANOPY_LOCKED", 1);
        put("F22_ALT_STANDBY_FAILURE", 0);
        mass(25000, 0, 0, 0, 100000, 150000, 200000);
        surface(0, 0, 1, 0, 1, 0);
        healthy_atmosphere();
        motion();
    }
    void step(double dt = .02) {
        now += dt;
        clock(now);
        simulate(dt);
    }
    void combat() { command(10850, .02f); }
    double rudder() {
        std::array<float, 2000> args{};
        draw(args.data(), args.size());
        require(close_to(args[17], args[18]), "Healthy left/right achieved rudders differ");
        return args[17];
    }
};

void assert_shared_failure(Port& p, double reserve) {
    require(p.get("EFM_HUD_VALID") == 0, "Fallback atmosphere authenticated legacy flight");
    require(p.get("EFM_ENVIRONMENT_VALID") == 0, "Fallback atmosphere authenticated environment");
    require(p.get("EFM_AIRDATA_VALID") == 0, "Invalid atmosphere authenticated ADC");
    require(p.get("EFM_OBOGS_AVAILABLE") == 0, "Fallback atmosphere authenticated OBOGS");
    require(p.get("EFM_HUD_KINEMATICS_VALID") == 1 && close_to(p.get("EFM_HUD_VN"), 200),
        "Atmosphere failure removed independent world motion");
    require(p.get("F22_ALT_STANDBY_NATIVE_VALID") == 0, "Invalid shared atmosphere authenticated standby");
    require(p.get("EFM_OXYGEN_BACKUP_ACTIVE") == 1 &&
        p.get("EFM_OXYGEN_RESERVE") < reserve && p.get("EFM_OXYGEN_RESERVE") >= 0,
        "Independent finite oxygen lost or refilled during atmosphere failure");
}

void atmosphere_cases(Port& p) {
    p.spawn("ed_fm_hot_start_in_air");
    p.step();
    p.combat();
    require(p.get("EFM_ENVIRONMENT_VALID") == 1, "Healthy environment unavailable");
    require(p.get("EFM_HUD_VALID") == 1, "Healthy legacy flight group unavailable");
    require(p.get("EFM_HUD_KINEMATICS_VALID") == 1, "Healthy independent velocity unavailable");
    require(close_to(p.get("EFM_HUD_VN"), 200), "World velocity transport differs");
    require(p.get("F22_ALT_STANDBY_NATIVE_VALID") == 1, "Healthy standby unavailable");
    const double baseline_altitude = p.get("F22_ALT_STANDBY_NATIVE_M");
    p.put("F22_AIRDATA_HEALTH_REQUEST", 1);
    p.step(); p.combat();
    require(p.get("EFM_AIRDATA_VALID") == 0, "ADC fault did not withdraw primary");
    require(p.get("F22_ALT_STANDBY_NATIVE_VALID") == 1 &&
        close_to(p.get("F22_ALT_STANDBY_NATIVE_M"), baseline_altitude), "ADC fault removed independent standby");
    p.put("F22_AIRDATA_HEALTH_REQUEST", 0);
    const double nan = std::numeric_limits<double>::quiet_NaN();
    const double inf = std::numeric_limits<double>::infinity();
    const std::array<double, 8> healthy{10000, 223, 300, .4135, 26436, 0, 0, 0};
    const std::array<double, 8> outside{100001, 99, 99, 0, 0, 5001, 5001, 5001};
    unsigned cases = 0;
    for (std::size_t field = 0; field < healthy.size(); ++field) {
        for (double bad : {nan, inf, -inf, outside[field]}) {
            p.healthy_atmosphere(); p.step(); p.combat();
            const double reserve = p.get("EFM_OXYGEN_RESERVE");
            auto sample = healthy;
            sample[field] = bad;
            p.atmosphere(sample[0], sample[1], sample[2], sample[3], sample[4], sample[5], sample[6], sample[7]);
            p.step(); p.combat();
            assert_shared_failure(p, reserve);
            p.healthy_atmosphere(); p.step(); p.combat();
            require(p.get("EFM_ENVIRONMENT_VALID") == 1 && p.get("F22_ALT_STANDBY_NATIVE_VALID") == 1,
                "Qualified atmospheric restoration did not recover eligible groups");
            ++cases;
        }
    }
    p.motion(nan); p.step();
    require(p.get("EFM_HUD_KINEMATICS_VALID") == 0, "Invalid world motion remained healthy");
    p.motion(); p.healthy_atmosphere(); p.step();
    p.efm.symbol<Void>("ed_fm_hot_start_in_air")();
    require(p.get("EFM_HUD_VALID") == 0 && p.get("EFM_HUD_KINEMATICS_VALID") == 0,
        "Fresh spawn without release retained previous generation validity");
    p.efm.symbol<Void>("ed_fm_release")();
    require(p.get("EFM_HUD_VALID") == 0 && p.get("EFM_HUD_KINEMATICS_VALID") == 0,
        "Release retained flight validity");
    std::cout << "Atmosphere: " << cases << " field/failure cases plus ADC independence and recovery\n";
}

std::vector<double> yaw_trace(Port& p, const char* spawn, int history, int new_command,
    bool release = true) {
    p.spawn("ed_fm_hot_start_in_air");
    if (history == 2) {
        p.command(2003, -.5f);
        for (unsigned i = 0; i < 100; ++i) p.step();
        p.command(2003, 0);
    } else if (history != 0) {
        p.command(history > 0 ? 201 : 203, 1);
        for (unsigned i = 0; i < 100; ++i) p.step();
        p.command(history > 0 ? 202 : 204, 0); // Explicit release before fresh spawn.
    }
    p.spawn(spawn, release);
    p.command(new_command, new_command == 2003 ? 0.0f : 1.0f);
    std::vector<double> trace;
    for (unsigned i = 0; i < 20; ++i) { p.step(); trace.push_back(p.rudder()); }
    return trace;
}
std::vector<double> release_trace(Port& p, int request, bool late_release) {
    p.spawn("ed_fm_hot_start_in_air");
    p.command(201, 1);
    p.command(request, request == 2003 ? -.4f : 1.0f);
    if (late_release) p.command(202, 0);
    std::vector<double> trace;
    for (unsigned i = 0; i < 20; ++i) { p.step(); trace.push_back(p.rudder()); }
    return trace;
}
void yaw_cases(Port& p) {
    unsigned comparisons = 0;
    for (const auto* start : {"ed_fm_cold_start", "ed_fm_hot_start", "ed_fm_hot_start_in_air"}) {
        for (int request : {201, 203, 2003}) {
            for (bool release : {false, true}) {
                const auto neutral = yaw_trace(p, start, 0, request, release);
                for (int history : {-1, 1, 2}) {
                    const auto previous = yaw_trace(p, start, history, request, release);
                    for (std::size_t i = 0; i < neutral.size(); ++i)
                        require(close_to(previous[i], neutral[i]), "Prior released yaw changed new-generation trajectory");
                    ++comparisons;
                }
            }
        }
    }
    for (int request : {203, 2003}) {
        const auto control = release_trace(p, request, false);
        const auto late = release_trace(p, request, true);
        require(control == late, "Late keyboard release stole opposite/analog request ownership");
    }
    p.spawn("ed_fm_hot_start_in_air");
    p.command(201, 1);
    for (unsigned i = 0; i < 6; ++i) p.step();
    require(std::abs(p.rudder()) > 0, "Healthy held keyboard yaw did not achieve rudder motion");
    const double before = p.rudder();
    const double clock = p.get("F22_AP_CLOCK");
    p.simulate(0); p.simulate(-1); p.simulate(std::numeric_limits<double>::quiet_NaN());
    p.simulate(std::numeric_limits<double>::infinity());
    for (unsigned i = 0; i < 20; ++i) static_cast<void>(p.rudder());
    require(close_to(p.rudder(), before) && p.get("F22_AP_CLOCK") == clock,
        "Invalid/zero dt or draw-only call advanced physical state");
    const double dropped = p.get("EFM_PHYSICAL_DROPPED_TIME_S");
    p.simulate(10);
    require(close_to(p.get("F22_AP_CLOCK"), clock + 1) &&
        close_to(p.get("EFM_PHYSICAL_DROPPED_TIME_S"), dropped + 9),
        "Large callback exceeded the bounded one-second integration window");
    std::cout << "Yaw: " << comparisons << " history/spawn/request comparisons and no-advance cases\n";
}
void baseline_observations(Port& p) {
    p.spawn("ed_fm_hot_start_in_air"); p.step(); p.combat();
    const double healthy_pressure = p.get("EFM_HUD_PRESSURE");
    p.atmosphere(10000, 223, 300, .4135,
        std::numeric_limits<double>::quiet_NaN(), 0, 0, 0);
    p.step(); p.combat();
    std::cout << "Baseline invalid shared pressure: original=" << healthy_pressure
        << " fallback=" << p.get("EFM_HUD_PRESSURE")
        << " environment_valid=" << p.get("EFM_ENVIRONMENT_VALID")
        << " legacy_hud_valid=" << p.get("EFM_HUD_VALID")
        << " standby_valid=" << p.get("F22_ALT_STANDBY_NATIVE_VALID") << '\n';
    const auto left = yaw_trace(p, "ed_fm_hot_start_in_air", 1, 201);
    const auto right = yaw_trace(p, "ed_fm_hot_start_in_air", -1, 201);
    std::cout << "Baseline explicit prior release, identical fresh left input: prior_left="
        << left[5] << " prior_right=" << right[5] << '\n';
    require(p.get("EFM_ENVIRONMENT_VALID") == 1, "Observation fixture lost healthy environment");
}
void healthy_fingerprint(Port& p) {
    p.spawn("ed_fm_hot_start_in_air");
    p.command(201, 1);
    const auto force = p.efm.symbol<void(*)(double&, double&, double&, double&, double&, double&)>(
        "ed_fm_add_local_force");
    const auto moment = p.efm.symbol<void(*)(double&, double&, double&)>("ed_fm_add_local_moment");
    std::cout << std::setprecision(17);
    for (unsigned i = 0; i < 20; ++i) {
        p.step();
        double x = 0, y = 0, z = 0, px = 0, py = 0, pz = 0, mx = 0, my = 0, mz = 0;
        force(x, y, z, px, py, pz); moment(mx, my, mz);
        std::cout << x << ',' << y << ',' << z << ',' << mx << ',' << my << ',' << mz
            << ',' << p.rudder() << ',' << p.get("EFM_AIRDATA_CAS_MPS") << '\n';
    }
}
void gear_callback_cases(Port& p) {
    const auto damage = p.efm.symbol<void(*)(int, double)>("ed_fm_on_damage");
    const auto parameter = p.efm.symbol<double(*)(unsigned)>("ed_fm_get_param");
    constexpr const char* lamps[] = {"N_GEAR_LIGHT", "L_GEAR_LIGHT", "R_GEAR_LIGHT"};
    constexpr const char* locks[] = {"EFM_GEAR_NOSE_DOWN_LOCKED", "EFM_GEAR_LEFT_DOWN_LOCKED",
        "EFM_GEAR_RIGHT_DOWN_LOCKED"};
    constexpr unsigned sdk_locks[] = {ED_FM_SUSPENSION_0_DOWN_LOCK,
        ED_FM_SUSPENSION_1_DOWN_LOCK, ED_FM_SUSPENSION_2_DOWN_LOCK};
    constexpr int damage_cells[] = {8, 15, 16, 83, 84, 85};
    for (unsigned test = 0; test < 6; ++test) {
        p.spawn("ed_fm_hot_start"); p.step();
        for (const auto* lamp : lamps) require(p.get(lamp) == 1, "Healthy achieved gear lamp unavailable");
        damage(damage_cells[test], 0); p.step();
        for (unsigned leg = 0; leg < 3; ++leg) {
            const double expected = leg == test % 3 ? 0.0 : 1.0;
            require(p.get(lamps[leg]) == expected && p.get(locks[leg]) == expected &&
                parameter(sdk_locks[leg]) == expected, "Per-leg lamp/physical/SDK lock disagrees");
        }
        require(p.get("EFM_GEAR_UNSAFE") == 1 && p.get("EFM_GEAR_DOWN_LOCKED") == 0,
            "Damaged leg retained aggregate down lock");
        require(p.get("EFM_GEAR_NOSE_DOOR_VALID") == 0 &&
            p.get("EFM_GEAR_HOST_EFFECTS_QUALIFIED") == 0, "Unobserved door/host effect authenticated");
    }
    p.efm.symbol<Void>("ed_fm_release")();
    for (const auto* lamp : lamps) require(p.get(lamp) == 0, "Release retained a gear lamp");
    std::cout << "Gear:6independent damage-cell cases agree across SDK, locks and lamps\n";
}
std::array<double, 6> forces(Port& p) {
    std::array<double, 6> result{};
    double x = 0, y = 0, z = 0;
    p.efm.symbol<void(*)(double&, double&, double&, double&, double&, double&)>("ed_fm_add_local_force")(
        result[0], result[1], result[2], x, y, z);
    p.efm.symbol<void(*)(double&, double&, double&)>("ed_fm_add_local_moment")(
        result[3], result[4], result[5]);
    return result;
}
void force_and_mass_cases(Port& p) {
    std::array<double, 6> reference{};
    for (double wind : {0.0, -50.0, 50.0}) {
        p.spawn("ed_fm_hot_start_in_air");
        p.atmosphere(10000, 223, 300, .4135, 26436, wind, 0, 0);
        p.world(0, 0, 0, 200 + wind, 0, 0, 0, 10000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1);
        p.body(0, 9.80665, 0, 200 + wind, 0, 0, wind, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        for (unsigned step = 0; step < 20; ++step) p.step();
        const auto actual = forces(p);
        if (wind == 0) reference = actual;
        for (unsigned axis = 0; axis < 6; ++axis)
            require(close_to(actual[axis], reference[axis]), "Airborne relative-wind translation changed force/moment");
    }
    p.mass(0, 0, 0, 0, 0, 0, 0); p.step();
    for (double component : forces(p)) require(component == 0, "Invalid mass produced force/moment");
    p.mass(25000, 0, 0, 0, 100000, 150000, 200000); p.step();
    require(p.get("EFM_FORCE_VALID") == 1, "Fresh mass did not restore physical eligibility");
    const auto fuel = p.efm.symbol<double(*)()>("ed_fm_get_internal_fuel");
    const double before = fuel();
    p.efm.symbol<Void>("ed_fm_repair")();
    require(fuel() == before, "Repair refilled fuel");
    std::cout << "Physics:matched airborne wind invariance, invalid mass and repair resource identity passed\n";
}
void planned_fault_cases(Port& p) {
    struct Fault { const char* id; const char* channel; const char* output; double expected; };
    constexpr Fault faults[] = {
        {"f22_battery", "BATTERY_FAILURE", "BATTERY_POWER", 0},
        {"f22_left_generator", "L_GEN_FAILURE", "L_GEN_POWER", 0},
        {"f22_right_generator", "R_GEN_FAILURE", "R_GEN_POWER", 0},
        {"f22_apu", "APU_FAILURE", nullptr, 0},
        {"f22_left_hydraulics", "L_HYD_FAILURE", nullptr, 0},
        {"f22_right_hydraulics", "R_HYD_FAILURE", nullptr, 0},
        {"f22_left_feed", "F22_L_FEED_FAILURE", "EFM_L_FEED_AVAILABLE", 0},
        {"f22_right_feed", "F22_R_FEED_FAILURE", "EFM_R_FEED_AVAILABLE", 0},
        {"f22_fuel_transfer", "F22_TRANSFER_FAILURE", nullptr, 0},
        {"f22_air_data", "F22_AIRDATA_HEALTH_REQUEST", "EFM_AIRDATA_VALID", 0},
        {"f22_ecs", "F22_ECS_FAILURE", "EFM_CONDITIONED_AIR_AVAILABLE", 0},
        {"f22_cooling", "F22_COOLING_FAILURE", nullptr, 0},
        {"f22_oxygen", "F22_OXYGEN_FAILURE", "EFM_OBOGS_AVAILABLE", 0},
        {"f22_left_hyd_pump_1", "F22_L_HYD_PUMP_1_FAILURE", "EFM_L_HYD_PUMP_1", 0},
        {"f22_left_hyd_pump_2", "F22_L_HYD_PUMP_2_FAILURE", "EFM_L_HYD_PUMP_2", 0},
        {"f22_right_hyd_pump_1", "F22_R_HYD_PUMP_1_FAILURE", "EFM_R_HYD_PUMP_1", 0},
        {"f22_right_hyd_pump_2", "F22_R_HYD_PUMP_2_FAILURE", "EFM_R_HYD_PUMP_2", 0},
        {"f22_left_engine_fire", "F22_L_ENGINE_FIRE", "EFM_L_FIRE_DETECTED", 1},
        {"f22_right_engine_fire", "F22_R_ENGINE_FIRE", "EFM_R_FIRE_DETECTED", 1},
        {"f22_left_starter", "F22_L_STARTER_FAILURE", nullptr, 0},
        {"f22_right_starter", "F22_R_STARTER_FAILURE", nullptr, 0},
        {"f22_left_ignition", "F22_L_IGNITION_FAILURE", nullptr, 0},
        {"f22_right_ignition", "F22_R_IGNITION_FAILURE", nullptr, 0},
        {"f22_left_hung_start", "F22_L_HUNG_START_FAILURE", nullptr, 0},
        {"f22_right_hung_start", "F22_R_HUNG_START_FAILURE", nullptr, 0},
        {"f22_left_hot_start", "F22_L_HOT_START_FAILURE", nullptr, 0},
        {"f22_right_hot_start", "F22_R_HOT_START_FAILURE", nullptr, 0},
        {"f22_left_control_degraded", "F22_L_CONTROL_DEGRADED_FAILURE", "EFM_L_ENGINE_CONTROL", 1},
        {"f22_right_control_degraded", "F22_R_CONTROL_DEGRADED_FAILURE", "EFM_R_ENGINE_CONTROL", 1},
        {"f22_left_control_failed", "F22_L_CONTROL_FAILED_FAILURE", "EFM_L_CONTROL_AVAILABLE", 0},
        {"f22_right_control_failed", "F22_R_CONTROL_FAILED_FAILURE", "EFM_R_CONTROL_AVAILABLE", 0},
        {"f22_left_augmentation", "F22_L_AUGMENTATION_FAILURE", "EFM_L_AUG_AVAILABLE", 0},
        {"f22_right_augmentation", "F22_R_AUGMENTATION_FAILURE", "EFM_R_AUG_AVAILABLE", 0}};
    const auto failure = p.efm.symbol<void(*)(const char*)>("ed_fm_on_planned_failure");
    const auto repair = p.efm.symbol<Void>("ed_fm_repair");
    for (const auto& fault : faults) {
        p.spawn("ed_fm_hot_start_in_air"); p.step();
        failure(fault.id);
        require(p.get(fault.channel) == 1, fault.id);
        p.step();
        if (fault.output) require(p.get(fault.output) == fault.expected, fault.output);
        const double fuel_before = p.efm.symbol<double(*)()>("ed_fm_get_internal_fuel")();
        repair();
        require(p.get(fault.channel) == 0, "Repair did not clear assigned fault producer");
        require(p.efm.symbol<double(*)()>("ed_fm_get_internal_fuel")() == fuel_before,
            "Fault repair changed fuel inventory");
    }
    std::cout << "Faults:33registered producers admitted and repaired; contextual start/thermal cases tested in owners\n";
}
void carriage_and_refill_cases(Port& p) {
    p.spawn("ed_fm_hot_start_in_air");
    const auto external = p.efm.symbol<double(*)()>("ed_fm_get_external_fuel");
    const auto set_external = p.efm.symbol<void(*)(int, double, double, double, double)>("ed_fm_set_external_fuel");
    const auto refill = p.efm.symbol<Scalar>("ed_fm_refueling_add_fuel");
    const auto set_internal = p.efm.symbol<Scalar>("ed_fm_set_internal_fuel");
    set_internal(8200); set_external(0, 0, 4, 0, -3);
    refill(100);
    require(external() == 0, "Unconfirmed empty station acquired refuel capacity");
    p.step();
    p.put("F22_HYD_DEMAND_VALID", 0);
    p.put("F22_HYD_DEMAND_SCHEMA", 1);
    p.put("F22_HYD_DEMAND_GENERATION", p.get("EFM_PHYSICAL_GENERATION"));
    p.put("F22_HYD_DEMAND_SEQUENCE", 1);
    p.put("F22_HYD_DEMAND_STAMP", p.get("F22_AP_CLOCK"));
    p.put("F22_L_HYD_LOAD", 0); p.put("F22_R_HYD_LOAD", 0);
    p.put("F22_FUEL_INVENTORY_VALID", 1);
    p.put("F22_FUEL_INVENTORY_STAMP", p.get("F22_AP_CLOCK"));
    p.put("F22_LEFT_TANK_INSTALLED", 1); p.put("F22_RIGHT_TANK_INSTALLED", 0);
    p.put("F22_HYD_DEMAND_VALID", 1);
    p.step(); refill(100);
    require(external() > 90 && external() <= 100, "Confirmed empty attached tank could not refill");
    const double quantity = external();
    refill(-1); refill(std::numeric_limits<double>::quiet_NaN());
    require(external() == quantity, "Invalid refueling changed tank inventory");
    set_external(0, 0, 4, 0, -3);
    set_internal(8200); refill(100);
    require(external() == 0, "Old carriage observation authenticated newer absolute callback");
    p.efm.symbol<Void>("ed_fm_release")();
    require(external() == 0, "Release retained external tank contents");
    std::cout << "Fuel carriage:unknown/empty/confirmed refill, invalid request and stale observation passed\n";
}
void trim_telemetry_cases(Port& p) {
    p.spawn("ed_fm_hot_start_in_air");
    p.command(95, 1); p.command(98, 1);
    for (unsigned step = 0; step < 10; ++step) p.step();
    require(p.get("EFM_TRIM_PITCH") > 0 && p.get("EFM_TRIM_YAW") > 0 &&
        p.get("EFM_TRIM_EVENT_UP") == 1 && p.get("EFM_TRIM_EVENT_RUDDER_LEFT") == 1,
        "Actual trim input/owner/telemetry chain failed");
    p.command(215, 0);
    const double pitch = p.get("EFM_TRIM_PITCH");
    for (unsigned step = 0; step < 20; ++step) p.step();
    require(p.get("EFM_TRIM_PITCH") == pitch, "Released trim retained motion");
    p.command(97, 1); p.step();
    require(p.get("EFM_TRIM_PITCH") == 0 && p.get("EFM_TRIM_ROLL") == 0 &&
        p.get("EFM_TRIM_YAW") == 0 && p.get("EFM_TRIM_EVENT_RESET") == 1,
        "Actual trim reset retained state");
    p.spawn("ed_fm_hot_start_in_air"); p.step();
    require(p.get("EFM_TRIM_EVENT_UP") == 0 && p.get("EFM_TRIM_PITCH") == 0,
        "Fresh generation retained prior trim events or command");
    require(p.get("EFM_OXYGEN_EFFECT_QUALIFIED") == 0 &&
        p.get("EFM_CANOPY_EFFECT_QUALIFIED") == 0, "Unqualified native effect was advertised healthy");
}

void refuel_callback_cases(Port& p) {
    const auto parameter = p.efm.symbol<double(*)(unsigned)>("ed_fm_get_param");
    p.spawn("ed_fm_hot_start_in_air"); p.step();
    require(parameter(ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER) == 0,
        "Closed receptacle authenticated native tanker eligibility");
    p.put("F22_REFUEL_DOOR_REQUEST", 1);
    p.put("F22_REFUEL_DISCONNECT_REQUEST", 0);
    p.step();
    require(parameter(ED_FM_FC3_AR_DOOR_PROBE_HANDLE_POS) == 1 &&
        parameter(ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER) == 0,
        "Selected request was confused with achieved receptacle state");
    std::array<float, 2000> arguments{};
    p.draw(arguments.data(), arguments.size());
    require(close_to(arguments[22], p.get("EFM_REFUEL_DOOR_POSITION")),
        "Receptacle drawing did not consume achieved travel");
    for (unsigned step = 0; step < 180; ++step) p.step();
    require(p.get("EFM_REFUEL_DOOR_POSITION") >= .99 &&
        parameter(ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER) == 1,
        "Achieved airborne receptacle did not admit native refuel eligibility");
    p.draw(arguments.data(), arguments.size());
    require(close_to(arguments[22], p.get("EFM_REFUEL_DOOR_POSITION")),
        "Open receptacle drawing disagreed with its physical owner");
    p.put("F22_REFUEL_DISCONNECT_REQUEST", 1); p.step();
    require(parameter(ED_FM_INTERRUPT_REFUEL) == 1 &&
        parameter(ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER) == 0,
        "Explicit disconnect retained native refuel eligibility");
    p.put("F22_REFUEL_DISCONNECT_REQUEST", std::numeric_limits<double>::quiet_NaN());
    p.step();
    require(parameter(ED_FM_INTERRUPT_REFUEL) == 1,
        "Missing disconnect consent authenticated continued refueling");
    p.put("F22_REFUEL_DISCONNECT_REQUEST", 0);
    p.step();
    p.efm.symbol<Scalar>("ed_fm_set_internal_fuel")(8200);
    require(parameter(ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER) == 0,
        "Full unmodified aircraft advertised refuel capacity");
    p.spawn("ed_fm_hot_start");
    p.atmosphere(0, 288.15, 340.294, 1.225, 101325, 0, 0, 0);
    p.world(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1);
    p.surface(0, 0, 1, 0, 1, 0);
    p.put("F22_REFUEL_DOOR_REQUEST", 1);
    p.put("F22_REFUEL_DISCONNECT_REQUEST", 0);
    ed_fm_suspension_info contact{};
    contact.acting_force[1] = 50000;
    contact.struct_compression = .3;
    const auto suspension = p.efm.symbol<void(*)(int, const ed_fm_suspension_info*)>("ed_fm_suspension_feedback");
    for (unsigned step = 0; step < 180; ++step) {
        for (int leg = 0; leg < 3; ++leg) suspension(leg, &contact);
        p.step();
    }
    require(parameter(ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER) == 0,
        "Ground service authenticated airborne tanker eligibility");
    std::cout << "Refuel:request/achieved/eligibility/disconnect/capacity/ground callbacks passed\n";
}
}

int main(int argc, char** argv) {
    try {
        require(argc == 4 || argc == 5,
            "Usage: flight_callbacks <CockpitBase.dll> <World.dll> <f22.dll> [--observe-baseline|--yaw-only]");
        const Module cockpit(argv[1]);
        const Module world(argv[2]);
        const Module efm(argv[3]);
        Port port(efm, cockpit, world);
        if (argc == 5) {
            const std::string mode(argv[4]);
            if (mode == "--observe-baseline") baseline_observations(port);
            else if (mode == "--yaw-only") yaw_cases(port);
            else if (mode == "--healthy-fingerprint") healthy_fingerprint(port);
            else require(false, "Unknown observation option");
            efm.symbol<Void>("ed_fm_release")();
            return 0;
        }
        atmosphere_cases(port);
        yaw_cases(port);
        gear_callback_cases(port);
        force_and_mass_cases(port);
        planned_fault_cases(port);
        carriage_and_refill_cases(port);
        trim_telemetry_cases(port);
        refuel_callback_cases(port);
        efm.symbol<Void>("ed_fm_release")();
        std::cout << "Actual DLL source-admission/lifecycle cases passed; DCS and aircraft calibration unqualified\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
