// GPL-3.0-or-later. Bounded DCS scene observations in the native sensor phase.
#pragma once
#include "AesaRadar.h"
class EDPARAM;
namespace NativeGroundSensor {
void update(EDPARAM &);
struct ArrayService {
    bool granted{};
    double azimuth{}, resource{};
    bool active{};
    AesaRadar::Beam beam{};
};
AesaRadar::SurfaceRequest pointing(double now,const AesaRadar::Pose&) noexcept;
void sample(void *owned_radar, const ArrayService& service);
void reset();
}
