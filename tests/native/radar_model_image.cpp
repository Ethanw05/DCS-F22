// Independent collection-to-retained-image transaction cases, not GPU/DCS proof.
#include "../../EFM/source/GroundVideoView.h"
#include <cstdlib>
#include <iostream>

namespace {
using namespace GroundVideoView;
void require(bool condition,const char* message) {
    if(!condition){std::cerr<<"FAIL: "<<message<<'\n';std::exit(1);}
}
View frame(double collection,double stamp,double north=0) {
    View value;value.enabled=true;value.collection=collection;value.stamp=stamp;
    value.north=north;value.altitude=1000;value.view_epoch=1;return value;
}
void retained_transaction() {
    ImageCycle image;
    auto candidate=frame(0,0);
    require(!image.available()&&!image.capture(candidate),"no-RF page state manufactured first pixels");
    candidate=frame(.125,0);
    require(prepare(candidate,0).accepted&&image.capture(candidate),"finite fractional completed work was rounded away");
    const auto* left=&image.image();const auto* right=&image.image();
    require(left==right&&left->stamp==0&&left->collection==.125,"consumers do not share one captured source frame");
    const int direction=image.direction();
    auto waiting=frame(.25,.1,100);
    for(unsigned stage=0;stage<3;++stage) {
        require(!image.capture(waiting)&&image.image().north==0&&image.image().stamp==0,
                "partial renderer pipeline replaced captured pixels/source epoch");
        image.submitted();
    }
    require(image.capture(waiting)&&image.direction()==-direction&&image.image().north==100&&image.image().stamp==.1,
            "completed renderer pipeline did not admit one new source image");
    for(unsigned stage=0;stage<3;++stage)image.submitted();
    auto geometry=waiting;geometry.north=200;geometry.stamp=.2;
    require(!image.capture(geometry)&&image.image().north==100&&image.image().stamp==.1,
            "geometry/page time alone renewed a retained observation");
    geometry.collection=.5;geometry.frozen=true;
    require(!image.capture(geometry)&&image.image().collection==.25,"frozen image consumed fresh RF pixels");
    geometry.frozen=false;
    require(image.capture(geometry)&&image.image().stamp==.2,"unfrozen new completed work did not recover");
    std::cout<<"PASS fractional RF work, pipeline hold, shared frame, frozen source time and recovery\n";
}
void expanded_work() {
    for(bool fast:{false,true}) {
        ImageCycle image;
        auto first=frame(1,1);first.expansion=1;first.fast=fast;
        first.center_m=10000;first.span_m=4000;first.width_deg=20;
        require(prepare(first,1).accepted&&image.capture(first),"qualified expanded source image rejected");
        auto second=first;second.collection=2;second.stamp=2;second.view_epoch=2;
        const unsigned required=fast?3u:6u;
        for(unsigned stage=0;stage<required;++stage) {
            require(!image.capture(second)&&image.image().view_epoch==1,"expanded work admitted before declared renderer completion");
            image.submitted();
        }
        require(image.capture(second)&&image.image().view_epoch==2&&image.image().stamp==2,
                "expanded transaction did not retain the selected complete source epoch");
        for(unsigned repeat=0;repeat<20;++repeat)image.submitted();
        require(!image.capture(second),"repeated submissions fabricated another RF completion");
    }
    ImageCycle fresh;
    require(!fresh.available(),"new owner/lifetime inherited old captured image authority");
    std::cout<<"PASS finite FAST/detail submission policy, explicit view epoch and fresh owner\n";
}
}
int main(){retained_transaction();expanded_work();}
