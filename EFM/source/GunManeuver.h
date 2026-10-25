// GPL-3.0-or-later. Original counterfactual maneuver references, separate from primary aim.
#pragma once
#include "GunTargetMotion.h"
#include <array>
namespace GunManeuver {
using GunIntercept::V;
inline V cross(V a,V b){return{a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x};}
struct Cases {std::array<V,4> acceleration{};double observed_load{};bool valid{};};
inline Cases references(V velocity,V acceleration){
 Cases result;const double speed=velocity.norm(),g=9.8;
 if(!std::isfinite(speed)||speed<20||!std::isfinite(acceleration.norm()))return result;
 V direction=velocity*(1/speed),gravity{0,-g,0};
 V tangent=direction*GunTargetMotion::dot(acceleration,direction);
 V gravity_normal=gravity-direction*GunTargetMotion::dot(gravity,direction);
 V lift=acceleration-tangent-gravity_normal;double magnitude=lift.norm();
 if(!std::isfinite(magnitude)||magnitude<.1*g)return result; // Maneuver plane undefined near ballistic free fall.
 V normal=lift*(1/magnitude),lateral=cross(direction,normal);double length=lateral.norm();
 if(length<1e-6)return result;lateral=lateral*(1/length);
 V low=tangent+gravity_normal+normal*g,high=tangent+gravity_normal+normal*(9*g);
 // The 1-g branch has sqrt(9²-1²) g of lateral reference load; total stays at 9 g.
 V side=lateral*(std::sqrt(80.)*g);
 result.acceleration={low,high,low+side,low-side};result.observed_load=magnitude/g;result.valid=true;return result;
}
struct CueSet {std::array<V,4> aim{};V base{};double time{},identity{},cost_ms{},observed_load{};bool valid{};};
}
