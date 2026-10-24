// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "AirframeData.h"
#include <deque>
#include <map>

namespace f22 {
// SI throughout. DCS right-handed body axes: X forward, Y up, Z right.
// Angular components: X right roll, Y left yaw, Z nose-up pitch.
struct Environment {
    Vec3 airVelocity, angularVelocity, cg;
    Vec3 inertia{30000,180000,170000}; // fallback only, replaced by host mass callback
    double mass=28000, density=1.225, pressure=101325, temperature=288.15;
    double soundSpeed=340.294, altitude=0, height=0, groundSpeed=0, pitch=0, roll=0;
    bool weightOnWheels=false;
};
struct AirData {
    double speed=0, mach=0, eas=0, alpha=0, beta=0, dynamicPressure=0;
    Vec3 direction, liftDirection, sideDirection;
};
AirData airData(const Environment& e);
struct PilotInput {
    double pitch=0, roll=0, yaw=0, pitchTrim=0, rollTrim=0, yawTrim=0;
    std::array<double,2> throttle{};
    std::array<bool,2> engineRun{};
    bool gearDown=true, speedBrake=false, refueling=false, manualFlaps=false;
};
enum class Start { Cold, GroundHot, AirHot };
enum class EngineMode { Off, Starting, Running, Shutdown };
struct Engine {
    EngineMode mode=EngineMode::Off;
    double fan=0, core=0, dryPower=0, afterburner=0, temperatureC=15;
    double thrust=0, dryAvailable=0, fuelFlow=0, fanPhase=0, startTime=0;
    bool combustion=false;
    void reset(bool hot);
    void advance(double dt, double lever, bool run, bool fuel, double health,
                 const Environment& environment, const AirData& air);
};
struct MassDelta { double kilograms=0; Vec3 position, inertia; };
struct Tank { double quantity=0; Vec3 position; };
class FuelSystem {
public:
    double internal=0;
    std::map<int,Tank> external;
    bool unlimited=false;
    double externalQuantity() const;
    double total() const { return internal+externalQuantity(); }
    double usable() const;
    void setInternal(double kg);
    void setExternal(int station,double kg,Vec3 position);
    double burn(double kg);
    double refuel(double kg);
    bool pop(MassDelta& delta);
    void clearPending() { pending_.clear(); }
private:
    std::deque<MassDelta> pending_;
    void changed(double removed,Vec3 position);
};
struct Health {
    double leftWing=1, rightWing=1, tail=1, hydraulic=1;
    std::array<double,2> engine{1,1};
    std::array<double,data::Count> actuator{1,1,1,1,1,1,1,1,1,1};
    std::array<double,data::Count> surface{1,1,1,1,1,1,1,1,1,1};
};
struct Configuration { double gear=0, speedBrake=0, leadingEdge=0, flaps=0; };
// Neutral surface schedule before moment allocation. R22 historical configuration;
// the allocator may depart from these biases to satisfy aircraft control demand.
std::array<double,data::Count> configurationBias(const Configuration&,bool refueling);
struct Aerodynamics { Wrench wrench; double liftCoefficient=0, dragCoefficient=0; };
Aerodynamics aerodynamicForces(const Environment&,const AirData&,const Configuration&,
                              const Health&,double externalTankCount);
Vec3 vectorThrust(double thrust,double angle);
Wrench effectorForces(const Environment&,const AirData&,const Configuration&,const Health&,
                     const std::array<Engine,2>&,const std::array<double,data::Count>&);

class FlightModel {
public:
    PilotInput input;
    FuelSystem fuel;
    Health health;
    Configuration config;
    AirData air;
    std::array<Engine,2> engines;
    std::array<double,data::Count> surface{}; // achieved radians, also animation source
    Wrench output;
    Vec3 allocationResidual;
    double normalLoad=1, buffet=0;
    void reset(Start start);
    void step(double dt,const Environment& environment);
private:
    double filteredLoad_=1, normalBlend_=0;
    bool commandInitialized_=false;
    void substep(double dt,const Environment& environment);
    Vec3 commandMoments(const Environment&,double dt);
    std::array<double,data::Count> allocate(const Environment&,Vec3 requested);
};
} // namespace f22
