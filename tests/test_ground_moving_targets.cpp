// Independent expected geometry, speed boundaries, reacquisition and expiry.
#include "../EFM/source/GroundMovingTargets.h"
#include <stdexcept>
#include <iostream>
#define CHECK(x) do {if(!(x))throw std::runtime_error(#x);}while(0)
int main(){try{
 using namespace GroundMovingTargets;
 CHECK(!moving({0,0,0}));CHECK(!moving({7.99/knot,0,0}));
 CHECK(moving({8/knot,0,0}));CHECK(moving({0,0,55/knot}));CHECK(!moving({0,0,55.01/knot}));
 CHECK(illuminated({1000,-100,0},0,0,.02,1500));
 CHECK(!illuminated({1000,-100,100},0,0,.02,1500));
 CHECK(illuminated({0,-100,1000},pi/2,0,.02,1500));
 CHECK(!illuminated({0,-100,1000},pi/2,0,.02,999));
 CHECK(!illuminated({1000,100,0},0,0,.02,1500));
 Tracks t;t.advance(10);t.observe({1,{1000,0,0},{8,0,0},10});CHECK(t.contacts().size()==1);
 t.observe({1,{1000.8,0,0},{8,0,0},10.1});CHECK(t.contacts().size()==1);
 t.observe({1,{1000.8,0,0},{0,0,0},10.2});CHECK(t.contacts().size()==1);
 t.advance(16.1);CHECK(t.contacts().size()==1);t.advance(16.201);CHECK(t.contacts().empty());
 t.observe({2,{1000,0,0},{8,0,0},17});t.observe({2,{1001,0,0},{8,0,0},17.1});CHECK(t.contacts().size()==1);
 t.observe({2,{4000,0,0},{8,0,0},17.2});CHECK(t.contacts().size()==1);
 t.observe({2,{4001,0,0},{8,0,0},17.3});CHECK(t.contacts().size()==1);
 t.advance(9);CHECK(t.contacts().empty());
 std::cout<<"GMT speed/beam, first-hit display, six-second search history and rewind PASS\n";
 return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 1;}}
