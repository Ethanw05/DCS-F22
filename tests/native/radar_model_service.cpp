// Actual finite AESA/receiver owner, independently driven measured/source events.
#include "../../EFM/source/AesaRadar.h"
#include "../../EFM/source/AesaReceiver.h"
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <memory>

namespace {
using namespace AesaRadar;
void require(bool condition,const char* message) {
    if(!condition){std::cerr<<"FAIL: "<<message<<'\n';std::exit(1);}
}
struct Port final:Environment {
    std::array<Truth,maximum_candidates> targets{};
    std::array<double,2048> observation_times{};
    unsigned count=1,queries{},looks{},visible_calls{},maximum_visible{};
    int receiver_failure{};
    double noise{},now{};
    bool supply=true,clear=true,permuted{},oversized{};
    double priority_run{},maximum_priority_run{};
    Port() {
        for(std::size_t i=0;i<targets.size();++i) {
            targets[i].id=static_cast<std::uint32_t>(1000+i);
            targets[i].position={1000+static_cast<double>(i)*.1,1000,0};
            targets[i].velocity={15,0,0};targets[i].cross_section_m2=1;
        }
    }
    bool interference(double time,const Pose&,const Beam& beam,Interference& result,QueryStats&) noexcept override {
        now=time;
        if(looks<observation_times.size())observation_times[looks]=time;
        ++looks;
        if(beam.priority)priority_run+=time-beam.started;else priority_run=0;
        maximum_priority_run=std::max(maximum_priority_run,priority_run);
        result={receiver_failure!=4,noise,time,noise>0?1u:0u};
        if(receiver_failure==2)result.noise_ratio=std::numeric_limits<double>::quiet_NaN();
        if(receiver_failure==3)result.time=time+1;
        if(receiver_failure==5)result.noise_ratio=-1;
        return receiver_failure!=1;
    }
    bool query(const Pose&,const Beam&,std::span<Truth> out,std::size_t& returned,QueryStats& stats) noexcept override {
        ++queries;visible_calls=0;
        returned=supply?std::min<std::size_t>(count,out.size()):0;
        for(std::size_t i=0;i<returned;++i) {
            out[i]=targets[i];out[i].position=targets[i].position+targets[i].velocity*now;
            if(permuted)out[i].id=static_cast<std::uint32_t>(8000+(i+queries%2)%2);
        }
        stats.visited=static_cast<std::uint32_t>(returned);
        if(oversized)returned=out.size()+1;
        return true;
    }
    bool visible(const Pose&,const Truth&,QueryStats&) noexcept override {
        ++visible_calls;maximum_visible=std::max(maximum_visible,visible_calls);return clear;
    }
    bool observed(double stamp) const {
        for(std::size_t i=0;i<std::min<std::size_t>(looks,observation_times.size());++i)
            if(observation_times[i]==stamp)return true;
        return false;
    }
};
Policy policy() {
    Policy result;result.dwell_s=.02;result.processing_s=.03;
    result.range_error_m=1;result.angular_error_rad=.001*degree;result.track_memory_s=1;
    return result;
}
Controls controls() {
    Controls result;result.enabled=true;result.half_azimuth=.001*degree;result.half_elevation=.001*degree;
    result.range_m=20000;return result;
}
Pose pose() {Pose result;result.position={0,1000,0};return result;}
const Measurement* first(const Model& radar) {
    for(const auto& report:radar.measurements())if(report.valid)return &report;
    return nullptr;
}
void current(const Model& radar,const Port& port,double now,double minimum_delay=0) {
    for(const auto& report:radar.measurements())if(report.valid) {
        require(report.id>0&&report.time<=now&&now-report.time+1e-9>=minimum_delay,
                "publication lost original observation/processing time");
        require(port.observed(report.time),"published time was not an actual completed sensing look");
        require(report.filter_valid&&finite(report.position)&&finite(report.velocity),"invalid measured filter publication");
    }
    require(radar.status().pending<=maximum_pending&&radar.status().tracks<=maximum_tracks,"capacity invariant failed");
}
void service_time_and_silence() {
    auto radar=std::make_unique<Model>(policy());auto port_storage=std::make_unique<Port>();auto& port=*port_storage;
    auto command=controls();const auto aircraft=pose();
    require(radar->update(0,command,aircraft,port)&&port.queries==0,"dispatch granted an immediate sensing look");
    for(unsigned tick=1;tick<=400;++tick) {
        const double time=tick*.005;
        require(radar->update(time,command,aircraft,port),"healthy finite owner unavailable");
        current(*radar,port,time,.03);
    }
    require(first(*radar)&&radar->status().detections>0,"bounded high-signal sequence never produced a measurement");
    const auto old=*first(*radar);const auto queries=port.queries;const auto dwells=radar->status().dwells;
    for(unsigned repeat=0;repeat<10;++repeat)require(radar->update(2,command,aircraft,port),"same-clock readiness lost");
    require(port.queries==queries&&radar->status().dwells==dwells&&first(*radar)->time==old.time,
            "same-clock callback fabricated RF work or sample age");
    command.emit=false;require(!radar->update(2.01,command,aircraft,port),"silent command retained an emitter");
    require(!first(*radar)&&radar->status().pending==0&&!radar->status().emitting,"silence retained pending authority");
    command.emit=true;
    for(unsigned tick=0;tick<=100;++tick)(void)radar->update(3+tick*.005,command,aircraft,port);
    require(first(*radar)&&first(*radar)->id>old.id&&first(*radar)->time>=3,
            "fresh post-silence recovery reused retired identity or old sample");
    std::cout<<"PASS actual finite sensing/processing/source clocks, same-clock no-work and silence recovery\n";
}
void capacity_and_cadence() {
    auto p=policy();p.dwell_s=.005;p.processing_s=2;
    auto radar=std::make_unique<Model>(p);auto crowded_storage=std::make_unique<Port>();auto& crowded=*crowded_storage;
    crowded.count=maximum_candidates;
    auto command=controls();const auto aircraft=pose();
    (void)radar->update(0,command,aircraft,crowded);
    unsigned previous_detections=0;
    for(unsigned tick=1;tick<=200;++tick) {
        (void)radar->update(tick*.005,command,aircraft,crowded);
        const auto detected=radar->status().detections;
        require(detected-previous_detections<=maximum_returns_per_dwell,"one callback exceeded eight RF returns");
        previous_detections=detected;
        require(radar->status().pending<=maximum_pending,"processing queue grew beyond fixed capacity");
    }
    require(radar->status().pending==maximum_pending&&radar->status().queue_drops>0,
            "full processing queue did not expose bounded rejection");
    require(crowded.maximum_visible<=maximum_visibility_queries,"visibility cost exceeded callback budget");
    auto full_policy=policy();full_policy.processing_s=.001;
    auto full=std::make_unique<Model>(full_policy);auto separated_storage=std::make_unique<Port>();auto& separated=*separated_storage;
    separated.count=maximum_candidates;
    for(std::size_t i=0;i<separated.targets.size();++i)separated.targets[i].position.n=1000+100*static_cast<double>(i);
    unsigned peak=0;
    for(unsigned tick=0;tick<=200;++tick) {
        (void)full->update(tick*.005,command,aircraft,separated);
        unsigned valid=0;
        for(const auto& report:full->measurements())if(report.valid)++valid;
        peak=std::max(peak,valid);
    }
    require(peak==maximum_tracks&&full->status().queue_drops>0,"full 64-track owner did not reject excess births");
    for(double resource:{1.0,.25})for(double hz:{30.0,60.0,240.0}) {
        auto finite_radar=std::make_unique<Model>(policy());auto empty_storage=std::make_unique<Port>();auto& empty=*empty_storage;
        empty.supply=false;
        command=controls();command.resource=resource;
        (void)finite_radar->update(0,command,aircraft,empty);
        for(unsigned tick=1;tick<=static_cast<unsigned>(hz);++tick)
            (void)finite_radar->update(tick/hz,command,aircraft,empty);
        const double work_limit=resource/policy().dwell_s+1;
        require(empty.queries>0&&empty.queries<=work_limit,"callback cadence created impossible elapsed RF service");
    }
    auto failed=std::make_unique<Model>(policy());auto malformed_storage=std::make_unique<Port>();auto& malformed=*malformed_storage;
    malformed.oversized=true;command=controls();
    (void)failed->update(0,command,aircraft,malformed);
    require(!failed->update(.02,command,aircraft,malformed)&&!failed->status().ready,
            "over-capacity environmental count was trusted");
    std::cout<<"PASS 128 candidates/8 returns/16 LOS/32 pending and elapsed resource/cadence limits\n";
}
void measured_identity_and_priority() {
    auto left=std::make_unique<Model>(policy()),right=std::make_unique<Model>(policy());
    auto normal_storage=std::make_unique<Port>(),permuted_storage=std::make_unique<Port>();
    auto& normal=*normal_storage;auto& permuted=*permuted_storage;
    normal.count=permuted.count=2;permuted.permuted=true;
    normal.targets[0].position.e=permuted.targets[0].position.e=-30;
    normal.targets[1].position.e=permuted.targets[1].position.e=30;
    auto command=controls();const auto aircraft=pose();
    for(unsigned tick=0;tick<=600;++tick) {
        const double time=tick*.005;
        (void)left->update(time,command,aircraft,normal);(void)right->update(time,command,aircraft,permuted);
        for(std::size_t i=0;i<maximum_tracks;++i) {
            const auto& a=left->measurements()[i];const auto& b=right->measurements()[i];
            require(a.valid==b.valid&&a.id==b.id&&a.time==b.time&&a.association_valid==b.association_valid,
                    "private host-ID permutation changed measured track identity");
            if(a.valid)require(a.position.n==b.position.n&&a.position.e==b.position.e,
                    "private host ID leaked into measured geometry");
        }
    }
    require(first(*left),"permutation sequence produced no measured track");
    const auto id=first(*left)->id;command.priority_ids[0]=command.fire_control_id=id;command.gun_tracking=true;
    normal.maximum_priority_run=normal.priority_run=0;
    for(unsigned tick=1;tick<=2000;++tick)(void)left->update(3+tick*.001,command,aircraft,normal);
    require(left->status().track_dwells>0&&left->status().search_dwells>0,
            "priority tracking starved search or never received a completed look");
    require(normal.maximum_priority_run<=3*policy().dwell_s+.00101,
            "priority run exceeded declared finite search reservation");
    require(left->status().fire_control_last_look>=3&&left->status().fire_control_last_look<=5,
            "fire-control service stamp was not an achieved current look");
    std::cout<<"PASS measured host-ID invariance and finite priority/search service\n";
}
void lifecycle_and_memory() {
    auto radar=std::make_unique<Model>(policy());auto port_storage=std::make_unique<Port>();auto& port=*port_storage;
    auto command=controls();const auto aircraft=pose();
    for(unsigned tick=0;tick<=200;++tick)(void)radar->update(tick*.005,command,aircraft,port);
    require(first(*radar),"memory setup missing measured track");
    port.supply=false;
    for(unsigned tick=1;tick<=40;++tick)(void)radar->update(1+tick*.005,command,aircraft,port);
    require(first(*radar),"track disappeared before declared observation memory");
    const double observed=first(*radar)->time;
    double time=1.2;
    while(time<observed+.99){time+=.005;(void)radar->update(time,command,aircraft,port);}
    require(first(*radar)&&first(*radar)->time==observed,"healthy heartbeat renewed or prematurely dropped old observation");
    while(time<observed+1.02){time+=.005;(void)radar->update(time,command,aircraft,port);}
    require(!first(*radar),"expired observation survived declared memory");
    port.supply=true;
    for(unsigned tick=1;tick<=100;++tick)(void)radar->update(time+tick*.005,command,aircraft,port);
    time+=.5;require(first(*radar),"fresh memory recovery failed");
    ++command.generation;(void)radar->update(time+.001,command,aircraft,port);
    require(!first(*radar)&&radar->status().pending==0,"generation change retained old filter/report authority");
    for(unsigned tick=1;tick<=100;++tick)(void)radar->update(time+.001+tick*.005,command,aircraft,port);
    require(first(*radar),"new generation failed to acquire fresh data");
    (void)radar->update(1,command,aircraft,port);
    require(!first(*radar)&&radar->status().pending==0,"rollback retained old queue/filter");
    (void)radar->update(2,command,aircraft,port);
    require(!first(*radar)&&radar->status().pending==0,"large source jump released old delayed report");
    std::cout<<"PASS original-time memory, source-generation/rollback/gap retirement and fresh recovery\n";
}
void failure_and_surface() {
    const auto aircraft=pose();
    for(int failure=1;failure<=5;++failure) {
        auto radar=std::make_unique<Model>(policy());auto port_storage=std::make_unique<Port>();auto& port=*port_storage;
        port.receiver_failure=failure;auto command=controls();
        (void)radar->update(0,command,aircraft,port);
        require(!radar->update(.02,command,aircraft,port)&&!radar->status().ready&&port.queries==0,
                "unavailable/future/nonfinite receiver environment authenticated healthy zero noise");
        port.receiver_failure=0;
        for(unsigned tick=1;tick<=100;++tick)(void)radar->update(.02+tick*.005,command,aircraft,port);
        require(first(*radar)&&first(*radar)->time>.02,"receiver recovery reused unavailable observation");
    }
    for(double bad:{0.0,1.01,std::numeric_limits<double>::quiet_NaN()}) {
        auto radar=std::make_unique<Model>(policy());auto port_storage=std::make_unique<Port>();auto& port=*port_storage;
        auto command=controls();command.resource=bad;
        require(!radar->update(0,command,aircraft,port)&&port.queries==0&&!first(*radar),"invalid resource granted sensing");
    }
    auto radar=std::make_unique<Model>(policy());auto empty_storage=std::make_unique<Port>();auto& empty=*empty_storage;
    empty.supply=false;auto command=controls();command.surface=true;
    (void)radar->update(0,command,aircraft,empty);
    unsigned surface=0,air=0;
    for(unsigned job=0;job<30;++job) {
        const auto completed=radar->status().beam;const double now=completed.completes;
        (void)radar->update(now,command,aircraft,empty);
        if(completed.surface) {
            ++surface;require(radar->status().surface_service&&radar->status().surface_beam.completes==now,
                    "surface grant did not preserve completed RF geometry/time");
        }else ++air;
        const double work=radar->status().surface_discovery_work;
        (void)radar->update(now,command,aircraft,empty);
        require(radar->status().surface_discovery_work==work&&!radar->status().surface_service,
                "same-clock surface callback added image credit");
    }
    require(surface==20&&air==10&&radar->status().surface_discovery_work>0,"bounded air/surface retained service ratio failed");
    std::cout<<"PASS receiver/control failure recovery and actual air/surface RF-only collection\n";
}
void receiver() {
    Pose aircraft;Beam beam;double measured{};
    require(AesaReceiver::noise_ratio(aircraft,beam,{80000,0,0},1,measured)&&std::abs(measured-4)<1e-12,
            "declared game reference J/N not preserved");
    const double reference=measured;
    require(AesaReceiver::noise_ratio(aircraft,beam,{160000,0,0},1,measured)&&std::abs(measured/reference-.25)<1e-12,
            "noise propagation lost inverse-square distance ratio");
    const Vector half_power{80000*std::cos(beam.half_angle),0,80000*std::sin(beam.half_angle)};
    require(AesaReceiver::noise_ratio(aircraft,beam,half_power,1,measured)&&
        std::abs(measured-2*std::cos(beam.half_angle))<1e-10,"declared Gaussian half-power law changed");
    require(AesaReceiver::noise_ratio(aircraft,beam,{80000,0,0},0,measured)&&measured==0,"legitimate zero noise rejected");
    require(AesaReceiver::noise_ratio(aircraft,beam,{300001,0,0},1,measured)&&measured==0,"outside survey bound retained noise");
    require(!AesaReceiver::noise_ratio(aircraft,beam,{},1,measured),"coincident propagation accepted");
    for(double invalid:{-1.0,101.0,std::numeric_limits<double>::infinity(),std::numeric_limits<double>::quiet_NaN()})
        require(!AesaReceiver::noise_ratio(aircraft,beam,{80000,0,0},invalid,measured),"malformed strength accepted");
    std::cout<<"PASS receiver analytic game ratios, legitimate zero, domain and survey limits\n";
}
}
int main(){service_time_and_silence();capacity_and_cadence();measured_identity_and_priority();lifecycle_and_memory();failure_and_surface();receiver();}
