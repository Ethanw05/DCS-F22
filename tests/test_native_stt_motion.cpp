#include "../EFM/source/NativeSTTMotion.h"
#include <array>
#include <stdexcept>
#include <iostream>
using namespace NativeSTTMotion;
#define CHECK(x) do{if(!(x))throw std::runtime_error(#x);}while(0)
int main(){std::array<std::byte,2440> b{};
 auto set=[&]<class T>(int at,T value){std::memcpy(b.data()+at,&value,sizeof(value));};
 set(2024,std::uint32_t{42});set(2128,100.0);
 for(int i=0;i<3;++i){set(2076+4*i,1000.f+float(i));set(2092+4*i,100.f+float(i));set(2104+4*i,2.f+float(i));}
 auto s=decode(b.data(),b.size(),100.05);CHECK(s.valid&&s.acceleration_valid&&s.id==42);CHECK(s.position[2]==1002&&s.velocity[1]==101&&s.acceleration[0]==2);
 CHECK(!decode(b.data(),b.size(),100.3).valid);CHECK(!decode(b.data(),2000,100).valid);
 set(2104,INFINITY);s=decode(b.data(),b.size(),100.05);CHECK(s.valid&&!s.acceleration_valid);
 set(2092,INFINITY);CHECK(!decode(b.data(),b.size(),100.05).valid);
 set(2024,std::uint32_t{0});CHECK(!decode(b.data(),b.size(),100.05).valid);
 std::cout<<"Native STT cache: layout, identity, age, finite velocity and separate acceleration validity OK\n";
}
