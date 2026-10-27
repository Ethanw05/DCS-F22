// GPL-3.0-or-later. Surface provider and shared scene-renderer coordination.
#include "NativeGroundRadar.h"
#include "NativeGroundSensor.h"
#include "NativeGroundVideo.h"
#include <Cockpit/CockpitAPI_Declare.h>
namespace NativeGroundRadar {
void reset() {
    NativeGroundSensor::reset();
    NativeGroundVideo::reset();
}
void update(EDPARAM& p) {
    NativeGroundVideo::update(p);
    NativeGroundSensor::update(p);
    const bool ready = p.getParamNumber(p.getParamHandle("F22_AESA_DRIVER_READY")) == 1;
    p.setParamNumber(p.getParamHandle("F22_AG_RADAR_NATIVE_READY"), ready ? 1 : 0);
    p.setParamNumber(p.getParamHandle("F22_AG_RADAR_NATIVE_REASON"), ready ? 0 : 4);
    // Terrain imagery is supplied by the renderer; no old radar noise cache.
    p.setParamNumber(p.getParamHandle("F22_AG_RETURN_COUNT"), 0);
}
}
