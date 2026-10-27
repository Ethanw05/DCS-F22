// Offline adapter tests. Fake sensor decisions do not validate native acquisition.
#include "../EFM/source/NativeSidewinder.cpp"
namespace NativeAesaRadar { void reset() noexcept {} void update(EDPARAM&) noexcept {} }
#include <iostream>
#include <stdexcept>
#include <thread>
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
HANDLE sensor_entered = nullptr, sensor_resume = nullptr;
void update(void*,double) {
    if (sensor_entered) {
        CHECK(SetEvent(sensor_entered));
        CHECK(WaitForSingleObject(sensor_resume, 5000) == WAIT_OBJECT_0);
    }
}
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
void* ammo_payload=nullptr;
unsigned ammo_rounds=480;
std::uintptr_t ammo_mount[2]{};
void* payload() { return ammo_payload; }
void* mount(void*,unsigned char index,unsigned char sub) { CHECK(sub==255);return index==0 ? ammo_mount : nullptr; }
unsigned rounds(void*) { return ammo_rounds; }
double now_model=100;
double model_clock() { return now_model; }
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
unsigned payload_target=0;std::array<float,3> payload_point{};
const NativeSidewinder::WeaponType* store_type(void*,unsigned) {return &launched_type;}
unsigned launch_payload(void*,unsigned,unsigned,unsigned target,const float* point,bool) {
    payload_target=target;if(point)for(unsigned i=0;i<3;++i)payload_point[i]=point[i];
    // A native release callback may be followed immediately by a mode change.
    NativeSidewinder::launch_master_mode=3;return payload_launch_allowed ? 9876 : 0;
}

void overlapping_reset(EDPARAM& p) {
    sensor_entered = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    sensor_resume = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    const auto resetting = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    const auto retired = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    CHECK(sensor_entered && sensor_resume && resetting && retired);
    std::exception_ptr callback_error;
    std::thread callback([&] {
        try { NativeSidewinder::update(p, .02); } catch (...) { callback_error = std::current_exception(); }
    });
    const bool entered = WaitForSingleObject(sensor_entered, 5000) == WAIT_OBJECT_0;
    const auto ticks = NativeSidewinder::tick_sequence;
    NativeSidewinder::update(p, .02); // Must return immediately while the first sensor is busy.
    const bool skipped = NativeSidewinder::tick_sequence == ticks;
    std::thread teardown([&] {
        SetEvent(resetting);
        NativeSidewinder::reset(&p);
        SetEvent(retired);
    });
    const bool started = WaitForSingleObject(resetting, 5000) == WAIT_OBJECT_0;
    const bool drained = WaitForSingleObject(retired, 50) == WAIT_TIMEOUT;
    SetEvent(sensor_resume);
    callback.join();
    teardown.join();
    CloseHandle(sensor_entered); CloseHandle(sensor_resume);
    CloseHandle(resetting); CloseHandle(retired);
    sensor_entered = nullptr; sensor_resume = nullptr;
    if (callback_error) std::rethrow_exception(callback_error);
    CHECK(entered && skipped && started && drained);
}
}
int scenarios() {
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
    api.clock=model_clock;
    api.gimbal_limit=scalar;api.sun_filter=sun_filter;api.motor_limits=motor_limits;
    void* context[3]={nullptr,nullptr,&p};void** context_ptr=context;api.contexts=&context_ptr;
    vtable[64]=reinterpret_cast<void*>(&launcher);
    values["MAIN_POWER"]=1;values["F22_IR_MODE"]=3;values["F22_IR_STATION"]=0;
    values["F22_IR_EXPOSURE_VALID"]=1;values["F22_IR_EXPOSED"]=1;
    values["F22_IR_EXPOSURE_TIME"]=now_model;
    values["F22_IR_TYPE1"]=4;values["F22_IR_TYPE2"]=4;values["F22_IR_TYPE3"]=7;
    values["F22_IR_TYPE4"]=136;values["F22_RADAR_STT_VALID"]=1;
    values["MASTER_ARM"]=1;values["WoW"]=0;
    start_feedback();
    values["F22_IR_CAGED"]=1;update(p,.02);
    CHECK(values["F22_IR_STATE"]==1 && slaves==0 && !consent);
    CHECK(values["F22_IR_SAMPLE_OWNER"]==1 && values["F22_IR_SAMPLE_SCHEMA"]==1);
    CHECK(values["F22_IR_SAMPLE_VALID"]==1 && values["F22_IR_SAMPLE_SEQUENCE"]==2);
    CHECK(values["F22_IR_SAMPLE_TIME"]==now_model && values["F22_IR_SAMPLE_STATION"]==0);
    CHECK(values["F22_IR_SAMPLE_GENERATION"]==values["F22_IR_STORE_GENERATION"]);
    EDPARAM missing_api=p;
    missing_api.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=nullptr;
    const auto previous_feedback_sequence=ir_feedback.sequence;
    update(missing_api,.02);
    CHECK(ir_feedback.sequence==previous_feedback_sequence && creations==1);
    update(p,0);
    CHECK(values["F22_IR_SAMPLE_VALID"]==0 && values["F22_IR_SAMPLE_SEQUENCE"]==3);
    update(p,.02);
    CHECK(values["F22_IR_SAMPLE_VALID"]==1 && values["F22_IR_SAMPLE_SEQUENCE"]==6);
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
    // Achieved exposure and weapon generation bound the actual native sensor.
    const int before_generation=creations;
    const int before_generation_launches=launches;
    values["MAIN_POWER"]=1;values["WoW"]=0;values["F22_IR_CAGED"]=0;
    values["F22_IR_STORE_GENERATION"]=42;values["F22_IR_RELEASE_REQUEST"]=1;
    sensor_track=true;update(p,.02);
    CHECK(creations==before_generation+1 && values["F22_IR_AVAILABLE"]==1);
    values["F22_IR_STORE_GENERATION"]=43;update(p,.02);
    CHECK(creations==before_generation+2 && launches==before_generation_launches);
    CHECK(values["F22_IR_SAMPLE_GENERATION"]==43);
    values["F22_IR_EXPOSED"]=0;update(p,.02);
    CHECK(values["F22_IR_AVAILABLE"]==0 && values["F22_IR_LOCK"]==0);
    CHECK(values["F22_IR_SAMPLE_VALID"]==0 && std::fmod(values["F22_IR_SAMPLE_SEQUENCE"],2)==1);
    values["F22_IR_EXPOSED"]=1;values["F22_IR_EXPOSURE_TIME"]=now_model-.2;update(p,.02);
    CHECK(values["F22_IR_AVAILABLE"]==0);
    values["F22_IR_EXPOSURE_TIME"]=now_model;update(p,.02);
    CHECK(values["F22_IR_AVAILABLE"]==1 && launches==before_generation_launches);
    for (double bad:{std::numeric_limits<double>::quiet_NaN(),
                     std::numeric_limits<double>::infinity(),1.5,11.}) {
        values["F22_IR_STATION"]=bad;update(p,.02);
        CHECK(values["F22_IR_AVAILABLE"]==0 && launches==before_generation_launches);
    }
    values["F22_IR_STATION"]=0;
    for (double bad:{-1.,std::numeric_limits<double>::quiet_NaN(),4294967296.}) {
        values["F22_IR_TYPE4"]=bad;update(p,.02);
        CHECK(values["F22_IR_AVAILABLE"]==0);
    }
    values["MAIN_POWER"]=0;update(p,.02);
    // A live-parameter reset invalidates publication before disposal. Late
    // callback delivery cannot reconstruct the seeker or republish a sample.
    values["F22_IR_TYPE4"]=136;values["MAIN_POWER"]=1;values["F22_IR_RELEASE_REQUEST"]=0;
    start_feedback();update(p,.02);CHECK(values["F22_IR_SAMPLE_VALID"]==1);
    const int before_retire_creations=creations;
    overlapping_reset(p);
    CHECK(values["F22_IR_SAMPLE_VALID"]==0 && !ir_feedback.accepting);
    CHECK(handles.empty() && !constructed);
    for (const auto pointer : ir_feedback.handles) CHECK(pointer==nullptr);
    update(p,.02);
    CHECK(creations==before_retire_creations && values["F22_IR_SAMPLE_VALID"]==0);
    // Restart is explicit; it does not treat held consent as a new press.
    api.ready=true;api.error=0; // Existing fake API functions remain bound.
    values["F22_IR_RELEASE_REQUEST"]=1;start_feedback();update(p,.02);
    CHECK(values["F22_IR_SAMPLE_VALID"]==1 && launches==before_generation_launches);
    values["MAIN_POWER"]=0;update(p,.02);
    api.profile_valid=true;
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
    api.clock=model_clock;api.profile_valid=true;now_model=100;
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
    const unsigned before_jettison=launched_sequence;
    CHECK(record_payload_launch(nullptr,2,0,101,nullptr,false)==9876);
    CHECK(launched_sequence==before_jettison);
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
    // Every custom type uses its own checked Rocket_Const, never enum1/C data.
    alignas(8) std::array<std::byte,324> descriptor{};
    *reinterpret_cast<unsigned*>(descriptor.data()+168)=999;
    selected_missile_descriptor=reinterpret_cast<std::uintptr_t>(descriptor.data());
    api.descriptor_flight=[](const void* rocket,float altitude,float range,float cosine,float speed,float* average,double* time)->float{
        CHECK(*reinterpret_cast<const unsigned*>(static_cast<const std::byte*>(rocket)+168)==999);
        CHECK(altitude==5000 && range==10000 && cosine==-1 && speed==200);
        *average=900;*time=20;return 18000;
    };
    values["F22_MISSILE_LIFETIME"]=170;now_model=103;publish_time_estimate(p);
    CHECK(values["F22_TOF_NATIVE_VALID"]==1 && values["F22_TOF_SOURCE"]==2 && values["F22_TOF_SECONDS"]==20);
    CHECK(values["F22_TOF_ACT_VALID"]==0 && tof_calls==3);
    predicted=launch_time_estimate(202,999,2,now_model);CHECK(predicted.source==2 && predicted.life==170 && !predicted.act_valid);
    values["HUD_MODE"]=3;now_model=103.3;publish_time_estimate(p);
    CHECK(values["F22_TOF_NATIVE_VALID"]==1 && values["F22_TOF_SOURCE"]==2);
    values["F22_MISSILE_LIFETIME"]=5;now_model=103.6;publish_time_estimate(p);
    CHECK(values["F22_TOF_NATIVE_VALID"]==0);
    *reinterpret_cast<unsigned*>(descriptor.data()+168)=777;now_model=104;publish_time_estimate(p);
    CHECK(values["F22_TOF_NATIVE_VALID"]==0);
    selected_missile_descriptor=0;api.descriptor_flight=nullptr;values["HUD_MODE"]=2;
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
    payload_launch_allowed=true;launched_type={4,5,36,0,85};launch_master_mode=7;
    values["F22_IR_MODE"]=7;values["HUD_AG_SUBMODE"]=3;values["F22_AG_DELIVERY_TARGET_VALID"]=1;
    values["F22_AG_GUIDED_SELECTED"]=1;values["MASTER_ARM"]=1;values["MAIN_POWER"]=1;values["WoW"]=0;
    values["F22_AG_SOLUTION_VALID"]=1;values["F22_AG_SOLUTION_TIME"]=now_model;values["F22_WEAPON_STATION"]=4;values["F22_AG_SOLUTION_STATION"]=4;
    values["F22_AG_DELIVERY_TARGET_N"]=10000;values["F22_AG_DELIVERY_TARGET_U"]=300;values["F22_AG_DELIVERY_TARGET_E"]=-2000;
    values["HUD_MODE"]=7;values["F22_AG_RELEASE_CONSENT"]=1;values["F22_AG_SOLUTION_SEQUENCE"]=501;values["F22_AG_SOLUTION_SCHEMA"]=2;
    values["F22_AG_DELIVERY_TARGET_SOURCE"]=2;values["F22_AG_DELIVERY_TARGET_SEQUENCE"]=10;
    values["F22_AG_SOLUTION_TARGET_VALID"]=1;values["F22_AG_SOLUTION_TARGET_SOURCE"]=2;values["F22_AG_SOLUTION_TARGET_SEQUENCE"]=10;
    values["F22_AG_SOLUTION_TARGET_N"]=10000;values["F22_AG_SOLUTION_TARGET_U"]=300;values["F22_AG_SOLUTION_TARGET_E"]=-2000;
    update_ground_release(p);float original_point[]={1,2,3};
    CHECK(values["F22_AG_GUIDANCE_CACHE_VALID"]==1&&values["F22_AG_GUIDANCE_CACHE_STATION"]==4&&values["F22_AG_GUIDANCE_CACHE_SOLUTION_SEQUENCE"]==501);
    CHECK(record_payload_launch(nullptr,4,0,987,original_point,true)==9876);
    CHECK(payload_target==0&&payload_point[0]==10000&&payload_point[1]==300&&payload_point[2]==-2000);
    launch_master_mode=7;CHECK(record_payload_launch(nullptr,3,0,0,original_point,true)==0);
    // Same-station edits cannot use a prepared coordinate before the next
    // native update, nor may old ballistic identity certify a new target.
    values["F22_AG_DELIVERY_TARGET_N"]=11000;values["F22_AG_DELIVERY_TARGET_SEQUENCE"]=11;
    launch_master_mode=7;CHECK(record_payload_launch(nullptr,4,0,0,original_point,true)==0);
    update_ground_release(p);CHECK(values["F22_AG_GUIDANCE_CACHE_VALID"]==0);
    values["F22_AG_SOLUTION_TARGET_N"]=11000;values["F22_AG_SOLUTION_TARGET_SEQUENCE"]=11;values["F22_AG_SOLUTION_SEQUENCE"]=502;
    update_ground_release(p);CHECK(values["F22_AG_GUIDANCE_CACHE_VALID"]==1);
    values["F22_AG_RELEASE_CONSENT"]=0;launch_master_mode=7;CHECK(record_payload_launch(nullptr,4,0,0,original_point,true)==0);
    values["F22_AG_RELEASE_CONSENT"]=1;values["F22_AG_SOLUTION_SEQUENCE"]=503;
    launch_master_mode=7;CHECK(record_payload_launch(nullptr,4,0,0,original_point,true)==0);
    update_ground_release(p);launch_master_mode=7;CHECK(record_payload_launch(nullptr,4,0,0,original_point,true)==9876);
    CHECK(payload_point[0]==11000);
    // Unarmed jettison bypasses target transfer/consent without generating a shot.
    const unsigned before_guided_jettison=launched_sequence;
    values["F22_AG_RELEASE_CONSENT"]=0;
    CHECK(record_payload_launch(nullptr,4,0,0,original_point,false)==9876);
    CHECK(launched_sequence==before_guided_jettison && payload_point[0]==1);
    values["F22_AG_RELEASE_CONSENT"]=1;
    values["MASTER_ARM"]=0;launch_master_mode=7;CHECK(record_payload_launch(nullptr,4,0,0,original_point,true)==0);values["MASTER_ARM"]=1;
    values["F22_AG_SOLUTION_TIME"]=now_model-.19;update_ground_release(p);CHECK(values["F22_AG_GUIDANCE_CACHE_VALID"]==1);
    now_model+=.02;launch_master_mode=7;CHECK(record_payload_launch(nullptr,4,0,0,original_point,true)==0);
    values["F22_AG_SOLUTION_TIME"]=now_model;update_ground_release(p);
    launch_master_mode=7;now_model+=1;CHECK(record_payload_launch(nullptr,4,0,0,original_point,true)==0);
    launched_type={4,4,7,0,106};launch_master_mode=2;
    CHECK(record_payload_launch(nullptr,4,0,987,original_point,true)==9876);
    CHECK(payload_target==987&&payload_point[0]==1&&payload_point[1]==2&&payload_point[2]==3);
    reset();
    CHECK(tof_destructions==1 && !api.tof_constructed);
    std::cout<<"Typed seeker control: descriptor, search/track, autonomous track, launch edge, SAFE/WOW, store change, power loss; payload/TOF integration PASS\n";
 return 0;
}

int main(){try{return scenarios();}catch(const std::exception& error){std::cerr<<error.what()<<"\n";return 1;}}
