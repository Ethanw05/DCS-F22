#include <windows.h>
#include <crtdbg.h>
#include <cassert>
#include <cmath>
#include <array>
#include <iostream>
#include <limits>
#include "../EFM/include/FM/wHumanCustomPhysicsAPI.h"

namespace {
template<typename T> T load(HMODULE module, const char* name) {
    const auto function = reinterpret_cast<T>(GetProcAddress(module, name));
    assert(function);
    return function;
}

struct Fixture {
    HMODULE cockpit = nullptr;
    HMODULE fm = nullptr;
    void* (*handle)(const char*) = nullptr;
    void (*write)(void*, double) = nullptr;
    bool (*read)(const void*, double&, bool) = nullptr;
    void (*cold)() = nullptr;
    void (*hot)() = nullptr;
    void (*air)() = nullptr;
    void (*release)() = nullptr;
    void (*repair)() = nullptr;
    void (*planned_failure)(const char*) = nullptr;
    bool (*needs_repair)() = nullptr;
    void (*damage)(int,double) = nullptr;
    void (*immortal)(bool) = nullptr;
    void (*draw)(float*,size_t) = nullptr;
    using MassState = void(*)(double,double,double,double,double,double,double);
    MassState mass_state = nullptr;
    using Force = void(*)(double&,double&,double&,double&,double&,double&);
    Force force = nullptr;
    void (*moment)(double&,double&,double&) = nullptr;
    void (*simulate)(double) = nullptr;
    void (*command)(int, float) = nullptr;
    double (*parameter)(unsigned) = nullptr;
    void (*fuel)(double) = nullptr;
    double (*getfuel)() = nullptr;
    void (*unlimited)(bool) = nullptr;
    void (*atmosphere)(double,double,double,double,double,double,double,double) = nullptr;
    void (*surface)(double,double,unsigned,double,double,double) = nullptr;
    using Body = void(*)(double,double,double,double,double,double,double,double,double,
        double,double,double,double,double,double,double,double,double,double,double);
    Body body = nullptr;
    using World = void(*)(double,double,double,double,double,double,double,double,double,
        double,double,double,double,double,double,double,double,double,double);
    World world = nullptr;
    using Mass = bool(*)(double&,double&,double&,double&,double&,double&,double&);
    Mass mass = nullptr;

    Fixture(const char* cockpit_path, const char* fm_path) {
        cockpit = LoadLibraryA(cockpit_path); assert(cockpit);
        handle = load<decltype(handle)>(cockpit, "ed_cockpit_get_parameter_handle");
        write = load<decltype(write)>(cockpit, "ed_cockpit_update_parameter_with_number");
        read = load<decltype(read)>(cockpit, "ed_cockpit_parameter_value_to_number");
        fm = LoadLibraryA(fm_path); assert(fm);
        cold = load<decltype(cold)>(fm, "ed_fm_cold_start");
        hot = load<decltype(hot)>(fm, "ed_fm_hot_start");
        air = load<decltype(air)>(fm, "ed_fm_hot_start_in_air");
        release = load<decltype(release)>(fm, "ed_fm_release");
        repair = load<decltype(repair)>(fm, "ed_fm_repair");
        planned_failure = load<decltype(planned_failure)>(fm, "ed_fm_on_planned_failure");
        needs_repair = load<decltype(needs_repair)>(fm, "ed_fm_need_to_be_repaired");
        damage = load<decltype(damage)>(fm, "ed_fm_on_damage");
        immortal = load<decltype(immortal)>(fm, "ed_fm_set_immortal");
        draw = load<decltype(draw)>(fm, "ed_fm_set_draw_args_v2");
        mass_state = load<MassState>(fm, "ed_fm_set_current_mass_state");
        force = load<Force>(fm, "ed_fm_add_local_force");
        moment = load<decltype(moment)>(fm, "ed_fm_add_local_moment");
        simulate = load<decltype(simulate)>(fm, "ed_fm_simulate");
        command = load<decltype(command)>(fm, "ed_fm_set_command");
        parameter = load<decltype(parameter)>(fm, "ed_fm_get_param");
        fuel = load<decltype(fuel)>(fm, "ed_fm_set_internal_fuel");
        getfuel = load<decltype(getfuel)>(fm, "ed_fm_get_internal_fuel");
        unlimited = load<decltype(unlimited)>(fm, "ed_fm_unlimited_fuel");
        atmosphere = load<decltype(atmosphere)>(fm, "ed_fm_set_atmosphere");
        surface = load<decltype(surface)>(fm, "ed_fm_set_surface");
        body = load<Body>(fm, "ed_fm_set_current_state_body_axis");
        world = load<World>(fm, "ed_fm_set_current_state");
        mass = load<Mass>(fm, "ed_fm_change_mass");
    }
    ~Fixture() {
        release();
        const bool fm_closed = FreeLibrary(fm) != 0;
        const bool cockpit_closed = FreeLibrary(cockpit) != 0;
        assert(fm_closed && cockpit_closed);
    }
    void set(const char* name, double value) const { write(handle(name), value); }
    double get(const char* name) const {
        double value = 0;
        const bool valid = read(handle(name), value, false);
        assert(valid);
        return value;
    }
    void ticks(int count) const {
        assert(count >= 0 && count <= 100000);
        for (int index = 0; index < count; ++index) simulate(.01);
    }
    void conditions(double speed, double uniform_wind = 0, double cg_x = 0) const {
        const double altitude = speed > 0.0 ? 3000.0 : 0.0;
        mass_state(30000,cg_x,0,0,100000,150000,120000);
        atmosphere(altitude, 288.15, 340, 1.225, 101325, uniform_wind, 0, 0);
        surface(0,0,0,0,1,0);
        world(0,0,0,speed+uniform_wind,0,0,0,altitude,0,0,0,0,0,0,0,0,0,0,1);
        body(0,0,0,speed+uniform_wind,0,0,uniform_wind,0,0,0,0,0,0,0,0,0,0,0,0,0);
    }
    double drain_mass() const {
        double kg=0, x=0, y=0, z=0, ix=0, iy=0, iz=0, total=0;
        for (int index = 0; index < 65; ++index) {
            if (!mass(kg,x,y,z,ix,iy,iz)) return total;
            assert(std::isfinite(kg) && x >= -20 && x <= 20);
            total += kg;
        }
        assert(false && "mass ledger exceeded declared capacity");
        return total;
    }
};

void cold_start_failure_recovery(Fixture& fixture) {
    fixture.cold(); fixture.fuel(5000); fixture.unlimited(false);
    fixture.conditions(0);
    fixture.command(311, 1); fixture.ticks(1);
    assert(fixture.get("EFM_L_START_REJECTION") == 2);
    assert(fixture.parameter(ED_FM_ENGINE_1_COMBUSTION) == 0);
    fixture.set("F22_POWER_REQUEST_VALID", 1);
    fixture.set("F22_POWER_REQUEST_SEQUENCE", 1);
    fixture.set("F22_BATTERY_REQUEST", 1);
    fixture.set("F22_L_GEN_REQUEST", 1); fixture.set("F22_R_GEN_REQUEST", 1);
    fixture.set("F22_APU_REQUEST", 1);
    fixture.set("F22_L_BLEED_REQUEST", 1); fixture.set("F22_R_BLEED_REQUEST", 1);
    fixture.set("F22_ECS_REQUEST", 1);
    fixture.ticks(1300);
    assert(fixture.get("APU_POWER") == 1 && fixture.get("MAIN_POWER") == 1);
    assert(fixture.get("EFM_HYD_LEFT_PSI") > 3900);
    assert(fixture.get("EFM_SES_AIR") < 1);
    fixture.command(311,1); fixture.ticks(4500);
    assert(fixture.get("EFM_L_ENGINE_PHASE") == 4);
    assert(fixture.parameter(ED_FM_ENGINE_1_COMBUSTION) == 1);
    const double consumed = 5000 - fixture.getfuel();
    assert(consumed > 2 && std::abs(consumed - fixture.drain_mass()) < 1e-7);
    fixture.planned_failure("f22_left_feed"); fixture.ticks(1);
    assert(fixture.needs_repair());
    assert(fixture.parameter(ED_FM_ENGINE_1_THRUST) == 0);
    assert(fixture.get("EFM_L_FEED_AVAILABLE") == 0 && fixture.getfuel() > 4900);
    fixture.repair(); fixture.ticks(1);
    assert(fixture.get("EFM_L_FEED_AVAILABLE") == 1);
    assert(fixture.parameter(ED_FM_ENGINE_1_COMBUSTION) == 0);
    fixture.command(311,1); fixture.ticks(4500);
    assert(fixture.parameter(ED_FM_ENGINE_1_COMBUSTION) == 1);
}

void fixed_force_and_wind_contract(Fixture& fixture) {
    fixture.air(); fixture.fuel(5000); fixture.unlimited(true); fixture.conditions(300);
    fixture.mass_state(30000,0,0,0,100000,150000,120000);
    fixture.ticks(3000);
    double fx=0,fy=0,fz=0,x=0,y=0,z=0,mx=0,my=0,mz=0;
    fixture.force(fx,fy,fz,x,y,z); fixture.moment(mx,my,mz);
    assert(fixture.get("EFM_MASS_VALID") == 1 && fixture.get("EFM_MASS_KG") == 30000);
    fixture.mass_state(30000,.5,0,0,100000,150000,120000);
    fixture.ticks(1);
    double fx2=0,fy2=0,fz2=0,mx2=0,my2=0,mz2=0;
    fixture.force(fx2,fy2,fz2,x,y,z); fixture.moment(mx2,my2,mz2);
    assert(std::abs(fx2-fx) < 1e-5 && std::abs(fy2-fy) < 1e-5 && std::abs(fz2-fz) < 1e-5);
    assert(std::abs((mz2-mz) + .5*fy) < 1e-4);
    fixture.conditions(300,40,.5); fixture.ticks(1);
    fixture.force(fx,fy,fz,x,y,z); fixture.moment(mx,my,mz);
    assert(std::abs(fx2-fx) < 1e-5 && std::abs(fy2-fy) < 1e-5 && std::abs(fz2-fz) < 1e-5);
    assert(std::abs(mz2-mz) < 1e-4);
}

void flow_and_sensor_separation(Fixture& fixture) {
    fixture.air(); fixture.fuel(5000); fixture.unlimited(true); fixture.conditions(200);
    fixture.command(2004,-1); fixture.ticks(2000);
    assert(fixture.getfuel() == 5000);
    const double augmented = fixture.parameter(ED_FM_ENGINE_1_FUEL_FLOW);
    assert(augmented > 5 && fixture.drain_mass() == 0);
    fixture.command(2004,1); fixture.ticks(1500);
    assert(fixture.parameter(ED_FM_ENGINE_1_FUEL_FLOW) < augmented * .1);
    assert(fixture.get("EFM_AIRDATA_VALID") == 1);
    const double cas = fixture.get("EFM_AIRDATA_CAS_MPS");
    fixture.set("F22_AIRDATA_HEALTH_REQUEST",2); fixture.conditions(300); fixture.ticks(50);
    assert(fixture.get("EFM_AIRDATA_CAS_MPS") == cas);
    assert(fixture.get("EFM_FCS_AIRDATA_REVERSION") == 1);
    assert(std::abs(fixture.get("EFM_FCS_SCHEDULE_MACH") - 200.0/340.0) < 1e-9);
    assert(fixture.get("EFM_TRIM_TAS_MPS") == 300);
    fixture.set("F22_AIRDATA_HEALTH_REQUEST",0); fixture.ticks(1);
    assert(fixture.get("EFM_FCS_AIRDATA_REVERSION") == 0);
    assert(fixture.get("EFM_AIRDATA_CAS_MPS") > cas);
    const double before = fixture.get("EFM_AIRDATA_CAS_MPS");
    fixture.conditions(300,40); fixture.ticks(1);
    assert(std::abs(fixture.get("EFM_AIRDATA_CAS_MPS") - before) < 1e-9);
    fixture.set("F22_AIRDATA_HEALTH_REQUEST",1); fixture.ticks(1);
    assert(fixture.get("EFM_AIRDATA_VALID") == 0);
}

void utility_and_alternate_gear(Fixture& fixture) {
    fixture.air(); fixture.fuel(5000); fixture.unlimited(true); fixture.conditions(100);
    fixture.set("R_HYD_FAILURE",1); fixture.ticks(200);
    assert(fixture.get("EFM_ACTUATOR_AVAILABLE") > .99 && fixture.get("EFM_UTILITY_AVAILABLE") == 0);
    fixture.command(431,1); fixture.ticks(200);
    assert(fixture.parameter(ED_FM_SUSPENSION_0_GEAR_POST_STATE) == 0);
    fixture.command(11700,1); fixture.ticks(500);
    assert(fixture.parameter(ED_FM_SUSPENSION_0_GEAR_POST_STATE) == 1);
    assert(fixture.get("EFM_ALTERNATE_GEAR") == 1);
}

void invalid_producer_recovery(Fixture& fixture) {
    fixture.air(); fixture.fuel(5000); fixture.unlimited(true); fixture.conditions(200); fixture.ticks(1);
    const double invalid = std::numeric_limits<double>::quiet_NaN();
    fixture.atmosphere(3000,288.15,340,invalid,101325,0,0,0);
    fixture.ticks(1);
    assert(fixture.get("EFM_AIRDATA_VALID") == 0 && fixture.get("EFM_FORCE_VALID") == 0);
    double fx=1,fy=1,fz=1,x=0,y=0,z=0;
    fixture.force(fx,fy,fz,x,y,z);
    assert(fx == 0 && fy == 0 && fz == 0);
    fixture.conditions(200); fixture.ticks(1);
    assert(fixture.get("EFM_AIRDATA_VALID") == 1 && fixture.get("EFM_FORCE_VALID") == 1);
    fixture.mass_state(30000,invalid,0,0,100000,150000,120000);
    fixture.ticks(1);
    assert(fixture.get("EFM_MASS_VALID") == 0);
    fixture.mass_state(30000,0,0,0,100000,150000,120000); fixture.ticks(1);
    assert(fixture.get("EFM_MASS_VALID") == 1);
}

void fire_and_structural_recovery(Fixture& fixture) {
    fixture.hot(); fixture.fuel(5000); fixture.unlimited(true); fixture.conditions(0); fixture.ticks(200);
    fixture.planned_failure("f22_left_engine_fire"); fixture.ticks(1);
    assert(fixture.get("EFM_L_FIRE_DETECTED") == 1);
    fixture.command(11705,1); fixture.ticks(1);
    assert(fixture.get("EFM_FIRE_BOTTLE_AVAILABLE") == 1); // not armed by a warning
    fixture.command(11703,1); fixture.ticks(1);
    assert(fixture.parameter(ED_FM_ENGINE_1_THRUST) == 0);
    assert(fixture.get("L_GEN_POWER") == 0 && fixture.get("EFM_L_BLEED_AVAILABLE") == 0);
    assert(fixture.parameter(ED_FM_ENGINE_2_THRUST) > 0);
    fixture.command(11705,1); fixture.ticks(1);
    assert(fixture.get("EFM_FIRE_BOTTLE_AVAILABLE") == 0);
    assert(fixture.get("EFM_FIRE_DISCHARGE_ATTEMPT") == 1 && fixture.get("EFM_L_FIRE_DETECTED") == 1);
    fixture.repair(); fixture.ticks(1);
    assert(fixture.get("EFM_FIRE_BOTTLE_AVAILABLE") == 1 && fixture.get("EFM_L_FIRE_ISOLATED") == 0);
    assert(fixture.parameter(ED_FM_ENGINE_1_COMBUSTION) == 0);
    for (const int wing : {23,24}) {
        fixture.air(); fixture.fuel(5000); fixture.conditions(200); fixture.immortal(false); fixture.ticks(100);
        fixture.damage(wing,0); fixture.damage(55,0); fixture.ticks(1);
        assert(fixture.parameter(ED_FM_ENGINE_1_COMBUSTION) == 1);
        assert(fixture.parameter(ED_FM_ENGINE_2_COMBUSTION) == 1);
        assert(fixture.needs_repair());
        fixture.repair(); fixture.ticks(1);
        assert(!fixture.needs_repair());
    }
    fixture.air(); fixture.fuel(5000); fixture.conditions(200); fixture.command(2002,.5f); fixture.ticks(200);
    double mx=0,my=0,mz=0;
    fixture.moment(mx,my,mz);
    fixture.damage(25,0); fixture.ticks(1);
    double damaged_mx=0;
    fixture.moment(damaged_mx,my,mz);
    assert(std::abs(damaged_mx) < std::abs(mx));
    fixture.damage(103,0); fixture.damage(104,0); fixture.damage(23,0); fixture.damage(55,0);
    fixture.ticks(1);
    std::array<float,800> arguments{};
    fixture.draw(arguments.data(),arguments.size());
    assert(arguments[114] == 1);
    fixture.repair(); fixture.ticks(1); fixture.draw(arguments.data(),arguments.size());
    assert(arguments[114] == 0 && fixture.parameter(ED_FM_ENGINE_1_COMBUSTION) == 0);
    fixture.immortal(true);
}

void configuration_and_lifecycle(Fixture& fixture) {
    fixture.hot(); fixture.fuel(5000); fixture.unlimited(true); fixture.conditions(0); fixture.ticks(1);
    fixture.command(430,1); fixture.ticks(1);
    assert(fixture.get("EFM_GEAR_REJECTION") == 1);
    fixture.command(11700,1); fixture.ticks(1);
    const double reserve = fixture.get("EFM_SES_AIR");
    fixture.command(11700,1); fixture.ticks(1);
    assert(fixture.get("EFM_SES_AIR") >= reserve && fixture.get("EFM_SES_AIR") < reserve + .001);
    fixture.set("FORM_KNOB",.25); fixture.ticks(1);
    assert(fixture.get("EFM_FORMATION_INTENSITY") == .25);
    fixture.set("FORM_KNOB",.5); fixture.ticks(2);
    assert(fixture.get("EFM_FORMATION_INTENSITY") == .5);
    fixture.set("L_GEN_FAILURE",1); fixture.set("R_GEN_FAILURE",1);
    fixture.set("BATTERY_FAILURE",1); fixture.ticks(2);
    assert(fixture.get("EFM_FORMATION_INTENSITY") == 0 && fixture.get("FORM_KNOB") == .5);
    fixture.repair(); fixture.ticks(2);
    assert(fixture.get("EFM_FORMATION_INTENSITY") == .5);
    const double stamp = fixture.get("EFM_PHYSICAL_STAMP");
    fixture.simulate(0);
    assert(fixture.get("EFM_PHYSICAL_STAMP") == stamp);
    fixture.simulate(2);
    assert(fixture.get("EFM_PHYSICAL_DROPPED_TIME_S") == 1);
    fixture.release(); fixture.ticks(1);
    assert(fixture.get("EFM_PHYSICAL_VALID") == 0);
    fixture.hot(); fixture.conditions(0); fixture.ticks(1);
    assert(fixture.get("EFM_PHYSICAL_VALID") == 1);
    assert(fixture.get("EFM_PHYSICAL_CLOCK_KIND") == 1);
    assert(fixture.get("EFM_PHYSICAL_STAMP") == fixture.get("F22_AP_CLOCK"));
    assert(fixture.get("EFM_PHYSICAL_STAMP") == .01);
}

void force_and_release_boundaries(Fixture& fixture) {
    fixture.air(); fixture.fuel(5000); fixture.unlimited(false); fixture.conditions(200);
    fixture.immortal(false);
    fixture.mass_state(30000,0,0,0,100000,150000,120000); fixture.ticks(10);
    double fx=0,fy=0,fz=0,x=0,y=0,z=0,mx=0,my=0,mz=0;
    fixture.force(fx,fy,fz,x,y,z);
    assert(std::abs(fx) + std::abs(fy) + std::abs(fz) > 100);
    fixture.damage(103,0); fixture.damage(104,0); fixture.damage(23,0); fixture.damage(55,0);
    fixture.ticks(1);
    std::array<float,800> arguments{};
    fixture.draw(arguments.data(),arguments.size());
    assert(arguments[114] == 1);
    fixture.force(fx,fy,fz,x,y,z); fixture.moment(mx,my,mz);
    assert(fx == 0 && fy == 0 && fz == 0 && mx == 0 && my == 0 && mz == 0);
    fixture.repair(); fixture.ticks(1);
    const double invalid = std::numeric_limits<double>::quiet_NaN();
    fixture.mass_state(30000,invalid,0,0,100000,150000,120000); fixture.ticks(1);
    fixture.force(fx,fy,fz,x,y,z); fixture.moment(mx,my,mz);
    assert(fixture.get("EFM_FORCE_VALID") == 0);
    assert(fx == 0 && fy == 0 && fz == 0 && mx == 0 && my == 0 && mz == 0);
    fixture.mass_state(30000,0,0,0,100000,150000,120000); fixture.ticks(1);
    assert(fixture.get("EFM_FORCE_VALID") == 1);
    fixture.air(); fixture.fuel(5000); fixture.conditions(200);
    fixture.mass_state(30000,0,0,0,100000,150000,120000); fixture.ticks(10);
    fixture.release();
    fixture.force(fx,fy,fz,x,y,z); fixture.moment(mx,my,mz);
    assert(fx == 0 && fy == 0 && fz == 0 && mx == 0 && my == 0 && mz == 0);
    assert(fixture.drain_mass() == 0);
    assert(fixture.parameter(ED_FM_ENGINE_1_COMBUSTION) == 0);
    assert(fixture.parameter(ED_FM_ENGINE_1_THRUST) == 0);
    for (const auto* name : {"EFM_FORCE_VALID", "EFM_MASS_VALID", "EFM_ENGINE_VALID",
                             "EFM_HUD_VALID", "EFM_GROUND_VALID", "EFM_TRIM_VALID"})
        assert(fixture.get(name) == 0);
}

void live_ground_power(Fixture& fixture) {
    fixture.cold(); fixture.fuel(5000); fixture.conditions(0);
    fixture.set("GROUND_POWER",1); fixture.ticks(1);
    assert(fixture.get("MAIN_POWER") == 1);
    fixture.set("F22_POWER_REQUEST_VALID",1); fixture.set("F22_POWER_REQUEST_SEQUENCE",5);
    fixture.set("F22_BATTERY_REQUEST",0); fixture.set("F22_L_GEN_REQUEST",0);
    fixture.set("F22_R_GEN_REQUEST",0); fixture.set("F22_APU_REQUEST",0);
    fixture.ticks(1);
    fixture.set("F22_POWER_REQUEST_VALID",0); fixture.set("GROUND_POWER",0);
    fixture.ticks(1);
    assert(fixture.get("MAIN_POWER") == 0 && fixture.get("F22_ESSENTIAL_POWER") == 0);
    fixture.set("GROUND_POWER",1); fixture.ticks(1);
    assert(fixture.get("MAIN_POWER") == 1);
    fixture.conditions(200); fixture.ticks(2);
    assert(fixture.get("MAIN_POWER") == 0); // A ground connector cannot follow the aircraft.
    fixture.set("GROUND_POWER",0);
}

void damaged_rudder_braking(Fixture& fixture) {
    std::array<double,2> lateral{}, longitudinal{};
    for (unsigned side=0;side<2;++side) {
        fixture.air(); fixture.fuel(5000); fixture.unlimited(true); fixture.conditions(200);
        fixture.immortal(false);
        fixture.command(147,1); fixture.ticks(1000);
        double fx=0,fy=0,fz=0,x=0,y=0,z=0;
        fixture.force(fx,fy,fz,x,y,z);
        const double healthy_drag = fx;
        assert(std::abs(fz) < 1e-8);
        fixture.damage(side == 0 ? 53 : 54,0); fixture.ticks(2);
        fixture.force(fx,fy,fz,x,y,z);
        assert(fx > healthy_drag + 1000); // A missing rudder cannot keep full braking drag.
        assert(std::abs(fz) > 1000); // The surviving splayed rudder is asymmetric.
        lateral[side]=fz; longitudinal[side]=fx;
    }
    assert(std::abs(lateral[0]+lateral[1]) < 1e-6);
    assert(std::abs(longitudinal[0]-longitudinal[1]) < 1e-6);
}
} // namespace

int main(int argc, char** argv) {
    _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
    _CrtSetReportMode(_CRT_ASSERT, _CRTDBG_MODE_FILE);
    _CrtSetReportFile(_CRT_ASSERT, _CRTDBG_FILE_STDERR);
    assert(argc == 3);
    Fixture fixture(argv[1], argv[2]);
    cold_start_failure_recovery(fixture);
    flow_and_sensor_separation(fixture);
    fixed_force_and_wind_contract(fixture);
    utility_and_alternate_gear(fixture);
    invalid_producer_recovery(fixture);
    fire_and_structural_recovery(fixture);
    configuration_and_lifecycle(fixture);
    force_and_release_boundaries(fixture);
    live_ground_power(fixture);
    damaged_rudder_braking(fixture);
    std::cout << "vehicle DLL: cold/APU/start, burn/mass, feed/repair, sensor truth, limits and lifecycle OK\n";
}
