/*    Grinnelli Designs F-22A Raptor
    Copyright (C) 2025, Branden Hooper

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see https://www.gnu.org/licenses.
*/

// DCS host adapter. Physics and controller implementation live in FlightModel/.
#ifdef _WIN32
#define EXPORT_ED_FM_PHYSICS_IMP extern "C" __declspec(dllexport)
#elif defined(F22_HOST_TEST)
#define EXPORT_ED_FM_PHYSICS_IMP extern "C"
#else
#error The DCS plugin requires Windows; use F22_HOST_TEST only for callback tests.
#endif
#include <cstddef>
#include <FM/wHumanCustomPhysicsAPI_ImplementationDeclare.h>
#include <Cockpit/CockpitAPI_Declare.h>
#include "RAPTOR.h"
#include "Inputs.h"
#include <algorithm>
#include <array>
#include <string>
#include <unordered_map>

namespace {
using namespace f22;
FlightModel model;
Environment environment;
Vec3 groundVelocityBody;
bool bodyStateReceived=false;
std::array<double,111> integrity=[] { std::array<double,111> a{}; a.fill(1); return a; }();
std::array<bool,3> contact{};
bool contactReceived=false, groundStart=true, immortal=false;
double surfaceHeight=0, commonBrake=0, leftBrake=0, rightBrake=0, elapsed=0;
std::array<double,3> keyboard{};
std::array<bool,3> keyboardActive{};
class Parameters {
    EDPARAM api;
    std::unordered_map<std::string,void*> handles;
    void* handle(const char* name) {
        auto& h=handles[name];
        if(!h) h=api.getParamHandle(name);
        return h;
    }
public:
    double read(const char* name,double fallback=0) {
        const double value=api.getParamNumber(handle(name));
        return std::isfinite(value) ? value : fallback;
    }
    void write(const char* name,double value) { api.setParamNumber(handle(name),value); }
    void clear() { handles.clear(); api=EDPARAM{}; }
} parameters;

bool onGround() {
    return contactReceived ? std::any_of(contact.begin(),contact.end(),[](bool v){return v;}) : groundStart;
}
double brake(bool left) {
    return std::max(commonBrake,clamp(parameters.read(left ? "F22_BRAKE_LEFT" : "F22_BRAKE_RIGHT",
        left ? leftBrake : rightBrake),0,1));
}
void updateHealth() {
    auto product=[](std::initializer_list<int> parts) { double h=1; for(int p:parts) h*=integrity[p]; return h; };
    auto& h=model.health;
    h=Health{};
    h.leftWing=product({23,29,35}); h.rightWing=product({24,30,36});
    h.engine={product({11,13,17,103}),product({12,14,18,104})};
    h.surface[data::TailLeft]=product({45,47,49,51,55,56});
    h.surface[data::TailRight]=product({46,48,50,52,55,57});
    h.surface[data::AileronLeft]=integrity[25]*h.leftWing;
    h.surface[data::AileronRight]=integrity[26]*h.rightWing;
    h.surface[data::FlaperonLeft]=product({31,37})*h.leftWing;
    h.surface[data::FlaperonRight]=product({32,38})*h.rightWing;
    h.surface[data::RudderLeft]=product({39,41,43,53});
    h.surface[data::RudderRight]=product({40,42,44,54});
    h.tail=.5*(h.surface[data::TailLeft]+h.surface[data::TailRight]);
}
void start(Start mode) {
    model.reset(mode); integrity.fill(1);
    contact.fill(false); contactReceived=false; groundStart=mode!=Start::AirHot;
    commonBrake=leftBrake=rightBrake=elapsed=0;
    keyboard.fill(0); keyboardActive.fill(false);
    environment.weightOnWheels=groundStart;
    groundVelocityBody={}; bodyStateReceived=false;
    parameters.write("F22_EFM_VALID",0);
}
void publish() {
    parameters.write("WoW",environment.weightOnWheels ? 1 : 0);
    parameters.write("F22_EFM_VALID",bodyStateReceived ? 1 : 0);
    parameters.write("F22_VEL_BODY_X",groundVelocityBody.x);
    parameters.write("F22_VEL_BODY_Y",groundVelocityBody.y);
    parameters.write("F22_VEL_BODY_Z",groundVelocityBody.z);
    parameters.write("F22_NORMAL_G",model.normalLoad);
    parameters.write("F22_FUEL_VALID",1);
    parameters.write("F22_FUEL_TOTAL_KG",model.fuel.total());
    parameters.write("F22_FUEL_INTERNAL_KG",model.fuel.internal);
    parameters.write("F22_FUEL_EXTERNAL_KG",model.fuel.externalQuantity());
    for(std::size_t i=0;i<2;++i) {
        parameters.write(i==0 ? "F22_FUEL_FLOW_LEFT_KGS" : "F22_FUEL_FLOW_RIGHT_KGS",model.engines[i].fuelFlow);
        parameters.write(i==0 ? "F22_THROTTLE_LEFT_RAW" : "F22_THROTTLE_RIGHT_RAW",1-2*model.input.throttle[i]);
        parameters.write(i==0 ? "F22_ENGINE_LEFT_RUN" : "F22_ENGINE_RIGHT_RUN",model.input.engineRun[i] ? 1 : 0);
    }
    parameters.write("F22_NOZZLE_LEFT_DEG",degrees(model.surface[data::NozzleLeft]));
    parameters.write("F22_NOZZLE_RIGHT_DEG",degrees(model.surface[data::NozzleRight]));
    parameters.write("F22_TAIL_LEFT_DEG",degrees(model.surface[data::TailLeft]));
    parameters.write("F22_TAIL_RIGHT_DEG",degrees(model.surface[data::TailRight]));
    const double gearLight=model.config.gear>.99 && (parameters.read("F22_SYSTEMS_VALID")>.5 ?
        parameters.read("F22_DC_AVAILABLE")>.5 :
        std::max(parameters.read("MAIN_POWER"),parameters.read("BATTERY_POWER"))>.5) ? 1 : 0;
    for(const char* name:{"N_GEAR_LIGHT","R_GEAR_LIGHT","L_GEAR_LIGHT"}) parameters.write(name,gearLight);
}
}

EXPORT_ED_FM_PHYSICS_IMP void ed_fm_simulate(double dt) {
    if(!std::isfinite(dt)||dt<=0) return;
    environment.weightOnWheels=onGround();
    environment.height=std::max(0.0,environment.altitude-surfaceHeight);
    double* axes[]={&model.input.pitch,&model.input.roll,&model.input.yaw};
    for(std::size_t i=0;i<3;++i) if(keyboardActive[i])
        *axes[i]=approach(*axes[i],keyboard[i],1.33,dt);
    if(parameters.read("F22_SYSTEMS_VALID")>.5) {
        const double supply=clamp((std::max(parameters.read("F22_HYD_LEFT_PSI"),
            parameters.read("F22_HYD_RIGHT_PSI"))-500)/3500,0,1);
        model.health.hydraulic=supply;
        model.health.actuator.fill(supply);
    }
    model.input.refueling=parameters.read("AAR")>.5;
    model.step(dt,environment); elapsed+=dt; publish();
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_add_local_force(double& x,double& y,double& z,double& px,double& py,double& pz) {
    x=model.output.force.x; y=model.output.force.y; z=model.output.force.z;
    px=environment.cg.x; py=environment.cg.y; pz=environment.cg.z;
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_add_local_moment(double& x,double& y,double& z) {
    x=model.output.moment.x; y=model.output.moment.y; z=model.output.moment.z;
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_surface(double h,double hObj,unsigned,double,double,double) {
    surfaceHeight=std::max(h,hObj);
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_atmosphere(double h,double t,double a,double rho,double p,double,double,double) {
    environment.altitude=h; environment.temperature=t; environment.soundSpeed=a;
    environment.density=rho; environment.pressure=p;
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_current_mass_state(double m,double x,double y,double z,double ix,double iy,double iz) {
    if(std::isfinite(m)&&m>0) environment.mass=m;
    environment.cg={x,y,z};
    if(ix>0&&iy>0&&iz>0) environment.inertia={ix,iy,iz};
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_current_state(double,double,double,double vx,double vy,double vz,
    double,double,double,double,double,double,double,double,double,double,double,double,double) {
    environment.groundSpeed=length({vx,vy,vz}); // earth-relative; never subtract wind here
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_current_state_body_axis(double,double,double,double vx,double vy,double vz,
    double wx,double wy,double wz,double,double,double,double ox,double oy,double oz,
    double,double pitch,double roll,double,double) {
    groundVelocityBody={vx,vy,vz}; bodyStateReceived=true;
    environment.airVelocity={vx-wx,vy-wy,vz-wz};
    environment.angularVelocity={ox,oy,oz}; environment.pitch=pitch; environment.roll=roll;
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_suspension_feedback(int idx,const ed_fm_suspension_info* info) {
    if(!info||idx<0||idx>=3) return;
    contactReceived=true;
    contact[static_cast<std::size_t>(idx)]=info->struct_compression>1e-5 ||
        length({info->acting_force[0],info->acting_force[1],info->acting_force[2]})>1;
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_command(int command,float value) {
    if(!std::isfinite(value)) return;
    auto& p=model.input;
    const double axis=clamp(static_cast<double>(value),-1,1);
    auto discrete=[](std::size_t i,double v) { keyboardActive[i]=true; keyboard[i]=v; };
    auto throttle=[&](std::size_t i,double v) { p.throttle[i]=clamp(v,0,1); };
    const bool mayStart=!onGround() || parameters.read("F22_SYSTEMS_VALID")<.5 ||
        parameters.read("F22_START_AVAILABLE")>.5;
    switch(command) {
    case JoystickPitch: p.pitch=axis; keyboardActive[0]=false; break;
    case JoystickRoll: p.roll=axis; keyboardActive[1]=false; break;
    case PedalYaw: p.yaw=-axis; keyboardActive[2]=false; break;
    case PitchUp: discrete(0,1); break;
    case PitchDown: discrete(0,-1); break;
    case PitchUpStop: case PitchDownStop: discrete(0,0); break;
    case RollLeft: discrete(1,-1); break;
    case RollRight: discrete(1,1); break;
    case RollLeftStop: case RollRightStop: discrete(1,0); break;
    case rudderleft: discrete(2,1); break;
    case rudderright: discrete(2,-1); break;
    case rudderleftstop: case rudderrightstop: discrete(2,0); break;
    case trimUp: p.pitchTrim=clamp(p.pitchTrim+.01,-1,1); break;
    case trimDown: p.pitchTrim=clamp(p.pitchTrim-.01,-1,1); break;
    case trimLeft: p.rollTrim=clamp(p.rollTrim-.01,-1,1); break;
    case trimRight: p.rollTrim=clamp(p.rollTrim+.01,-1,1); break;
    case ruddertrimLeft: p.yawTrim=clamp(p.yawTrim+.01,-1,1); break;
    case ruddertrimRight: p.yawTrim=clamp(p.yawTrim-.01,-1,1); break;
    case resetTrim: p.pitchTrim=p.rollTrim=p.yawTrim=0; break;
    case EnginesOn: if(mayStart) p.engineRun={true,true}; break;
    case EnginesOff: p.engineRun={false,false}; break;
    case LeftEngineOn: if(mayStart) p.engineRun[0]=true; break;
    case RightEngineOn: if(mayStart) p.engineRun[1]=true; break;
    case LeftEngineOff: p.engineRun[0]=false; break;
    case RightEngineOff: p.engineRun[1]=false; break;
    case ThrottleAxis: throttle(0,(1-axis)*.5); throttle(1,(1-axis)*.5); break;
    case ThrottleAxisLeft: throttle(0,(1-axis)*.5); break;
    case ThrottleAxisRight: throttle(1,(1-axis)*.5); break;
    case ThrottleIncrease: throttle(0,p.throttle[0]+.0075); throttle(1,p.throttle[1]+.0075); break;
    case ThrottleDecrease: throttle(0,p.throttle[0]-.0075); throttle(1,p.throttle[1]-.0075); break;
    case ThrottleLeftUp: throttle(0,p.throttle[0]+.0075); break;
    case ThrottleLeftDown: throttle(0,p.throttle[0]-.0075); break;
    case ThrottleRightUp: throttle(1,p.throttle[1]+.0075); break;
    case ThrottleRightDown: throttle(1,p.throttle[1]-.0075); break;
    case gearToggle: if(p.gearDown) { if(!onGround()) p.gearDown=false; } else p.gearDown=true; break;
    case gearUp: if(!onGround()) p.gearDown=false; break;
    case gearDown: p.gearDown=true; break;
    case AirBrakes: p.speedBrake=!p.speedBrake; break;
    case AirBrakesOn: p.speedBrake=true; break;
    case AirBrakesOff: p.speedBrake=false; break;
    case flapsToggle: p.manualFlaps=!p.manualFlaps; break;
    case flapsDown: p.manualFlaps=true; break;
    case flapsUp: p.manualFlaps=false; break;
    case WheelBrakeOn: commonBrake=1; break;
    case WheelBrakeOff: commonBrake=0; break;
    case 10056: leftBrake=(axis+1)*.5; break;
    case 10057: rightBrake=(axis+1)*.5; break;
    case 10058: leftBrake=rightBrake=(axis+1)*.5; break;
    default: break;
    }
}
EXPORT_ED_FM_PHYSICS_IMP bool ed_fm_change_mass(double& kg,double& x,double& y,double& z,double& ix,double& iy,double& iz) {
    MassDelta d;
    if(!model.fuel.pop(d)) return false;
    kg=d.kilograms; x=d.position.x; y=d.position.y; z=d.position.z;
    ix=d.inertia.x; iy=d.inertia.y; iz=d.inertia.z; return true;
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_internal_fuel(double kg) { if(std::isfinite(kg)) model.fuel.setInternal(kg); }
EXPORT_ED_FM_PHYSICS_IMP double ed_fm_get_internal_fuel() { return model.fuel.internal; }
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_external_fuel(int station,double kg,double x,double y,double z) {
    if(std::isfinite(kg)&&finite({x,y,z})) model.fuel.setExternal(station,kg,{x,y,z});
}
EXPORT_ED_FM_PHYSICS_IMP double ed_fm_get_external_fuel() { return model.fuel.externalQuantity(); }
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_refueling_add_fuel(double kg) { if(std::isfinite(kg)) model.fuel.refuel(kg); }
EXPORT_ED_FM_PHYSICS_IMP double ed_fm_get_param(unsigned param) {
    using namespace f22;
    constexpr unsigned engineBlock=ED_FM_ENGINE_1_RPM-ED_FM_ENGINE_0_RPM;
    if(param>=engineBlock&&param<3*engineBlock) {
        const std::size_t i=param/engineBlock-1;
        const auto& engine=model.engines[i];
        const double related=engine.dryAvailable>0 ? engine.thrust/engine.dryAvailable : 0;
        switch(param%engineBlock) {
        case ED_FM_ENGINE_0_RPM: return engine.fan*data::fanMaxRpm;
        case ED_FM_ENGINE_0_RELATED_RPM: return engine.fan;
        case ED_FM_ENGINE_0_CORE_RPM: return engine.core*data::coreMaxRpm;
        case ED_FM_ENGINE_0_CORE_RELATED_RPM: return engine.core;
        case ED_FM_ENGINE_0_THRUST: return engine.thrust;
        case ED_FM_ENGINE_0_RELATED_THRUST: return related;
        case ED_FM_ENGINE_0_CORE_THRUST: return engine.thrust*.7; // assumed core/fan split
        case ED_FM_ENGINE_0_CORE_RELATED_THRUST: return related;
        case ED_FM_ENGINE_0_TEMPERATURE: return engine.temperatureC;
        case ED_FM_ENGINE_0_FUEL_FLOW: return engine.fuelFlow;
        case ED_FM_ENGINE_0_COMBUSTION: return engine.combustion ? 1 : 0;
        case ED_FM_ENGINE_0_OPERABILITY_FACTOR: return model.health.engine[i];
        case ED_FM_ENGINE_0_FAN_PHASE: return engine.fanPhase*2*pi;
        case ED_FM_ENGINE_0_GAIN: return engine.combustion ? engine.dryPower+engine.afterburner : 0;
        default: return 0;
        }
    }
    if(param>=ED_FM_SUSPENSION_0_RELATIVE_BRAKE_MOMENT&&param<=ED_FM_SUSPENSION_2_WHEEL_SELF_ATTITUDE) {
        const unsigned offset=param-ED_FM_SUSPENSION_0_RELATIVE_BRAKE_MOMENT;
        const unsigned wheel=offset/10;
        switch(offset%10) {
        case 0: return wheel==0 ? 0 : brake(wheel==1);
        case 1: return model.config.gear;
        case 2: return model.config.gear<.01 ? 1 : 0;
        case 3: return model.config.gear>.99 ? 1 : 0;
        case 4: return wheel==0&&onGround() ? -model.input.yaw*radians(60)*
            (1-smoothStep(0,60,environment.groundSpeed*1.943844)) : 0;
        default: return 0;
        }
    }
    switch(param) {
    case ED_FM_FUEL_INTERNAL_FUEL: return model.fuel.internal;
    case ED_FM_FUEL_TOTAL_FUEL: return model.fuel.total();
    case ED_FM_FUEL_LOW_SIGNAL: return model.fuel.total()<1500 ? 1 : 0; // assumed warning threshold
    case ED_FM_ANTI_SKID_ENABLE: return 1;
    case ED_FM_OXYGEN_SUPPLY: return 101000; // Pa in bundled API; retained constant, not an OBOGS model
    case ED_FM_FLOW_VELOCITY: return 10; // retained wake/jet visualization placeholder
    case ED_FM_FC3_GEAR_HANDLE_POS: return model.input.gearDown ? 1 : 0;
    case ED_FM_FC3_FLAPS_HANDLE_POS: return model.input.manualFlaps ? 1 : 0;
    case ED_FM_FC3_SPEED_BRAKE_HANDLE_POS: return model.input.speedBrake ? 1 : 0;
    case ED_FM_FC3_STICK_PITCH: return model.input.pitch;
    case ED_FM_FC3_STICK_ROLL: return model.input.roll;
    case ED_FM_FC3_RUDDER_PEDALS: return -model.input.yaw;
    case ED_FM_FC3_THROTTLE_LEFT: return model.input.throttle[0];
    case ED_FM_FC3_THROTTLE_RIGHT: return model.input.throttle[1];
    case ED_FM_FC3_WHEEL_BRAKE_LEFT: case ED_FM_FC3_WHEEL_BRAKE_COMMAND_LEFT: return brake(true);
    case ED_FM_FC3_WHEEL_BRAKE_RIGHT: case ED_FM_FC3_WHEEL_BRAKE_COMMAND_RIGHT: return brake(false);
    case ED_FM_FC3_STICK_PITCH_LIMITER: case ED_FM_FC3_STICK_ROLL_L_LIMITER:
    case ED_FM_FC3_PEDAL_L_LIMITER: case ED_FM_FC3_PEDAL_R_LIMITER: return 1;
    case ED_FM_STICK_FORCE_FACTOR_PITCH: case ED_FM_STICK_FORCE_FACTOR_ROLL: return 1;
    case ED_FM_CAN_ACCEPT_FUEL_FROM_TANKER: return parameters.read("AAR")>.5&&
        (parameters.read("F22_ELECTRICAL_VALID")<.5||parameters.read("AAR_READY")>.5)&&
        model.fuel.internal<data::internalCapacity ? 1 : 0;
    case ED_FM_INTERRUPT_REFUEL: return model.fuel.internal>=data::internalCapacity ? 1 : 0;
    case ED_FM_FC3_AR_DOOR_PROBE_HANDLE_POS: return parameters.read("AAR");
    default: return 0;
    }
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_draw_args_v2(float* array,std::size_t size) {
    if(!array) return;
    auto set=[&](std::size_t i,double v) { if(i<size) array[i]=static_cast<float>(clamp(v,-1,1)); };
    for(std::size_t i:{0u,3u,5u}) set(i,model.config.gear);
    set(15,-degrees(model.surface[data::TailRight])/30); set(16,-degrees(model.surface[data::TailLeft])/30);
    set(17,degrees(model.surface[data::RudderLeft])/30); set(18,degrees(model.surface[data::RudderRight])/30);
    set(11,degrees(model.surface[data::AileronLeft])/25); set(12,degrees(model.surface[data::AileronRight])/25);
    set(9,degrees(model.surface[data::FlaperonLeft])/35); set(10,degrees(model.surface[data::FlaperonRight])/35);
    set(603,model.config.leadingEdge); set(622,-degrees(model.surface[data::NozzleLeft])/20);
    set(623,-degrees(model.surface[data::NozzleRight])/20);
    for(std::size_t i:{21u,182u,184u}) set(i,model.config.speedBrake);
    for(std::size_t i=0;i<2;++i) {
        const auto& e=model.engines[i];
        set(i==0 ? 29 : 28,e.combustion ? e.afterburner : 0);
        set(i==0 ? 90 : 89,clamp(1-smoothStep(.67,.9,e.fan)+e.afterburner,0,1));
        set(i==0 ? 325 : 324,e.fanPhase);
    }
    const double power=parameters.read("MAIN_POWER")>.5 &&
        (parameters.read("F22_ELECTRICAL_VALID")<.5||parameters.read("F22_EXTERNAL_LIGHTS_MASTER")>.5) ? 1 : 0;
    const double taxi=parameters.read("TAXI_SWITCH");
    set(604,power*(taxi<-.5 ? 1 : 0)); set(605,power*(taxi>.5 ? 1 : 0));
    set(606,power*parameters.read("FORM_KNOB"));
    const double nav=parameters.read("NAV_LIGHT_SWITCH");
    const double blink=std::fmod(elapsed,1)<.5 ? 1 : 0;
    set(607,power*(nav>=.3 ? (nav<.35 ? blink : 1) : 0));
    set(608,power*(nav>.1&&nav<.3 ? blink : 0));
    set(612,power*(nav>.1 ? 1 : 0)); set(613,power*(nav>.1 ? 1 : 0));
    set(609,power*parameters.read("AAR")*parameters.read("AAR_KNOB"));
    // Clamshell doors 610/611 remain owned by Engine_System.lua.
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_fc3_cockpit_draw_args_v2(float* array,std::size_t size) {
    if(!array) return;
    const std::array<std::pair<std::size_t,const char*>,5> args={{{709,"TAXI_SWITCH"},{712,"AAR"},
        {713,"AAR_KNOB"},{714,"FORM_KNOB"},{715,"NAV_LIGHT_SWITCH"}}};
    for(const auto& arg:args) if(arg.first<size) array[arg.first]=static_cast<float>(parameters.read(arg.second));
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_cold_start() { start(Start::Cold); }
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_hot_start() { start(Start::GroundHot); }
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_hot_start_in_air() { start(Start::AirHot); }
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_release() {
    parameters.write("F22_EFM_VALID",0);parameters.write("F22_FUEL_VALID",0);
    model=FlightModel{}; environment=Environment{}; groundVelocityBody={}; bodyStateReceived=false; parameters.clear();
    integrity.fill(1); contact.fill(false); contactReceived=false; groundStart=true;
    keyboard.fill(0); keyboardActive.fill(false); commonBrake=leftBrake=rightBrake=elapsed=0;
    surfaceHeight=0; immortal=false;
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_configure(const char*) {}
EXPORT_ED_FM_PHYSICS_IMP double ed_fm_get_shake_amplitude() { return model.buffet; }
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_on_damage(int element,double factor) {
    if(immortal||element<0||element>=static_cast<int>(integrity.size())||!std::isfinite(factor)) return;
    integrity[static_cast<std::size_t>(element)]=clamp(factor,0,1); updateHealth();
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_repair() { integrity.fill(1); updateHealth(); }
EXPORT_ED_FM_PHYSICS_IMP bool ed_fm_need_to_be_repaired() {
    return std::any_of(integrity.begin(),integrity.end(),[](double v){return v<1;});
}
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_immortal(bool value) { immortal=value; }
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_unlimited_fuel(bool value) { model.fuel.unlimited=value; }
EXPORT_ED_FM_PHYSICS_IMP void ed_fm_set_easy_flight(bool) {} // one control law; no separate assisted mode
EXPORT_ED_FM_PHYSICS_IMP bool ed_fm_pop_simulation_event(ed_fm_simulation_event&) { return false; }
EXPORT_ED_FM_PHYSICS_IMP bool ed_fm_push_simulation_event(const ed_fm_simulation_event&) { return false; }
EXPORT_ED_FM_PHYSICS_IMP bool ed_fm_LERX_vortex_update(unsigned idx,LERX_vortex& out) {
    if(idx>=2) return false;
    // Cosmetic approximation; density is not used as a humidity measurement.
    static std::array<std::array<LERX_vortex_spline_point,10>,2> splines{};
    const double alpha=std::abs(degrees(model.air.alpha));
    const double strength=.5*smoothStep(8,18,alpha)*(1-smoothStep(50,75,alpha))
        *(1-smoothStep(1.3,1.65,model.air.mach))*smoothStep(20,100,model.air.speed);
    out=LERX_vortex{}; out.version=1; out.opacity=static_cast<float>(strength);
    if(strength<=.01) return true;
    for(std::size_t i=0;i<10;++i) {
        auto& point=splines[idx][i]; const float t=static_cast<float>(i)/9.0f;
        point.pos[0]=6-8*t; point.pos[1]=.025f+.75f*t; point.pos[2]=idx==0 ? -1.2f : 1.2f;
        point.vel[0]=-static_cast<float>(model.air.speed)*(1-t); point.vel[1]=point.vel[2]=0;
        point.radius=.22f+.42f*std::sin(t*static_cast<float>(pi)); point.opacity=1-t;
    }
    out.explosion_start=9; out.spline=splines[idx].data(); out.spline_points_count=10;
    return true;
}
