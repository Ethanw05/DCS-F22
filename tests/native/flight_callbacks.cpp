// R-FLT-001/013 and D-R-INT-001. Independent source-admission and history oracle.
// This executable loads an external test DLL; it cannot attach to running DCS.
#include <Windows.h>
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
        efm.symbol<Void>("ed_fm_release")();
        std::cout << "Actual DLL source-admission/lifecycle cases passed; DCS and aircraft calibration unqualified\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
