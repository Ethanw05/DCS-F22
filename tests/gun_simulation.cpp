// Offline benchmark: synthetic flight truth, not DCS or complete Hornet/F-15 avionics.
#include "../EFM/source/GunTargetMotion.h"
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <iostream>
#include <iomanip>
using GunIntercept::V;
V bullet(V dir,double time,double hmax){
 V p{},v=dir*1030+V{220,0,0},wind{12,0,15};double t=0;
 auto a=[&](V vel){V air=vel-wind;return air*(-.00012*air.norm())+V{0,-9.8,0};};
 while(t<time){double h=std::min(hmax,time-t);V a1=a(v),v2=v+a1*(h*.5),a2=a(v2),v3=v+a2*(h*.5),a3=a(v3),v4=v+a3*h,a4=a(v4);
  p=p+(v+v2*2+v3*2+v4)*(h/6);v=v+(a1+a2*2+a3*2+a4)*(h/6);t+=h;}
 return p;
}
V truth(double speed,double rate,double heading,double bank,int scenario,double age,double time){
 V p{};double t=0,angle=heading;
 while(t<time){double h=std::min(.001,time-t);double u=t+h*.5-age-.3;double w=rate;
  if(scenario==1&&u>0)w=rate*std::max(0.,1-u/.6);
  if(scenario==2&&u>0)w=rate*(1-2*std::clamp(u/.6,0.,1.));
  double mid=angle+w*h*.5;p=p+V{std::cos(mid),std::sin(mid)*std::sin(bank),std::sin(mid)*std::cos(bank)}*(speed*h);angle+=w*h;t+=h;}
 return p;
}
int main(int argc,char**argv){if(argc!=3)return 2;std::ifstream in(argv[1]);std::ofstream out(argv[2]);std::string line;std::getline(in,line);
 out<<"scenario,noise,age,range,rate,old_runtime,aligned_ca,turn_director\n";unsigned count=0;
 while(std::getline(in,line)){std::stringstream ss(line);std::vector<double>x;std::string part;while(std::getline(ss,part,','))x.push_back(std::stod(part));if(x.size()!=20)return 3;
  int scenario=static_cast<int>(x[0]);double noise=x[1],age=x[2],distance=x[3],speed=x[4],rate=x[5],heading=x[6],bank=x[7];
  V p{x[8],x[9],x[10]},v{x[11],x[12],x[13]},an{x[14],x[15],x[16]},ao{x[17],x[18],x[19]};
  GunTargetMotion::Model model(p,v,an);V true_initial{distance,30,80};
  auto projectile=[](V d,double t,V& end){end=bullet(d,t,.01);return true;};
  out<<scenario<<','<<noise<<','<<age<<','<<distance<<','<<rate;
  for(int kind=0;kind<3;++kind){
   auto predict=[&](double t){if(kind==0)return p+v*age+ao*(.5*age*age)+v*t+ao*(.5*t*t);
    if(kind==1)return p+v*(age+t)+ao*(.5*(age+t)*(age+t));return model.at(age+t);};
   auto result=GunIntercept::solve(p,v,kind==2?an:ao,V{220,0,0},1030,projectile,predict);
   if(!result.valid)out<<",invalid";
   else{V actual_target=true_initial+truth(speed,rate,heading,bank,scenario,age,age+result.time);V actual_bullet=bullet(result.direction,result.time,.002);
    out<<','<<std::setprecision(9)<<(actual_bullet-actual_target).norm();}
  }
  out<<'\n';++count;
 }
 std::cout<<"Simulated "<<count<<" encounters across three predictor comparisons.\n";
}
