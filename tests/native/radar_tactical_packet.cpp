// I-DEEP-005: independently specified tuples through the actual owning reader.
#include "../../EFM/source/RadarTacticalPacket.h"
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <vector>
namespace {
struct Field { double value{};bool available=true; };
struct Write { std::string name;double value{}; };
using Trace=std::vector<Write>;
std::map<std::string,Field> bus;
Trace old_writes,new_writes;
unsigned checks{},failures{},reads{},lookups{};
int publish_at=-1,context_at=-1;
EDPARAM* port{};
void require(bool condition,const char* message) {
    ++checks;
    if (!condition) {++failures;std::cout<<"FAIL "<<message<<'\n';}
}
void apply(const Trace& writes) { for (const auto& w : writes) bus[w.name]={w.value,true}; }
void* handle(const char* name) {
    ++lookups;
    const auto found=bus.find(name);
    return found==bus.end()?nullptr:&found->second;
}
bool number(const void* opaque,double& value,bool) {
    const auto boundary=static_cast<int>(reads++);
    if (boundary==publish_at) apply(new_writes);
    if (boundary==context_at) port->invalidate();
    const auto& field=*static_cast<const Field*>(opaque);
    value=field.value;
    return field.available;
}
void activate(EDPARAM& p) {
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=handle;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
}
void write(Trace& trace,const std::string& name,double value) { trace.push_back({name,value}); }
Trace independent_writer(bool newer) {
    Trace trace;trace.reserve(1200);
    write(trace,"F22_RADAR_TACTICAL_SEQUENCE",newer?3:1);
    write(trace,"F22_RADAR_TACTICAL_SCHEMA",1);
    write(trace,"F22_RADAR_TACTICAL_SOURCE_EPOCH",newer?2:1);
    write(trace,"F22_RADAR_TACTICAL_TIME",newer?10.1:10);
    const std::array fields{"VALID","SOURCE","POSITION_VALID","ASSOCIATION_VALID","VELOCITY_VALID",
        "MEASUREMENT_SOURCE","AGE","N","U","E","VN","VU","VE","IDENTITY_KNOWN",
        "IDENTITY_TIME","FRIENDLY","HOSTILE"};
    for (unsigned slot=1;slot<=64;++slot) {
        char prefix[64]{};std::snprintf(prefix,sizeof(prefix),"F22_RADAR_TACTICAL_%02u_",slot);
        const auto values=slot!=1?std::array<double,17>{0,0,0,0,0,0,999,0,0,0,0,0,0,0,-100,0,0}:
            newer?std::array<double,17>{1,88,1,1,1,2,.1,4000,5000,6000,-10,5,20,0,-100,0,0}:
            std::array<double,17>{1,84,1,1,1,2,.5,1000,2000,3000,10,20,30,1,7,1,0};
        for (std::size_t i=0;i<fields.size();++i) write(trace,std::string(prefix)+fields[i],values[i]);
    }
    write(trace,"F22_RADAR_TACTICAL_SEQUENCE",newer?4:2);
    return trace;
}
bool tuple(const RadarTacticalPacket::Packet& p,bool newer) {
    if (!p.valid || p.count!=1 || p.truncated || p.source_epoch!=(newer?2:1)
        || p.producer_time!=(newer?10.1:10)) return false;
    RadarTacticalPacket::Report expected;
    expected.source=newer?88:84;
    expected.position=newer?std::array<double,3>{4000,5000,6000}:std::array<double,3>{1000,2000,3000};
    expected.velocity=newer?std::array<double,3>{-10,5,20}:std::array<double,3>{10,20,30};
    expected.observation_time=newer?10:9.5;
    expected.association_valid=expected.velocity_valid=true;
    expected.identity_known=expected.friendly=!newer;expected.identity_time=newer?-100:7;
    auto actual=p.reports[0];
    if (std::abs(actual.observation_time-expected.observation_time)>1e-9) return false;
    actual.observation_time=expected.observation_time;
    return actual==expected;
}
bool coherent(bool captured,const RadarTacticalPacket::Packet& p) {
    return captured?(tuple(p,false)||tuple(p,true)):(!p.valid && p.count==0);
}
void writer_boundaries(RadarTacticalPacket::Reader& reader,EDPARAM& p) {
    RadarTacticalPacket::Packet result;
    apply(old_writes);
    require(reader.capture(p,10.2,result) && tuple(result,false),"independent old fixture matches actual reader");
    apply(new_writes);
    require(reader.capture(p,10.2,result) && tuple(result,true),"independent new fixture matches actual reader");
    for (std::size_t boundary=0;boundary<=new_writes.size();++boundary) {
        apply(old_writes);
        for (std::size_t i=0;i<boundary;++i) bus[new_writes[i].name]={new_writes[i].value,true};
        const bool captured=reader.capture(p,10.2,result);
        require(coherent(captured,result),"each actual writer-field prefix is old/new/unavailable");
    }
    apply(old_writes);reads=0;reader.capture(p,10.2,result);const auto count=reads;
    for (unsigned boundary=0;boundary<=count;++boundary) {
        apply(old_writes);reads=0;publish_at=static_cast<int>(boundary);
        const bool captured=reader.capture(p,10.2,result);
        require(coherent(captured,result),"complete publisher commit at every actual reader boundary");
    }
    publish_at=-1;
    for (unsigned boundary=0;boundary<count;++boundary) {
        activate(p);apply(old_writes);reads=0;context_at=static_cast<int>(boundary);
        require(!reader.capture(p,10.2,result) && !result.valid,"context changes cannot authenticate old handles/tuples");
    }
    context_at=-1;activate(p);
}
void invalid_fields(RadarTacticalPacket::Reader& reader,EDPARAM& p) {
    RadarTacticalPacket::Packet result;
    const std::array names{"F22_RADAR_TACTICAL_SEQUENCE","F22_RADAR_TACTICAL_SCHEMA",
        "F22_RADAR_TACTICAL_SOURCE_EPOCH","F22_RADAR_TACTICAL_TIME","F22_RADAR_TACTICAL_01_VALID",
        "F22_RADAR_TACTICAL_01_SOURCE","F22_RADAR_TACTICAL_01_POSITION_VALID",
        "F22_RADAR_TACTICAL_01_ASSOCIATION_VALID","F22_RADAR_TACTICAL_01_VELOCITY_VALID",
        "F22_RADAR_TACTICAL_01_MEASUREMENT_SOURCE","F22_RADAR_TACTICAL_01_AGE",
        "F22_RADAR_TACTICAL_01_N","F22_RADAR_TACTICAL_01_U","F22_RADAR_TACTICAL_01_E",
        "F22_RADAR_TACTICAL_01_VN","F22_RADAR_TACTICAL_01_VU","F22_RADAR_TACTICAL_01_VE",
        "F22_RADAR_TACTICAL_01_IDENTITY_KNOWN","F22_RADAR_TACTICAL_01_IDENTITY_TIME",
        "F22_RADAR_TACTICAL_01_FRIENDLY","F22_RADAR_TACTICAL_01_HOSTILE"};
    for (const auto name : names) {
        for (const double value : {0.0,7.0}) {
            apply(old_writes);bus[name]={value,false};
            require(!reader.capture(p,10.2,result) && !result.valid,"failed conversion wins over payload zero/seven");
        }
        for (const double value : {NAN,INFINITY,-INFINITY}) {
            apply(old_writes);bus[name]={value,true};
            require(!reader.capture(p,10.2,result),"nonfinite protected field is unavailable");
        }
    }
    for (const double sequence : {0.0,1.0,3.0,2.5,16777216.0}) {
        apply(old_writes);bus["F22_RADAR_TACTICAL_SEQUENCE"].value=sequence;
        require(!reader.capture(p,10.2,result),"zero/odd/noninteger/out-of-range sequence withdraws");
    }
    apply(old_writes);bus["F22_RADAR_TACTICAL_TIME"].value=9;
    require(!reader.capture(p,10.2,result),"stale producer is unavailable");
    apply(old_writes);bus["F22_RADAR_TACTICAL_TIME"].value=10.3;
    require(!reader.capture(p,10.2,result),"future producer beyond declared tolerance is unavailable");
    for (const auto name : {"F22_RADAR_TACTICAL_01_SOURCE","F22_RADAR_TACTICAL_SOURCE_EPOCH"}) {
        apply(old_writes);bus[name].value=.5;
        require(!reader.capture(p,10.2,result),"identity/epoch cannot be cast from fractional value");
    }
    apply(old_writes);bus["F22_RADAR_TACTICAL_01_IDENTITY_TIME"].value=11;
    require(!reader.capture(p,10.2,result),"future known identity is unavailable");
    apply(old_writes);require(reader.capture(p,10.2,result) && tuple(result,false),"fresh complete recovery");
}
void capacity_and_independence(RadarTacticalPacket::Reader& reader,EDPARAM& p) {
    RadarTacticalPacket::Packet result;
    apply(old_writes);
    for (unsigned i=1;i<=64;++i) {
        char prefix[64]{};std::snprintf(prefix,sizeof(prefix),"F22_RADAR_TACTICAL_%02u_",i);
        const std::string s=prefix;
        for (const auto key : {"VALID","POSITION_VALID","ASSOCIATION_VALID","VELOCITY_VALID"}) bus[s+key].value=1;
        bus[s+"SOURCE"].value=83+i;bus[s+"MEASUREMENT_SOURCE"].value=2;
        bus[s+"AGE"].value=0;bus[s+"IDENTITY_KNOWN"].value=0;
    }
    require(reader.capture(p,10.2,result) && result.count==32 && result.truncated
        && result.reports[31].source==115,"fixed64 slots retain at most32 reports and expose truncation");
}
void independent_authority(RadarTacticalPacket::Reader& reader,EDPARAM& p) {
    RadarTacticalPacket::Packet result;
    apply(old_writes);bus["F22_RADAR_TACTICAL_01_IDENTITY_KNOWN"].value=0;
    bus["F22_RADAR_TACTICAL_01_IDENTITY_TIME"].value=7;
    require(reader.capture(p,10.2,result) && !result.reports[0].identity_known
        && result.reports[0].identity_time==7,"unknown identity is never renewed by geometry or numeric time");
    apply(old_writes);bus["F22_RADAR_TACTICAL_01_VELOCITY_VALID"].value=0;
    require(reader.capture(p,10.2,result) && !result.reports[0].velocity_valid,
        "position validity does not invent velocity validity");
    apply(old_writes);bus["F22_RADAR_TACTICAL_01_AGE"].value=8;
    for (const auto suffix : {"VALID","SOURCE","POSITION_VALID","ASSOCIATION_VALID","VELOCITY_VALID",
        "MEASUREMENT_SOURCE","AGE","N","U","E","VN","VU","VE","IDENTITY_KNOWN",
        "IDENTITY_TIME","FRIENDLY","HOSTILE"})
        bus[std::string("F22_RADAR_TACTICAL_02_")+suffix]=bus[std::string("F22_RADAR_TACTICAL_01_")+suffix];
    bus["F22_RADAR_TACTICAL_02_SOURCE"].value=88;bus["F22_RADAR_TACTICAL_02_AGE"].value=.5;
    require(reader.capture(p,10.2,result) && result.count==1 && result.reports[0].source==88,
        "a legitimate old coasted slot cannot withdraw an independently fresh report");
    apply(old_writes);bus["F22_RADAR_TACTICAL_01_MEASUREMENT_SOURCE"].value=1;
    require(reader.capture(p,10.2,result) && result.count==0,"unowned cues are never sent as own measured reports");
    apply(old_writes);bus["F22_RADAR_TACTICAL_TIME"].value=0;
    bus["F22_RADAR_TACTICAL_01_AGE"].value=0;bus["F22_RADAR_TACTICAL_01_IDENTITY_TIME"].value=0;
    for (const auto key : {"N","U","E","VN","VU","VE"}) bus[std::string("F22_RADAR_TACTICAL_01_")+key].value=0;
    require(reader.capture(p,0,result) && result.reports[0].observation_time==0
        && result.reports[0].position==std::array<double,3>{},"true zero time/position/velocity remain valid");
}
void explicit_limits(RadarTacticalPacket::Reader& reader,EDPARAM& p) {
    RadarTacticalPacket::Packet result;
    for (const double source : {0.0,123.5,4294967296.0}) {
        apply(old_writes);bus["F22_RADAR_TACTICAL_01_SOURCE"].value=source;
        require(!reader.capture(p,10.2,result),"raw token bounds precede uint32 cast");
    }
    for (const double epoch : {0.0,.5,16777216.0}) {
        apply(old_writes);bus["F22_RADAR_TACTICAL_SOURCE_EPOCH"].value=epoch;
        require(!reader.capture(p,10.2,result),"source epoch must remain a positive exact integer");
    }
    for (const double age : {-1.0,20.000001}) {
        apply(old_writes);bus["F22_RADAR_TACTICAL_01_AGE"].value=age;
        require(!reader.capture(p,10.2,result),"negative/expired source age is rejected");
    }
    apply(old_writes);bus["F22_RADAR_TACTICAL_SEQUENCE"].value=16777214;
    require(reader.capture(p,10.2,result),"maximum even source commit remains admissible");
    apply(old_writes);bus["F22_RADAR_TACTICAL_SOURCE_EPOCH"].value=16777215;
    require(reader.capture(p,10.2,result),"maximum agreed source epoch remains admissible");
    apply(old_writes);bus["F22_RADAR_TACTICAL_01_SOURCE"].value=4294967295.0;
    require(reader.capture(p,10.2,result) && result.reports[0].source==4294967295u,
        "positive uint32 maximum is transportable without a reserved-token mismatch");
    apply(old_writes);bus["F22_RADAR_TACTICAL_01_AGE"].value=6.000001;
    require(reader.capture(p,10.2,result) && result.count==0,"coasted SA report expires alone beyond transmit age6");
    apply(old_writes);bus["F22_RADAR_TACTICAL_TIME"].value=30;
    bus["F22_RADAR_TACTICAL_01_AGE"].value=20;
    require(reader.capture(p,30.2,result) && result.count==0,"legitimate20second SA memory remains a coherent unavailable report");
    apply(old_writes);bus["F22_RADAR_TACTICAL_01_IDENTITY_TIME"].value=-100;
    require(!reader.capture(p,10.2,result),"unknown identity sentinel cannot authenticate known evidence");
    apply(old_writes);
    require(reader.capture(p,10.25,result) && !reader.capture(p,10.250001,result),
        "source packet lease includes its exact boundary and expires immediately beyond");
    apply(old_writes);bus["F22_RADAR_TACTICAL_01_POSITION_VALID"].value=.5;
    require(!reader.capture(p,10.2,result),"flag domains are exact zero/one");
    apply(old_writes);bus["F22_RADAR_TACTICAL_01_VN"].value=1501;
    require(!reader.capture(p,10.2,result),"qualified velocity follows the existing receiver1500mps transport bound");
    p.invalidate();
    require(!reader.capture(p,10.2,result),"missing native parameter context withdraws all reports");
    activate(p);apply(old_writes);
    require(reader.capture(p,10.2,result),"fresh current parameter context recovers");
    const auto previous_lookups=lookups;
    reader.invalidate();result={};
    require(reader.capture(p,10.2,result) && lookups>previous_lookups,
        "terminal reset reacquires handles even when parameter context epoch is unchanged");
    for (const auto& bound : std::array<std::pair<const char*,double>,4>{{
        {"N",30000001},{"E",-30000001},{"U",-501},{"U",100001}}}) {
        apply(old_writes);bus[std::string("F22_RADAR_TACTICAL_01_")+bound.first].value=bound.second;
        require(!reader.capture(p,10.2,result),"position domain matches the Lua world-coordinate contract");
    }
}
bool load_trace(const char* path) {
    std::ifstream file(path);if (!file) return false;
    old_writes.clear();new_writes.clear();
    std::string line;
    while (std::getline(file,line)) {
        if (line.size()>512 || old_writes.size()+new_writes.size()>=20000) return false;
        std::istringstream row(line);std::string stage,name;double value{};
        if (!(row>>stage>>name>>value) || name.size()>128 || !std::isfinite(value)) return false;
        if (stage=="old") old_writes.push_back({name,value});
        else if (stage=="new") new_writes.push_back({name,value});
        else return false;
    }
    return !old_writes.empty() && !new_writes.empty();
}
}
int main(int argc,char** argv) {
    old_writes=independent_writer(false);new_writes=independent_writer(true);
    if (argc==3 && std::string(argv[1])=="--writer-trace") {
        if (!load_trace(argv[2])) return 2;
    } else if (argc!=1) return 2;
    apply(old_writes);EDPARAM parameters;port=&parameters;activate(parameters);
    static RadarTacticalPacket::Reader reader;
    writer_boundaries(reader,parameters);
    invalid_fields(reader,parameters);
    capacity_and_independence(reader,parameters);
    independent_authority(reader,parameters);
    explicit_limits(reader,parameters);
    std::cout<<"tactical packet checks="<<checks<<" failures="<<failures
        <<" writer_fields="<<new_writes.size()<<'\n';
    return failures?1:0;
}
