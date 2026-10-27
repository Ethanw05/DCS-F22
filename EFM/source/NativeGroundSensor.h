// GPL-3.0-or-later. Bounded DCS scene observations in the native sensor phase.
#pragma once
class EDPARAM;
namespace NativeGroundSensor {
void update(EDPARAM &);
struct ArrayService { bool granted{};double azimuth{}, resource{};bool active{}; };
void sample(void *owned_radar, const ArrayService* service = nullptr);
void reset();
}
