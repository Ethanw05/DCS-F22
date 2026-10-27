// GPL-3.0-or-later.
#pragma once
class EDPARAM;
namespace NativeAltimetry {
void reset();
void update(EDPARAM&,double static_pressure_pa,bool sample_valid);
void update_standby(EDPARAM&, double static_pressure_pa, bool sample_valid);
// Fresh standalone indicated altitude; callers decide how to handle loss.
bool altitude(double& metres);
bool model_time(double& seconds);
}
