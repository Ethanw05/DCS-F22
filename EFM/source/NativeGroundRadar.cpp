// GPL-3.0-or-later. Surface provider and shared scene-renderer coordination.
#include "NativeGroundRadar.h"
#include "NativeGroundSensor.h"
#include "NativeGroundVideo.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <cmath>
namespace NativeGroundRadar {
namespace {
bool read(EDPARAM& p,const char* name,double& value) {
    return p.getParamNumber(p.getParamHandle(name),value);
}
bool committed(double sequence) {
    return sequence >= 2 && sequence <= 16777214 && std::fmod(sequence,2) == 0;
}
bool header(EDPARAM& p,double& sequence,double& epoch) {
    double schema{};
    return read(p,"F22_AG_NATIVE_SEQUENCE",sequence) && committed(sequence)
        && read(p,"F22_AG_NATIVE_SCHEMA",schema) && schema == 1
        && read(p,"F22_AG_NATIVE_SOURCE_EPOCH",epoch) && epoch >= 1
        && epoch <= 16777215 && epoch == std::floor(epoch);
}
bool sensor_state(EDPARAM& p,double& driver,double& sensor,double& reason) {
    const auto parameter_epoch = p.epoch();
    double sequence{},epoch{},after{},after_epoch{};
    return read(p,"F22_AESA_DRIVER_READY",driver) && header(p,sequence,epoch)
        && read(p,"F22_AG_GMT_READY",sensor) && read(p,"F22_AG_GMT_REASON",reason)
        && read(p,"F22_AG_NATIVE_SEQUENCE",after) && after == sequence
        && read(p,"F22_AG_NATIVE_SOURCE_EPOCH",after_epoch) && after_epoch == epoch
        && parameter_epoch == p.epoch();
}
}
void reset() {
    NativeGroundSensor::reset();
    NativeGroundVideo::reset();
}
void update(EDPARAM& p) {
    NativeGroundVideo::update(p);
    NativeGroundSensor::update(p);
    double driver_value{},sensor{},reason{};
    const bool coherent = sensor_state(p,driver_value,sensor,reason);
    const bool driver = coherent && driver_value == 1;
    const bool ready = driver && coherent && sensor == 1;
    p.setParamNumber(p.getParamHandle("F22_AG_RADAR_NATIVE_READY"), ready ? 1 : 0);
    p.setParamNumber(p.getParamHandle("F22_AG_RADAR_NATIVE_REASON"), ready ? 0 : driver && coherent ? reason : 4);
}
}
