#include <windows.h>
#include <cassert>
#include <cmath>
#include <array>
#include <iostream>
#include "../EFM/include/FM/wHumanCustomPhysicsAPI.h"
#include "../EFM/source/VehicleSystems.h"

template<typename T>T proc(HMODULE m,const char* name) {
    auto p=reinterpret_cast<T>(GetProcAddress(m,name));assert(p);return p;
}
int main(int argc,char** argv) {
    assert(argc==3);
    HMODULE cockpit=LoadLibraryA(argv[1]);assert(cockpit);
    auto handle=proc<void*(*)(const char*)>(cockpit,"ed_cockpit_get_parameter_handle");
    auto write=proc<void(*)(void*,double)>(cockpit,"ed_cockpit_update_parameter_with_number");
    auto read=proc<bool(*)(const void*,double&,bool)>(cockpit,"ed_cockpit_parameter_value_to_number");
    auto set=[&](const char* n,double v){write(handle(n),v);};
    auto get=[&](const char* n){double v=0;assert(read(handle(n),v,false));return v;};
    HMODULE fm=LoadLibraryA(argv[2]);assert(fm);
    auto hot=proc<void(*)()>(fm,"ed_fm_hot_start");
    auto air=proc<void(*)()>(fm,"ed_fm_hot_start_in_air");
    auto cold=proc<void(*)()>(fm,"ed_fm_cold_start");
    auto sim=proc<void(*)(double)>(fm,"ed_fm_simulate");
    auto cmd=proc<void(*)(int,float)>(fm,"ed_fm_set_command");
    auto param=proc<double(*)(unsigned)>(fm,"ed_fm_get_param");
    auto draw=proc<void(*)(float*,size_t)>(fm,"ed_fm_set_draw_args_v2");
    auto atmosphere=proc<void(*)(double,double,double,double,double,double,double,double)>(fm,"ed_fm_set_atmosphere");
    auto surface=proc<void(*)(double,double,unsigned,double,double,double)>(fm,"ed_fm_set_surface");
    using State=void(*)(double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double);
    auto state=proc<State>(fm,"ed_fm_set_current_state_body_axis");
    using WorldState=void(*)(double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double,double);
    auto world=proc<WorldState>(fm,"ed_fm_set_current_state");
    auto fuel=proc<void(*)(double)>(fm,"ed_fm_set_internal_fuel");
    auto external=proc<void(*)(int,double,double,double,double)>(fm,"ed_fm_set_external_fuel");
    auto refuel=proc<void(*)(double)>(fm,"ed_fm_refueling_add_fuel");
    auto getfuel=proc<double(*)()>(fm,"ed_fm_get_internal_fuel");
    auto getexternal=proc<double(*)()>(fm,"ed_fm_get_external_fuel");
    auto infinite=proc<void(*)(bool)>(fm,"ed_fm_unlimited_fuel");
    auto suspension=proc<void(*)(int,const ed_fm_suspension_info*)>(fm,"ed_fm_suspension_feedback");
    auto mass=proc<bool(*)(double&,double&,double&,double&,double&,double&,double&)>(fm,"ed_fm_change_mass");
    auto ticks=[&](int n){for(int i=0;i<n;++i)sim(.01);};
    auto body=[&](double speed,double aoa=0){
        world(0,0,0,speed,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
        state(0,0,0,speed*std::cos(aoa),-speed*std::sin(aoa),0,
              0,0,0,0,0,0,0,0,0,0,0,0,aoa,0);
    };
    auto setup=[&](bool in_air){
        if(in_air)air();else hot();
        atmosphere(in_air?3000:0,288.15,340,1.225,101325,0,0,0);
        surface(0,0,0,0,1,0);fuel(5000);infinite(true);
        set("MAIN_POWER",1);set("BATTERY_POWER",1);
        set("L_HYD_FAILURE",0);set("R_HYD_FAILURE",0);
        body(in_air?100:0);
    };
    setup(false);ticks(100);
    assert(param(ED_FM_ENGINE_1_CORE_RPM)>10000);
    assert(param(ED_FM_ENGINE_1_RPM)>6000);
    assert(std::abs(param(ED_FM_ENGINE_1_CORE_RELATED_RPM)-.67)<1e-6);
    assert(param(ED_FM_ENGINE_1_TEMPERATURE)>400 && param(ED_FM_ENGINE_1_TEMPERATURE)<500);
    cmd(10540,.25f);cmd(10541,.8f);ticks(1);
    assert(param(ED_FM_SUSPENSION_0_RELATIVE_BRAKE_MOMENT)==0);
    assert(std::abs(param(ED_FM_SUSPENSION_1_RELATIVE_BRAKE_MOMENT)-.25)<1e-6);
    assert(std::abs(param(ED_FM_SUSPENSION_2_RELATIVE_BRAKE_MOMENT)-.8)<1e-6);
    cmd(74,1);ticks(1);
    assert(param(ED_FM_SUSPENSION_1_RELATIVE_BRAKE_MOMENT)==1 && param(ED_FM_SUSPENSION_2_RELATIVE_BRAKE_MOMENT)==1);
    cmd(75,1);ticks(1);assert(param(ED_FM_SUSPENSION_1_RELATIVE_BRAKE_MOMENT)<.3);

    // Manual flap request must reach an achieved position, then Up retracts.
    cmd(146,1);ticks(200);std::array<float,800> args{};draw(args.data(),args.size());assert(args[9]>.99);
    cmd(145,1);ticks(200);draw(args.data(),args.size());assert(args[9]==0);
    // Loss of both supplies freezes physical effectors; healthy recovery moves.
    set("L_HYD_FAILURE",1);set("R_HYD_FAILURE",1);ticks(200);
    assert(get("EFM_HYD_LEFT_PSI")==0 && get("EFM_HYD_RIGHT_PSI")==0 && get("EFM_ACTUATOR_AVAILABLE")==0);
    cmd(146,1);ticks(200);draw(args.data(),args.size());assert(args[9]==0);
    set("R_HYD_FAILURE",0);ticks(400);draw(args.data(),args.size());assert(args[9]>.99);
    assert(get("EFM_HYD_LEFT_PSI")==0 && get("EFM_HYD_RIGHT_PSI")>3900);
    set("MAIN_POWER",0);set("BATTERY_POWER",0);cmd(145,1);ticks(200);draw(args.data(),args.size());assert(args[9]>.99);
    set("MAIN_POWER",1);ticks(200);draw(args.data(),args.size());assert(args[9]==0);

    // DCS's repeated trim binding delivers value zero as a valid command.
    // Event bursts alone must not move trim; elapsed simulation time does.
    setup(true);body(210);ticks(100);
    for(int i=0;i<100;++i)cmd(95,0);
    ticks(10);assert(std::abs(get("EFM_TRIM_PITCH")-.004)<1e-8);
    assert(get("EFM_TRIM_MANUAL")==1 && get("EFM_TRIM_AUTO_ACTIVE")==0);
    cmd(215,0);ticks(40);
    assert(get("EFM_TRIM_MANUAL")==0 && get("EFM_TRIM_AUTO_ACTIVE")==1);
    ticks(100);assert(std::abs(get("EFM_TRIM_PITCH")-.004)<1e-8);
    cmd(97,0);ticks(1);assert(get("EFM_TRIM_PITCH")==0);

    setup(true);ticks(100);
    cmd(94,0);ticks(1100);cmd(215,0); // held roll trim saturates at +0.2
    ticks(100);draw(args.data(),args.size());assert(args[11]>.19 && args[11]<.21 && args[12]<-.19);
    cmd(98,0);ticks(1100);cmd(215,0);
    ticks(100);draw(args.data(),args.size());assert(args[17]>.19 && args[17]<.35);
    cmd(97,1);ticks(100);draw(args.data(),args.size());assert(std::abs(args[11])<1e-6 && std::abs(args[17])<1e-6);

    // At the same speed/spool, toggling only wheel contact must not jump thrust.
    setup(false);body(80);cmd(2004,-.6511628f);ticks(1500);
    ed_fm_suspension_info contact{};contact.struct_compression=.1;
    suspension(0,&contact);ticks(1);const double ground_thrust=param(ED_FM_ENGINE_1_THRUST);
    contact.struct_compression=0;suspension(0,&contact);ticks(1);
    assert(std::abs(param(ED_FM_ENGINE_1_THRUST)-ground_thrust)<1e-5);
    assert(param(ED_FM_ENGINE_1_OIL_PRESSURE)>1e6); // Pa, not psi

    setup(true);cmd(2001,-1);ticks(150);draw(args.data(),args.size());
    assert(std::abs(args[622])>.01);
    // Only one nozzle can be held by a side-specific fault. Force and drawing
    // still read the same achieved angle; the healthy side centers at Mach 1.6.
    set("L_HYD_FAILURE",1);ticks(200);
    atmosphere(3000,288.15,340,1.225,101325,0,0,0);body(544);cmd(2001,0);ticks(300);
    draw(args.data(),args.size());
    assert(std::abs(args[623])<1e-6);
    assert(std::abs(args[622])>.01);
    assert(std::abs(get("EFM_TVC_LEFT_DEG")+args[622]*20)<1e-5);
    assert(get("EFM_ENGINE_LEFT_THRUST_N")>=0 && get("EFM_ENGINE_LEFT_THRUST_PCT")<=100);
    // Draw calls cannot independently move an effector.
    const auto before=args;for(int i=0;i<20;++i)draw(args.data(),args.size());
    assert(before[622]==args[622] && before[15]==args[15]);
    cmd(313,1);ticks(1);assert(param(ED_FM_ENGINE_1_THRUST)==0);

    // Callback-reported tank station IDs are authoritative, without guessing
    // whether the host's station enumeration is zero- or one-based.
    cold();fuel(8190);external(1,1000,0,0,-3);external(9,500,0,0,3);
    const double cap=RaptorVehicle::external_tank_capacity_kg;
    assert(param(ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER)==1);
    refuel(10000);
    assert(getfuel()==8200 && std::abs(getexternal()-2*cap)<1e-8);
    assert(param(ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER)==0);
    double dm=0,x=0,y=0,z=0,ix=0,iy=0,iz=0,total=0;
    while(mass(dm,x,y,z,ix,iy,iz))total+=dm;
    assert(std::abs(total+(10+2*cap-1500))<1e-8);
    refuel(100);assert(!mass(dm,x,y,z,ix,iy,iz));
    external(1,0,0,0,-3);external(9,0,0,0,3);assert(getexternal()==0);
    assert(param(ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER)==0); // no ghost installed tanks
    cold();fuel(500);cmd(2004,-1);ticks(50);
    assert(param(ED_FM_ENGINE_1_CORE_RPM)==0 && param(ED_FM_ENGINE_1_RPM)==0);
    std::cout<<"EFM callbacks: RPM/temp, differential brakes, flaps, power/hydraulic/nozzle faults, fuel/refuel ledger OK\n";
}
