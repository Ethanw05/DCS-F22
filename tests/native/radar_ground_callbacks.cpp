// R-RAD-003/015 and D-R-RAD-003: actual native owner through explicit host ports.
// These ports qualify software admission, not DCS private ABI or scene lifetime.
#include <Windows.h>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <limits>
#include <map>
#include <string>
#include <vector>
#include "../../EFM/source/NativeGroundSensor.cpp"

namespace {
using GroundMovingTargets::Contact;
using GroundMovingTargets::Vec;
struct Parameter { double value{}; bool convertible{}; };
std::map<std::string,Parameter> parameters;
double model_time{};
unsigned read_count{}, mutation_at{}, volume_queries{}, ray_queries{};
unsigned resolve_count{};
bool mutate_packet{}, invalidate_epoch{};
bool invalidate_context{}, invalidate_output_context{}, output_context_changed{};
unsigned writes_after_context_change{};
EDPARAM* active_parameters{};
std::string unresolved_parameter;
std::array<void*,60> object_table{};
std::array<void*,7> response_table{};
alignas(16) std::array<std::byte,256> own_memory{}, aircraft_memory{}, manager_memory{}, land_memory{};
alignas(16) std::array<std::byte,256> first_memory{}, second_memory{}, response_memory{};
void* manager_pointer=manager_memory.data();
void* land_pointer=land_memory.data();
struct Entry {
    unsigned id{};
    Vec point{};
    NativeGroundSensor::VecF velocity{};
    std::array<unsigned char,3> type{2,0,0};
    std::array<float,16> basis{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1};
};
std::map<const void*,Entry> objects;
std::vector<void*> scene;

void require(bool condition,const char* message) {
    if(!condition){std::cerr<<"FAIL: "<<message<<'\n';std::exit(1);}
}
void set(const std::string& name,double value) { parameters[name]={value,true}; }
double value(const std::string& name) { return parameters.at(name).value; }
void* resolve(const char* name) {
    ++resolve_count;
    if(unresolved_parameter==name)return nullptr;
    return &parameters[name];
}
void seed(double stamp,bool request=false,double request_sequence=0,int mode=2) {
    set("F22_AG_NATIVE_CONTROL_SCHEMA",1);set("F22_AG_NATIVE_CONTROL_SEQUENCE",2);
    set("F22_AG_NATIVE_CONTROL_TIME",stamp);
    set("F22_AG_NATIVE_CONTROL_EPOCH",static_cast<double>(NativeGroundSensor::epoch.load()));
    set("F22_AG_MODE",mode);set("F22_AG_VIDEO_ANTENNA_DEG",0);set("F22_AG_VIDEO_FAN",1);
    set("F22_AG_TRACK_REQUEST_ACTIVE",request?1:0);set("F22_AG_TRACK_REQUEST_SEQUENCE",request_sequence);
    set("F22_AG_TRACK_REQUEST_NORTH",10000);set("F22_AG_TRACK_REQUEST_ALTITUDE",0);
    set("F22_AG_TRACK_REQUEST_EAST",0);set("HUD_MODE",7);set("MAIN_POWER",1);set("RADAR_PWR",1);
    set("F22_AG_RADAR_OPERATING",1);set("F22_AG_SILENT",0);set("F22_AG_ACTIVE",0);
    set("F22_AG_RADAR_RANGE_NM",20);
}
bool read_number(const void* handle,double& result,bool) {
    const auto& parameter=*static_cast<const Parameter*>(handle);
    result=parameter.value; // False conversions deliberately modify the host buffer.
    const bool status=parameter.convertible;
    ++read_count;
    if(mutate_packet&&read_count==mutation_at) {
        seed(10.01,false,8,4);
        set("F22_AG_TRACK_REQUEST_NORTH",20000);
        set("F22_AG_NATIVE_CONTROL_SEQUENCE",4);
        if(invalidate_epoch)NativeGroundSensor::epoch.fetch_add(1);
    }
    if(invalidate_context&&read_count==mutation_at)active_parameters->invalidate();
    return status;
}
void write_number(void* handle,double number) {
    if(output_context_changed)++writes_after_context_change;
    *static_cast<Parameter*>(handle)={number,true};
    if(invalidate_output_context&&handle==&parameters["F22_AG_NATIVE_TRACK_TIME"]) {
        invalidate_output_context=false;output_context_changed=true;
        const auto port=active_parameters->ed_param_api;
        active_parameters->invalidate();active_parameters->ed_param_api=port;
    }
}
double __cdecl clock() { return model_time; }
void* __cdecl aircraft() { return aircraft_memory.data(); }
void* __fastcall own(void*) { return own_memory.data(); }
void* __fastcall same(void* object) { return object; }
unsigned __fastcall identity(void* object) {
    const auto found=objects.find(object);
    return found==objects.end()?0:found->second.id;
}
Vec* __fastcall point(void* object,Vec* result) {
    const auto found=objects.find(object);
    if(found==objects.end())return nullptr;
    *result=found->second.point;return result;
}
const NativeGroundSensor::VecF* __fastcall velocity(const void* object) {
    const auto found=objects.find(object);
    return found==objects.end()?nullptr:&found->second.velocity;
}
const unsigned char* __fastcall type(const void* object) { return objects.at(object).type.data(); }
bool __fastcall dead(const void*) { return false; }
bool __fastcall flag(const void*,int) { return true; }
const float* __fastcall position(void* object) { return objects.at(object).basis.data(); }
void* __fastcall response(void*) { return response_memory.data(); }
float __fastcall cross_section(void*,float,const NativeGroundSensor::VecF&) { return 1; }
bool __fastcall terrain(void*,const NativeGroundSensor::VecF& from,
                        const NativeGroundSensor::VecF& direction,float maximum,
                        NativeGroundSensor::VecF* hit) {
    ++ray_queries;
    if(direction.u>=0)return false;
    const double distance=-static_cast<double>(from.u)/direction.u;
    if(distance<0||distance>maximum)return false;
    *hit={static_cast<float>(from.n+direction.n*distance),0,
          static_cast<float>(from.e+direction.e*distance)};
    return true;
}
void* __fastcall camera(void* memory,int) { return memory; }
const void* __fastcall clip(const void* memory) { return memory; }
const char* __fastcall intersect(const NativeGroundSensor::Scene&,const Vec&,const Vec&,
                                 Vec&,double&,Vec&) { return nullptr; }
int __fastcall query(void*,const void*,unsigned,NativeGroundSensor::Query visitor) {
    require(static_cast<bool>(visitor),"volume port received an empty callback");
    ++volume_queries;
    for(void* item:scene)
        if(visitor(*reinterpret_cast<NativeGroundSensor::Scene*>(item)))return 1;
    return 0;
}
int __fastcall segment(void*,const Vec&,const Vec&,unsigned,NativeGroundSensor::Query visitor) {
    require(static_cast<bool>(visitor),"segment port received an empty callback");
    return 0;
}
template<std::size_t N> void bind_object(std::array<std::byte,N>& memory,void** table,std::size_t offset=0) {
    std::memcpy(memory.data()+offset,&table,sizeof(table));
}
void configure(EDPARAM& p) {
    NativeGroundSensor::reset();
    parameters.clear();objects.clear();scene.clear();
    read_count=mutation_at=volume_queries=ray_queries=resolve_count=0;
    mutate_packet=invalidate_epoch=invalidate_context=false;active_parameters=&p;unresolved_parameter.clear();
    invalidate_output_context=output_context_changed=false;writes_after_context_change=0;
    p.ed_param_api={};
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=&resolve;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=&read_number;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=&write_number;
    object_table.fill(nullptr);response_table.fill(nullptr);
    object_table[1]=reinterpret_cast<void*>(&identity);
    object_table[6]=object_table[7]=reinterpret_cast<void*>(&same);
    object_table[13]=reinterpret_cast<void*>(&terrain);
    object_table[19]=reinterpret_cast<void*>(&query);
    object_table[24]=reinterpret_cast<void*>(&segment);
    object_table[38]=reinterpret_cast<void*>(&velocity);
    object_table[40]=reinterpret_cast<void*>(&own);
    object_table[59]=reinterpret_cast<void*>(&response);
    response_table[6]=reinterpret_cast<void*>(&cross_section);
    bind_object(own_memory,object_table.data());bind_object(own_memory,object_table.data(),120);
    bind_object(aircraft_memory,object_table.data());bind_object(manager_memory,object_table.data());
    bind_object(land_memory,object_table.data());bind_object(first_memory,object_table.data());
    bind_object(second_memory,object_table.data());bind_object(response_memory,response_table.data());
    objects[own_memory.data()]={1,{0,1000,0},{}};
    objects[own_memory.data()+120]={1,{0,1000,0},{}};
    objects[first_memory.data()]={100,{10000,0,-100},{10,0,0}};
    objects[second_memory.data()]={200,{10000,0,100},{10,0,0}};
    auto& api=NativeGroundSensor::api;
    api.clock=&clock;api.aircraft=&aircraft;api.point=&point;api.type=&type;
    api.dead=&dead;api.flag=&flag;api.position=&position;api.intersect=&intersect;
    api.camera=&camera;api.clip=&clip;api.manager=&manager_pointer;api.land=&land_pointer;
    api.reason=0;api.ready=true;
    NativeGroundSensor::sampled_epoch=0;NativeGroundSensor::source_faulted=false;
    NativeGroundSensor::previous_active=false;
}
struct CallbackLifetime { unsigned owners{},calls{},destroyed{},copies{};bool stop{}; };
struct TrackedVisitor {
    CallbackLifetime* lifetime{};
    explicit TrackedVisitor(CallbackLifetime& value) noexcept :lifetime(&value) { ++lifetime->owners; }
    TrackedVisitor(const TrackedVisitor& other) noexcept :lifetime(other.lifetime) {
        if(lifetime){++lifetime->owners;++lifetime->copies;}
    }
    TrackedVisitor(TrackedVisitor&& other) noexcept :lifetime(other.lifetime) { other.lifetime=nullptr; }
    ~TrackedVisitor() { if(lifetime){--lifetime->owners;++lifetime->destroyed;} }
    int operator()(NativeGroundSensor::Scene&) const noexcept {
        ++lifetime->calls;return lifetime->stop?1:0;
    }
};
void query_ownership(EDPARAM& p) {
    configure(p);scene={first_memory.data(),second_memory.data()};
    using Volume=int(__fastcall*)(void*,const void*,unsigned,NativeGroundSensor::Query);
    using Segment=int(__fastcall*)(void*,const Vec&,const Vec&,unsigned,NativeGroundSensor::Query);
    const auto volume=NativeGroundSensor::method<Volume>(manager_memory.data(),19);
    const auto segment_port=NativeGroundSensor::method<Segment>(manager_memory.data(),24);
    require(volume&&segment_port,"owned query port missing from actual vtable adapter");
    if(!volume||!segment_port)return;
    for(bool stop:{false,true}) {
        CallbackLifetime lifetime;lifetime.stop=stop;
        NativeGroundSensor::Query visitor=TrackedVisitor(lifetime);
        const auto copies=lifetime.copies;
        require(lifetime.owners==1,"callback setup did not own exactly one callable");
        const int hint=volume(manager_memory.data(),nullptr,32,std::move(visitor));
        require(!visitor&&lifetime.owners==0&&lifetime.destroyed==1&&lifetime.copies==copies,
                "volume callback was borrowed, copied, retained or destroyed twice");
        require(lifetime.calls==(stop?1u:2u)&&hint==(stop?1:0),
                "volume callback early completion/returned int hint changed");
    }
    CallbackLifetime lifetime;NativeGroundSensor::Query visitor=TrackedVisitor(lifetime);
    const int hint=segment_port(manager_memory.data(),Vec{},Vec{100,0,0},35,std::move(visitor));
    require(!visitor&&lifetime.owners==0&&lifetime.destroyed==1&&lifetime.calls==0&&hint==0,
            "empty segment query did not consume/destroy its unused callback exactly once");
    std::cout<<"PASS by-value volume/segment ownership, zero callback retention, int hints and early-return destruction\n";
}
NativeGroundSensor::ArrayService service(double now,bool granted=true) {
    NativeGroundSensor::ArrayService result;
    result.granted=granted;result.active=true;result.resource=1;
    const double norm=std::hypot(10000.0,1000.0);
    result.beam.direction={10000/norm,-1000/norm,0};
    result.beam.surface=true;result.beam.half_angle=GroundMovingTargets::pi/18;
    result.beam.range_m=20000;result.beam.started=now-.05;result.beam.completes=now;
    return result;
}
void tick(EDPARAM& p,double now,bool granted=true,bool request=false,double sequence=0,int mode=2) {
    model_time=now;seed(now,request,sequence,mode);
    NativeGroundSensor::update(p);
    NativeGroundSensor::sample(own_memory.data(),service(now,granted));
    NativeGroundSensor::update(p);
}
void packet_admission(EDPARAM& p) {
    configure(p);model_time=10;seed(10,true,6);
    NativeGroundSensor::update(p);
    require(value("F22_AG_NATIVE_SOURCE_EPOCH")>=1&&value("F22_AG_NATIVE_SCHEMA")==1,
            "unavailable output must still permit initial epoch echo");
    read_count=0;
    const auto original=NativeGroundSensor::read_controls(p,10.02);
    const unsigned boundaries=read_count;
    require(original.active&&original.request&&original.stamp==10&&original.request_point.n==10000,
            "complete original control packet rejected");
    for(unsigned boundary=1;boundary<=boundaries;++boundary) {
        seed(10,true,6);read_count=0;mutation_at=boundary;mutate_packet=true;
        const auto accepted=NativeGroundSensor::read_controls(p,10.02);
        mutate_packet=false;
        const bool old=accepted.source_epoch>0&&accepted.request&&accepted.request_sequence==6&&
            accepted.request_point.n==10000&&accepted.stamp==10;
        const bool current=accepted.source_epoch>0&&!accepted.request&&accepted.request_sequence==8&&
            accepted.request_point.n==20000&&accepted.stamp==10.01;
        require(accepted.source_epoch==0||old||current,"field preemption admitted a torn control packet");
    }
    const auto parameter_api=p.ed_param_api;
    for(unsigned boundary=1;boundary<=boundaries;++boundary) {
        p.ed_param_api=parameter_api;seed(10,true,6);
        read_count=0;mutation_at=boundary;invalidate_context=true;
        require(!NativeGroundSensor::read_controls(p,10.02).active,"changed API context authenticated old packet");
        invalidate_context=false;
    }
    p.ed_param_api=parameter_api;seed(10,true,6);
    const auto resolved=resolve_count;
    require(NativeGroundSensor::read_controls(p,10.02).active&&resolve_count>resolved,
            "new API epoch reused a prior borrowed parameter handle cache");
    const std::array<const char*,9> checked{{"F22_AG_NATIVE_CONTROL_SEQUENCE","F22_AG_NATIVE_CONTROL_TIME",
        "F22_AG_NATIVE_CONTROL_EPOCH","F22_AG_MODE","F22_AG_VIDEO_FAN","MAIN_POWER",
        "F22_AG_TRACK_REQUEST_SEQUENCE","F22_AG_TRACK_REQUEST_NORTH","F22_AG_TRACK_REQUEST_EAST"}};
    for(const char* field:checked)for(double retained:{0.0,7.0}) {
        seed(10,true,6);parameters[field]={retained,false};
        require(!NativeGroundSensor::read_controls(p,10.02).active,"failed native conversion became healthy data");
    }
    seed(0,false,0);set("F22_AG_VIDEO_FAN",0);
    require(NativeGroundSensor::read_controls(p,0).active,"valid zero time/flag/request ID lost");
    const std::array<double,5> bad_commits{{1,3,2.5,std::numeric_limits<double>::infinity(),std::numeric_limits<double>::quiet_NaN()}};
    for(double sequence:bad_commits) {
        seed(10,true,6);set("F22_AG_NATIVE_CONTROL_SEQUENCE",sequence);
        require(!NativeGroundSensor::read_controls(p,10.02).active,"bad commit admitted");
    }
    seed(10,true,6);
    require(NativeGroundSensor::read_controls(p,10.5).active,"source lease exact boundary rejected");
    require(!NativeGroundSensor::read_controls(p,10.50001).active,"expired original producer lease admitted");
    require(!NativeGroundSensor::read_controls(p,9.99).active,"future producer clock admitted");
    p.invalidate();require(!NativeGroundSensor::read_controls(p,10).active,"missing native API admitted");
    p.ed_param_api=parameter_api;
    std::cout<<"PASS actual control packet: "<<boundaries<<" preemptions, conversion failures and zero\n";
}
void camera_admission(EDPARAM& p) {
    configure(p);
    const auto normal=NativeGroundSensor::volume({},0,0,.1,.1,20000);
    require(normal!=nullptr,"finite zero ground camera geometry rejected");
    std::array<float,5> projection{};
    std::memcpy(projection.data(),static_cast<const std::byte*>(normal)+688,sizeof(projection));
    require(std::abs(projection[0]-.2f)<1e-6f&&std::abs(projection[1]-.2f)<1e-6f&&
        projection[2]==1&&projection[3]==0&&projection[4]==20000,"ground clip projection layout changed");
    const double infinity=std::numeric_limits<double>::infinity();
    const double nan=std::numeric_limits<double>::quiet_NaN();
    require(!NativeGroundSensor::volume({nan,0,0},0,0,.1,.1,20000),"nonfinite camera origin accepted");
    require(!NativeGroundSensor::volume({},infinity,0,.1,.1,20000),"nonfinite camera heading accepted");
    require(!NativeGroundSensor::volume({},0,0,.1,1e-320,20000),"overflowed derived camera aspect accepted");
    std::cout<<"PASS finite zero and nonfinite/overflow ground camera admission\n";
}
std::vector<Contact> measured_run(EDPARAM& p,bool permute) {
    configure(p);scene={first_memory.data(),second_memory.data()};
    std::vector<Contact> history;
    for(unsigned step=0;step<12;++step) {
        const double t=1+step*.2;
        auto& first=objects.at(first_memory.data());auto& second=objects.at(second_memory.data());
        first.point={10000+10*(t-1),0,-100};second.point={10000+10*(t-1),0,100};
        if(permute){first.id=(step%2)?800:900;second.id=(step%2)?900:800;}
        tick(p,t);tick(p,t+.061,false);
        const auto reports=NativeGroundSensor::output.contacts;
        require(reports.size()==2,"actual callback did not release two measured returns");
        for(const auto& report:reports) {
            require(report.id==1||report.id==2,"ground callback published scene identity");
            require(report.stamp==t&&report.filter_valid,"callback renewed or lost source observation time");
            history.push_back(report);
        }
        require(value("F22_AG_GMT_COUNT")==2&&value("F22_AG_NATIVE_SEQUENCE")>=2&&
            std::fmod(value("F22_AG_NATIVE_SEQUENCE"),2)==0,"ground output not committed");
    }
    return history;
}
void measured_association(EDPARAM& p) {
    const auto original=measured_run(p,false),permuted=measured_run(p,true);
    require(original.size()==permuted.size(),"permuted measurement count mismatch");
    for(std::size_t i=0;i<original.size();++i)
        require(original[i].id==permuted[i].id&&original[i].stamp==permuted[i].stamp&&
            original[i].point.n==permuted[i].point.n&&original[i].point.e==permuted[i].point.e,
            "private ID permutation changed the actual callback's measured history");
    configure(p);scene={first_memory.data(),second_memory.data()};bool coasted=false;
    for(unsigned step=0;step<=20;++step) {
        const double t=1+step*.1,east=40-20*(t-1);
        objects.at(first_memory.data()).point={10000,0,-east};
        objects.at(second_memory.data()).point={10000,0,east};
        objects.at(first_memory.data()).velocity={0,0,20};
        objects.at(second_memory.data()).velocity={0,0,-20};
        tick(p,t);tick(p,t+.061,false);
        for(const auto& report:NativeGroundSensor::output.contacts)
            if(!report.association_valid&&report.stamp<t)coasted=true;
    }
    require(coasted,"actual crossing callback retained perfect identity instead of coasting");
    std::cout<<"PASS actual callback host-ID permutation and ambiguous crossing\n";
}
void acquisition_and_fixed(EDPARAM& p) {
    configure(p);scene={first_memory.data()};
    tick(p,1,true,true,1);require(!value("F22_AG_NATIVE_TRACK_VALID"),"cue granted immediate object track");
    tick(p,1.061,false,true,1);
    require(value("F22_AG_NATIVE_TRACK_VALID")==1&&value("F22_AG_NATIVE_TRACK_ID")==1&&
        value("F22_AG_NATIVE_TRACK_TYPE")!=3,"measured matching acquisition failed");
    require(value("F22_AG_NATIVE_TRACK_TIME")==1,"selected report was retimed at release");
    configure(p);scene={first_memory.data()};
    tick(p,1,true,true,1);tick(p,1.061,false,true,2);
    require(value("F22_AG_NATIVE_TRACK_VALID")==0,"late request A report satisfied request B");
    tick(p,1.2,true,true,2);tick(p,1.261,false,true,2);
    require(value("F22_AG_NATIVE_TRACK_VALID")==1&&value("F22_AG_NATIVE_TRACK_REQUEST_SEQUENCE")==2,
            "fresh request B did not recover with its own measurement");
    configure(p);
    for(unsigned step=0;step<=16;++step)tick(p,1+step*.2,true,true,3);
    require(value("F22_AG_NATIVE_TRACK_VALID")==1&&value("F22_AG_NATIVE_TRACK_TYPE")==3&&
        value("F22_AG_NATIVE_TRACK_ID")==0&&value("F22_AG_NATIVE_TRACK_VELOCITY_VALID")==0,
        "failed object acquisition did not remain disclosed fixed terrain FTT");
    std::cout<<"PASS correlated acquisition, delayed replacement and type3 FTT\n";
}
void require_retired() {
    require(NativeGroundSensor::selected.id==0&&!NativeGroundSensor::fixed&&!NativeGroundSensor::acquiring&&
        NativeGroundSensor::selected_type==0&&NativeGroundSensor::request_sequence==-1&&
        NativeGroundSensor::acquisition_time==0&&NativeGroundSensor::acquisition_point.n==0,
        "ground selection/acquisition state survived source retirement");
    require(NativeGroundSensor::measurements.statistics().pending==0&&
        NativeGroundSensor::measurements.statistics().tracks==0&&!NativeGroundSensor::range_report.valid,
        "pending/filter/range result survived source retirement");
    for(const auto& report:NativeGroundSensor::range_pending)require(!report.valid,"range queue survived retirement");
}
void retirement(EDPARAM& p) {
    for(int phase=0;phase<3;++phase) {
        configure(p);scene={first_memory.data()};
        tick(p,100,true,phase==1,1,phase==2?7:2);
        if(phase==1)tick(p,100.061,false,true,1);
        const auto previous=NativeGroundSensor::epoch.load();
        model_time=10;
        NativeGroundSensor::sample(own_memory.data(),service(10,false));
        NativeGroundSensor::update(p);
        require(NativeGroundSensor::epoch.load()!=previous,"clock rewind did not advance source epoch");
        require_retired();
        require(value("F22_AG_NATIVE_TRACK_VALID")==0&&value("F22_AG_AGR_VALID")==0,
                "retired histories published current authority");
        tick(p,10.1,false);
        require_retired();
        tick(p,100.2,false);
        require_retired();
    }
    configure(p);scene={first_memory.data()};
    model_time=10.49;seed(10,false,0);NativeGroundSensor::update(p);
    require(NativeGroundSensor::controls.stamp==10,"copy time renewed producer lease");
    NativeGroundSensor::sample(own_memory.data(),service(10.49));
    require(NativeGroundSensor::measurements.statistics().pending==1,"lease fixture failed to queue");
    model_time=10.8;NativeGroundSensor::sample(own_memory.data(),service(10.8,false));
    require_retired();
    configure(p);scene={first_memory.data()};tick(p,1);
    const auto queries=volume_queries;
    model_time=1;NativeGroundSensor::sample(own_memory.data(),service(1));
    require(volume_queries==queries&&NativeGroundSensor::measurements.statistics().pending==1,
            "same-clock repeated grant generated new RF credit");
    std::cout<<"PASS pending/selected/range rewind, original producer lease and repeated-clock no-work\n";
}
void mode_family(EDPARAM& p) {
    configure(p);scene={first_memory.data()};objects.at(first_memory.data()).velocity={};
    tick(p,1,true,false,0,1);tick(p,1.061,false,false,0,1);
    require(value("F22_AG_NATIVE_MAP")==1&&value("F22_AG_NATIVE_SEA")==0&&value("F22_AG_GMT_COUNT")==1,
            "MAP stationary report lacks producing family in the protected output");
    model_time=1.07;seed(1.07,false,0,2);NativeGroundSensor::update(p);
    require(value("F22_AG_NATIVE_MAP")==1&&value("F22_AG_GMT_COUNT")==0,
            "new GMT request relabelled an old MAP publication");
    objects.at(first_memory.data()).type[0]=3;objects.at(first_memory.data()).velocity={10,0,0};
    tick(p,1.2,true,false,0,4);tick(p,1.261,false,false,0,4);
    require(value("F22_AG_NATIVE_MAP")==0&&value("F22_AG_NATIVE_SEA")==1&&value("F22_AG_GMT_COUNT")==1,
            "SEA observation lost its distinct producing family");
    std::cout<<"PASS protected MAP/GMT/SEA family identity and mode-change search withdrawal\n";
}
void publication_failure(EDPARAM& p) {
    configure(p);scene={first_memory.data()};
    tick(p,1,true,true,1);tick(p,1.061,false,true,1);
    require(value("F22_AG_NATIVE_TRACK_VALID")==1,"writer failure setup has no selected report");
    const auto port=p.ed_param_api;
    p.invalidate();p.ed_param_api=port;
    unresolved_parameter="F22_AG_NATIVE_TRACK_N";
    model_time=1.07;seed(1.07,true,1);
    NativeGroundSensor::output.selected.point.n=12000;
    NativeGroundSensor::output.selected.stamp=1.07;NativeGroundSensor::output.stamp=1.07;
    NativeGroundSensor::update(p);
    require(std::fmod(value("F22_AG_NATIVE_SEQUENCE"),2)==1&&
        value("F22_AG_NATIVE_TRACK_VALID")==0&&value("F22_AG_GMT_READY")==0,
        "failed payload write authenticated old coordinates under a new completed packet");
    require(!NativeGroundSensor::controls.active,"failed publication retained current sensing consent");
    unresolved_parameter.clear();NativeGroundSensor::update(p);
    require(std::fmod(value("F22_AG_NATIVE_SEQUENCE"),2)==0&&value("F22_AG_NATIVE_TRACK_N")==12000,
        "resolved current payload did not restore a complete coherent packet");
    const double committed_sequence=value("F22_AG_NATIVE_SEQUENCE");
    p.invalidate();p.ed_param_api=port;
    unresolved_parameter="F22_AG_NATIVE_SEQUENCE";
    model_time=1.08;seed(1.08,true,1);
    NativeGroundSensor::output.selected.point.n=13000;
    NativeGroundSensor::output.selected.stamp=1.08;NativeGroundSensor::output.stamp=1.08;
    NativeGroundSensor::update(p);
    require(value("F22_AG_NATIVE_SEQUENCE")==committed_sequence&&
        value("F22_AG_NATIVE_TRACK_N")==12000&&value("F22_AG_NATIVE_TRACK_TIME")==1.07,
        "failed odd marker modified payload beneath a prior completed packet");
    require(!NativeGroundSensor::controls.active,"failed odd marker retained sensing consent");
    unresolved_parameter.clear();NativeGroundSensor::update(p);
    require(std::fmod(value("F22_AG_NATIVE_SEQUENCE"),2)==0&&value("F22_AG_NATIVE_TRACK_N")==13000,
        "resolved odd marker did not recover the current payload");
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=nullptr;
    NativeGroundSensor::update(p);
    require(!NativeGroundSensor::controls.active,"missing publication export retained sensing consent");
    p.ed_param_api=port;
    std::cout<<"PASS checked payload-write failure, missing writer and coherent current recovery\n";
}
void publication_context_change(EDPARAM& p) {
    configure(p);scene={first_memory.data()};
    tick(p,1,true,true,1);tick(p,1.061,false,true,1);
    const double prior_n=value("F22_AG_NATIVE_TRACK_N");
    model_time=1.07;seed(1.07,true,1);
    NativeGroundSensor::output.selected.point.n=17000;
    NativeGroundSensor::output.selected.stamp=1.07;NativeGroundSensor::output.stamp=1.07;
    invalidate_output_context=true;NativeGroundSensor::update(p);
    require(output_context_changed&&writes_after_context_change==0&&
        std::fmod(value("F22_AG_NATIVE_SEQUENCE"),2)==1&&value("F22_AG_NATIVE_TRACK_N")==prior_n,
        "API context change allowed later payload writes into the new context");
    require(!NativeGroundSensor::controls.active,"API context change retained sensing consent");
    output_context_changed=false;NativeGroundSensor::update(p);
    require(std::fmod(value("F22_AG_NATIVE_SEQUENCE"),2)==0&&value("F22_AG_NATIVE_TRACK_N")==17000,
        "current API context did not reacquire publication handles and recover");
    std::cout<<"PASS mid-publication API context change stops all later writes and recovers\n";
}
}
int main() {
    EDPARAM actual;
    query_ownership(actual);packet_admission(actual);camera_admission(actual);measured_association(actual);acquisition_and_fixed(actual);retirement(actual);mode_family(actual);publication_failure(actual);publication_context_change(actual);
    std::cout<<"Actual ground callback software ports pass; DCS ABI/lifetime/effects remain unqualified.\n";
}
