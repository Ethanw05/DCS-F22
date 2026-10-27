#include "../EFM/source/VehicleSystems.h"
#include <cassert>
#include <limits>
#include <iostream>
using namespace RaptorVehicle;
int main() {
    // A nozzle at +15 degrees must recenter after entering a zero-envelope,
    // zero-scheduled-rate region, without teleporting or violating 40 deg/s.
    double a = radians(15);
    for (int i=0;i<100;++i) {
        double next=nozzle(a,1,0,0,1,.01);
        assert(std::abs(next-a)<=radians(40)*.01+1e-12); a=next;
    }
    assert(a==0);
    assert(nozzle(.1,0,0,0,0,1)==.1); // failed hydraulic holds physical state
    assert(nozzle(0,1,radians(20),radians(80),1,.1)==radians(4));
    assert(nozzle(.1,1,0,0,1,-1)==.1);

    Hydraulics h; h.reset(true);
    for(int i=0;i<1000;++i)h.update(.67,.67,1,1,true,false,0,0,.01);
    assert(h.left_psi==0 && h.right_psi==hydraulic_nominal_psi && h.shared()==1);
    for(int i=0;i<4000;++i)h.update(0,0,1,1,true,true,1,15,.01);
    assert(h.shared()==0 && h.brakes()==0);
    h.reset(false);
    for(int i=0;i<1000;++i)h.update(.67,0,1,1,false,false,0,0,.01);
    assert(h.left_psi==hydraulic_nominal_psi && h.right_psi==0 && h.shared()==1);
    assert(slew(.1,1,10*0,.1)==.1); // lost supply freezes an achieved effector

    Engine e; e.reset(0,288.15);
    assert(e.raw_core_rpm()==0 && e.raw_fan_rpm()==0 && std::abs(e.temperature_c-15)<1e-12);
    for(int i=0;i<2000;++i)e.update(.67,true,0,288.15,.01);
    assert(std::abs(e.core-.67)<1e-8 && std::abs(e.fan-.55)<1e-8);
    assert(e.raw_core_rpm()>10000 && e.raw_fan_rpm()>6000);
    assert(e.temperature_c>440 && e.temperature_c<460 && e.oil_psi>180);
    const double hot=e.temperature_c;
    e.update(0,false,0,288.15,.1); assert(e.temperature_c<hot && e.temperature_c>15);
    for(int i=0;i<30000;++i)e.update(0,false,0,288.15,.01);
    assert(e.core<1e-9 && e.fan<1e-9 && std::abs(e.temperature_c-15)<.001 && e.oil_psi<1e-9);
    Engine e2; e2.reset(0,288.15);
    for(int i=0;i<100;++i)e2.update(.67,true,0,288.15,.1);
    Engine e3; e3.reset(0,288.15);
    for(int i=0;i<1000;++i)e3.update(.67,true,0,288.15,.01);
    assert(std::abs(e2.temperature_c-e3.temperature_c)<1e-8); // frame-rate independent
    assert(std::abs(e2.core-e3.core)<1e-8);
    assert(normalized_brake(-1)==0 && normalized_brake(0)==.5 && normalized_brake(1)==1);
    assert(normalized_brake(std::numeric_limits<double>::quiet_NaN())==0);
    assert(installed_thrust(100,200,0)==100 && installed_thrust(100,200,100)==200);
    assert(installed_thrust(100,200,50)==150);
    assert(relative_thrust(50,100)==.5 && relative_thrust(50,0)==0);
    assert(external_tank_capacity_kg>1850 && external_tank_capacity_kg<1900);
    std::cout << "vehicle: nozzle, hydraulics, brake reserve, spool/RPM, thermal/oil, thrust continuity OK\n";
}
