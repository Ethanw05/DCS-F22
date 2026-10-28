// Receiver effects through the actual detector, including off-beam propagation.
#include "../EFM/source/AesaReceiver.h"
#include <iostream>
#include <stdexcept>
#define CHECK(x) do { if (!(x)) throw std::runtime_error(#x); } while (false)
using namespace AesaRadar;
namespace {
struct World final : Environment {
    Truth target{42,{80000,3000,0},{},1};
    double noise{}, clock_offset{};
    bool known = true, empty{};
    bool interference(double now,const Pose&,const Beam&,Interference& value,QueryStats&) noexcept override {
        value={known,noise,now+clock_offset,noise>0?1u:0u}; return known;
    }
    bool query(const Pose&,const Beam&,std::span<Truth> out,std::size_t& count,QueryStats&) noexcept override {
        count=empty?0:1; if(count)out[0]=target; return true;
    }
    bool visible(const Pose&,const Truth&,QueryStats&) noexcept override { return true; }
};
Pose pose() { Pose result{}; result.position.u=3000; return result; }
Controls controls() {
    Controls result{};result.enabled=true;result.half_azimuth=degree;result.half_elevation=degree;return result;
}
void propagation() {
    const auto p=pose();Beam beam{};double on=0,near=0,off=0,rear=0;
    CHECK(AesaReceiver::noise_ratio(p,beam,{80000,3000,0},1,on));
    CHECK(AesaReceiver::noise_ratio(p,beam,{40000,3000,0},1,near));
    const double angle=60*degree;
    CHECK(AesaReceiver::noise_ratio(p,beam,{80000*std::cos(angle),3000,80000*std::sin(angle)},1,off));
    CHECK(AesaReceiver::noise_ratio(p,beam,{-80000,3000,0},1,rear));
    CHECK(std::abs(on-4)<1e-12 && std::abs(near/on-4)<1e-12);
    CHECK(off>0 && off<on/1000 && rear<off);
    CHECK(!AesaReceiver::noise_ratio(p,beam,{80000,3000,0},-1,on));
    CHECK(!AesaReceiver::noise_ratio(p,beam,{80000,3000,0},NAN,on));
    beam.half_angle=0;CHECK(!AesaReceiver::noise_ratio(p,beam,{80000,3000,0},1,on));
}
void detection() {
    static std::array<Model,4> models;
    std::array<unsigned,4> detections{};
    auto c=controls();const auto p=pose();World world;
    double clean_sigma=0,jammed_sigma=0;unsigned paired=0;
    for(unsigned seed=1;seed<=512;++seed) {
        c.generation=seed*0x9e3779b9ull;
        std::array<Measurement,2> far{};
        for(std::size_t scenario=0;scenario<models.size();++scenario) {
            const double range=scenario<2?80000:20000;
            world.target.position.n=range;
            CHECK(AesaReceiver::noise_ratio(p,Beam{},world.target.position,scenario%2==1?1:0,world.noise));
            auto& model=models[scenario];model.reset(c.generation);
            CHECK(model.update(0,c,p,world));CHECK(model.update(.021,c,p,world));
            detections[scenario]+=model.status().detections;
            CHECK(model.update(.034,c,p,world));
            if(scenario<2)far[scenario]=model.measurements()[0];
        }
        if(far[0].valid&&far[1].valid) {
            clean_sigma+=far[0].range_sigma_m;jammed_sigma+=far[1].range_sigma_m;++paired;
        }
    }
    CHECK(detections[1]>0 && detections[1]<detections[0]/2);
    CHECK(detections[3]>3*detections[1] && detections[3]<detections[2]);
    CHECK(paired>20 && jammed_sigma>1.9*clean_sigma);
    std::cout<<"512 dwells: far clean/jammed="<<detections[0]<<'/'<<detections[1]
        <<", near clean/jammed="<<detections[2]<<'/'<<detections[3]<<'\n';
}
void age_and_unknown() {
    static Model model;World world;world.target.position.n=20000;
    const auto p=pose();auto c=controls();
    for(unsigned tick=0;tick<240;++tick)CHECK(model.update(tick/240.0,c,p,world));
    const auto measured=model.measurements()[0];CHECK(measured.valid);
    world.noise=1e12;
    for(unsigned tick=240;tick<480;++tick)CHECK(model.update(tick/240.0,c,p,world));
    CHECK(model.measurements()[0].time<=1 && model.measurements()[0].time<1.1);
    CHECK(model.measurements()[0].hits<=measured.hits+1); // At most the already pending report.
    world.known=false;
    bool rejected=false;
    for(unsigned tick=480;tick<500;++tick)if(!model.update(tick/240.0,c,p,world))rejected=true;
    CHECK(rejected && !model.status().interference.valid);
    world.known=true;world.noise=0;
    for(unsigned tick=500;tick<740;++tick)model.update(tick/240.0,c,p,world);
    CHECK(model.status().interference.valid && model.measurements()[0].time>2.5);
    model.reset();world.clock_offset=-.01;
    CHECK(model.update(0,c,p,world));CHECK(!model.update(.021,c,p,world));
    model.reset();world.clock_offset=0;world.noise=NAN;
    CHECK(model.update(0,c,p,world));CHECK(!model.update(.021,c,p,world));
    model.reset();world.noise=100;world.empty=true;
    for(unsigned tick=0;tick<240;++tick)CHECK(model.update(tick/240.0,c,p,world));
    CHECK(model.status().detections==0 && model.status().tracks==0);
}
}
int main() {
    try { propagation();detection();age_and_unknown();std::cout<<"Owned receiver interference PASS\n";return 0; }
    catch(const std::exception& error) { std::cerr<<error.what()<<'\n';return 1; }
}
