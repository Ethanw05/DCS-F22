// SPDX-License-Identifier: GPL-3.0-or-later
// Small independent rigid-body harness, not a substitute for DCS flight testing.
#include "FlightModel/FlightModel.h"
#include <iostream>
#include <stdexcept>
using namespace f22;
namespace {
int assertions=0;
void check(bool ok,const char* message) { ++assertions; if(!ok) throw std::runtime_error(message); }
struct Quaternion {
    double w=1; Vec3 v{};
    Vec3 rotate(Vec3 a) const { return a+cross(v,a)*(2*w)+cross(v,cross(v,a))*2; }
    Vec3 inverse(Vec3 a) const { return a-cross(v,a)*(2*w)+cross(v,cross(v,a))*2; }
    void advance(Vec3 omega,double dt) {
        const double nw=w-dot(v,omega)*(.5*dt);
        v+=(omega*w+cross(v,omega))*(.5*dt); w=nw;
        const double norm=std::sqrt(w*w+dot(v,v)); w/=norm; v=v/norm;
    }
};
struct Aircraft {
    FlightModel fm; Environment e; Quaternion orientation;
    Aircraft(double speed,double mass=28000) {
        e.mass=mass; e.altitude=e.height=3000;
        const double alpha=std::min(radians(20),mass*gravity/(.5*e.density*speed*speed*data::area*3.6));
        orientation.w=std::cos(alpha*.5); orientation.v.z=std::sin(alpha*.5);
        e.airVelocity={speed*std::cos(alpha),-speed*std::sin(alpha),0};
        fm.fuel.unlimited=true; fm.reset(Start::AirHot); fm.input.throttle={.45,.45};
    }
    void step(double dt) {
        e.pitch=std::asin(clamp(orientation.rotate({1,0,0}).y,-1,1));
        e.roll=std::atan2(-orientation.rotate({0,0,1}).y,orientation.rotate({0,1,0}).y);
        fm.step(dt,e);
        const auto acceleration=fm.output.force/e.mass+orientation.inverse({0,-gravity,0})
            -cross(e.angularVelocity,e.airVelocity);
        const Vec3 angularMomentum{e.inertia.x*e.angularVelocity.x,e.inertia.y*e.angularVelocity.y,e.inertia.z*e.angularVelocity.z};
        const auto moment=fm.output.moment-cross(e.angularVelocity,angularMomentum);
        e.airVelocity+=acceleration*dt;
        e.angularVelocity+=Vec3{moment.x/e.inertia.x,moment.y/e.inertia.y,moment.z/e.inertia.z}*dt;
        orientation.advance(e.angularVelocity,dt);
        check(finite(e.airVelocity)&&finite(e.angularVelocity),"finite closed-loop motion");
    }
};
void longitudinal() {
    for(double speed:{100.,150.,250.,400.}) for(double mass:{22000.,28000.,34000.}) {
        Aircraft aircraft(speed,mass); double peakRate=0;
        for(int i=0;i<7500;++i) {
            aircraft.fm.input.pitch=i>=2500&&i<3000 ? .2 : 0;
            aircraft.step(.004); peakRate=std::max(peakRate,std::abs(degrees(aircraft.e.angularVelocity.z)));
        }
        check(std::abs(degrees(aircraft.e.angularVelocity.z))<1,"pitch settles after pulse");
        check(std::abs(degrees(airData(aircraft.e).alpha))<30,"no uncommanded departure in tested longitudinal cases");
        check(peakRate<30,"bounded pitch pulse response in selected cases");
        std::cout<<"longitudinal initial V="<<speed<<" m/s mass="<<mass<<" kg; final V="
            <<length(aircraft.e.airVelocity)<<" alpha="<<degrees(airData(aircraft.e).alpha)
            <<" q="<<degrees(aircraft.e.angularVelocity.z)<<" deg/s; g="<<aircraft.fm.normalLoad<<'\n';
    }
}
void lateral() {
    Aircraft aircraft(180);
    for(int i=0;i<1000;++i) aircraft.step(.004);
    aircraft.fm.input.roll=.3;
    for(int i=0;i<125;++i) aircraft.step(.004);
    check(aircraft.e.angularVelocity.x>radians(10),"positive roll command rolls right");
    aircraft.fm.input.roll=0;
    for(int i=0;i<1500;++i) aircraft.step(.004);
    check(std::abs(degrees(aircraft.e.angularVelocity.x))<2,"roll rate settles after release");
    check(std::abs(degrees(airData(aircraft.e).beta))<5,"coordination contains sideslip in selected roll case");
    Aircraft yaw(180); yaw.fm.input.yaw=.3;
    for(int i=0;i<125;++i) yaw.step(.004);
    check(yaw.e.angularVelocity.y>0,"positive internal yaw command rotates left");
}
}
int main() {
    try {longitudinal();lateral();} catch(const std::exception& e) {std::cerr<<"FAIL: "<<e.what()<<'\n';return 1;}
    std::cout<<"PASS: "<<assertions<<" scenario assertions\n";
}
