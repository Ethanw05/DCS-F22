// Offline adapter tests. Fake sensor decisions do not validate native acquisition.
#include "../EFM/source/NativeSidewinder.cpp"
#include <iostream>
#include <stdexcept>
#define CHECK(x) do { if (!(x)) throw std::runtime_error(#x); } while (0)

namespace {
std::map<std::string,double> values;
void* handle(const char* n) { return &values[n]; }
void number(void* p,double v) { *static_cast<double*>(p)=v; }
bool get_number(const void* p,double& out,bool) { out=*static_cast<const double*>(p);return true; }
bool sensor_track=false,consent=false;
int creations=0,destructions=0,slaves=0,launches=0;
int uncage_calls=0;
float detected_strength=-1;
NativeSidewinder::WeaponType last_type;
void* construct(void* self,const NativeSidewinder::WeaponType* type) { ++creations;last_type=*type;return self; }
void destroy(void*) { ++destructions; }
void method(void*) {}
void uncage(void*) {++uncage_calls;}
void power(void*,bool) {}
void scalar(void*,float) {}
int sun_filter_calls=0;
void sun_filter(void*,float value) {CHECK(value==1.f);++sun_filter_calls;}
void motor_limits(void*,double low,double high) { CHECK(low<-1.4 && high>1.4); }
void set_consent(void*,bool v) { consent=v; }
void status(void*,unsigned v) { CHECK(v==3); }
void station(void*,int selected,int sub) { CHECK(selected>=0 && sub==0); }
void update(void*,double) {}
void slave(void*,const NativeSidewinder::Direction* v) { CHECK(std::abs(v->x-1)<1e-8);++slaves; }
void boresight(void*,const NativeSidewinder::Pose* p) { CHECK(p->m[12]>NativeSidewinder::model_max[0]);CHECK(std::abs(std::hypot(p->m[0],p->m[1],p->m[2])-1)<1e-8); }
bool tracking(void*) { return sensor_track && consent; }
float strength(void*) { return detected_strength>=0 ? detected_strength : sensor_track ? 1.f : 0.f; }
const void* seeker(const void* p) { return p; }
NativeSidewinder::Pose* local_pose(const void*,NativeSidewinder::Pose* p) { p->m[0]=1;return p; }
unsigned launch(void*,void*) { CHECK(sensor_track && consent);++launches;return 42; }
void launcher(void*,NativeSidewinder::LauncherPose* p,unsigned char station,unsigned char sub) {
    CHECK(station<=10 && sub==0);p->m[0]=p->m[5]=p->m[10]=.99143f;p->m[15]=1;
}
void* vtable[65]{};
void** aircraft_object=vtable;
void* aircraft() { return &aircraft_object; }
void* radar_instance=nullptr;
void* ammo_payload=nullptr;
unsigned ammo_rounds=480;
std::uintptr_t ammo_mount[2]{};
void* payload() { return ammo_payload; }
void* mount(void*,unsigned char index,unsigned char sub) { CHECK(sub==255);return index==0 ? ammo_mount : nullptr; }
unsigned rounds(void*) { return ammo_rounds; }
double now_model=100;
double model_clock() { return now_model; }
unsigned native_target=0;
bool native_tracking(const void*,unsigned id,unsigned) {return native_target && id==native_target;}
unsigned native_selected(const void*) {return native_target;}
double native_range(const void*) {return native_target ? 20000 : -1;}
void* binding_context() { return &aircraft_object; }
void* device(void* context,unsigned id) { CHECK(context==&aircraft_object && id==13);return radar_instance; }
const NativeSidewinder::ScanPattern* native_pattern(const void* self) {
    const auto base=static_cast<const std::byte*>(self);
    return reinterpret_cast<const NativeSidewinder::ScanPattern*>(base+(*reinterpret_cast<const int*>(base+2020)==2 ? 1984 : 1952));
}
int native_acquisition_calls=0;
bool rank_candidates=false,throw_acquisition=false;
std::array<std::array<double,2>,2> native_candidate_angles{};
std::array<unsigned,2> native_candidate_hits{5,5};
std::array<double,2> supplied_metric{};
NativeSidewinder::ScanPattern supplied_physical{};
const void* supplied_context=nullptr;
void native_acquisition(void* self) {
    ++native_acquisition_calls;
    auto b=static_cast<std::byte*>(self);
    supplied_metric={*reinterpret_cast<double*>(b+2000),*reinterpret_cast<double*>(b+2008)};
    auto getter=reinterpret_cast<NativeSidewinder::Api::PatternQuery>((*static_cast<void***>(self))[27]);
    supplied_physical=*getter(self);supplied_context=NativeSidewinder::acquisition_coordinates.owner;
    if (throw_acquisition) throw std::runtime_error("native acquisition test exception");
    if (rank_candidates) {
        auto error=[](const auto& c) {return std::pow(c[0]-supplied_metric[0],2)+std::pow(c[1]-supplied_metric[1],2);};
        unsigned winner=error(native_candidate_angles[0])<=error(native_candidate_angles[1]) ? 0 : 1;
        // This fake native function alone decides the STT ID and count gate.
        // It is adapter-contract coverage, not a native sensor acceptance test.
        if (native_candidate_hits[winner]>4) {
            *reinterpret_cast<int*>(b+2020)=3;*reinterpret_cast<unsigned*>(b+2024)=901+winner;
        }
    }
}
int tof_calls=0,tof_constructions=0,tof_destructions=0;
double fake_tof=25,fake_act=12;
std::array<double,9> tof_arguments{};
void* tof_construct(void* p) {++tof_constructions;*static_cast<std::uintptr_t*>(p)=0xbeef;return p;}
void tof_destroy(void* p) {CHECK(*static_cast<std::uintptr_t*>(p)==0xbeef);++tof_destructions;}
double aam_tof(void* p,double h,double v,double pitch,double tv,double course,double bearing,double range,double th,double ar,double* act,int type,bool sparrow) {
    CHECK(*static_cast<std::uintptr_t*>(p)==0xbeef && (type==0 || type==1) && !sparrow);
    ++tof_calls;tof_arguments={h,v,pitch,tv,course,bearing,range,th,ar};*act=fake_act;return fake_tof;
}
NativeSidewinder::WeaponType launched_type{4,4,7,0,106};
bool payload_launch_allowed=true;
const NativeSidewinder::WeaponType* store_type(void*,unsigned) {return &launched_type;}
unsigned launch_payload(void*,unsigned,unsigned,unsigned,const float*,bool) {
    // A native release callback may be followed immediately by a mode change.
    NativeSidewinder::launch_master_mode=3;return payload_launch_allowed ? 9876 : 0;
}
}
int main() {
    using namespace NativeSidewinder;
    Pose scaled;scaled.m[0]=scaled.m[5]=scaled.m[10]=.99143;scaled.m[12]=4;
    CHECK(scaled.m[0]<std::cos(.03054)); // centered target rejected before repair
    CHECK(normalize_mount_pose(scaled) && scaled.m[0]>=std::cos(.03054) && scaled.m[12]==4);
    const double low[]={-1,-1,-1},high[]={1,1,1};
    scaled.m[12]=0;CHECK(std::abs(clear_observation_aperture(scaled,low,high)-1.05)<1e-8);
    CHECK(std::abs(scaled.m[12]-1.05)<1e-8 && clear_observation_aperture(scaled,low,high)==0);
    Pose degenerate;CHECK(!normalize_mount_pose(degenerate));
    EDPARAM p;
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=handle;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=number;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=get_number;
    api.ready=true;api.error=0;api.profile_valid=false;
    api.construct=construct;api.destroy=destroy;api.initialize=method;
    api.uncage=uncage;api.to_boresight=method;api.power=power;api.consent=set_consent;
    api.status=status;api.station=station;api.update=update;api.slave=slave;api.boresight=boresight;
    api.tracking=tracking;api.strength=strength;api.seeker=seeker;api.local_pose=local_pose;
    api.launch=launch;api.aircraft=aircraft;
    api.gimbal_limit=scalar;api.sun_filter=sun_filter;api.motor_limits=motor_limits;
    void* context[3]={nullptr,nullptr,&p};void** context_ptr=context;api.contexts=&context_ptr;
    vtable[64]=reinterpret_cast<void*>(&launcher);
    values["MAIN_POWER"]=1;values["F22_IR_MODE"]=3;values["F22_IR_STATION"]=0;
    values["F22_IR_TYPE1"]=4;values["F22_IR_TYPE2"]=4;values["F22_IR_TYPE3"]=7;
    values["F22_IR_TYPE4"]=136;values["F22_RADAR_STT_VALID"]=1;
    values["MASTER_ARM"]=1;values["WoW"]=0;
    values["F22_IR_CAGED"]=1;update(p,.02);
    CHECK(values["F22_IR_STATE"]==1 && slaves==0 && !consent);
    values["F22_IR_CAGED"]=0;update(p,.02);
    CHECK(creations==1 && last_type.level4==136 && values["F22_IR_AVAILABLE"]==1);
    CHECK(sun_filter_calls==1 && values["F22_IR_AIM9X_CONFIGURED"]==1);
    CHECK(values["F22_IR_LOCK"]==0 && slaves==1);
    values["F22_IR_RELEASE_REQUEST"]=1;update(p,.02);CHECK(launches==0);
    values["F22_IR_RELEASE_REQUEST"]=0;update(p,.02);
    sensor_track=true;update(p,.02);CHECK(values["F22_IR_LOCK"]==1);
    int prior_slaves=slaves;update(p,.02);CHECK(slaves==prior_slaves);
    // Radar loss does not destroy independent IR tracking. Fresh acquisition
    // without any radar target is permitted by the control adapter too.
    values["F22_RADAR_STT_VALID"]=0;update(p,.02);
    CHECK(values["F22_IR_LOCK"]==1 && slaves==prior_slaves);
    sensor_track=false;update(p,.02);CHECK(values["F22_IR_STATE"]==2);
    sensor_track=true;update(p,.02);CHECK(values["F22_IR_LOCK"]==1 && slaves==prior_slaves);
    values["F22_IR_RELEASE_REQUEST"]=1;update(p,.02);update(p,.02);
    CHECK(launches==1 && values["F22_IR_LAUNCH_ID"]==42 && values["F22_IR_LAUNCH_SEQUENCE"]==1);
    values["F22_IR_RELEASE_REQUEST"]=0;update(p,.02);
    values["MASTER_ARM"]=0;values["F22_IR_RELEASE_REQUEST"]=1;update(p,.02);CHECK(launches==1);
    values["F22_IR_RELEASE_REQUEST"]=0;update(p,.02);
    values["MASTER_ARM"]=1;values["WoW"]=1;values["F22_IR_RELEASE_REQUEST"]=1;update(p,.02);CHECK(launches==1);
    values["F22_IR_STATION"]=10;values["F22_IR_TYPE4"]=22;update(p,.02);
    CHECK(creations==2 && destructions==1 && last_type.level4==22 && launches==1);
    values["MAIN_POWER"]=0;update(p,.02);CHECK(destructions==2 && values["F22_IR_AVAILABLE"]==0);
    // Mod missile has a dynamic ID. Configure the real AIM9X capabilities,
    // while retaining that actual type for construction and launch.
    values["MAIN_POWER"]=1;values["F22_IR_TYPE4"]=10042;values["F22_IR_AIM9X_PROFILE"]=1;
    values["F22_IR_RELEASE_REQUEST"]=0;update(p,.02);
    CHECK(last_type.level4==10042 && sun_filter_calls==2 && values["F22_IR_AIM9X_CONFIGURED"]==1);
    values["F22_IR_AIM9X_PROFILE"]=0;update(p,.02);
    CHECK(creations==4 && sun_filter_calls==2 && values["F22_IR_AIM9X_CONFIGURED"]==0);
    values["MAIN_POWER"]=0;update(p,.02);
    // Latched uncage intent can precede acquisition without letting an empty
    // native head random-walk. Detection alone (no radar lock) then releases it.
    const int before_uncage=uncage_calls;
    values["MAIN_POWER"]=1;values["F22_IR_CAGED"]=0;values["F22_RADAR_STT_VALID"]=0;
    sensor_track=false;detected_strength=0;
    for(int i=0;i<20;++i) update(p,.02);
    CHECK(consent && uncage_calls==before_uncage && values["F22_IR_HEAD_RELEASED"]==0);
    detected_strength=.81f;update(p,.02);
    CHECK(uncage_calls==before_uncage+1 && values["F22_IR_HEAD_RELEASED"]==1);
    update(p,.02);CHECK(uncage_calls==before_uncage+1);
    sensor_track=true;update(p,.02);CHECK(values["F22_IR_LOCK"]==1);
    values["F22_IR_CAGED"]=1;update(p,.02);
    CHECK(!consent && values["F22_IR_HEAD_RELEASED"]==0 && values["F22_IR_LOCK"]==0);
    values["MAIN_POWER"]=0;update(p,.02);detected_strength=-1;
    alignas(16) std::array<std::byte,2440> radar{};
    auto base=reinterpret_cast<std::uintptr_t>(radar.data());
    *reinterpret_cast<double*>(base+1944)=300;
    apply_radar_configuration(base);
    CHECK(*reinterpret_cast<double*>(base+1944)==40);
    CHECK(*reinterpret_cast<double*>(base+2416)<-.8 && *reinterpret_cast<double*>(base+2424)>.8);
    // Exercise the actual guarded lookup path, not only field writes. The
    // previous test never caught that this path failed in the simulator.
    std::array<unsigned,6> radar_locator{1,0,0,0,0,0};
    std::array<void*,radar_primary_methods+1> native_radar_table{};
    native_radar_table[0]=radar_locator.data();
    for (unsigned i=0;i<radar_primary_methods;++i) native_radar_table[i+1]=reinterpret_cast<void*>(&method);
    native_radar_table[28]=reinterpret_cast<void*>(&native_pattern);
    native_radar_table[24]=reinterpret_cast<void*>(&native_acquisition);
    auto canonical=native_radar_table.data()+1;
    *reinterpret_cast<void***>(base)=canonical;
    radar_instance=radar.data();api.binding_context=binding_context;api.device=device;
    api.radar_vtable=canonical;api.scan_pattern=native_pattern;api.acquisition_update=native_acquisition;api.profile_valid=true;
    api.clock=model_clock;
    values["F22_RADAR_DEVICE_ID"]=13;
    *reinterpret_cast<double*>(base+1944)=300;
    configure_radar(p);
    CHECK(values["F22_RADAR_NATIVE_CONFIGURED"]==1 && values["F22_RADAR_NATIVE_CONFIG_REASON"]==0);
    CHECK(values["F22_RADAR_ACQ_COORDINATES_READY"]==1 && *reinterpret_cast<void***>(base)==radar_coordinate_table.data()+1);
    CHECK(radar_coordinate_table[0]==radar_locator.data() && canonical[27]==reinterpret_cast<void*>(&native_pattern));
    for (unsigned i=0;i<radar_primary_methods;++i)
        CHECK(radar_coordinate_table[i+1]==(i==27 ? reinterpret_cast<void*>(&coordinate_scan_pattern) :
            i==23 ? reinterpret_cast<void*>(&coordinate_acquisition_update) : canonical[i]));
    CHECK(values["F22_RADAR_NATIVE_MIN_METRES"]==40 && values["F22_RADAR_NATIVE_EL_LIMIT"]>1);
    auto normal=reinterpret_cast<ScanPattern*>(base+1952),acquisition=reinterpret_cast<ScanPattern*>(base+1984);
    *normal={.3,1.2,.1,.04};*acquisition={.2,.14,.2,.05};
    auto pattern_call=reinterpret_cast<Api::PatternQuery>((*reinterpret_cast<void***>(base))[27]);
    for (int mode:{0,1,3,6}) {
        *reinterpret_cast<int*>(base+2020)=mode;
        CHECK(pattern_call(radar.data())==normal && normal->azimuth==.1);
    }
    *reinterpret_cast<int*>(base+2020)=2;*reinterpret_cast<unsigned*>(base+2024)=789;
    for (double target:{-.25,.25}) {
        acquisition->azimuth=target;
        const auto unchanged=radar;
        const auto corrected=pattern_call(radar.data());
        CHECK(corrected!=acquisition && corrected->azimuth==-target && acquisition->azimuth==target);
        CHECK(corrected->elevation_volume==acquisition->elevation_volume && corrected->azimuth_volume==acquisition->azimuth_volume && corrected->elevation==acquisition->elevation);
        // Outside the acquisition call the stored controls remain raw body
        // centres. The native beam rotates by -phase from the physical getter.
        CHECK(-corrected->azimuth==target);
        CHECK(std::equal(radar.begin(),radar.end(),unchanged.begin()));
    }
    alignas(16) std::array<std::byte,2440> unrelated{};
    *reinterpret_cast<void***>(unrelated.data())=canonical;
    *reinterpret_cast<int*>(unrelated.data()+2020)=2;
    auto foreign_pattern=reinterpret_cast<ScanPattern*>(unrelated.data()+1984);foreign_pattern->azimuth=.4;
    CHECK(coordinate_scan_pattern(unrelated.data())==foreign_pattern && foreign_pattern->azimuth==.4);
    CHECK(!install_radar_coordinates(reinterpret_cast<std::uintptr_t>(unrelated.data())) && *reinterpret_cast<void***>(unrelated.data())==canonical);
    auto acquire_call=reinterpret_cast<Api::Method>((*reinterpret_cast<void***>(base))[23]);
    // Vertical neighbours: native reference rotates by origin elevation, so
    // the intended centre becomes zero while the neighbour is two degrees away.
    rank_candidates=true;
    for (double sign:{-1.,1.}) {
        *acquisition={.2,.14,0,sign*3.141592653589793/18};
        native_candidate_angles={{{0,0},{0,sign*3.141592653589793/90}}};
        *reinterpret_cast<int*>(base+2020)=2;*reinterpret_cast<unsigned*>(base+2024)=0;
        acquire_call(radar.data());
        CHECK(std::abs(supplied_metric[0])<1e-12 && std::abs(supplied_metric[1])<1e-12);
        CHECK(supplied_physical.elevation==acquisition->elevation && supplied_physical.azimuth==0 && supplied_context==radar.data());
        CHECK(*reinterpret_cast<int*>(base+2020)==3 && *reinterpret_cast<unsigned*>(base+2024)==901);
        CHECK(acquisition->azimuth==0 && acquisition->elevation==sign*3.141592653589793/18 && acquisition_coordinates.owner==nullptr);
    }
    // Mixed az/el expected scan-reference angles independently computed from
    // Body*Pitch(30deg): target20/30 ->17.2355/1.4964, neighbour23/30 ->19.7906/1.9726.
    *acquisition={.2,.14,3.141592653589793/9,3.141592653589793/6};
    native_candidate_angles={{{.3008154926128581,.02611683011589689},{.34541132563189975,.03442920968554919}}};
    *reinterpret_cast<int*>(base+2020)=2;*reinterpret_cast<unsigned*>(base+2024)=0;
    const ScanPattern saved_pattern=*acquisition;
    acquire_call(radar.data());
    CHECK(std::abs(supplied_metric[0]-.3008154926128581)<1e-12 && std::abs(supplied_metric[1]-.02611683011589689)<1e-12);
    CHECK(supplied_physical.azimuth==-saved_pattern.azimuth && supplied_physical.elevation==saved_pattern.elevation);
    CHECK(*reinterpret_cast<unsigned*>(base+2024)==901 && acquisition->azimuth==saved_pattern.azimuth && acquisition->elevation==saved_pattern.elevation);
    CHECK(acquisition_coordinates.owner==nullptr);
    publish_radar_coordinates(p,base);
    CHECK(values["F22_RADAR_NATIVE_ACQ_METRIC_VALID"]==1 && std::abs(values["F22_RADAR_NATIVE_ACQ_METRIC_AZ"]-supplied_metric[0])<1e-12);
    CHECK(values["F22_RADAR_NATIVE_ACQ_BODY_AZ"]==saved_pattern.azimuth && values["F22_RADAR_NATIVE_ACQ_BODY_EL"]==saved_pattern.elevation);
    now_model+=.351;publish_radar_coordinates(p,base);CHECK(values["F22_RADAR_NATIVE_ACQ_METRIC_VALID"]==0);now_model-=.351;
    // The original native five-hit gate remains decisive; the adapter cannot
    // promote its preferred four-hit candidate even if another has five.
    native_candidate_hits={4,5};*reinterpret_cast<int*>(base+2020)=2;*reinterpret_cast<unsigned*>(base+2024)=0;
    acquire_call(radar.data());CHECK(*reinterpret_cast<int*>(base+2020)==2 && *reinterpret_cast<unsigned*>(base+2024)==0);
    native_candidate_hits={5,5};rank_candidates=false;
    AcquisitionCoordinates previous_context{unrelated.data(),{.3,.4,.5,.6}};acquisition_coordinates=previous_context;
    throw_acquisition=true;bool caught=false;
    try {acquire_call(radar.data());} catch(const std::runtime_error&) {caught=true;}
    CHECK(caught && acquisition->azimuth==saved_pattern.azimuth && acquisition->elevation==saved_pattern.elevation);
    CHECK(acquisition->azimuth_volume==saved_pattern.azimuth_volume && acquisition->elevation_volume==saved_pattern.elevation_volume);
    CHECK(acquisition_coordinates.owner==previous_context.owner && acquisition_coordinates.physical.azimuth==.5);
    acquisition_coordinates={};throw_acquisition=false;
    *reinterpret_cast<int*>(base+2020)=1;acquire_call(radar.data());
    CHECK(supplied_context==nullptr && supplied_physical.azimuth==normal->azimuth && supplied_metric[0]==saved_pattern.azimuth);
    coordinate_acquisition_update(unrelated.data());
    CHECK(supplied_context==nullptr && supplied_metric[0]==.4 && supplied_physical.azimuth==.4 && foreign_pattern->azimuth==.4);
    *reinterpret_cast<int*>(base+2020)=2;
    // World beam stays independent of the native transformed scan reference.
    auto own=reinterpret_cast<float*>(base+1840),beam=reinterpret_cast<float*>(base+1712);
    own[0]=own[5]=own[10]=1;beam[0]=std::cos(.25f);beam[2]=std::sin(.25f);
    publish_radar_coordinates(p,base);
    CHECK(values["F22_RADAR_NATIVE_BEAM_WORLD_VALID"]==1 && values["F22_RADAR_NATIVE_SCAN_REF_BEAM_VALID"]==1);
    CHECK(std::abs(values["F22_RADAR_NATIVE_BEAM_WORLD_N"]-std::cos(.25))<1e-6 && values["F22_RADAR_NATIVE_BEAM_WORLD_U"]==0);
    CHECK(std::abs(values["F22_RADAR_NATIVE_BEAM_WORLD_E"]-std::sin(.25))<1e-6);
    CHECK(std::abs(values["F22_RADAR_NATIVE_SCAN_REF_BEAM_AZ"]-.25)<1e-6);
    CHECK(!values.contains("F22_RADAR_NATIVE_BEAM_AZ") && !values.contains("F22_RADAR_NATIVE_BEAM_EL"));
    own[0]=std::cos(.4f);own[2]=std::sin(.4f);own[8]=-std::sin(.4f);own[10]=std::cos(.4f);
    publish_radar_coordinates(p,base);
    CHECK(values["F22_RADAR_NATIVE_BEAM_WORLD_VALID"]==1 && values["F22_RADAR_NATIVE_SCAN_REF_BEAM_VALID"]==1);
    CHECK(std::abs(values["F22_RADAR_NATIVE_SCAN_REF_BEAM_AZ"]+.15)<1e-6);
    CHECK(std::abs(values["F22_RADAR_NATIVE_BEAM_WORLD_E"]-std::sin(.25))<1e-6);
    own[0]=0;publish_radar_coordinates(p,base);
    CHECK(values["F22_RADAR_NATIVE_BEAM_WORLD_VALID"]==1 && values["F22_RADAR_NATIVE_SCAN_REF_BEAM_VALID"]==0);
    beam[0]=std::numeric_limits<float>::quiet_NaN();publish_radar_coordinates(p,base);
    CHECK(values["F22_RADAR_NATIVE_BEAM_WORLD_VALID"]==0 && values["F22_RADAR_NATIVE_SCAN_REF_BEAM_VALID"]==0);
    beam[0]=2;beam[2]=0;publish_radar_coordinates(p,base);CHECK(values["F22_RADAR_NATIVE_BEAM_WORLD_VALID"]==0);
    beam[0]=beam[2]=0;publish_radar_coordinates(p,base);CHECK(values["F22_RADAR_NATIVE_BEAM_WORLD_VALID"]==0);
    beam[0]=std::cos(.25f);beam[2]=std::sin(.25f);own[0]=1;own[2]=own[8]=0;own[10]=1;
    *reinterpret_cast<int*>(base+2020)=3;publish_radar_coordinates(p,base);CHECK(values["F22_RADAR_NATIVE_BEAM_WORLD_VALID"]==0);
    *reinterpret_cast<int*>(base+2020)=2;
    reset_radar_coordinates();
    CHECK(*reinterpret_cast<void***>(base)==canonical && values["F22_RADAR_ACQ_COORDINATES_READY"]==0);
    CHECK(values["F22_RADAR_NATIVE_BEAM_WORLD_VALID"]==0 && values["F22_RADAR_NATIVE_SCAN_REF_BEAM_VALID"]==0 && values["F22_RADAR_NATIVE_ACQ_METRIC_VALID"]==0);
    configure_radar(p);CHECK(values["F22_RADAR_ACQ_COORDINATES_READY"]==1);
    api.profile_valid=false;configure_radar(p);
    CHECK(values["F22_RADAR_ACQ_COORDINATES_READY"]==0 && *reinterpret_cast<void***>(base)==canonical);
    api.profile_valid=true;api.scan_pattern=nullptr;configure_radar(p);
    CHECK(values["F22_RADAR_ACQ_COORDINATES_READY"]==0 && values["F22_RADAR_NATIVE_CONFIG_REASON"]==6 && *reinterpret_cast<void***>(base)==canonical);
    api.scan_pattern=native_pattern;api.acquisition_update=nullptr;configure_radar(p);
    CHECK(values["F22_RADAR_ACQ_COORDINATES_READY"]==0 && values["F22_RADAR_NATIVE_CONFIG_REASON"]==6 && *reinterpret_cast<void***>(base)==canonical);
    api.acquisition_update=native_acquisition;configure_radar(p);
    // Do not overwrite a different owner's replacement table on teardown.
    void* foreign_table[1]{};*reinterpret_cast<void***>(base)=foreign_table;reset_radar_coordinates();
    CHECK(*reinterpret_cast<void***>(base)==foreign_table && values["F22_RADAR_ACQ_COORDINATES_READY"]==0);
    *reinterpret_cast<void***>(base)=canonical;configure_radar(p);
    alignas(16) std::array<std::byte,144*3> returns{};
    auto records=reinterpret_cast<std::uintptr_t>(returns.data());
    for (unsigned i=0;i<3;++i) {
        auto record=records+144*i;
        *reinterpret_cast<double*>(record)=12964+i;
        *reinterpret_cast<double*>(record+8)=5000;
        *reinterpret_cast<double*>(record+48)=-200;
        *reinterpret_cast<double*>(record+112)=98+i*.5;
        *reinterpret_cast<std::uint32_t*>(record+128)=i==2 ? 456 : 123;
    }
    *reinterpret_cast<std::uintptr_t*>(base+2168)=records;
    *reinterpret_cast<std::uintptr_t*>(base+2176)=records+returns.size();
    configure_radar(p);
    CHECK(values["F22_RADAR_OBSERVATIONS_READY"]==1 && values["F22_RADAR_OBSERVATION_COUNT"]==2);
    CHECK(values["F22O_01_ID"]==123 && values["F22O_01_NORTH"]==12965 && values["F22O_01_AGE"]==1.5);
    CHECK(values["F22O_02_ID"]==456 && values["F22O_02_ALTITUDE"]==5000 && values["F22O_02_VN"]==-200);
    *reinterpret_cast<std::uintptr_t*>(base+2176)=records+1;configure_radar(p);
    CHECK(values["F22_RADAR_OBSERVATIONS_READY"]==0 && values["F22_RADAR_OBSERVATION_COUNT"]==0);
    *reinterpret_cast<const void**>(base)=nullptr;configure_radar(p);
    CHECK(values["F22_RADAR_NATIVE_CONFIGURED"]==0 && values["F22_RADAR_NATIVE_CONFIG_REASON"]==4);
    // Actual magazine changes, empty, rearm, absent backend and ABI rejection.
    void* payload_table[71]{};payload_table[70]=reinterpret_cast<void*>(&mount);
    void** payload_object=payload_table;ammo_payload=&payload_object;api.payload=payload;
    void* gun_table[12]{};gun_table[11]=reinterpret_cast<void*>(&rounds);
    void** gun_object=gun_table;ammo_mount[1]=reinterpret_cast<std::uintptr_t>(&gun_object);
    for (unsigned count : {480u,326u,0u,480u}) {
        ammo_rounds=count;publish_gun_ammunition(p);
        CHECK(values["F22_GUN_AMMO_VALID"]==1 && values["F22_GUN_AMMO_COUNT"]==count);
    }
    ammo_payload=nullptr;publish_gun_ammunition(p);CHECK(values["F22_GUN_AMMO_VALID"]==0);
    ammo_payload=&payload_object;api.profile_valid=false;publish_gun_ammunition(p);
    CHECK(values["F22_GUN_AMMO_VALID"]==0 && values["F22_GUN_AMMO_COUNT"]==0);
    // Distinct contracts: native STT selection vs bounded-age support of a
    // previously launched TWS target. No synthetic sensor decision is implied.
    void* original_responder[4]={nullptr,reinterpret_cast<void*>(&native_tracking),
        reinterpret_cast<void*>(&native_selected),reinterpret_cast<void*>(&native_range)};
    api.responder_vtable=original_responder;api.clock=model_clock;
    support={};support.enabled=true;support.selection_enabled=true;support.stamp=100;
    support.selected=101;support.selected_until=106;support.range=30000;
    support.ids[0]=101;support.expires[0]=106;
    CHECK(support_target(nullptr)==101 && support_range(nullptr)==30000);
    CHECK(support_tracking(nullptr,101,9001));
    native_target=202;support.selection_enabled=false;
    CHECK(support_target(nullptr)==202 && support_range(nullptr)==20000);
    CHECK(support_tracking(nullptr,101,9001) && support_tracking(nullptr,202,9002));
    native_target=0;
    CHECK(support_target(nullptr)==0 && support_range(nullptr)==-1);
    CHECK(support_tracking(nullptr,101,9001));
    now_model=105.99;support.stamp=105.9;
    CHECK(support_tracking(nullptr,101,9001));
    now_model=106.01;CHECK(!support_tracking(nullptr,101,9001)); // age, not watchdog, expires it
    support.expires[0]=110;now_model=106.26;
    CHECK(!support_tracking(nullptr,101,9001)); // stopped publication also fails closed
    now_model=105.95;support.enabled=false;
    CHECK(!support_tracking(nullptr,101,9001));
    native_target=202;CHECK(support_tracking(nullptr,202,9002)); // native STT remains native
    native_target=0;now_model=100;
    // Optional shared TOF adapter: real ABI argument positions, units, cache
    // age/identity gates and immutable successful-launch snapshots. This fake
    // estimator validates the adapter contract, not native missile performance.
    api.aam_tof=aam_tof;api.tof_construct=tof_construct;api.tof_destroy=tof_destroy;
    values["HUD_MODE"]=2;values["MAIN_POWER"]=1;values["F22_WEAPON_TYPE4"]=106;
    values["F22_MISSILE_DATA_VALID"]=1;values["F22_FC_TARGET_INPUT_VALID"]=1;
    values["F22_FC_TARGET_INPUT_ID"]=101;values["F22_RADAR_WEAPON_TARGET_ID"]=101;
    values["F22_FC_OWN_ALTITUDE"]=5000;values["EFM_HUD_TAS"]=220;
    values["F22_FC_TARGET_DN"]=10000;values["F22_FC_TARGET_DU"]=0;values["F22_FC_TARGET_DE"]=0;
    values["F22_FC_TARGET_VN"]=-200;
    publish_time_estimate(p);
    CHECK(values["F22_TOF_NATIVE_VALID"]==1 && values["F22_TOF_ACT_VALID"]==1 && tof_calls==1 && tof_constructions==1);
    CHECK(tof_arguments[0]==5000 && tof_arguments[1]==220 && tof_arguments[2]==0 && tof_arguments[3]==200);
    CHECK(std::abs(tof_arguments[4]-3.141592653589793)<1e-9 && tof_arguments[5]==0);
    CHECK(tof_arguments[6]==10000 && tof_arguments[7]==5000 && tof_arguments[8]==16000);
    now_model=100.1;publish_time_estimate(p);CHECK(tof_calls==1);
    auto predicted=launch_time_estimate(101,106,2,now_model);
    CHECK(predicted.valid && predicted.tof==25 && predicted.act==12 && predicted.stamp==now_model);
    CHECK(!launch_time_estimate(202,106,2,now_model).valid && !launch_time_estimate(101,24,2,now_model).valid);
    CHECK(!launch_time_estimate(101,106,3,now_model).valid && !launch_time_estimate(101,106,2,100.36).valid);
    CHECK(!launch_time_estimate(101,106,2,99.9).valid);
    void* recording_table[51]{};recording_table[20]=reinterpret_cast<void*>(&store_type);recording_table[50]=reinterpret_cast<void*>(&launch_payload);
    payload_original=recording_table;launch_master_mode=2;
    CHECK(record_payload_launch(nullptr,2,0,101,nullptr,true)==9876);
    CHECK(launched_sequence==1 && launched[0].target==101 && launched[0].mode==2 && launched[0].estimate.valid);
    CHECK(launched[0].estimate.act==12 && launched[0].estimate.stamp==now_model);
    const auto frozen=launched[0];payload_launch_allowed=false;launch_master_mode=2;
    CHECK(record_payload_launch(nullptr,2,0,101,nullptr,true)==0 && launched_sequence==1);
    values["F22_RADAR_WEAPON_TARGET_ID"]=202;publish_time_estimate(p);
    CHECK(values["F22_TOF_NATIVE_VALID"]==0 && !launch_time_estimate(101,106,2,now_model).valid);
    CHECK(launched[0].target==frozen.target && launched[0].estimate.act==frozen.estimate.act);
    values["F22_FC_TARGET_INPUT_ID"]=202;now_model=101;fake_tof=-1;publish_time_estimate(p);
    CHECK(tof_calls==2 && values["F22_TOF_NATIVE_VALID"]==0 && values["F22_TOF_ACT_VALID"]==0);
    fake_tof=25;fake_act=std::numeric_limits<double>::quiet_NaN();now_model=102;publish_time_estimate(p);
    CHECK(values["F22_TOF_NATIVE_VALID"]==1 && values["F22_TOF_ACT_VALID"]==0);
    values["F22_WEAPON_TYPE4"]=999;publish_time_estimate(p);CHECK(values["F22_TOF_NATIVE_VALID"]==0);
    values["F22_WEAPON_TYPE4"]=106;values["F22_FC_TARGET_DU"]=std::numeric_limits<double>::quiet_NaN();publish_time_estimate(p);
    CHECK(values["F22_TOF_NATIVE_VALID"]==0 && tof_calls==3);
    const auto east=tof_body({0,0,10},0,0,3.141592653589793/2);
    CHECK(std::abs(east.x-10)<1e-9 && std::abs(east.z)<1e-9);
    const auto climb=tof_body({8.660254037844386,5,0},3.141592653589793/6,0,0);
    CHECK(std::abs(climb.x-10)<1e-9 && std::abs(climb.y)<1e-9);
    const auto bank=tof_body({0,10,0},0,3.141592653589793/2,0);
    CHECK(std::abs(bank.z+10)<1e-9 && std::abs(bank.y)<1e-9);
    for (double pitch:{-.7,0.,.7}) for (double roll:{-1.2,0.,1.2}) for (double heading:{0.,1.,4.}) {
        const auto body=tof_body({1234,-564,324},pitch,roll,heading);
        CHECK(std::abs(std::hypot(body.x,body.y,body.z)-std::hypot(1234.,-564.,324.))<1e-8);
    }
    reset();
    CHECK(tof_destructions==1 && !api.tof_constructed);
    std::cout<<"Typed seeker control: descriptor, search/track, autonomous track, launch edge, SAFE/WOW, store change, power loss; radar range/elevation configuration OK\n";
}
