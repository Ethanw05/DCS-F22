// Independent load-budget and native-trajectory counterfactual intercept checks.
#include "../EFM/source/GunManeuver.h"
#include <iostream>
#include <stdexcept>
using GunIntercept::V;
#define CHECK(x) do{if(!(x))throw std::runtime_error(#x);}while(0)
int main(){
 auto refs=GunManeuver::references(V{250,0,0},V{});CHECK(refs.valid);
 CHECK(refs.acceleration[0].norm()<1e-9);CHECK(std::abs(refs.acceleration[1].y-8*9.8)<1e-9);
 V gravity{0,-9.8,0};CHECK(std::abs((refs.acceleration[2]-gravity).norm()-9*9.8)<1e-8);
 CHECK(std::abs((refs.acceleration[3]-gravity).norm()-9*9.8)<1e-8);
 CHECK(refs.acceleration[2].z==-refs.acceleration[3].z);
 CHECK(!GunManeuver::references(V{0,250,0},gravity).valid);
 V p{600,0,0},v{250,0,0},own{220,0,0};
 for(V a:refs.acceleration){
  GunTargetMotion::Model target(p,v,a);
  auto projectile=[&](V d,double t,V& end){end=(d*1030+own)*t+V{0,-4.9*t*t,0};return true;};
  auto result=GunIntercept::solve(p,v,a,own,1030,projectile,[&](double t){return target.at(t);});CHECK(result.valid);
  V end;projectile(result.direction,result.time,end);CHECK((end-target.at(result.time)).norm()<.25);
 }
 std::cout<<"Gun maneuver references: proper load, coupled lateral budget, undefined plane and intercepts OK\n";
}
