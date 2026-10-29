// Actual warning owner, with native-admitted optical measurements as the port.
#include "../../EFM/source/NativeMWS.cpp"
#include <iostream>

namespace {
NativeMWS::Polar bearing(double north, double up, double east) {
    return {std::atan2(east,north),std::atan2(up,std::hypot(north,east)),
        std::hypot(north,up,east)};
}
bool approaching(double north, double up, double east, double vn, double vu, double ve) {
    NativeMWS::ApproachFilter filter;
    if (filter.observe(17,100,bearing(north,up,east))) return false;
    return filter.observe(17,100.15,bearing(north+vn*.15,up+vu*.15,east+ve*.15));
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
    NativeMWS::ApproachFilter filter;
    filter.observe(17,100,bearing(10000,0,0));
    filter.observe(17,100.15,bearing(9850,0,0));
    filter.expire(102);
    if (filter.observe(17,102,bearing(10000,0,0))) return 6;
    if (filter.observe(17,90,bearing(10000,0,0))) return 7;
    if (filter.observe(17,90.15,{0,0,-1})) return 8;
    if (filter.diagnostic(17).decision != NativeMWS::ApproachFilter::Decision::None) return 9;
    if (filter.observe(17,90.3,bearing(9000,0,0))) return 10;
    std::cout<<"MAWS approach owner: direct/lofted approach, outgoing, stationary, horizon and reset pass\n";
}
