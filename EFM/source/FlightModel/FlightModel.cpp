// SPDX-License-Identifier: GPL-3.0-or-later
#include "FlightModel.h"
#include <limits>

namespace f22 {
AirData airData(const Environment& e) {
    AirData a;
    a.speed=length(e.airVelocity);
    a.mach=a.speed/std::max(e.soundSpeed,1.0);
    a.eas=a.speed*std::sqrt(std::max(e.density,0.0)/1.225);
    a.dynamicPressure=.5*std::max(e.density,0.0)*a.speed*a.speed;
    a.direction=a.speed>1e-6 ? e.airVelocity/a.speed : Vec3{1,0,0};
    a.alpha=std::atan2(-a.direction.y,a.direction.x);
    a.beta=std::asin(clamp(a.direction.z,-1,1));
    a.liftDirection=unit(cross({0,0,1},a.direction));
    a.sideDirection=unit(cross(a.direction,a.liftDirection));
    return a;
}

void Engine::reset(bool hot) {
    *this=Engine{};
    mode=hot ? EngineMode::Running : EngineMode::Off;
    fan=hot ? .67 : 0;
    core=hot ? .70 : 0;
    combustion=hot;
    temperatureC=hot ? 450 : 15;
}
void Engine::advance(double dt,double lever,bool run,bool fuel,double health,
                     const Environment& e,const AirData& a) {
    lever=clamp(lever,0,1);
    const bool permitted=run&&fuel&&health>.25;
    if(!permitted && mode!=EngineMode::Off) mode=EngineMode::Shutdown;
    if(permitted && (mode==EngineMode::Off||mode==EngineMode::Shutdown)) {
        mode=EngineMode::Starting;
        startTime=44.0*clamp(core/.70,0,1); // retained approximate start duration
    }
    if(mode==EngineMode::Starting) {
        startTime+=dt;
        fan=approach(fan,.67,.67/44.0,dt);
        core=approach(core,.70,.70/44.0,dt);
        if(startTime>=44) { mode=EngineMode::Running; fan=.67; core=.70; }
    } else if(mode==EngineMode::Running) {
        const double dry=clamp(lever/data::militaryLever,0,1);
        fan=lag(fan,.67+.33*dry,1.6,dt);
        core=lag(core,.70+.30*dry,1.2,dt);
    } else {
        const double windmill=clamp(a.mach*.025,0,.10);
        fan=lag(fan,windmill,3.0,dt);
        core=lag(core,windmill,3.5,dt);
        if(!run&&core<.005) mode=EngineMode::Off;
    }
    combustion=permitted&&(mode==EngineMode::Running||
                          (mode==EngineMode::Starting&&startTime>=18));
    dryPower=clamp((fan-.67)/.33,0,1);
    const double abRequest=(mode==EngineMode::Running&&dryPower>.9&&combustion)
        ? clamp((lever-data::militaryLever)/(1-data::militaryLever),0,1) : 0;
    afterburner=lag(afterburner,abRequest,abRequest>afterburner ? .8 : .25,dt);
    // Pressure/temperature lapse and net-thrust Mach curves are assumed surrogates.
    const double lapse=std::pow(std::max(0.0,e.pressure/101325.0),.70)
        /std::sqrt(std::max(.35,e.temperature/288.15));
    const double inlet=1-.30*smoothStep(radians(35),radians(100),std::abs(a.alpha));
    const double maxDry=data::dryThrust*interpolate(data::mach,data::dryFactor,a.mach);
    const double maxWet=std::max(maxDry,data::wetThrust*interpolate(data::mach,data::wetFactor,a.mach));
    dryAvailable=maxDry*lapse*inlet*clamp(health,0,1);
    const double idle=6000*std::pow(clamp(fan/.67,0,1),2);
    thrust=combustion ? (idle+(maxDry-idle)*std::pow(dryPower,1.6)
        +(maxWet-maxDry)*afterburner)*lapse*inlet*clamp(health,0,1) : 0;
    const double sfc=2e-5+3e-5*afterburner; // kg/N/s: assumed, see ledger
    fuelFlow=combustion ? .10*lapse+thrust*sfc : 0;
    const double targetTemperature=combustion ? 450+350*dryPower+100*afterburner
                                             : e.temperature-273.15;
    temperatureC=lag(temperatureC,targetTemperature,4.0,dt);
    fanPhase=std::fmod(fanPhase+fan*data::fanMaxRpm/60*dt,1.0);
}

double FuelSystem::externalQuantity() const {
    double result=0;
    for(const auto& entry:external) result+=entry.second.quantity;
    return result;
}
double FuelSystem::usable() const {
    return unlimited ? std::numeric_limits<double>::infinity()
                     : externalQuantity()+std::max(0.0,internal-data::reserveFuel);
}
void FuelSystem::setInternal(double kg) { internal=clamp(kg,0,data::internalCapacity); }
void FuelSystem::setExternal(int station,double kg,Vec3 position) {
    if(kg<=0) external.erase(station);
    else external[station]={kg,position};
}
void FuelSystem::changed(double removed,Vec3 position) {
    // Point-tank approximation: intrinsic inertia of the removed piece is zero.
    // DCS receives its position and owns the CG/parallel-axis mass update.
    // Supplying m*r^2 here as well would risk counting that translation twice.
    pending_.push_back({removed,position,{}});
}
double FuelSystem::burn(double kg) {
    if(kg<=0) return 0;
    if(unlimited) return kg;
    double remaining=std::min(kg,usable());
    const double supplied=remaining;
    // Drain external tanks proportionally, avoiding an artificial lateral fuel imbalance.
    const double outside=externalQuantity();
    const double externalBurn=std::min(remaining,outside);
    for(auto& entry:external) {
        auto& tank=entry.second;
        const double amount=outside>0 ? externalBurn*tank.quantity/outside : 0;
        tank.quantity=std::max(0.0,tank.quantity-amount);
        if(amount>0) changed(amount,tank.position);
    }
    remaining-=externalBurn;
    if(remaining>0) { internal-=remaining; changed(remaining,{}); }
    return supplied;
}
double FuelSystem::refuel(double kg) {
    const double accepted=clamp(kg,0,data::internalCapacity-internal);
    internal+=accepted;
    if(accepted>0) changed(-accepted,{});
    return accepted;
}
bool FuelSystem::pop(MassDelta& delta) {
    if(pending_.empty()) return false;
    delta=pending_.front(); pending_.pop_front(); return true;
}

Aerodynamics aerodynamicForces(const Environment& e,const AirData& a,
                              const Configuration& c,const Health& h,double externalTankCount) {
    Aerodynamics result;
    const double alpha=a.alpha;
    const double attached=1-smoothStep(radians(15),radians(50),std::abs(alpha));
    const double slope=interpolate(data::mach,data::liftSlope,a.mach);
    const double clAttached=.04*std::cos(alpha)+slope*alpha;
    const double clSeparated=1.30*std::sin(2*alpha);
    result.liftCoefficient=(clAttached*attached+clSeparated*(1-attached))
        *std::pow(std::cos(a.beta),2)+.12*c.leadingEdge*std::sin(2*alpha);
    const double groundEffect=.55+.45*smoothStep(0,data::span*.5,std::max(0.0,e.height));
    const double cd0=interpolate(data::mach,data::parasiteDrag,a.mach);
    result.dragCoefficient=cd0+.12*groundEffect*result.liftCoefficient*result.liftCoefficient*attached
        +1.15*std::pow(std::sin(alpha),2)*(1-attached)+.55*std::pow(std::sin(a.beta),2)
        +.08*c.gear+.07*c.speedBrake;
    // An installed empty external tank remains drag-producing until host jettison/removal.
    if(externalTankCount>0) result.dragCoefficient+=.008*externalTankCount;
    const Vec3 halfForce=(a.liftDirection*result.liftCoefficient
        -a.direction*result.dragCoefficient)*(a.dynamicPressure*data::area*.5);
    result.wrench.add(halfForce*h.leftWing,{0,0,-data::span*.25},e.cg);
    result.wrench.add(halfForce*h.rightWing,{0,0,data::span*.25},e.cg);
    const double integrity=.5*(h.leftWing+h.rightWing);
    result.wrench.add(a.sideDirection*(-.65*std::sin(a.beta)*a.dynamicPressure*data::area*integrity),{},e.cg);
    const double velocity=std::max(a.speed,20.0);
    const double p=e.angularVelocity.x*data::span/(2*velocity);
    const double yaw=e.angularVelocity.y*data::span/(2*velocity);
    const double pitch=e.angularVelocity.z*data::chord/(2*velocity);
    const double staticPitch=.06-.18*smoothStep(.8,1.4,a.mach);
    const double cm=.012*std::cos(alpha)+staticPitch*std::sin(2*alpha)*.5
        -.04*std::sin(alpha)*smoothStep(radians(35),radians(70),std::abs(alpha))-6*clamp(pitch,-3,3);
    result.wrench.moment+=Vec3{(-.06*std::sin(a.beta)-.40*clamp(p,-3,3))*data::span,
        (-.10*std::sin(a.beta)-.30*clamp(yaw,-3,3))*data::span,
        cm*data::chord}*(a.dynamicPressure*data::area*integrity);
    return result;
}

Vec3 vectorThrust(double thrust,double angle) {
    return {thrust*std::cos(angle),thrust*std::sin(angle),0};
}
Wrench effectorForces(const Environment& e,const AirData& a,const Configuration&,
                     const Health& h,const std::array<Engine,2>& engines,
                     const std::array<double,data::Count>& angle) {
    Wrench w;
    const double tailEffect=.12+.88*std::pow(std::cos(a.alpha),2);
    const double wingEffect=.10+.90*std::pow(std::cos(a.alpha),2);
    double controlDrag=0;
    for(std::size_t i=0;i<8;++i) {
        double health=h.surface[i], effectiveness=wingEffect;
        if(i<2) effectiveness=tailEffect;
        else if(i>=6) effectiveness=.15+.85*std::pow(std::cos(a.alpha),2);
        const double magnitude=a.dynamicPressure*data::forceAreaSlope[i]
            *std::sin(angle[i])*effectiveness*health;
        w.add((i<6 ? a.liftDirection : a.sideDirection)*magnitude,data::position[i],e.cg);
        controlDrag+=.006*std::pow(std::sin(angle[i]),2)*health;
    }
    w.add(a.direction*(-a.dynamicPressure*data::area*controlDrag),{},e.cg);
    w.add(vectorThrust(engines[0].thrust,angle[data::NozzleLeft]),data::position[data::NozzleLeft],e.cg);
    w.add(vectorThrust(engines[1].thrust,angle[data::NozzleRight]),data::position[data::NozzleRight],e.cg);
    return w;
}

void FlightModel::reset(Start start) {
    const bool unlimited=fuel.unlimited;
    input=PilotInput{}; health=Health{}; config=Configuration{};
    config.gear=start==Start::AirHot ? 0 : 1;
    input.gearDown=start!=Start::AirHot;
    for(std::size_t i=0;i<2;++i) {
        engines[i].reset(start!=Start::Cold);
        input.engineRun[i]=start!=Start::Cold;
        input.throttle[i]=start==Start::AirHot ? .5 : 0;
    }
    surface.fill(0); output={}; air={}; allocationResidual={};
    normalLoad=filteredLoad_=1; normalBlend_=0; commandInitialized_=false; buffet=0;
    fuel.clearPending(); fuel.unlimited=unlimited;
}
Vec3 FlightModel::commandMoments(const Environment& e,double dt) {
    filteredLoad_=lag(filteredLoad_,normalLoad,.08,dt);
    const double stick=clamp(input.pitch,-1,1);
    const double demand=clamp(1+(stick>=0 ? 8 : 4)*stick+2*input.pitchTrim,-3,9);
    double normalBlend=smoothStep(225,275,air.eas*1.943844);
    normalBlend*=1-smoothStep(radians(35),radians(60),std::abs(air.alpha));
    if(input.gearDown||input.refueling||e.weightOnWheels) normalBlend=0;
    // Bumpless approach/refueling/cruise transition; time constant is an assumption.
    if(!commandInitialized_) { normalBlend_=normalBlend; commandInitialized_=true; }
    normalBlend_=lag(normalBlend_,normalBlend,.5,dt);
    const double gravityNormal=std::cos(e.pitch)*std::cos(e.roll);
    const double gRate=(demand-gravityNormal+1.5*(demand-filteredLoad_))*gravity/std::max(air.speed,40.0);
    const double directRate=radians(25)*(stick+.25*input.pitchTrim);
    const double desiredPitch=clamp(normalBlend_*gRate+(1-normalBlend_)*directRate,-radians(45),radians(60));
    constexpr std::array<double,5> alpha={0,15,30,60,90};
    constexpr std::array<double,5> rollRates={200,160,90,30,10};
    const double rollLimit=radians(interpolate(alpha,rollRates,std::abs(degrees(air.alpha))))
        *(1-.35*smoothStep(.9,2.0,air.mach));
    const double stabilityRoll=clamp(input.roll+.3*input.rollTrim,-1,1)*rollLimit;
    const double desiredRoll=stabilityRoll*std::cos(air.alpha);
    const double coordination=-gravity*std::sin(e.roll)/std::max(air.speed,40.0);
    const double desiredYaw=-stabilityRoll*std::sin(air.alpha)+coordination
        +radians(15)*clamp(input.yaw+.5*input.yawTrim,-1,1)-air.beta;
    const Vec3 acceleration{(desiredRoll-e.angularVelocity.x)/.25,
        (desiredYaw-e.angularVelocity.y)/.40,(desiredPitch-e.angularVelocity.z)/.30};
    const Vec3 momentum{e.inertia.x*e.angularVelocity.x,e.inertia.y*e.angularVelocity.y,
                        e.inertia.z*e.angularVelocity.z};
    return Vec3{e.inertia.x*acceleration.x,e.inertia.y*acceleration.y,e.inertia.z*acceleration.z}
        +cross(e.angularVelocity,momentum);
}

std::array<double,data::Count> FlightModel::allocate(const Environment& e,Vec3 requested) {
    using namespace data;
    std::array<double,Count> common{};
    // R22: cruise distributed wing/rudder braking; approach uses rudders only.
    const double wingBrake=config.speedBrake*(1-config.gear);
    common[AileronLeft]=common[AileronRight]=-radians(15)*wingBrake;
    common[FlaperonLeft]=common[FlaperonRight]=radians(20)*config.flaps+radians(10)*wingBrake;
    common[RudderLeft]=-radians(20)*config.speedBrake;
    common[RudderRight]=radians(20)*config.speedBrake;
    for(std::size_t i=0;i<Count;++i) if(health.actuator[i]<=0) common[i]=surface[i];
    const Wrench base=effectorForces(e,air,config,health,engines,common);
    const Wrench aero=aerodynamicForces(e,air,config,health,static_cast<double>(fuel.external.size())).wrench;
    const Vec3 residual=requested-(base.moment+aero.moment);
    // Nine virtual controls: eight surfaces and a common pitch-vector command.
    // Each physical nozzle still has independent achieved position/rate/health.
    constexpr std::size_t n=9;
    std::array<Vec3,n> b{};
    std::array<double,n> lo{},hi{},x{};
    const double tvAvailability=std::max(1-smoothStep(170,250,air.eas*1.943844),
        smoothStep(radians(10),radians(25),std::abs(air.alpha)));
    const Vec3 weights{1.2/std::max(1.0,e.inertia.x),1.0/std::max(1.0,e.inertia.y),2.0/std::max(1.0,e.inertia.z)};
    auto weighted=[&](Vec3 v) { return Vec3{v.x*weights.x,v.y*weights.y,v.z*weights.z}; };
    for(std::size_t j=0;j<n;++j) {
        auto plus=common,minus=common;
        if(j<8) { plus[j]+=.001; minus[j]-=.001;
            lo[j]=radians(lowerDegrees[j])-common[j]; hi[j]=radians(upperDegrees[j])-common[j];
            if(health.actuator[j]<=0) lo[j]=hi[j]=0;
        } else {
            for(std::size_t i=NozzleLeft;i<=NozzleRight;++i) {
                if(health.actuator[i]>0) { plus[i]+=.001; minus[i]-=.001; }
            }
            lo[j]=-nozzleLimit*tvAvailability; hi[j]=nozzleLimit*tvAvailability;
        }
        b[j]=weighted((effectorForces(e,air,config,health,engines,plus).moment-
                       effectorForces(e,air,config,health,engines,minus).moment)/.002);
    }
    Vec3 error=weighted(residual)*-1;
    for(int sweep=0;sweep<40;++sweep) for(std::size_t j=0;j<n;++j) {
        const double cost=j==8 ? 1+7*(1-tvAvailability) : 1;
        const double regularization=.002*cost*cost;
        const double next=clamp(x[j]-(dot(b[j],error)+regularization*x[j])/
            (dot(b[j],b[j])+regularization),lo[j],hi[j]);
        error+=b[j]*(next-x[j]); x[j]=next;
    }
    auto target=common;
    for(std::size_t i=0;i<8;++i) target[i]+=x[i];
    for(std::size_t i=NozzleLeft;i<=NozzleRight;++i)
        if(health.actuator[i]>0) target[i]=x[8];
    return target;
}
void FlightModel::substep(double dt,const Environment& e) {
    air=airData(e);
    config.gear=approach(config.gear,input.gearDown ? 1 : 0,.25*health.hydraulic,dt);
    config.speedBrake=approach(config.speedBrake,input.speedBrake ? 1 : 0,.7*health.hydraulic,dt);
    const double leadingTarget=clamp((degrees(air.alpha)-5)/25,0,1)*(1-smoothStep(.8,1.2,air.mach));
    config.leadingEdge=approach(config.leadingEdge,leadingTarget,30.0/35.0*health.hydraulic,dt);
    const double flapTarget=(input.manualFlaps||input.gearDown) ? 1-smoothStep(220,300,air.eas*1.943844) : 0;
    config.flaps=approach(config.flaps,flapTarget,2*health.hydraulic,dt);
    for(std::size_t i=0;i<2;++i)
        engines[i].advance(dt,input.throttle[i],input.engineRun[i],fuel.usable()>0,health.engine[i],e,air);
    const double requestedFuel=(engines[0].fuelFlow+engines[1].fuelFlow)*dt;
    const double supplied=fuel.burn(requestedFuel);
    const double fraction=requestedFuel>0 ? supplied/requestedFuel : 1;
    for(auto& engine:engines) {
        engine.thrust*=fraction; engine.fuelFlow*=fraction;
        if(fraction==0) engine.combustion=false;
    }
    const Vec3 commanded=commandMoments(e,dt);
    const auto target=allocate(e,commanded);
    for(std::size_t i=0;i<data::Count;++i) if(health.actuator[i]>0) {
        // Rate never goes to zero at a mode/Mach boundary: neutral remains reachable.
        surface[i]=approach(surface[i],clamp(target[i],radians(data::lowerDegrees[i]),
            radians(data::upperDegrees[i])),radians(data::rateDegrees[i])*health.actuator[i],dt);
    }
    output=aerodynamicForces(e,air,config,health,static_cast<double>(fuel.external.size())).wrench;
    output+=effectorForces(e,air,config,health,engines,surface);
    allocationResidual=commanded-output.moment;
    normalLoad=output.force.y/(std::max(e.mass,1.0)*gravity);
    buffet=clamp(.25*smoothStep(radians(15),radians(35),std::abs(air.alpha))
        +.12*(smoothStep(.90,.98,air.mach)-smoothStep(1.02,1.12,air.mach)),0,1);
}
void FlightModel::step(double dt,const Environment& environment) {
    if(!std::isfinite(dt)||dt<=0) return;
    if(!finite(environment.airVelocity)||!finite(environment.angularVelocity)) { output={}; return; }
    // Integrate internal states on <=4 ms steps; return interval-average wrench to DCS.
    // Host aircraft motion is never advanced here (DCS owns rigid-body integration).
    const int steps=std::max(1,static_cast<int>(std::ceil(dt/.004)));
    const double stepTime=dt/steps;
    Wrench sum;
    for(int i=0;i<steps;++i) { substep(stepTime,environment); sum+=output; }
    output.force=sum.force/static_cast<double>(steps);
    output.moment=sum.moment/static_cast<double>(steps);
}
} // namespace f22
