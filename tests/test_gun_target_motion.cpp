// Compare analytic prediction against independently stepped rotating velocity.
#include "../EFM/source/GunTargetMotion.h"
#include <iostream>
#include <stdexcept>
using namespace GunTargetMotion;
#define CHECK(x) do{if(!(x))throw std::runtime_error(#x);}while(0)
int main(){
 for(double speed:{150.,250.,350.})for(double rate:{0.,.05,.2,.4})for(double tangential:{-10.,0.,10.}){
  V p{800,5000,40},v{speed,0,0},a{tangential,speed*rate,0};Model m(p,v,a);
  for(double t:{.01,.1,1.,2.,3.5}){
   V truth=p;double elapsed=0;
   while(elapsed<t){double h=std::min(.0002,t-elapsed);double mid=elapsed+h*.5;
    truth=truth+V{std::cos(rate*mid),std::sin(rate*mid),0}*((speed+tangential*mid)*h);elapsed+=h;}
   CHECK((m.at(t)-truth).norm()<1e-5);
   V derivative=(m.velocity(t+.00001)-m.velocity(t-.00001))*(1/.00002);CHECK((m.acceleration(t)-derivative).norm()<1e-5);
  }
 }
 Model straight(V{},V{200,0,0},V{10,0,0});CHECK((straight.at(2)-V{420,0,0}).norm()<1e-9);
 Model stationary(V{},V{},V{});CHECK(stationary.at(2).norm()==0);
 std::cout<<"Target prediction: straight/turning/climbing, changing speed and zero-turn continuity OK\n";
}
