#include "GroundVideoView.h"
#include <cassert>
#include <cstring>
#include <limits>
using namespace GroundVideoView;
int main() {
  const Binding expected{0x1000,0x2000,8};
  assert(matches(expected,expected));
  assert(!matches({0,0x2000,8},expected));
  assert(!matches({0x1000,0,8},expected));
  assert(!matches({0x1001,0x2000,8},expected));
  assert(!matches({0x1000,0x2001,8},expected));
  assert(!matches({0x1000,0x2000,7},expected));
  int getter_calls=0;
  const auto read=[&] {++getter_calls;return expected;};
  // Even a foreign target8 must be rejected without touching typed getters.
  assert(!verify_binding(0x4000,0x5000,0x6000,false,expected,read));
  assert(!verify_binding(0x6000,0x5000,0x6000,false,expected,read));
  assert(getter_calls==0);
  assert(verify_binding(0x5000,0x5000,0x6000,false,expected,read));
  assert(verify_binding(0x6000,0x5000,0x6000,true,expected,read));
  assert(getter_calls==2);
  Guard guard;assert(!guard.available());
  guard.verify(true);assert(guard.available());
  guard.fail(7);assert(!guard.available() && guard.reason()==7);
  guard.verify(false);guard.verify(true);assert(!guard.available() && guard.reason()==7);
  guard.reset();assert(!guard.available() && guard.reason()==0);
  guard.verify(true);assert(guard.available());

  View v;v.enabled=true;v.stamp=5;v.altitude=3000;v.range_nm=20;
  assert(valid(v,5));assert(valid(v,5.5));assert(!valid(v,5.500001));assert(!valid(v,4.99));
  for (double heading : {0.,.25,pi/2,pi,3*pi/2,1.75*pi}) {
    v.heading=heading;const auto p=position(prepare(v,5));
    for(unsigned row=0;row<3;++row)
      assert(std::abs(p[row*3]*p[row*3]+p[row*3+1]*p[row*3+1]+p[row*3+2]*p[row*3+2]-1)<1e-6);
    assert(std::abs(p[0]*p[3]+p[1]*p[4]+p[2]*p[5])<1e-6);
    assert(std::abs(p[0]*p[6]+p[2]*p[8])<1e-6);
    const double determinant=p[0]*(p[4]*p[8]-p[5]*p[7])-p[1]*(p[3]*p[8]-p[5]*p[6])+p[2]*(p[3]*p[7]-p[4]*p[6]);
    assert(std::abs(determinant-1)<1e-6);
    assert(p[1]<0 && std::abs(std::asin(p[1])+13*pi/180)<1e-6);
    assert(p[10]==3000);
    // Independent flat-terrain ray: the forward beam must hit ahead/below at
    // every cardinal, with the same ground bearing and depression.
    const double distance=-p[10]/p[1];
    const double north=p[0]*distance,east=p[2]*distance;
    assert(distance>0 && std::hypot(north,east)>0);
    assert(std::abs(std::remainder(std::atan2(east,north)-heading,2*pi))<1e-6);
    assert(std::abs(std::hypot(north,east)-3000/std::tan(13*pi/180))<.01);
    // AGRadar update rotates the forward vector upward by verticalAngle/2;
    // renderScanned passes NEGATIVE rotated Y as PS_SOURCE params2[0].
    // The default90deg pattern must accept the upward ground-to-radar ray.
    const double cutoff=-std::sin(std::asin(p[1])+45*pi/180);
    assert(cutoff<0 && -p[1]>=cutoff);
  }
  // Evaluate the installed shader's full radiation weight, not merely its
  // cutoff. At high altitude a level beam nearly nulls the inner map despite
  // passing that cutoff; the reference depression must retain useful weight.
  const auto radiation=[](double elevation,double height,double horizontal) {
    const double cutoff=-std::sin(elevation+45*pi/180);
    const double vy=height/std::hypot(height,horizontal);
    const double dot=std::sqrt(1-cutoff*cutoff)*std::sqrt(1-vy*vy)+cutoff*vy;
    return vy>=cutoff?std::fmax(0.,std::sin(2.29*std::pow(std::acos(std::fmax(0.,dot)),.7))):0.;
  };
  v.heading=0;
  const auto earth=position(prepare(v,5));
  const double elevation=std::asin(earth[1]);
  assert(radiation(0,20000,10*1852)<.001); // Old level-beam negative control.
  assert(radiation(elevation,20000,10*1852)>.2);
  assert(radiation(elevation,2000,10*1852)>radiation(0,2000,10*1852));
  for(double range:{5.,10.,20.,40.}) {
    v.range_nm=range;const auto p=projection(prepare(v,5));
    assert(p.near_clip==10 && p.far_clip==static_cast<float>(range*1852));
    assert(p.near_clip<p.far_clip && std::abs(p.aspect-std::sqrt(3.))<1e-6);
    assert(std::abs(p.fov_x-120*pi/180)<1e-6 && std::abs(p.fov_y-pi/2)<1e-6);
    const double a=p.far_clip/(p.far_clip-p.near_clip),b=-a*p.near_clip;
    assert(std::isfinite(a) && std::isfinite(b) && b!=0);
    assert(std::abs((a*p.near_clip+b)/p.near_clip)<1e-12);
    assert(std::abs((a*p.far_clip+b)/p.far_clip-1)<1e-6);
  }
  v.fan=false;v.antenna_elevation=-std::atan(3000./(20*1852));
  auto pencil=projection(prepare(v,5));
  assert(std::abs(pencil.fov_y-3.3*pi/180)<1e-6);
  const auto pencil_basis=position(prepare(v,5));
  assert(std::abs(std::asin(-pencil_basis[1])-std::atan(3000./(20*1852)))<1e-6);
  v.fan=true;v.antenna_elevation=0;
  // Mode-dependent search limits and the real renderer presets.
  for(double range:{80.,160.}){v.mode=1;v.range_nm=range;assert(valid(v,5));}
  v.mode=2;v.range_nm=80;assert(!valid(v,5));
  v.mode=4;assert(valid(v,5));v.range_nm=160;assert(!valid(v,5));
  v.mode=6;v.range_nm=10;assert(valid(v,5));
  assert(std::abs(projection(prepare(v,5)).near_clip-2963.2f)<.01);
  assert(std::strcmp(preset(v),"F18_TA")==0);
  v.mode=1;v.range_nm=20;
  Aircraft patch_aircraft;patch_aircraft.valid=true;patch_aircraft.stamp=5;
  patch_aircraft.altitude=5000;patch_aircraft.fn=1;
  for(int level:{1,2,3}) {
    View patch=v;patch.expansion=level;patch.center_m=15000;patch.span_m=2000;
    patch.stabilized=true;patch.patch_n=15000;patch.patch_e=4000;patch.patch_u=100;
    for(double north:{0.,500.,1000.}) {
      patch_aircraft.north=north;
      const auto a=antenna(patch,patch_aircraft,5);
      assert(valid(a,5));const auto lens=projection(prepare(a,5));
      assert(lens.near_clip>10 && lens.far_clip>lens.near_clip);
      assert(std::abs((lens.far_clip-lens.near_clip)-a.span_m)<.02);
      const double bearing=a.heading+a.scan_center;
      assert(std::abs(a.north+a.center_m*std::cos(bearing)-patch.patch_n)<.001);
      assert(std::abs(a.east+a.center_m*std::sin(bearing)-patch.patch_e)<.001);
      const auto par=parameters(a,false,true);
      assert(std::strcmp(par[7].text,level==1?"EXP_F16":level==2?"DBS1_F16":"DBS2_F16")==0);
      patch.fast=true;assert(parameters(patch,false,false)[2].number==.5f);
    }
  }
  v.mode=1;v.range_nm=20;
  // Every expanded camera can look far below the aircraft's nose. A nose-axis
  // offset may put the aircraft in front of that camera during a climb.
  // Verify clearance along the actual rendered view, including frame timing.
  for(double pitch:{-60.,0.,30.,60.,85.})for(double heading:{0.,pi/2,pi,3*pi/2})
  for(double azimuth:{-50.,0.,50.})for(double distance:{1500.,10000.,40000.})
  for(double speed:{0.,310.})for(double age:{-.02,.05})
  for(bool fan:{false,true})for(double offset:{-45.,0.,45.})for(int level:{1,2,3}) {
    Aircraft body;body.valid=true;body.stamp=5;body.north=1000;body.east=2000;body.altitude=3000;
    body.fn=std::cos(pitch*pi/180)*std::cos(heading);
    body.fu=std::sin(pitch*pi/180);body.fe=std::cos(pitch*pi/180)*std::sin(heading);
    body.vn=speed*std::cos(heading);body.ve=speed*std::sin(heading);
    const double n=body.north+body.vn*age,e=body.east+body.ve*age;
    View patch=v;patch.expansion=level;patch.stabilized=true;patch.patch_u=100;
    patch.fan=fan;patch.antenna_offset=offset*pi/180;
    patch.patch_n=n+distance*std::cos(heading+azimuth*pi/180);
    patch.patch_e=e+distance*std::sin(heading+azimuth*pi/180);
    const auto mapped=antenna(patch,body,5+age);
    assert(mapped.enabled);const auto basis=position(prepare(mapped,5+age));
    const double clearance=(mapped.north-n)*basis[0]+(mapped.altitude-body.altitude)*basis[1]+(mapped.east-e)*basis[2];
    assert(clearance>29.0 && "Expanded camera clearance must follow its view, not the aircraft nose");
  }
  auto p=parameters(v,true,true);assert(p[6].bits==1);assert(std::strcmp(p[7].text,"GM_F16")==0);
  assert(p[8].number==0 && p[9].number==0 && p[10].number==50);
  v.gmt=true;p=parameters(v,false,false);assert(p[8].number==.5f&&p[9].number==50&&p[10].number==55);
  v.interleave=true;v.scan_direction=-1;p=parameters(v,false,false);assert(p[9].number==0);
  v.scan_direction=1;p=parameters(v,false,false);assert(p[9].number==50);
  v.tracking=true;p=parameters(v,false,false);assert(p[8].number==0);
  v.gmt=false;v.tracking=false;v.interleave=false;
  // A completed partial collection must refresh before one full volume.
  View partial=v;partial.collection=v.collection+1.0/150;
  assert(std::floor(partial.collection)==std::floor(v.collection));
  assert(refresh(partial,v,true));
  assert(!refresh(v,v,true)); // A faster graphics callback creates no RF work.
  View geometry=v;geometry.range_nm=40;geometry.erase_sequence=v.erase_sequence+1;
  assert(!refresh(geometry,v,true));
  geometry.collection=0;assert(!refresh(geometry,v,false));
  partial.frozen=true;assert(!refresh(partial,v,true));
  p=parameters(v,false,false);assert(p[6].bits==0 && p[7].bits==0);
  for (auto invalid : {std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::infinity()}) {
    v.range_nm=invalid;assert(!valid(v,5));
  }
  v.range_nm=20;v.enabled=false;assert(!valid(v,5));
  v.enabled=true;v.scan_direction=0;assert(!valid(v,5));
  v.scan_direction=-1;v.width_deg=121;assert(!valid(v,5));
  v.width_deg=120;v.scan_fraction=1.01;assert(!valid(v,5));
  v.scan_fraction=0;v.gain=1.01;assert(!valid(v,5));
  v.gain=.5;
  // Flight regression: at 310m/s the old 50ms cockpit snapshot placed the
  // antenna behind the moving aircraft. Predict native motion at the graphics
  // time; both forward and backwards interpolation retain the moving-flight clearance.
  Aircraft flight;flight.valid=true;flight.stamp=5;flight.north=1000;
  flight.altitude=2000;flight.vn=310;
  for(double t:{4.98,5.,5.016,5.05}) {
    const auto a=antenna(v,flight,t);
    const double actual_aircraft_n=1000+310*(t-5);
    assert(std::abs(a.north-actual_aircraft_n-30)<1e-9);
    assert(a.altitude==2000 && a.stamp==t);
    const auto basis=position(prepare(a,t));
    const double expected=13*pi/180+std::atan(2000./37040);
    assert(std::abs(std::asin(-basis[1])-expected)<1e-6);
  }
  assert(!antenna(v,flight,5.101).enabled);
  flight.fn=0;flight.fe=1;flight.vn=0;flight.ve=310;
  const auto east=antenna(v,flight,5.05);
  assert(std::abs(east.east-45.5)<1e-9 && std::abs(east.heading-pi/2)<1e-9);
  v.frozen=true;const auto frozen=antenna(v,flight,5.05);
  assert(frozen.north==v.north && frozen.east==v.east && frozen.stamp==v.stamp);v.frozen=false;
  auto rejected=[](const Prepared &f) {
    assert(!f.accepted && !f.view.enabled);
    for(float x:position(f)) assert(std::isfinite(x));
    for(double x:point(f)) assert(std::isfinite(x) && x==0);
    assert(f.view.width_deg==120 && f.view.range_nm==20);
    const auto lens=projection(f);
    assert(std::isfinite(lens.fov_x) && lens.near_clip==10 && lens.far_clip==37040);

  };
  rejected(prepare(v,5.51));
  v.enabled=false;rejected(prepare(v,5));v.enabled=true;
  rejected(prepare(v,5,false));
  v.north=std::numeric_limits<double>::quiet_NaN();rejected(prepare(v,5));v.north=0;
  v.heading=std::numeric_limits<double>::infinity();rejected(prepare(v,5));v.heading=0;
  v.range_nm=std::numeric_limits<double>::infinity();rejected(prepare(v,5));v.range_nm=20;
  rejected(prepare(v,std::numeric_limits<double>::quiet_NaN()));
}
