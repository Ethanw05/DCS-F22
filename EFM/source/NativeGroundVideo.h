// GPL-3.0-or-later. Own cockpit source for the shared DCS radar image renderer.
#pragma once
class EDPARAM;
namespace NativeGroundVideo {
void set_aircraft(double n,double u,double e,double vn,double vu,double ve,
                  double qx,double qy,double qz,double qw);
void update(EDPARAM &);
void reset();
}
