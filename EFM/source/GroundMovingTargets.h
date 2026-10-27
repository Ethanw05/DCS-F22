// GPL-3.0-or-later. Independent ground-contact geometry and scan history.
#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <map>
#include <vector>
namespace GroundMovingTargets {
constexpr double pi=3.14159265358979323846, knot=1.943844492440605;
struct Vec {double n{},u{},e{};};
inline double length(Vec v){return std::hypot(v.n,v.u,v.e);}
inline Vec operator-(Vec a,Vec b){return {a.n-b.n,a.u-b.u,a.e-b.e};}
inline double bearing(Vec v){return std::atan2(v.e,v.n);}
inline double difference(double a,double b){return std::remainder(a-b,2*pi);}
struct Contact {
  unsigned id{};Vec point{},velocity{};double stamp{};unsigned hits{};
  double observed_az{},horizontal_range{};
};
// Recovered APG-73 simulation predicate (FA18C 0x1804A0210), not an APG-77
// specification: ordinary GMT uses 8..55kt movers; an acquired track may stop.
inline bool moving(Vec v){const double k=length(v)*knot;return std::isfinite(k)&&k>=8&&k<=55;}
inline bool illuminated(Vec relative,double heading,double az,double half,double range) {
  const double r=length(relative);
  return std::isfinite(r)&&r>=100&&r<=range&&relative.u<0&&
      std::abs(difference(bearing(relative),heading+az))<=half;
}
class Tracks {
  std::map<unsigned,Contact> tracks;
  double clock=-1;
public:
  void clear(){tracks.clear();clock=-1;}
  void advance(double now) {
    if(now<clock||now-clock>10)tracks.clear();clock=now;
    for(auto it=tracks.begin();it!=tracks.end();)
      if(now-it->second.stamp>6)it=tracks.erase(it);else ++it;
  }
  void observe(Contact c) {
    if(!c.id||!std::isfinite(c.stamp)||!std::isfinite(length(c.point))||!std::isfinite(length(c.velocity)))return;
    auto it=tracks.find(c.id);c.hits=1;
    if(it!=tracks.end()&&c.stamp<it->second.stamp)return;
    tracks[c.id]=c;
  }
  const Contact *find(unsigned id)const{auto i=tracks.find(id);return i==tracks.end()?nullptr:&i->second;}
  std::vector<Contact> contacts()const {
    std::vector<Contact> out;
    // FA18C 49F190 inserts on the FIRST valid observation. Search symbols
    // retain observation bearing/range until the next illuminated hit.
    for(const auto &[id,c]:tracks)out.push_back(c);
    std::sort(out.begin(),out.end(),[](const auto&a,const auto&b){return a.stamp>b.stamp;});
    if(out.size()>64)out.resize(64);return out;
  }
};
}
