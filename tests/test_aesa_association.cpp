// Measurement association and host binding are deliberately separate domains.
#include "../EFM/source/AesaRadar.h"
#include <algorithm>
#include <iostream>
#include <stdexcept>
#include <string>
#define CHECK(x) do { if (!(x)) throw std::runtime_error(std::to_string(__LINE__)+": "+#x); } while(false)
using namespace AesaRadar;
struct Scene final : Environment {
    std::array<Truth,2> objects{{{7001,{10000,3000,0},{},1},{9001,{11000,3000,0},{},1}}};
    std::size_t count=1;
    bool query(const Pose&,const Beam&,std::span<Truth> out,std::size_t& size,QueryStats&) noexcept override {
        size=count;std::copy_n(objects.begin(),count,out.begin());return true;
    }
    bool visible(const Pose&,const Truth&,QueryStats&) noexcept override { return true; }
};
void advance(Model& model,Scene& scene,Controls& controls,Pose& pose,unsigned begin,unsigned end) {
    for (unsigned tick=begin;tick<end;++tick) CHECK(model.update(tick/240.0,controls,pose,scene));
}
void identifiers() {
    static Model model;
    Scene scene;
    Controls controls{};controls.enabled=true;controls.half_azimuth=degree;controls.half_elevation=degree;
    Pose pose{};pose.position.u=3000;
    advance(model,scene,controls,pose,0,240);
    const auto track=model.measurements()[0];
    CHECK(track.valid && track.velocity_valid && track.id!=7001 && model.bindings()[0].qualified);
    scene.objects[0].id=123456;
    advance(model,scene,controls,pose,240,480);
    CHECK(model.measurements()[0].id==track.id && model.measurements()[0].hits>track.hits);
    CHECK(model.bindings()[0].host==123456 && model.bindings()[0].qualified);
    CHECK(!model.measurements()[1].valid); // Changing hidden identity cannot spawn a new measured track.
    const auto previous=model.measurements()[0].time;
    scene.objects[0].position.n=30000;
    advance(model,scene,controls,pose,480,530);
    CHECK(model.measurements()[0].time==previous); // Same hidden ID cannot drag an established track.
    CHECK(model.measurements()[1].valid && model.measurements()[1].id!=track.id);
}
void ambiguity() {
    static Model model;
    Scene scene;scene.count=2;
    Controls controls{};controls.enabled=true;controls.half_azimuth=degree;controls.half_elevation=degree;
    Pose pose{};pose.position.u=3000;
    advance(model,scene,controls,pose,0,240);
    CHECK(model.measurements()[0].valid && model.measurements()[1].valid);
    // Two statistically indistinguishable reports compete for one track.
    scene.objects[1].position=scene.objects[0].position;
    const auto before=model.status().association_ambiguous;
    bool withdrew=false;
    for (unsigned tick=240;tick<300;++tick) {
        CHECK(model.update(tick/240.0,controls,pose,scene));
        if (!model.measurements()[0].association_valid) {
            CHECK(!model.bindings()[0].qualified);
            CHECK(model.measurements()[0].time<tick/240.0);
            withdrew=true;
        }
    }
    CHECK(withdrew && model.status().association_ambiguous>before);
}
void doppler_separation() {
    static Model model;
    Scene scene;scene.count=2;
    scene.objects[1].position=scene.objects[0].position;
    scene.objects[0].velocity.n=-150;scene.objects[1].velocity.n=150;
    Controls controls{};controls.enabled=true;controls.half_azimuth=degree;controls.half_elevation=degree;
    Pose pose{};pose.position.u=3000;
    for (unsigned tick=0;tick<1440;++tick) {
        const double time=tick/240.0;
        scene.objects[0].position.n=10400-150*time;
        scene.objects[1].position.n=9600+150*time;
        CHECK(model.update(time,controls,pose,scene));
    }
    CHECK(model.measurements()[0].velocity_valid && model.measurements()[1].velocity_valid);
    CHECK(model.measurements()[0].velocity.n*model.measurements()[1].velocity.n<0);
    CHECK(model.bindings()[0].host==7001 && model.bindings()[1].host==9001);
    CHECK(model.measurements()[0].position.n<model.measurements()[1].position.n);
}
int main() {
    try { identifiers();ambiguity();doppler_separation();std::cout<<"Owned association: identity permutation, teleport, ambiguous coast and Doppler separation PASS\n";return 0; }
    catch(const std::exception& error) {std::cerr<<error.what()<<'\n';return 1;}
}
