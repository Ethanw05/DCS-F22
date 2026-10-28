// D-R-RAD-002/004: actual checked native command reader; no host sensor calls.
#include "../../EFM/source/NativeAesaRadar.cpp"
#include <cstdlib>
#include <iostream>

// These link-only ports make an accidental native/sample entry fail loudly.
namespace NativeGroundSensor {
AesaRadar::SurfaceRequest pointing(double,const AesaRadar::Pose&) noexcept { std::abort(); }
void sample(void*,const ArrayService&) { std::abort(); }
}
namespace NativeGroundVideo {
void set_aircraft(const AesaRadar::Pose*,double) noexcept { std::abort(); }
}
namespace {
struct Field { double value{}; bool available=true; };
std::array<Field,22> fields;
std::array<Field,10> priorities;
unsigned reads{};
int publication_at=-1, epoch_at=-1, context_at=-1;
EDPARAM* context{};
Field binding_storage[2];
unsigned binding_index{},handle_lookups{};
unsigned checks{}, failures{};
void require(bool condition,const char* description) {
    ++checks;
    if (!condition) { ++failures;std::cout<<"FAIL "<<description<<'\n'; }
}
void packet(bool newer=false) {
    // Independently specified SI/radian controls. New packet disables consent.
    const std::array<double,22> values=newer
        ? std::array<double,22>{0,10.1,4,0,.7,1,.2,-.1,.4,.2,20000,1,.1,.1,8,.6,8,0,.1,.1,5,25000}
        : std::array<double,22>{1,10,2,1,1,0,0,0,1,.5,10000,0,0,0,7,1,0,0,0,0,0,0};
    for (std::size_t i=0;i<fields.size();++i) fields[i]={values[i],true};
    for (std::size_t i=0;i<priorities.size();++i) priorities[i]={newer&&i==0?8.0:0.0,true};
}
bool number(const void* handle,double& value,bool) {
    const auto boundary=static_cast<int>(reads++);
    if (boundary==publication_at) packet(true);
    if (boundary==epoch_at) NativeAesaRadar::epoch.fetch_add(1);
    if (boundary==context_at) context->invalidate();
    const auto field=static_cast<const Field*>(handle);
    if (!field) return false;
    value=field->value; // Failure may modify the buffer; status must win.
    return field->available;
}
void* resolve(const char*) {
    ++handle_lookups;
    return &binding_storage[binding_index];
}
void store(void*,double) {}
bool complete(const NativeAesaRadar::Request& r) {
    const bool unavailable=r.stamp==-100 && !r.controls.enabled;
    const auto& c=r.controls;
    const std::array<double,21> actual{
        static_cast<double>(c.enabled),r.stamp,static_cast<double>(c.emit),c.resource,
        static_cast<double>(c.surface),c.azimuth,c.elevation,c.half_azimuth,c.half_elevation,
        c.range_m,static_cast<double>(c.cue_valid),c.cue_azimuth,c.cue_elevation,
        static_cast<double>(c.selected_id),c.surface_half_azimuth,static_cast<double>(c.fire_control_id),
        static_cast<double>(c.gun_tracking),c.cue_half_azimuth,c.cue_half_elevation,
        static_cast<double>(c.cue_request),c.cue_range_m};
    bool old=actual==std::array<double,21>{1,10,1,1,0,0,0,1,.5,10000,0,0,0,7,1,0,0,0,0,0,0};
    bool newer=actual==std::array<double,21>{0,10.1,0,.7,1,.2,-.1,.4,.2,20000,1,.1,.1,8,.6,8,0,.1,.1,5,25000};
    for (std::size_t i=0;i<c.priority_ids.size();++i) {
        old=old && c.priority_ids[i]==0;
        newer=newer && c.priority_ids[i]==(i==0?8u:0u);
    }
    return unavailable || old || newer;
}
void schedules(EDPARAM& p,NativeAesaRadar::Parameters& reader) {
    for (unsigned boundary=0;boundary<=33;++boundary) {
        packet();reads=0;publication_at=static_cast<int>(boundary);
        require(complete(reader.controls(p,10.2)),"complete old/new/unavailable at every read boundary");
    }
    publication_at=-1;
    for (unsigned boundary=0;boundary<33;++boundary) {
        packet();reads=0;epoch_at=static_cast<int>(boundary);
        require(reader.controls(p,10.2).stamp==-100,"source epoch change withdraws entire packet");
    }
    epoch_at=-1;
    for (unsigned boundary=0;boundary<33;++boundary) {
        p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
        packet();reads=0;context_at=static_cast<int>(boundary);
        require(reader.controls(p,10.2).stamp==-100,"parameter context reset withdraws entire packet");
    }
    context_at=-1;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
}
void conversion_failures(EDPARAM& p,NativeAesaRadar::Parameters& reader) {
    for (std::size_t i=0;i<fields.size();++i) {
        packet();fields[i].available=false;
        require(reader.controls(p,10.2).stamp==-100,"failed required conversion cannot authorize a packet");
        packet();fields[i].value=NAN;
        require(reader.controls(p,10.2).stamp==-100,"nonfinite required field cannot authorize a packet");
    }
    for (std::size_t i=0;i<priorities.size();++i) {
        packet();priorities[i].available=false;
        require(reader.controls(p,10.2).stamp==-100,"failed priority conversion cannot become a valid zero");
    }
    packet();p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=nullptr;
    require(reader.controls(p,10.2).stamp==-100,"missing native conversion export withdraws");
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
}
void clocks_and_domains(EDPARAM& p,NativeAesaRadar::Parameters& reader) {
    packet();const auto copied=reader.controls(p,10.49);
    require(copied.stamp==10 && !NativeAesaRadar::fresh(10.8,copied.stamp,.5),"producer lease is not renewed by copy");
    require(!NativeAesaRadar::request_current(copied,10.8,copied.controls.generation),
        "actual sampler admission cannot renew the copied producer lease");
    require(NativeAesaRadar::fresh(10.5,copied.stamp,.5),"source lease includes its exact boundary");
    require(!NativeAesaRadar::fresh(10.500001,copied.stamp,.5),"source lease expires immediately beyond boundary");
    NativeAesaRadar::request=copied;
    NativeAesaRadar::snapshot.epoch=NativeAesaRadar::epoch.load();
    NativeAesaRadar::snapshot.status.ready=true;
    NativeAesaRadar::snapshot.status.interference.valid=true;
    NativeAesaRadar::snapshot.status.time=10.49;
    require(NativeAesaRadar::bridge_ready(10.49),"fresh complete source grants actual bridge admission");
    NativeAesaRadar::snapshot.status.time=10.8;
    require(!NativeAesaRadar::bridge_ready(10.8),"fresh bridge snapshot cannot renew expired command source");
    NativeAesaRadar::snapshot.status.time=10.49;
    ++NativeAesaRadar::request.controls.generation;
    require(!NativeAesaRadar::bridge_ready(10.49),"foreign request epoch cannot grant bridge authority");
    packet();fields[1].value=0;
    require(reader.controls(p,0).stamp==0,"zero World observation clock remains valid");
    for (const double sequence : {0.0,1.0,3.0,2.5,16000002.0,std::numeric_limits<double>::infinity()}) {
        packet();fields[2].value=sequence;
        require(reader.controls(p,10.2).stamp==-100,"invalid/odd/uncommitted sequence withdraws");
    }
    packet();fields[2].value=16000000;
    require(reader.controls(p,10.2).controls.enabled,"maximum publisher sequence is valid");
    for (const unsigned i : {0u,3u,5u,11u,17u}) {
        packet();fields[i].value=.5;
        require(reader.controls(p,10.2).stamp==-100,"typed boolean domain is exact");
    }
    packet();fields[14].value=-1;
    require(reader.controls(p,10.2).stamp==-100,"invalid selected identity withdraws");
    packet();fields[1].value=11;
    require(reader.controls(p,10.2).stamp==-100,"future producer time withdraws");
    packet();fields[1].value=9;
    require(reader.controls(p,10.2).stamp==-100,"stale producer time withdraws");
    packet();fields[0].value=0;
    require(!reader.controls(p,10.2).controls.enabled && reader.controls(p,10.2).stamp==10,"disabled packet commits coherently");
    packet();require(reader.controls(p,10.2).controls.enabled,"fresh current recovery");
}
void parameter_binding(EDPARAM& p,NativeAesaRadar::Parameters& reader) {
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=resolve;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=store;
    require(reader.bind(p) && reader.inputs[0]==&binding_storage[0],"initial checked adapter binding");
    const auto first=handle_lookups;
    require(reader.bind(p) && first==handle_lookups,"current context reuses only its own handles");
    p.invalidate();binding_index=1;
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=resolve;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=store;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
    require(reader.bind(p) && reader.inputs[0]==&binding_storage[1] && handle_lookups>first,
        "new parameter context reacquires every borrowed handle");
    p.invalidate();
    require(!reader.bind(p),"missing export after context loss never reuses a prior ready binding");
    NativeAesaRadar::request.controls.enabled=true;NativeAesaRadar::snapshot.status.ready=true;
    NativeAesaRadar::update(p);
    require(!NativeAesaRadar::request.controls.enabled && !NativeAesaRadar::snapshot.status.ready,
        "failed parameter binding immediately withdraws cached native request and bridge readiness");
}
}
int main() {
    EDPARAM port;context=&port;port.ed_param_api={};
    port.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=number;
    static NativeAesaRadar::Parameters reader;
    for (std::size_t i=0;i<fields.size();++i) reader.inputs[i]=&fields[i];
    for (std::size_t i=0;i<priorities.size();++i) reader.priorities[i]=&priorities[i];
    schedules(port,reader);
    conversion_failures(port,reader);
    clocks_and_domains(port,reader);
    parameter_binding(port,reader);
    std::cout<<"radar packet checks="<<checks<<" failures="<<failures<<'\n';
    return failures?1:0;
}
