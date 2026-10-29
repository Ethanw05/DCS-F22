// Actual warning owner, with native-admitted optical measurements as the port.
#include "../../EFM/source/NativeMWS.cpp"
#include "weapon_parameter_port.h"
#include <iostream>

namespace {
NativeMWS::Polar bearing(double north, double up, double east) {
    return {std::atan2(east,north),std::atan2(up,std::hypot(north,east)),
        std::hypot(north,up,east)};
}
bool approaching(double north, double up, double east, double vn, double vu, double ve) {
    static NativeMWS::ApproachFilter filter;
    filter.reset();
    if (filter.observe(17,100,bearing(north,up,east))) return false;
    return filter.observe(17,100.15,bearing(north+vn*.15,up+vu*.15,east+ve*.15));
}
bool temporary_opening() {
    static MawsThreat::Core f;
    f.reset();
    f.observe(17,100,bearing(10000,0,0));
    if (!f.observe(17,100.15,bearing(9850,0,0))) return false;
    if (!f.observe(17,100.3,bearing(9900,0,0))) return false;
    if (f.diagnostic(17).decision != MawsThreat::Decision::ManeuverHold) return false;
    // Receipt/continued opening cannot renew the original approach evidence.
    for (unsigned i=1;i<=35;++i)
        f.observe(17,100.3+i*.15,bearing(9900+i*50,0,0));
    const auto t=f.diagnostic(17);
    return !t.threat && t.decision==MawsThreat::Decision::Uncertain && t.evidence_time==100.15;
}
bool passed_and_turnback() {
    static MawsThreat::Core f;
    f.reset();
    f.observe(17,100,bearing(1000,0,0));
    f.observe(17,100.15,bearing(850,0,0));
    if (!f.observe(17,100.3,bearing(-200,0,0))) return false;
    f.observe(17,100.45,bearing(-500,0,0));
    f.observe(17,100.6,bearing(-800,0,0));
    if (!f.observe(17,100.75,bearing(-1100,0,0))) return false;
    if (f.observe(17,100.95,bearing(-1500,0,0))) return false;
    if (f.diagnostic(17).decision!=MawsThreat::Decision::Passed) return false;
    if (f.observe(17,101.1,bearing(-1650,0,0))) return false;
    return f.observe(17,101.25,bearing(-1500,0,0));
}
bool sustained_divergence() {
    static MawsThreat::Core f;
    f.reset();
    f.observe(17,100,bearing(10000,0,0));
    f.observe(17,100.15,bearing(9850,0,0));
    for (unsigned i=1;i<=16;++i)
        f.observe(17,100.15+i*.15,{i*.06,0,9850+i*100.});
    return !f.diagnostic(17).threat && f.diagnostic(17).decision==MawsThreat::Decision::Diverging;
}
bool outgoing_and_identity() {
    static MawsThreat::Core f;
    f.reset();
    f.observe(17,100,bearing(1000,0,0),1);
    if (f.observe(17,100.15,bearing(1150,0,0),1)) return false;
    if (!f.observe(17,100.3,bearing(1000,0,0),1)) return false;
    f.observe(17,100.3,bearing(10,0,0),1); // Repeated stamp is not a new measurement.
    if (f.diagnostic(17).evidence_time!=100.3) return false;
    if (f.observe(17,100.45,bearing(850,0,0),2)) return false;
    if (f.diagnostic(17).decision!=MawsThreat::Decision::Measuring) return false;
    f.reset();
    for (unsigned id=1;id<=MawsThreat::capacity;++id) f.observe(id,100,bearing(1000,0,0));
    f.observe(10000,100,bearing(1000,0,0));
    if (!f.overflow || f.diagnostic(1).id!=1 || f.diagnostic(10000).id) return false;
    f.expire(102);
    return !f.overflow && !f.diagnostic(1).id;
}
bool publication_commit() {
    EDPARAM p;
    WeaponParameterPort::bind(p);
    NativeMWS::begin_publication(p);
    const auto pending=WeaponParameterPort::cells["F22_MWS_NATIVE_SEQUENCE"].value;
    if (static_cast<unsigned>(pending)%2!=1) return false;
    NativeMWS::finish_publication(p,true);
    if (WeaponParameterPort::cells["F22_MWS_NATIVE_SEQUENCE"].value!=pending+1) return false;
    if (WeaponParameterPort::cells["F22_MWS_NATIVE_READY"].value!=1) return false;
    NativeMWS::begin_publication(p);
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=nullptr;
    NativeMWS::put(p,"F22_MWS_NATIVE_TIME",100);
    NativeMWS::finish_publication(p,true);
    return static_cast<unsigned>(WeaponParameterPort::cells["F22_MWS_NATIVE_SEQUENCE"].value)%2==1;
}
}
int main() {
    if (!approaching(10000,0,0,-1000,0,0)) return 1;
    // A native-confirmed closing missile may still be climbing/turning.
    // Its current straight-line extrapolation need not intersect our aircraft.
    if (!approaching(20000,3000,0,-700,200,0)) {
        std::cerr<<"Confirmed approaching lofting missile suppressed by impact prediction\n";
        return 2;
    }
    if (approaching(1000,0,0,1000,0,0)) return 3; // Our outgoing missile.
    if (approaching(10000,0,0,0,0,0)) return 4;
    if (approaching(100000,0,0,-1000,0,0)) return 5; // Existing60s horizon.
    static NativeMWS::ApproachFilter filter;
    filter.observe(17,100,bearing(10000,0,0));
    filter.observe(17,100.15,bearing(9850,0,0));
    filter.expire(102);
    if (filter.observe(17,102,bearing(10000,0,0))) return 6;
    if (filter.observe(17,90,bearing(10000,0,0))) return 7;
    if (filter.observe(17,90.15,{0,0,-1})) return 8;
    if (filter.diagnostic(17).decision != NativeMWS::ApproachFilter::Decision::None) return 9;
    if (filter.observe(17,90.3,bearing(9000,0,0))) return 10;
    if (!temporary_opening()) return 11;
    if (!passed_and_turnback()) return 12;
    if (!sustained_divergence()) return 13;
    if (!outgoing_and_identity()) return 14;
    if (!publication_commit()) return 15;
    std::cout<<"MAWS owner: approach, maneuver hold/expiry, pass/divergence/turnback, identity/reset/capacity and publication pass\n";
}
