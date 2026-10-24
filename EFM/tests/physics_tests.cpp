// SPDX-License-Identifier: GPL-3.0-or-later
#include "FlightModel/FlightModel.h"
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>
using namespace f22;
namespace {
int assertions=0;
void check(bool ok,const char* message) {
    ++assertions; if(!ok) throw std::runtime_error(message);
}
void near(double a,double b,double tolerance,const char* message) { check(std::abs(a-b)<=tolerance,message); }
Environment flight(double speed=150,double alpha=0) {
    Environment e; e.airVelocity={speed*std::cos(alpha),-speed*std::sin(alpha),0};
    e.altitude=3000; e.height=3000; return e;
}
void airAndForces() {
    Environment e=flight(100,radians(10)); const auto a=airData(e);
    near(a.alpha,radians(10),1e-12,"alpha sign/units");
    near(a.dynamicPressure,6125,1e-8,"dynamic pressure");
    near(dot(a.liftDirection,a.direction),0,1e-12,"lift perpendicular to flow");
    Health health; Configuration config;
    std::array<Engine,2> engines{}; std::array<double,data::Count> controls{};
    for(std::size_t i=0;i<controls.size();++i) controls[i]=radians(15);
    for(int alpha=-180;alpha<=180;++alpha) for(int beta=-90;beta<=90;beta+=5) {
        const double al=radians(alpha),be=radians(beta);
        e.airVelocity={180*std::cos(al)*std::cos(be),-180*std::sin(al)*std::cos(be),180*std::sin(be)};
        const auto air=airData(e);
        auto result=aerodynamicForces(e,air,config,health,0).wrench;
        result+=effectorForces(e,air,config,health,engines,controls);
        check(finite(result.force)&&finite(result.moment),"finite full-angle force/moment");
        check(dot(result.force,e.airVelocity)<=1e-5,"unpowered aerodynamic force cannot add translational energy");
    }
    e=flight(0); const auto zero=aerodynamicForces(e,airData(e),config,health,0);
    near(length(zero.wrench.force),0,0,"zero-speed aero force");
    for(double boundary:{65.0,90.0,100.0}) {
        e=flight(130,radians(boundary-1e-5)); auto before=aerodynamicForces(e,airData(e),config,health,0).wrench;
        e=flight(130,radians(boundary+1e-5)); auto after=aerodynamicForces(e,airData(e),config,health,0).wrench;
        check(length(after.force-before.force)<1,"no old 65/100-degree discontinuity");
    }
    for(double angle:{-20.0,-5.0,0.0,20.0}) {
        const auto thrust=vectorThrust(100000,radians(angle));
        near(length(thrust),100000,1e-8,"vectoring conserves thrust magnitude");
        near(thrust.y,100000*std::sin(radians(angle)),1e-8,"no extra throttle multiplier in vertical thrust");
    }
    Wrench w; w.add({100,20,0},{-5,0,1},{1,0,0});
    near(w.moment.y,100,1e-9,"right engine thrust gives left yaw");
    near(w.moment.z,-120,1e-9,"force lever arm follows current CG");
}
void fuel() {
    FuelSystem f; f.setInternal(100); f.setExternal(1,40,{-1,0,-3}); f.setExternal(2,60,{-1,0,3});
    near(f.total(),200,1e-12,"partial tanks retain host quantities");
    near(f.burn(125),125,1e-12,"fuel actually supplied");
    near(f.total(),75,1e-12,"fuel conserved");
    MassDelta d; double removed=0,inertiaZ=0;
    while(f.pop(d)) { removed+=d.kilograms; inertiaZ+=d.inertia.z; }
    near(removed,125,1e-12,"mass ledger exactly matches burn");
    near(inertiaZ,0,0,"point-piece intrinsic inertia leaves translation to host");
    near(f.burn(1000),50,1e-12,"reserve cannot be burned"); near(f.internal,25,1e-12,"unusable reserve");
    f.clearPending(); near(f.refuel(9000),8175,1e-12,"refueling accepts only capacity");
    check(f.pop(d),"refueling queues mass addition"); near(d.kilograms,-8175,1e-12,"refueling mass sign");
    check(!f.pop(d),"one refuel callback produces one mass addition");
    f.unlimited=true; near(f.burn(10),10,0,"unlimited fuel supplies request");
    near(f.internal,8200,0,"unlimited fuel preserves quantity"); check(!f.pop(d),"unlimited fuel has no mass removal");
    f.setExternal(1,0,{}); check(f.external.count(1)==0,"host removal clears installed tank");
}
void enginesAndStates() {
    auto e=flight(); auto a=airData(e); Engine engine; engine.reset(false);
    engine.advance(.01,1,false,true,1,e,a);
    near(engine.thrust,0,0,"healthy shut-down engine has no thrust"); check(!engine.combustion,"integrity is not combustion");
    for(int i=0;i<11000;++i) engine.advance(.004,1,true,true,1,e,a);
    check(engine.mode==EngineMode::Running,"engine completes approximate start");
    for(int i=0;i<6000;++i) engine.advance(.004,1,true,true,1,e,a);
    check(engine.afterburner>.99,"afterburner reaches command after spool");
    check(engine.thrust>data::dryThrust,"afterburner increases thrust");
    engine.advance(.004,1,true,false,1,e,a); near(engine.thrust,0,0,"fuel starvation cuts thrust");
    check(!engine.combustion,"fuel starvation removes combustion");
    engine.reset(true); engine.advance(.004,1,true,true,0,e,a);
    near(engine.thrust,0,0,"destroyed engine has no thrust");
    FlightModel fm; fm.fuel.setInternal(1000); fm.reset(Start::AirHot);
    fm.input.throttle={1,0};
    for(int i=0;i<1000;++i) fm.step(.004,e);
    check(fm.engines[0].thrust>fm.engines[1].thrust,"independent engine commands");
    fm.reset(Start::Cold); MassDelta d;
    check(!fm.fuel.pop(d),"reset clears pending mass events");
    check(fm.fuel.internal>25,"start/reset preserves host fuel");
    near(fm.engines[0].thrust,0,0,"cold reset clears thrust");
    near(fm.surface[data::NozzleLeft],0,0,"reset clears achieved nozzle");
}
void controls() {
    Configuration cruise;cruise.speedBrake=1;
    const auto cruiseBias=configurationBias(cruise,false);
    const auto refuelBias=configurationBias(cruise,true);
    check(cruiseBias[data::AileronLeft]<0&&cruiseBias[data::FlaperonLeft]>0,
        "cruise braking distributes wing deflections");
    near(refuelBias[data::AileronLeft],0,0,"refueling does not command wing braking");
    near(refuelBias[data::FlaperonLeft],0,0,"refueling does not command flap braking");
    check(refuelBias[data::RudderLeft]<0&&refuelBias[data::RudderRight]>0,
        "refueling retains opposed rudder braking");
    FlightModel approach;approach.fuel.unlimited=true;approach.reset(Start::GroundHot);
    auto approachEnvironment=flight(70);
    approach.step(1,approachEnvironment);
    near(degrees(configurationBias(approach.config,false)[data::FlaperonLeft]),35,1e-9,
        "normal low-speed approach flap bias is 35 degrees");
    approach.input.engineRun[1]=false;approach.step(1,approachEnvironment);
    near(degrees(configurationBias(approach.config,false)[data::FlaperonLeft]),20,1e-9,
        "single-engine low-speed approach flap bias is 20 degrees");
    auto e=flight(80,radians(25));
    FlightModel f; f.fuel.unlimited=true; f.reset(Start::AirHot); f.input.pitch=1; f.input.roll=.6;
    auto previous=f.surface;
    for(int i=0;i<500;++i) {
        f.step(.004,e);
        for(std::size_t j=0;j<data::Count;++j) {
            check(std::abs(f.surface[j]-previous[j])<=radians(data::rateDegrees[j])*.004+1e-10,"physical actuator rate limit");
            check(f.surface[j]>=radians(data::lowerDegrees[j])-1e-10 &&
                f.surface[j]<=radians(data::upperDegrees[j])+1e-10,"surface travel limit");
        }
        previous=f.surface;
    }
    check(std::abs(f.surface[data::NozzleLeft])>radians(.1),"TVC contributes at low-speed/high-alpha");
    e=flight(400,0); f.input.pitch=0; f.input.roll=0;
    for(int i=0;i<500;++i) f.step(.004,e);
    near(f.surface[data::NozzleLeft],0,1e-10,"nozzle can return to neutral across Mach/schedule boundary");
    FlightModel base,trim; base.fuel.unlimited=trim.fuel.unlimited=true;
    base.reset(Start::AirHot); trim.reset(Start::AirHot); trim.input.rollTrim=.5; trim.input.yawTrim=.5;
    e=flight(); for(int i=0;i<100;++i) {base.step(.004,e);trim.step(.004,e);}
    check(std::abs(trim.output.moment.x-base.output.moment.x)>100,"roll trim changes moment");
    check(std::abs(trim.output.moment.y-base.output.moment.y)>100,"yaw trim changes moment");
    trim.health.actuator[data::TailLeft]=0;
    const double jam=trim.surface[data::TailLeft]; trim.input.pitch=1; trim.step(.5,e);
    near(trim.surface[data::TailLeft],jam,0,"failed actuator holds achieved position");
    FlightModel hydraulic; hydraulic.fuel.unlimited=true; hydraulic.reset(Start::AirHot);
    hydraulic.health.hydraulic=0;hydraulic.health.actuator.fill(0);
    hydraulic.input.gearDown=true;hydraulic.input.speedBrake=true;hydraulic.input.pitch=1;
    hydraulic.step(1,e);
    near(hydraulic.config.gear,0,0,"lost hydraulic supply cannot move gear");
    near(hydraulic.config.speedBrake,0,0,"lost hydraulic supply cannot move speed-brake actuators");
    near(hydraulic.surface[data::TailLeft],0,0,"lost hydraulic supply holds flight-control actuator");
    FlightModel slow,fast; slow.fuel.unlimited=fast.fuel.unlimited=true;
    slow.reset(Start::AirHot);fast.reset(Start::AirHot);
    slow.input.pitch=fast.input.pitch=.2;
    Vec3 impulseSlow{},impulseFast{},angularSlow{},angularFast{};
    for(int i=0;i<1000;++i) { slow.step(.004,e); impulseSlow+=slow.output.force*.004; angularSlow+=slow.output.moment*.004; }
    for(int i=0;i<250;++i) { fast.step(.016,e); impulseFast+=fast.output.force*.016; angularFast+=fast.output.moment*.016; }
    near(length(impulseSlow-impulseFast),0,1e-5,"interval-averaged force preserves total impulse across host timesteps");
    near(length(angularSlow-angularFast),0,1e-5,"interval-averaged moment preserves angular impulse");
    near(slow.engines[0].fan,fast.engines[0].fan,1e-12,"engine state timestep consistency");

}
}
int main() {
    try { airAndForces();fuel();enginesAndStates();controls(); }
    catch(const std::exception& e) { std::cerr<<"FAIL: "<<e.what()<<'\n'; return EXIT_FAILURE; }
    std::cout<<"PASS: "<<assertions<<" physics assertions\n"; return EXIT_SUCCESS;
}
