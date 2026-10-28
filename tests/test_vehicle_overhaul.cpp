#include <windows.h>
#include <crtdbg.h>
#include <cassert>
#include <cmath>
#include <array>
#include <iostream>
#include <limits>
#include "../EFM/include/FM/wHumanCustomPhysicsAPI.h"
#include "../EFM/source/Inputs.h"

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
    void (*refuel)(double) = nullptr;
    double (*getfuel)() = nullptr;
    void (*external)(int,double,double,double,double) = nullptr;
    double (*getexternal)() = nullptr;
    void (*suspension)(int,const ed_fm_suspension_info*) = nullptr;
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
        refuel = load<decltype(refuel)>(fm, "ed_fm_refueling_add_fuel");
        getfuel = load<decltype(getfuel)>(fm, "ed_fm_get_internal_fuel");
        external = load<decltype(external)>(fm, "ed_fm_set_external_fuel");
        getexternal = load<decltype(getexternal)>(fm, "ed_fm_get_external_fuel");
        suspension = load<decltype(suspension)>(fm, "ed_fm_suspension_feedback");
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

void nonzero_spawn_cg_pitch_authority(Fixture& fixture) {
    // Matched-state baseline from the pre-overhaul DLL: this case produced
    // +1,167,636 Nm. Moving the wing datum to model-origin zero reduced it
    // to +58,199 Nm despite identical achieved surfaces, thrust and force.
    fixture.air(); fixture.fuel(7000); fixture.unlimited(true);
    fixture.conditions(220);
    fixture.mass_state(28000,1,0,0,100000,150000,120000);
    fixture.atmosphere(3000,268.65,328.58,.9091,70108,0,0,0);
    const double alpha = 10.0 * 3.141592653589793 / 180.0;
    fixture.body(0,4*9.81,0,220*std::cos(alpha),-220*std::sin(alpha),0,
        0,0,0,0,0,0,0,0,alpha,0,alpha,0,alpha,0);
    fixture.command(2001,1); fixture.command(2004,-1);
    fixture.ticks(1200);
    double mx=0,my=0,mz=0,fx=0,fy=0,fz=0,x=0,y=0,z=0;
    fixture.moment(mx,my,mz); fixture.force(fx,fy,fz,x,y,z);
    assert(fixture.get("EFM_ACTUATOR_AVAILABLE") == 1);
    assert(mz > 1100000 && mz < 1230000);
    // A later CG change must still change the moment: the datum is captured
    // once, rather than following the live CG and hiding fuel/store effects.
    fixture.mass_state(28000,1.25,0,0,100000,150000,120000);
    fixture.ticks(1);
    double shifted_mz=0;
    fixture.moment(mx,my,shifted_mz);
    assert(std::abs(shifted_mz-mz+.25*fy) < 1e-4);
    fixture.repair(); fixture.ticks(1);
    fixture.moment(mx,my,shifted_mz);
    assert(std::abs(shifted_mz-mz+.25*fy) < 1e-4);
}

void flow_and_sensor_separation(Fixture& fixture) {
    fixture.air(); fixture.fuel(5000); fixture.unlimited(true); fixture.conditions(200);
    fixture.command(2004,-1); fixture.ticks(2000);
    assert(fixture.getfuel() == 5000);
    const double augmented = fixture.parameter(ED_FM_ENGINE_1_FUEL_FLOW);
    assert(augmented > 5 && fixture.drain_mass() == 0);
    assert(fixture.get("EFM_ENGINE_INDICATION_SCHEMA") == 1);
    assert(fixture.get("EFM_ENGINE_LEFT_FLOW_KG_S") == augmented);
    assert(fixture.get("EFM_ENGINE_RIGHT_FLOW_KG_S") ==
        fixture.parameter(ED_FM_ENGINE_2_FUEL_FLOW));
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
    fixture.damage(53,0); fixture.refuel(100);
    assert(!fixture.needs_repair() && fixture.getfuel() == 0 && fixture.drain_mass() == 0);
    fixture.fuel(1000); fixture.cold(); fixture.conditions(0); fixture.ticks(1);
    assert(fixture.getfuel() == 1000); // Initial absolute fuel loading before spawn remains supported.
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

void prepare_engine_start(Fixture& f) {
    f.cold(); f.fuel(5000); f.unlimited(false); f.conditions(0);
    f.set("F22_POWER_REQUEST_VALID",1); f.set("F22_POWER_REQUEST_SEQUENCE",1);
    f.set("F22_BATTERY_REQUEST",1); f.set("F22_L_GEN_REQUEST",1); f.set("F22_R_GEN_REQUEST",1);
    f.set("F22_APU_REQUEST",1); f.set("F22_L_BLEED_REQUEST",1);
    f.set("F22_R_BLEED_REQUEST",1); f.set("F22_ECS_REQUEST",1);
    f.ticks(1300);
    assert(f.get("APU_READY") == 1 && f.get("EFM_ENGINE_CONTROL_SCHEMA") == 1);
}

void manual_engine_and_unlit_fuel(Fixture& f) {
    prepare_engine_start(f);
    f.command(11719,1); f.ticks(1500);
    assert(f.get("EFM_L_ENGINE_PHASE") == 1 && f.get("EFM_L_STARTER_ENGAGED") == 1);
    assert(f.parameter(ED_FM_ENGINE_1_FUEL_FLOW) == 0 && f.parameter(ED_FM_ENGINE_1_THRUST) == 0);
    assert(f.get("EFM_L_FUEL_VALVE") == 0 && f.get("EFM_APU_FLOW_KG_S") > .05);
    f.command(11723,1); f.command(11721,1); f.ticks(3500);
    assert(f.get("EFM_L_ENGINE_PHASE") == 4 && f.get("EFM_L_STARTER_ENGAGED") == 0);
    assert(f.get("EFM_L_STARTER_SELECTED") == 1); // request survives the automatic cutout
    f.command(11719,0); f.command(11723,0); f.ticks(1);
    assert(f.parameter(ED_FM_ENGINE_1_COMBUSTION) == 1);
    assert(std::abs(5000 - f.getfuel() - f.drain_mass()) < 1e-7);
    prepare_engine_start(f);
    f.command(11719,1); f.ticks(1500);
    f.planned_failure("f22_left_ignition"); f.command(11723,1); f.command(11721,1);
    const double before = f.getfuel(); f.ticks(1200);
    assert(f.get("EFM_L_START_FAULT") == 1 && f.parameter(ED_FM_ENGINE_1_COMBUSTION) == 0);
    assert(f.parameter(ED_FM_ENGINE_1_THRUST) == 0 && before - f.getfuel() > .3);
    assert(std::abs(5000 - f.getfuel() - f.drain_mass()) < 1e-7);
    f.repair(); f.command(11725,1); f.ticks(1);
    assert(f.get("EFM_L_START_FAULT") == 1 && f.get("EFM_L_START_REJECTION") == 12);
    f.command(11721,0); f.command(11719,0); f.ticks(1600);
    f.command(11719,1); f.ticks(1800); f.command(11719,0); f.command(11725,1); f.ticks(1);
    assert(f.get("EFM_L_PURGE_S") == 0 && f.get("EFM_L_START_FAULT") == 0);
    assert(f.parameter(ED_FM_ENGINE_1_COMBUSTION) == 0);
    f.command(311,1); f.ticks(4500);
    assert(f.get("EFM_L_ENGINE_PHASE") == 4);
}

void engine_temperature_and_control_faults(Fixture& f) {
    prepare_engine_start(f); f.planned_failure("f22_left_hot_start");
    f.command(311,1); f.ticks(2500);
    assert(f.get("EFM_L_START_FAULT") == 3 && f.parameter(ED_FM_ENGINE_1_THRUST) == 0);
    f.repair(); f.ticks(1);
    assert(f.get("EFM_L_START_FAULT") == 3); // repair preserves purge/temperature protection
    prepare_engine_start(f); f.planned_failure("f22_left_hung_start");
    f.command(311,1); f.ticks(6000);
    assert(f.get("EFM_L_START_FAULT") == 2 && f.parameter(ED_FM_ENGINE_1_THRUST) == 0);
    f.air(); f.fuel(5000); f.unlimited(true); f.conditions(300);
    f.command(2004,-1); f.ticks(1500);
    f.planned_failure("f22_left_control_degraded"); f.ticks(1);
    assert(f.get("EFM_L_ENGINE_CONTROL") == 1 && f.get("EFM_L_AUG_AVAILABLE") == 0);
    assert(f.parameter(ED_FM_ENGINE_1_COMBUSTION) == 1);
    f.ticks(300);
    assert(f.parameter(ED_FM_ENGINE_1_CORE_RELATED_RPM) < .951);
    assert(f.parameter(ED_FM_ENGINE_2_CORE_RELATED_RPM) > 1.09);
    f.planned_failure("f22_left_control_failed"); f.ticks(1);
    assert(f.get("EFM_L_ENGINE_CONTROL") == 2 && f.get("EFM_L_START_FAULT") == 4);
    assert(f.parameter(ED_FM_ENGINE_1_COMBUSTION) == 0 && f.parameter(ED_FM_ENGINE_2_COMBUSTION) == 1);
    f.repair(); f.ticks(1500); f.command(11725,1); f.ticks(1);
    assert(f.get("EFM_L_START_FAULT") == 0 && f.parameter(ED_FM_ENGINE_1_COMBUSTION) == 0);
    f.command(311,1); f.ticks(4500);
    assert(f.parameter(ED_FM_ENGINE_1_COMBUSTION) == 1);
}
void held_roll_input_ownership(Fixture& f) {
    for (const float direction : {-1.0f, 1.0f}) {
        f.air(); f.fuel(5000); f.unlimited(true); f.conditions(200);
        f.command(2002,direction); f.ticks(100);
        double x=0,y=0,z=0; f.moment(x,y,z);
        const double held_moment=x;
        assert(std::abs(held_moment)>1000);
        // Native keyboard releases can arrive after the joystick took over.
        // They must not steal the held axis; no repeated axis event is needed.
        for (const int release : {198,200}) {
            f.command(release,0); f.ticks(100); f.moment(x,y,z);
            assert(std::abs(x-held_moment)<1.0);
        }
        f.ticks(1000); f.moment(x,y,z);
        assert(std::abs(x-held_moment)<1.0);
        f.command(2002,0); f.ticks(100); f.moment(x,y,z);
        assert(std::abs(x)<1.0); // genuine axis centering still stops the roll command
    }
    f.air(); f.fuel(5000); f.unlimited(true); f.conditions(200);
    f.command(197,1); f.command(199,1); f.ticks(100);
    double x=0,y=0,z=0; f.moment(x,y,z); const double right_moment=x;
    f.command(198,0); f.ticks(100); f.moment(x,y,z);
    assert(std::abs(x-right_moment)<1.0); // left release cannot cancel right still held
    f.command(200,0); f.ticks(100); f.moment(x,y,z);
    assert(std::abs(x)<1.0);
}

struct AxisCommands {
    int analog;
    std::array<int,2> press;
    std::array<int,2> release;
    unsigned component;
};
constexpr AxisCommands pitch_axis{JoystickPitch, {PitchDown,PitchUp}, {PitchDownStop,PitchUpStop}, 2};
constexpr AxisCommands yaw_axis{PedalYaw, {rudderright,rudderleft}, {rudderrightstop,rudderleftstop}, 1};

double axis_moment(Fixture& fixture, unsigned component) {
    assert(component < 3);
    std::array<double,3> value{};
    fixture.moment(value[0],value[1],value[2]);
    return value[component];
}

void prepare_axis_fixture(Fixture& fixture) {
    fixture.air(); fixture.fuel(5000); fixture.unlimited(true); fixture.conditions(200);
    fixture.command(2004,1); // Fixed idle thrust: compare input ownership, not spool transients.
    fixture.ticks(300);
}

void held_pitch_and_yaw_ownership(Fixture& fixture) {
    for (const auto& axis : {pitch_axis,yaw_axis}) {
        for (const float direction : {-1.0f,1.0f}) {
            prepare_axis_fixture(fixture);
            const double neutral = axis_moment(fixture,axis.component);
            fixture.command(axis.press[0],1);
            fixture.command(axis.analog,direction); // Real axis event takes over from a key.
            fixture.ticks(200);
            const double held = axis_moment(fixture,axis.component);
            assert(std::abs(held-neutral)>1000);
            for (const int release : {194,196,198,200,202,204}) {
                fixture.command(release,0); fixture.ticks(100);
                assert(std::abs(axis_moment(fixture,axis.component)-held)<1.0);
            }
            fixture.ticks(1000); // No artificial repeated joystick/pedal event.
            assert(std::abs(axis_moment(fixture,axis.component)-held)<1.0);
            fixture.command(axis.analog,0); fixture.ticks(300);
            assert(std::abs(axis_moment(fixture,axis.component)-neutral)<1.0);
        }
    }
}

void pitch_and_yaw_keyboard_release(Fixture& fixture) {
    for (const auto& axis : {pitch_axis,yaw_axis}) {
        for (unsigned first = 0; first < 2; ++first) {
            prepare_axis_fixture(fixture);
            const double neutral = axis_moment(fixture,axis.component);
            fixture.command(axis.press[first],1);
            fixture.command(axis.press[1-first],1); fixture.ticks(200);
            const double held = axis_moment(fixture,axis.component);
            assert(std::abs(held-neutral)>1000);
            fixture.command(axis.release[first],0); fixture.ticks(100);
            assert(std::abs(axis_moment(fixture,axis.component)-held)<1.0);
            fixture.command(axis.release[1-first],0); fixture.ticks(300);
            fixture.command(axis.release[1-first],0); fixture.ticks(100);
            assert(std::abs(axis_moment(fixture,axis.component)-neutral)<1.0);
        }
    }
}

void utility_frame(Fixture& f, double right, bool tank, double inventory_stamp) {
    f.set("F22_HYD_DEMAND_VALID",0);
    f.set("F22_HYD_DEMAND_SCHEMA",1);
    f.set("F22_HYD_DEMAND_GENERATION",f.get("EFM_PHYSICAL_GENERATION"));
    f.set("F22_HYD_DEMAND_STAMP",f.get("F22_AP_CLOCK"));
    f.set("F22_HYD_DEMAND_SEQUENCE",f.get("F22_HYD_DEMAND_SEQUENCE")+1);
    f.set("F22_L_HYD_LOAD",0); f.set("F22_R_HYD_LOAD",right);
    f.set("F22_FUEL_INVENTORY_VALID",1); f.set("F22_FUEL_INVENTORY_STAMP",inventory_stamp);
    f.set("F22_LEFT_TANK_INSTALLED",tank?1:0); f.set("F22_RIGHT_TANK_INSTALLED",0);
    f.set("F22_HYD_DEMAND_VALID",1);
}

void tank_identity_and_demand(Fixture& f) {
    f.release(); f.hot(); f.fuel(8200); f.unlimited(true); f.conditions(0); f.ticks(1);
    f.external(2,0,-.21,-.9,-1.487); // empty-at-install is not removal
    f.refuel(100); assert(f.getexternal()==0); // no invented installation identity
    f.ticks(1);
    utility_frame(f,0,true,f.get("F22_AP_CLOCK")); f.ticks(1);
    f.refuel(100); assert(f.getexternal()==100);
    assert(std::abs(f.drain_mass()+100)<1e-9);
    f.external(2,0,0,0,0); // zero quantity does not discard the known tank
    f.ticks(1); utility_frame(f,0,true,f.get("F22_AP_CLOCK")); f.ticks(1);
    f.refuel(50); assert(f.getexternal()==50);
    assert(std::abs(f.drain_mass()+50)<1e-9);
    for (int index=0; index<100; ++index) {
        utility_frame(f,1,true,f.get("F22_AP_CLOCK")); f.ticks(1);
    }
    const double loaded=f.get("EFM_HYD_RIGHT_PSI");
    assert(loaded<3700 && f.get("EFM_HYD_LEFT_PSI")>3900);
    f.ticks(150); assert(f.get("EFM_HYD_RIGHT_PSI")>3900); // stale demand expires
    utility_frame(f,0,false,f.get("F22_AP_CLOCK")); f.ticks(1);
    assert(f.getexternal()==0 && f.drain_mass()==0); // host owns jettison mass
    f.refuel(100); assert(f.getexternal()==0 && f.drain_mass()==0);
    f.external(2,100,-.21,-.9,-1.487); f.ticks(1);
    assert(f.getexternal()==100); // old absent inventory cannot erase a new loadout
    f.external(-1,100,0,0,-2); f.external(16,100,0,0,2);
    assert(f.getexternal()==100);
}

void brake_force_and_thermal_path(Fixture& f) {
    f.release(); f.hot(); f.fuel(5000); f.unlimited(true); f.conditions(70);
    f.surface(3000,0,0,0,1,0);
    f.ticks(1500); // settle engines/actuators before comparing pedal effects
    ed_fm_suspension_info wheel{};
    wheel.struct_compression=.1; wheel.acting_force[1]=150000;
    wheel.acting_force_point[0]=-1; wheel.acting_force_point[1]=-2;
    f.suspension(1,&wheel); f.suspension(2,&wheel); f.ticks(1);
    double before=0,fy=0,fz=0,x=0,y=0,z=0,after=0;
    f.force(before,fy,fz,x,y,z);
    f.command(74,1); f.ticks(1); f.force(after,fy,fz,x,y,z);
    assert(std::abs(after-before)<1); // braking cannot invent aerodynamic drag
    assert(f.parameter(ED_FM_SUSPENSION_1_RELATIVE_BRAKE_MOMENT)>.99);
    for (int index=0; index<3000; ++index) {
        f.suspension(1,&wheel); f.suspension(2,&wheel); f.ticks(1);
    }
    assert(f.get("EFM_L_BRAKE_TEMP_EST_C")>450);
    assert(f.parameter(ED_FM_SUSPENSION_1_RELATIVE_BRAKE_MOMENT)<.9);
    const double work=f.get("EFM_L_BRAKE_WORK_UPPER_J");
    f.ticks(100); // feedback loss cannot leave a wheel heater latched
    assert(f.get("EFM_L_BRAKE_WORK_UPPER_J")>=work);
    const double expired=f.get("EFM_L_BRAKE_WORK_UPPER_J");
    f.ticks(100); assert(f.get("EFM_L_BRAKE_WORK_UPPER_J")==expired);
    f.command(75,1); f.conditions(0); f.ticks(30000);
    assert(f.get("EFM_L_TIRE_FAILED")==1 && f.needs_repair());
    const double heat=f.get("EFM_L_BRAKE_TEMP_EST_C");
    f.conditions(30); f.surface(3000,0,0,0,1,0); f.ticks(1);
    f.force(before,fy,fz,x,y,z);
    wheel.acting_force_point[2]=-1.5;
    f.suspension(1,&wheel); f.ticks(1); f.force(after,fy,fz,x,y,z);
    assert(after < before-8000); // failed tire adds a physical contact force
    f.repair(); f.ticks(1);
    assert(f.get("EFM_L_TIRE_FAILED")==0 && f.get("EFM_L_BRAKE_TEMP_EST_C")>heat-1);
}

void actual_approach_contact_rejection(Fixture& f) {
    f.release(); f.hot(); f.fuel(5000); f.unlimited(true); f.conditions(72);
    // User trace: gear extended at 2230 m MSL, runway about 241 m. Positive
    // strut travel must not hide the landing cue throughout that descent.
    f.atmosphere(2230,288.15,340,1.225,101325,0,0,0);
    f.surface(241,241,0,0,1,0);
    ed_fm_suspension_info wheel{};
    wheel.struct_compression=.3;
    for (int index=0;index<3;++index) f.suspension(index,&wheel);
    f.ticks(1);
    assert(f.get("EFM_GEAR_DOWN_LOCKED")==1 && f.get("EFM_GROUND_VALID")==1);
    assert(f.get("EFM_WEIGHT_ON_WHEELS")==0);
    assert(f.get("EFM_GROUND_CLEARANCE_M")==1989); // elevations, not h + h_obj/2
    // At flare height, unloaded positive strut travel still is not contact.
    f.atmosphere(243,288.15,340,1.225,101325,0,0,0);f.surface(241,241,0,0,1,0);
    for (int index=0;index<3;++index) f.suspension(index,&wheel);
    f.ticks(1);assert(f.get("EFM_WEIGHT_ON_WHEELS")==0);
    wheel.acting_force[1]=120000;f.suspension(1,&wheel);f.ticks(1);
    assert(f.get("EFM_WEIGHT_ON_WHEELS")==1 && f.get("EFM_GROUND_VALID")==1);
    wheel.acting_force[1]=0;f.suspension(1,&wheel);f.ticks(1);
    assert(f.get("EFM_WEIGHT_ON_WHEELS")==0); // bounce / unload, same travel
    wheel.acting_force[1]=120000;f.suspension(1,&wheel);f.ticks(1);
    f.ticks(20);assert(f.get("EFM_GROUND_VALID")==0); // no latched stale evidence
    // An erroneous/stale loaded sample cannot establish contact at altitude.
    f.atmosphere(2230,288.15,340,1.225,101325,0,0,0);f.surface(241,241,0,0,1,0);
    f.suspension(1,&wheel);f.ticks(1);
    assert(f.get("EFM_GROUND_VALID")==1 && f.get("EFM_WEIGHT_ON_WHEELS")==0);
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
    nonzero_spawn_cg_pitch_authority(fixture);
    utility_and_alternate_gear(fixture);
    invalid_producer_recovery(fixture);
    fire_and_structural_recovery(fixture);
    configuration_and_lifecycle(fixture);
    force_and_release_boundaries(fixture);
    live_ground_power(fixture);
    damaged_rudder_braking(fixture);
    manual_engine_and_unlit_fuel(fixture);
    engine_temperature_and_control_faults(fixture);
    held_roll_input_ownership(fixture);
    held_pitch_and_yaw_ownership(fixture);
    pitch_and_yaw_keyboard_release(fixture);
    tank_identity_and_demand(fixture);
    brake_force_and_thermal_path(fixture);
    actual_approach_contact_rejection(fixture);
    std::cout << "vehicle DLL: cold/APU/start, burn/mass, feed/repair, sensor truth, limits and lifecycle OK\n";
}
