// Independent forward propagation checks for the original inverse solver.
#include "../EFM/source/GunIntercept.h"
#include <stdexcept>
#include <iostream>
using namespace GunIntercept;
#define CHECK(x) do{if(!(x))throw std::runtime_error(#x);}while(0)
int main(){
 V own{220,0,0};double speed=1030;
 for(V velocity:{V{220,0,0},V{-250,0,170},V{0,80,-200}})
 for(V accel:{V{},V{0,35,15}}){
  V p{850,30,70};
  auto vacuum=[&](V dir,double t,V& out){out=(dir*speed+own)*t+V{0,-4.9*t*t,0};return true;};
  auto prediction=[&](double t){return p+velocity*t+accel*(.5*t*t);};
  auto r=solve(p,velocity,accel,own,speed,vacuum,prediction);CHECK(r.valid);
  V b;vacuum(r.direction,r.time,b);CHECK((b-(p+velocity*r.time+accel*(.5*r.time*r.time))).norm()<.25);
  // Independently integrate a nonlinear drag law; the inverse solver sees only this callback.
  auto drag=[&](V dir,double t,V& out){V v=dir*speed+own;out={};double elapsed=0;
   while(elapsed<t){double h=std::min(.001,t-elapsed);V a=v*(-.00015*v.norm())+V{0,-9.8,0};out=out+v*h+a*(.5*h*h);v=v+a*h;elapsed+=h;}return true;};
  auto rd=solve(p,velocity,accel,own,speed,drag,prediction);CHECK(rd.valid);CHECK(rd.time>r.time);
  drag(rd.direction,rd.time,b);CHECK((b-(p+velocity*rd.time+accel*(.5*rd.time*rd.time))).norm()<.25);
 }
 CHECK(!solve(V{5000,0,0},V{},V{},own,speed,[](V,double,V&){return true;},[](double){return V{};}).valid);
 CHECK(!solve(V{500,0,0},V{},V{},own,speed,[](V,double,V&){return false;},[](double){return V{};}).valid);
 std::cout<<"Gun intercept: crossing, closing, vertical, acceleration and nonlinear drag intersections OK\n";
}
