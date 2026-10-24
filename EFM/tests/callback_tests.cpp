// SPDX-License-Identifier: GPL-3.0-or-later
#define EXPORT_ED_FM_PHYSICS_IMP extern "C"
#include <cstddef>
#include <FM/wHumanCustomPhysicsAPI_ImplementationDeclare.h>
#include <cmath>
#include <iostream>
#include <stdexcept>
#include <vector>
namespace {
int assertions=0;
void check(bool ok,const char* message) { ++assertions; if(!ok) throw std::runtime_error(message); }
void near(double a,double b,double tol,const char* message) { check(std::abs(a-b)<=tol,message); }
void body(double vx=150,double wx=0) {
    ed_fm_set_current_state_body_axis(0,0,0,vx,0,0,wx,0,0,0,0,0,0,0,0,0,0,0,0,0);
}
void callbacks() {
    ed_fm_release(); ed_fm_set_internal_fuel(1000); ed_fm_hot_start_in_air();
    ed_fm_set_atmosphere(3000,268.65,328.58,.90912,70109,20,0,0);
    ed_fm_set_surface(100,120,0,0,1,0);
    ed_fm_set_current_mass_state(28000,.1,0,0,30000,180000,170000);
    body(); ed_fm_simulate(.004);
    check(ed_fm_get_param(ED_FM_ENGINE_1_RPM)>1000,"RPM export is shaft RPM, not a normalized ratio");
    check(ed_fm_get_param(ED_FM_ENGINE_1_RELATED_RPM)<1,"relative RPM export normalized");
    near(ed_fm_get_param(ED_FM_ENGINE_1_RPM)/12000,
        ed_fm_get_param(ED_FM_ENGINE_1_RELATED_RPM),1e-12,"RPM and relative RPM agree");
    check(ed_fm_get_param(ED_FM_ENGINE_1_COMBUSTION)==1,"hot engine burning");
    check(ed_fm_get_param(ED_FM_ENGINE_1_TEMPERATURE)<1000,"temperature exported in Celsius");
    double kg,x,y,z,ix,iy,iz; double removed=0;
    while(ed_fm_change_mass(kg,x,y,z,ix,iy,iz)) removed+=kg;
    near(1000-ed_fm_get_internal_fuel(),removed,1e-9,"callback mass exactly matches actual fuel burn");
    ed_fm_refueling_add_fuel(200); check(ed_fm_change_mass(kg,x,y,z,ix,iy,iz),"refueling mass event");
    near(kg,-200,1e-9,"host supplied refuel amount applied exactly once");
    check(!ed_fm_change_mass(kg,x,y,z,ix,iy,iz),"no duplicated refuel event");
    ed_fm_set_external_fuel(1,123,-1,0,-4); near(ed_fm_get_external_fuel(),123,0,"host partial external fuel");
    ed_fm_set_external_fuel(1,0,0,0,0); near(ed_fm_get_external_fuel(),0,0,"host removes external station");
    ed_fm_set_command(2001,.8f); near(ed_fm_get_param(ED_FM_FC3_STICK_PITCH),.8,1e-6,"full stick export");
    ed_fm_set_command(10056,0); ed_fm_set_command(10057,1);
    near(ed_fm_get_param(ED_FM_SUSPENSION_1_RELATIVE_BRAKE_MOMENT),.5,0,"proportional left brake");
    near(ed_fm_get_param(ED_FM_SUSPENSION_2_RELATIVE_BRAKE_MOMENT),1,0,"independent right brake");
    ed_fm_set_command(74,1); near(ed_fm_get_param(ED_FM_SUSPENSION_1_RELATIVE_BRAKE_MOMENT),1,0,"keyboard common brake");
    ed_fm_set_command(75,0); near(ed_fm_get_param(ED_FM_SUSPENSION_1_RELATIVE_BRAKE_MOMENT),.5,0,"common release retains axis");
    // Rendering must be a bounded read-only view, including zero/undersized buffers.
    ed_fm_set_draw_args_v2(nullptr,0); ed_fm_set_fc3_cockpit_draw_args_v2(nullptr,0);
    for(std::size_t size:{0u,1u,12u,100u,624u,716u}) {
        std::vector<float> args(size+2,123.0f);
        ed_fm_set_draw_args_v2(args.data()+1,size);
        ed_fm_set_fc3_cockpit_draw_args_v2(args.data()+1,size);
        near(args.front(),123,0,"draw left guard"); near(args.back(),123,0,"draw right guard");
    }
    ed_fm_on_damage(13,0); ed_fm_simulate(.004);
    near(ed_fm_get_param(ED_FM_ENGINE_1_THRUST),0,0,"damaged engine no thrust");
    near(ed_fm_get_param(ED_FM_ENGINE_1_COMBUSTION),0,0,"damaged engine no combustion");
    check(ed_fm_need_to_be_repaired(),"damage requires repair");
    ed_fm_repair(); check(!ed_fm_need_to_be_repaired(),"repair clears all damage");
    ed_fm_simulation_event event{}; check(!ed_fm_pop_simulation_event(event),"incoming damage not echoed as structure events");
    ed_fm_set_immortal(true); ed_fm_on_damage(13,0); check(!ed_fm_need_to_be_repaired(),"invulnerability honors host setting");
    ed_fm_set_immortal(false);
    ed_fm_on_planned_failure(nullptr);ed_fm_on_planned_failure("unknown");
    check(!ed_fm_need_to_be_repaired(),"unsupported planned failure does not invent a fault");
    ed_fm_on_planned_failure("l_engine");ed_fm_simulate(.004);
    near(ed_fm_get_param(ED_FM_ENGINE_1_OPERABILITY_FACTOR),0,0,"planned left-engine fault reaches physics");
    check(ed_fm_get_param(ED_FM_ENGINE_2_OPERABILITY_FACTOR)>0,"planned engine fault remains independent");
    check(ed_fm_need_to_be_repaired(),"planned failure requests repair");
    ed_fm_repair();near(ed_fm_get_param(ED_FM_ENGINE_1_OPERABILITY_FACTOR),1,0,"repair restores planned engine operability");
    ed_fm_hot_start_in_air();ed_fm_on_planned_failure("hydro");ed_fm_set_command(431,1);ed_fm_simulate(1);
    float gearArgs[6]{};ed_fm_set_draw_args_v2(gearArgs,6);
    near(gearArgs[0],0,0,"planned hydraulic failure holds gear without cockpit DLL");
    ed_fm_repair();ed_fm_simulate(1);ed_fm_set_draw_args_v2(gearArgs,6);
    check(gearArgs[0]>.2,"repair restores hydraulic actuation");
    for(const char* id:{"apu","l_generator","r_generator"}) {
        ed_fm_on_planned_failure(id);check(ed_fm_need_to_be_repaired(),"supply failure requests repair");
        ed_fm_repair();check(!ed_fm_need_to_be_repaired(),"repair clears supply failure");
    }
    ed_fm_on_planned_failure("r_engine");ed_fm_cold_start();
    check(!ed_fm_need_to_be_repaired(),"new start clears old planned failures");
    // WOW comes from contact, including flight below 50 m AGL.
    ed_fm_hot_start(); ed_fm_set_command(430,1);
    near(ed_fm_get_param(ED_FM_FC3_GEAR_HANDLE_POS),1,0,"ground-start gear inhibit");
    ed_fm_suspension_info feedback{};
    for(int i=0;i<3;++i) ed_fm_suspension_feedback(i,&feedback);
    ed_fm_set_atmosphere(10,288.15,340.294,1.225,101325,0,0,0);
    ed_fm_set_command(430,1); near(ed_fm_get_param(ED_FM_FC3_GEAR_HANDLE_POS),0,0,"airborne low AGL is not weight on wheels");
    // Steering uses earth speed, so a stationary aircraft in wind retains steering authority.
    feedback.struct_compression=.1; ed_fm_suspension_feedback(0,&feedback);
    ed_fm_set_current_state(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
    ed_fm_set_command(2003,1);
    check(ed_fm_get_param(ED_FM_SUSPENSION_0_WHEEL_YAW)>.5,"stationary steering uses ground speed");
    ed_fm_set_internal_fuel(1000); ed_fm_hot_start_in_air(); body(170,20); ed_fm_simulate(.004);
    double fx1,fy1,fz1,px,py,pz; ed_fm_add_local_force(fx1,fy1,fz1,px,py,pz);
    ed_fm_hot_start_in_air(); body(150,0); ed_fm_simulate(.004);
    double fx2,fy2,fz2; ed_fm_add_local_force(fx2,fy2,fz2,px,py,pz);
    near(fx1,fx2,1e-8,"air-relative velocity subtracts body wind exactly once");
    ed_fm_release(); near(ed_fm_get_internal_fuel(),0,0,"release clears internal fuel");
    near(ed_fm_get_external_fuel(),0,0,"release clears external fuel");
    check(!ed_fm_change_mass(kg,x,y,z,ix,iy,iz),"release clears mass queue");
}
}
int main() {
    try { callbacks(); } catch(const std::exception& e) { std::cerr<<"FAIL: "<<e.what()<<'\n'; return 1; }
    std::cout<<"PASS: "<<assertions<<" callback assertions (absent cockpit DLL)\n";
}
