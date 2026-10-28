// GPL-3.0-or-later. Our adapter/control policy; no Hornet binary dependency.
// ABI reference: Standalone-F22-IDA-Research.md, typed Sidewinder investigation.
// Runtime validation is still required. Reject a different CockpitBase ABI.
#include "NativeSidewinder.h"
#include "NativeAesaRadar.h"
#include "WeaponFlightFrame.h"
#include "GroundTargetPacket.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <array>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <map>
#include <limits>
#include <string>

namespace NativeSidewinder {
namespace {
struct WeaponType {
    std::uint8_t level1{}, level2{}, level3{}, padding{};
    std::uint32_t level4{};
    bool operator==(const WeaponType&) const = default;
};
static_assert(sizeof(WeaponType)==8);
struct Pose { double m[16]{}; };
struct LauncherPose { float m[16]{}; };
struct Direction { double x{}, y{}, z{}; };
// Model connector transforms can carry scale/shear. avPlatform's IR angular
// gate assumes an orthonormal rigid pose (dot(direction, forward) >= cos(FOV)).
bool normalize_mount_pose(Pose& p) {
    for (double value:p.m) if (!std::isfinite(value)) return false;
    auto norm=[](double* v) {
        double length=std::hypot(v[0],v[1],v[2]);
        if (length<1e-8) return false;
        for (int i=0;i<3;++i) v[i]/=length;
        return true;
    };
    if (!norm(p.m)) return false;
    double dot=0;for (int i=0;i<3;++i) dot+=p.m[i]*p.m[4+i];
    for (int i=0;i<3;++i) p.m[4+i]-=dot*p.m[i];
    if (!norm(p.m+4)) return false;
    double right[]={p.m[1]*p.m[6]-p.m[2]*p.m[5],p.m[2]*p.m[4]-p.m[0]*p.m[6],p.m[0]*p.m[5]-p.m[1]*p.m[4]};
    double handedness=0;for (int i=0;i<3;++i) handedness+=right[i]*p.m[8+i];
    if (handedness<=1e-8) return false;
    for (int i=0;i<3;++i) p.m[8+i]=right[i];
    p.m[3]=p.m[7]=p.m[11]=0;p.m[15]=1;
    return true;
}
// Conservative virtual sensor aperture for the internal-bay model. The shared
// IR sensor's search ray can stop at its own aircraft mesh. This moves only
// the observation origin along its mounting axis; native station launch stays
// at the actual hardpoint. Bounds are parsed from Shapes/F-22A.EDM RootNode.
constexpr double model_min[]={-7.807378768920898,-2.015413522720337,-6.808021068572998};
constexpr double model_max[]={11.57210636138916,3.4293808937072754,6.808021068572998};
double clear_observation_aperture(Pose& pose,const double* low,const double* high) {
    for (int i=0;i<3;++i) if (pose.m[12+i]<low[i] || pose.m[12+i]>high[i]) return 0;
    double exit=1e9;
    for (int i=0;i<3;++i) {
        const double direction=pose.m[i];
        if (std::abs(direction)>1e-8) {
            const double face=direction>0 ? high[i] : low[i];
            exit=std::min(exit,(face-pose.m[12+i])/direction);
        }
    }
    const double travel=exit+.05;
    for (int i=0;i<3;++i) pose.m[12+i]+=travel*pose.m[i];
    return travel;
}

struct Api {
    using Construct = void* (__fastcall*)(void*, const WeaponType*);
    using Method = void (__fastcall*)(void*);
    using Boolean = void (__fastcall*)(void*, bool);
    using Test = bool (__fastcall*)(void*);
    using Status = void (__fastcall*)(void*, unsigned);
    using Station = void (__fastcall*)(void*, int, int);
    using Update = void (__fastcall*)(void*, double);
    using Slave = void (__fastcall*)(void*, const Direction*);
    using Boresight = void (__fastcall*)(void*, const Pose*);
    using Strength = float (__fastcall*)(void*);
    using Seeker = const void* (__fastcall*)(const void*);
    // MSVC member-function aggregate return: this=RCX, result buffer=RDX.
    using LocalPose = Pose* (__fastcall*)(const void*, Pose*);
    using Launch = unsigned (__fastcall*)(void*, void*);
    using Aircraft = void* (__cdecl*)();
    using Clock = double (__cdecl*)();
    using Device = void* (__fastcall*)(void*, unsigned);
    using Scalar = void (__fastcall*)(void*, float);
    using MotorLimits = void (__fastcall*)(void*, double, double);
    using Launcher = void (__fastcall*)(void*, LauncherPose*, unsigned char, unsigned char);
    Construct construct{};
    Method destroy{}, initialize{}, uncage{}, to_boresight{};
    Boolean power{}, consent{};
    Status status{};
    Station station{};
    Update update{};
    Slave slave{};
    Boresight boresight{};
    Test tracking{};
    Strength strength{};
    Seeker seeker{},platform_position{};
    LocalPose local_pose{};
    Launch launch{};
    Aircraft aircraft{}, binding_context{}, payload{};
    Clock clock{};
    Device device{};
    const void* weapon_vtable{};
    const void* missile_vtable{};
    const void* guided_vtable{};
    const void* homing_vtable{};
    using DLZ=void (__fastcall*)(const void*,float,float,float,float,const float*,const float*,const float*,float*,float*,float*);
    DLZ dlz{};
    // Generic selected-descriptor estimator, independent of the stock AAM enum.
    // Weapons 0x180121dc0: altitude, slant range, target aspect cosine, target
    // speed; outputs average flyout velocity and flight time in SI units.
    using DescriptorFlight=float (__fastcall*)(const void*,float,float,float,float,float*,double*);
    DescriptorFlight descriptor_flight{};
    // Shared WeaponsBase export; nine SI/radian inputs, auxiliary ACT output,
    // TOFE::AAM enum, Sparrow high-power flag. This is not a Hornet import.
    using AAMTOF=double (__fastcall*)(void*,double,double,double,double,double,double,double,double,double,double*,int,bool);
    using TOFConstruct=void* (__fastcall*)(void*);
    AAMTOF aam_tof{};
    TOFConstruct tof_construct{};
    Method tof_destroy{};
    std::uintptr_t tof_object{}; // Verified constructor writes exactly 8 bytes.
    bool tof_constructed=false,tof_rejected=false;
    using FindObject=void* (__fastcall*)(unsigned);
    using ActiveDistance=float (__fastcall*)(void*);
    FindObject find_object{};
    ActiveDistance active_distance{};
    Scalar gimbal_limit{}, sun_filter{};
    MotorLimits motor_limits{};
    void*** contexts{};
    bool ready=false;
    bool profile_valid=false;
    int error=1;

    void resolve_tof() {
        if (aam_tof || tof_rejected) return;
        auto module=GetModuleHandleW(L"WeaponsBase.dll");if (!module) return;
        const auto base=reinterpret_cast<const std::byte*>(module);
        const auto dos=reinterpret_cast<const IMAGE_DOS_HEADER*>(base);
        const auto pe=reinterpret_cast<const IMAGE_NT_HEADERS64*>(base+dos->e_lfanew);
        if (pe->FileHeader.TimeDateStamp!=0x6aae1e3b || pe->OptionalHeader.SizeOfImage!=0xeb000) {tof_rejected=true;return;}
        tof_construct=reinterpret_cast<TOFConstruct>(GetProcAddress(module,"??0TOFEstimator@@QEAA@XZ"));
        tof_destroy=reinterpret_cast<Method>(GetProcAddress(module,"??1TOFEstimator@@QEAA@XZ"));
        if (tof_construct && tof_destroy)
            aam_tof=reinterpret_cast<AAMTOF>(GetProcAddress(module,"?getAAMTOF@TOFEstimator@@QEAANNNNNNNNNNPEANW4AAM@TOFE@@_N@Z"));
        if (!aam_tof) tof_rejected=true;
    }

    template<class T> bool bind(HMODULE module, T& fn, const char* symbol) {
        fn=reinterpret_cast<T>(GetProcAddress(module,symbol));
        return fn!=nullptr;
    }
    void resolve() {
        if (ready || error>1) return;
        HMODULE module=GetModuleHandleW(L"CockpitBase.dll");
        if (!module) return;
        const auto base=reinterpret_cast<const std::byte*>(module);
        const auto dos=reinterpret_cast<const IMAGE_DOS_HEADER*>(base);
        const auto pe=reinterpret_cast<const IMAGE_NT_HEADERS64*>(base+dos->e_lfanew);
        if (pe->FileHeader.TimeDateStamp!=0x6ac12468 || pe->OptionalHeader.SizeOfImage!=0x59a000) {
            error=2;return;
        }
        profile_valid=true;
        weapon_vtable=GetProcAddress(module,"??_7avSimpleWeaponSystem@cockpit@@6BccContextRelatedObject@1@@");
        find_object=reinterpret_cast<FindObject>(const_cast<std::byte*>(base)+0x2165d0);
        auto weapons_module=GetModuleHandleW(L"Weapons.dll");
        if (weapons_module) {
            auto wb=reinterpret_cast<const std::byte*>(weapons_module);
            auto wd=reinterpret_cast<const IMAGE_DOS_HEADER*>(wb);
            auto wp=reinterpret_cast<const IMAGE_NT_HEADERS64*>(wb+wd->e_lfanew);
            if (wp->FileHeader.TimeDateStamp==0x6ac12438 && wp->OptionalHeader.SizeOfImage==0x21f000) {
                homing_vtable=GetProcAddress(weapons_module,"??_7wAmmunitionSelfHoming@@6BviObject@@@");
                guided_vtable=GetProcAddress(weapons_module,"??_7wAmmunitionGuided@@6BviObject@@@");
                dlz=reinterpret_cast<DLZ>(GetProcAddress(weapons_module,"?DLZ@@YAXPEAURocket_Const@@MMMMAEBVVec3f@osg@@11AEAM22@Z"));
                descriptor_flight=reinterpret_cast<DescriptorFlight>(GetProcAddress(weapons_module,"?getDFlight@Rocket_Const@@QEBAMMMMMAEAMAEAN@Z"));
                missile_vtable=GetProcAddress(weapons_module,"??_7woMissile@@6BviObject@@@");
                active_distance=reinterpret_cast<ActiveDistance>(GetProcAddress(weapons_module,"?getActiveLockDist@woMissile@@QEAAMXZ"));
            }
        }
        // Optional read-only gun-ammunition source; absence does not disable IR.
        bind(module,payload,"?c_payload@cockpit@@YAPEAVIwHumanPayload@@XZ");
        bool ok=true;
#define BIND(field,symbol) ok=bind(module,field,symbol)&&ok
        BIND(construct,"??0eqSidewinderNew@cockpit@@QEAA@AEBVwsType@@@Z");
        BIND(destroy,"??1eqSidewinderNew@cockpit@@UEAA@XZ");
        BIND(initialize,"?initialize@eqSidewinderNew@cockpit@@UEAAXXZ");
        BIND(uncage,"?uncage@eqSidewinderNew@cockpit@@QEAAXXZ");
        BIND(to_boresight,"?toBoresight@eqSidewinderNew@cockpit@@QEAAXXZ");
        BIND(power,"?setElecPower@eqSidewinder@cockpit@@UEAAX_N@Z");
        BIND(consent,"?setConsentToTrack@eqSidewinderNew@cockpit@@QEAAX_N@Z");
        BIND(status,"?setStatus@eqSidewinder@cockpit@@QEAAXI@Z");
        BIND(station,"?set_station@eqSidewinder@cockpit@@QEAAXHH@Z");
        BIND(update,"?update@eqSidewinderNew@cockpit@@UEAAXN@Z");
        BIND(slave,"?slaveToDirection@eqSidewinderNew@cockpit@@QEAAXAEBVVec3d@osg@@@Z");
        BIND(boresight,"?setBoresight@eqSidewinderNew@cockpit@@QEAAXV?$wPosition3@N@@@Z");
        BIND(tracking,"?isInTrack@eqSidewinderNew@cockpit@@QEAA_NXZ");
        BIND(strength,"?getLockStrength@eqSidewinderNew@cockpit@@QEAAMXZ");
        BIND(seeker,"?getSeeker@eqSidewinder@cockpit@@QEBAAEBVavSidewinderSeeker@2@XZ");
        BIND(local_pose,"?getPlatformLocalPosition@avPlatform@cockpit@@QEBA?AV?$wPosition3@N@@XZ");
        bind(module,platform_position,"?getPlatformPosition@avPlatform@cockpit@@QEBAAEBV?$wPosition3@N@@XZ");
        BIND(launch,"?launch@eqSidewinder@cockpit@@QEAAIPEAVIwHumanPlane@@@Z");
        BIND(aircraft,"?c_LA@cockpit@@YAPEAVIwoLA@@XZ");
        BIND(binding_context,"?binding_context@cockpit@@YAPEAVccCockpitContext@1@XZ");
        BIND(device,"?get_wide_device@ccCockpitContext@cockpit@@QEAAPEAVavDevice@2@I@Z");
        BIND(gimbal_limit,"?setGimbalLimit@avSidewinderSeeker@cockpit@@QEAAXM@Z");
        BIND(sun_filter,"?setSunFilter@avSidewinderSeeker@cockpit@@QEAAXM@Z");
        BIND(motor_limits,"?set_limits@avMotor@cockpit@@QEAAXNN@Z");
        contexts=reinterpret_cast<void***>(GetProcAddress(module,"?contexts_ptr@ccCockpitContext@cockpit@@0PAPEAV12@A"));
#undef BIND
        auto world=GetModuleHandleW(L"World.dll");
        clock=world ? reinterpret_cast<Clock>(GetProcAddress(world,"?GetModelTime@wTime@@SANXZ")) : nullptr;
        ready=ok && contexts;error=ready ? 0 : 3;
    }
};
Api api;
// Allocation extent of eqSidewinderNew in this verified simulator build.
alignas(16) std::array<std::byte,0x480> object{};
bool constructed=false;
WeaponType current_type{};
bool current_aim9x=false;
int current_station=-1;
double current_store_generation=-1;
bool was_caged=true, was_release=false;
bool head_released=false;
unsigned launch_sequence=0, launch_id=0;
unsigned tick_sequence=0;
SRWLOCK feedback_lifetime_lock = SRWLOCK_INIT;
enum class FeedbackAccess { Callback, Lifecycle };
class FeedbackGuard {
    bool held_ = false;
public:
    explicit FeedbackGuard(FeedbackAccess access) {
        if (access == FeedbackAccess::Lifecycle) {
            AcquireSRWLockExclusive(&feedback_lifetime_lock);
            held_ = true;
        } else {
            held_ = TryAcquireSRWLockExclusive(&feedback_lifetime_lock) != 0;
        }
    }
    ~FeedbackGuard() {
        if (held_) ReleaseSRWLockExclusive(&feedback_lifetime_lock);
    }
    FeedbackGuard(const FeedbackGuard&) = delete;
    FeedbackGuard& operator=(const FeedbackGuard&) = delete;
    explicit operator bool() const { return held_; }
};
// Fixed publication metadata; World model seconds, independent of RAPTOR time.
struct IrFeedbackPublication {
    enum Field : unsigned { Owner, Schema, Valid, Sequence, Time, Station, Generation, Count };
    std::array<void*, Count> handles{};
    unsigned sequence = 0;
    bool accepting = false;
    bool begin(EDPARAM& p) {
        if (!accepting || !p.ed_param_api.pfn_ed_cockpit_get_parameter_handle ||
            !p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number ||
            !p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number) return false;
        constexpr std::array<const char*, Count> names = {"F22_IR_SAMPLE_OWNER", "F22_IR_SAMPLE_SCHEMA",
            "F22_IR_SAMPLE_VALID", "F22_IR_SAMPLE_SEQUENCE", "F22_IR_SAMPLE_TIME",
            "F22_IR_SAMPLE_STATION", "F22_IR_SAMPLE_GENERATION"};
        for (unsigned index = 0; index < Count; ++index) {
            if (!handles[index]) handles[index] = p.getParamHandle(names[index]);
            if (!handles[index]) return false;
        }
        p.setParamNumber(handles[Owner], 1);
        p.setParamNumber(handles[Schema], 1);
        p.setParamNumber(handles[Valid], 0);
        sequence = sequence >= 16777214 ? 2 : sequence + 2;
        p.setParamNumber(handles[Sequence], sequence - 1); // Odd until committed.
        return true;
    }
    void commit(EDPARAM& p, double time, int station, double generation) const {
        p.setParamNumber(handles[Time], time);
        p.setParamNumber(handles[Station], station);
        p.setParamNumber(handles[Generation], generation);
        p.setParamNumber(handles[Valid], 1);
        p.setParamNumber(handles[Sequence], sequence); // Publish completion last.
    }
};
IrFeedbackPublication ir_feedback;
std::map<std::string,void*> handles;
bool read(EDPARAM& p,const char* name,double& value) {
    auto& h=handles[name];if (!h) h=p.getParamHandle(name);
    return p.getParamNumber(h,value);
}
template<std::size_t N>
bool read_fields(EDPARAM& p,const std::array<const char*,N>& names,std::array<double,N>& values) {
    const auto epoch=p.epoch();
    for(std::size_t i=0;i<N;++i)if(!read(p,names[i],values[i]))return false;
    return epoch==p.epoch();
}
struct IrControls {
    enum Field : std::size_t { Mode,Power,ExposureTime,ExposureValid,Exposed,Generation,Aim9x,
        Release,Caged,MasterArm,WoW,Count };
    static constexpr std::array<const char*,Count> names{{"F22_IR_MODE","MAIN_POWER",
        "F22_IR_EXPOSURE_TIME","F22_IR_EXPOSURE_VALID","F22_IR_EXPOSED","F22_IR_STORE_GENERATION",
        "F22_IR_AIM9X_PROFILE","F22_IR_RELEASE_REQUEST","F22_IR_CAGED","MASTER_ARM","WoW"}};
    std::array<double,Count> value{};
    bool load(EDPARAM& p) {
        if(!read_fields(p,names,value))return false;
        for(const auto field:{Power,ExposureValid,Exposed,Aim9x,Release,Caged,MasterArm,WoW})
            if(value[field]!=0 && value[field]!=1)return false;
        return value[Mode]>=0 && value[Mode]<=10 && value[Mode]==std::floor(value[Mode]);
    }
};
void write(EDPARAM& p,const char* name,double value) {
    auto& h=handles[name];if (!h) h=p.getParamHandle(name);
    p.setParamNumber(h,value);
}
void dispose() {
    if (constructed) { api.power(object.data(),false);api.destroy(object.data()); }
    constructed=false;current_station=-1;current_store_generation=-1;
    was_caged=true;was_release=false;head_released=false;
}
bool readable(std::uintptr_t address,std::size_t size) {
    MEMORY_BASIC_INFORMATION info{};
    if (!address || !VirtualQuery(reinterpret_cast<void*>(address),&info,sizeof(info))) return false;
    auto end=reinterpret_cast<std::uintptr_t>(info.BaseAddress)+info.RegionSize;
    return info.State==MEM_COMMIT && !(info.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && address+size<=end;
}
struct TimeEstimate {
    unsigned target=0,type=0;
    double stamp=0,tof=0,act=0;
    bool valid=false,act_valid=false;
    unsigned source=0,mode=0;double life=1000;
    double physical_generation=0;
    const EDPARAM* parameter_owner=nullptr;
    std::uint64_t parameter_epoch=0;
};
SRWLOCK time_estimate_lock=SRWLOCK_INIT;
TimeEstimate time_estimate{};
double last_tof_attempt=-1e9;
unsigned last_tof_target=0,last_tof_type=0;
TimeEstimate launch_time_estimate(unsigned target,unsigned type,unsigned mode,double now) {
    AcquireSRWLockShared(&time_estimate_lock);auto value=time_estimate;ReleaseSRWLockShared(&time_estimate_lock);
    if ((mode!=2 && mode!=3) || value.mode!=mode || value.target!=target || value.type!=type || now<value.stamp || now-value.stamp>.35) return {};
    // Sampling age gates the geometry's freshness. The weapon has not flown
    // during that sampling delay; its countdown starts at successful release.
    value.stamp=now;
    return value;
}
struct LaunchEvent {unsigned sequence=0,id=0,target=0,station=0,type=0,mode=0;double time=0;TimeEstimate estimate{};};
SRWLOCK launch_lock=SRWLOCK_INIT;
std::array<LaunchEvent,16> launched{};
unsigned launched_sequence=0;
std::atomic<unsigned> launch_master_mode{0};
std::array<void*,193> payload_table{};
void** payload_slot=nullptr;
void** payload_original=nullptr;
using PayloadLaunch=unsigned (__fastcall*)(void*,unsigned,unsigned,unsigned,const float*,bool);
constexpr std::array<const char*,26> ground_live_names={
    "F22_AG_RELEASE_CONSENT","MAIN_POWER","MASTER_ARM","WoW","HUD_MODE","HUD_AG_SUBMODE","F22_WEAPON_STATION",
    "F22_AG_SOLUTION_VALID","F22_AG_SOLUTION_STATION","F22_AG_SOLUTION_SEQUENCE","F22_AG_SOLUTION_TIME",
    "F22_AG_DELIVERY_TARGET_VALID","F22_AG_SOLUTION_TARGET_VALID","F22_AG_DELIVERY_TARGET_SOURCE","F22_AG_SOLUTION_TARGET_SOURCE",
    "F22_AG_DELIVERY_TARGET_SEQUENCE","F22_AG_SOLUTION_TARGET_SEQUENCE","F22_AG_DELIVERY_TARGET_N","F22_AG_SOLUTION_TARGET_N",
    "F22_AG_DELIVERY_TARGET_U","F22_AG_SOLUTION_TARGET_U","F22_AG_DELIVERY_TARGET_E","F22_AG_SOLUTION_TARGET_E","F22_AG_SOLUTION_SCHEMA",
    "F22_IR_MODE","F22_AG_GUIDED_SELECTED"};
struct GroundHandles {
    EDPARAM* owner{};std::uint64_t context{};
    std::array<void*,ground_live_names.size()> values{};
    void invalidate(){owner=nullptr;context=0;values.fill(nullptr);}
    bool bind(EDPARAM& p){
        if(owner==&p&&context==p.epoch()&&p.numericReady())return true;
        invalidate();const auto before=p.epoch();
        if(!p.numericReady()||!GroundTargetPacket::bind_handles(p,values,ground_live_names)||before!=p.epoch())return false;
        owner=&p;context=before;return true;
    }
} ground_handles;
GroundTargetPacket::Reader ground_target_reader;
struct GroundRelease {
    bool valid=false;unsigned station=0;double delivery_mode=0,stamp=-100,solution_time=0,solution_sequence=0,target_source=0,target_sequence=0;
    std::array<float,3> point{};std::array<double,3> identity_point{};EDPARAM* parameters=nullptr;
    std::array<void*,ground_live_names.size()> live_handles{};
    std::uint64_t parameter_epoch=0;
    GroundTargetPacket::Target target{};GroundTargetPacket::Binding target_binding{};
};
bool ground_values(const GroundRelease& g,std::array<double,ground_live_names.size()>& live) {
    if(!g.parameters||g.target_binding.port!=g.parameters||g.parameters->epoch()!=g.parameter_epoch||g.parameter_epoch!=g.target_binding.context)return false;
    double sequence{},valid{},after{},after_valid{};
    if(!g.parameters->getParamNumber(g.live_handles[9],sequence)||!g.parameters->getParamNumber(g.live_handles[7],valid))return false;
    for(unsigned i=0;i<live.size();++i)if(!g.parameters->getParamNumber(g.live_handles[i],live[i]))return false;
    if(!g.parameters->getParamNumber(g.live_handles[9],after)||!g.parameters->getParamNumber(g.live_handles[7],after_valid))return false;
    return sequence==live[9]&&sequence==after&&valid==live[7]&&valid==after_valid&&g.parameters->epoch()==g.parameter_epoch;
}
bool ground_control_policy(const GroundRelease& g,const std::array<double,ground_live_names.size()>& v) {
    return GroundTargetPacket::release_flags(v[0],v[1],v[2],v[3],v[25])&&v[4]==7&&v[5]==g.delivery_mode&&
        v[6]==g.station&&v[24]==7;
}
bool ground_solution_policy(const GroundRelease& g,const std::array<double,ground_live_names.size()>& v) {
    return v[7]==1&&v[8]==g.station&&v[9]==g.solution_sequence&&v[10]==g.solution_time&&v[11]==1&&v[12]==1&&v[23]==2;
}
bool ground_point_policy(const GroundRelease& g,const std::array<double,ground_live_names.size()>& v) {
    if(v[13]!=g.target_source||v[14]!=g.target_source||v[15]!=g.target_sequence||v[16]!=g.target_sequence)return false;
    for(unsigned i=0;i<3;++i)if(v[17+i*2]!=g.identity_point[i]||v[18+i*2]!=g.identity_point[i])return false;
    return true;
}
bool ground_identity_current(const GroundRelease& g,double now) {
    GroundTargetPacket::Target current;
    if(!GroundTargetPacket::read(g.target_binding,now,current)||!GroundTargetPacket::current(g.target_binding,g.target,current,now))return false;
    // Copied fixed handles only: no callback lookup or mutable map traversal.
    std::array<double,ground_live_names.size()> live{};
    if(!ground_values(g,live))return false;
    return ground_control_policy(g,live)&&ground_solution_policy(g,live)&&ground_point_policy(g,live)&&
        GroundTargetPacket::current(g.target_binding,g.target,current,now);
}
SRWLOCK ground_release_lock=SRWLOCK_INIT;
GroundRelease ground_release{};
bool ground_delivery_source(double mode,double source) {
    return (mode==2 && source==3) || (mode==3 && (source==1 || source==2));
}
void update_ground_release(EDPARAM& p) {
    GroundRelease next;const double now=api.clock?api.clock():-100;
    next.parameters=&p;next.parameter_epoch=p.epoch();next.stamp=now;
    if(ground_target_reader.capture(p,now,next.target)&&ground_handles.bind(p)){
        next.target_binding=ground_target_reader.binding();next.live_handles=ground_handles.values;
        std::array<double,ground_live_names.size()> live{};
        if(ground_values(next,live)){
            const double station=live[6];const auto& point=next.target.identity.point;
            next.delivery_mode=live[5];next.solution_time=live[10];next.solution_sequence=live[9];
            next.target_source=next.target.identity.delivery_source;next.target_sequence=next.target.identity.sequence;
            next.identity_point=point;
            const bool station_valid=GroundTargetPacket::integer(station,0,10);
            next.station=station_valid?static_cast<unsigned>(station):0;
            next.valid=station_valid&&(next.delivery_mode==2||next.delivery_mode==3)&&GroundTargetPacket::fresh(now,next.solution_time,.2)&&
                GroundTargetPacket::integer(next.solution_sequence,1,9007199254740991.0)&&
                std::abs(point[0])<1e7&&std::abs(point[2])<1e7&&point[1]>=-1000&&point[1]<20000&&
                ground_delivery_source(next.delivery_mode,next.target_source)&&ground_identity_current(next,now);
            if(next.valid)next.point={static_cast<float>(point[0]),static_cast<float>(point[1]),static_cast<float>(point[2])};
        }
    }
    write(p,"F22_AG_GUIDANCE_CACHE_VALID",next.valid?1:0);write(p,"F22_AG_GUIDANCE_CACHE_TIME",now);
    write(p,"F22_AG_GUIDANCE_CACHE_STATION",next.station);write(p,"F22_AG_GUIDANCE_CACHE_SOLUTION_SEQUENCE",next.solution_sequence);
    write(p,"F22_AG_GUIDANCE_CACHE_TARGET_SOURCE",next.target_source);write(p,"F22_AG_GUIDANCE_CACHE_TARGET_SEQUENCE",next.target_sequence);
    write(p,"F22_AG_GUIDANCE_CACHE_TARGET_N",next.identity_point[0]);write(p,"F22_AG_GUIDANCE_CACHE_TARGET_U",next.identity_point[1]);write(p,"F22_AG_GUIDANCE_CACHE_TARGET_E",next.identity_point[2]);
    AcquireSRWLockExclusive(&ground_release_lock);ground_release=next;ReleaseSRWLockExclusive(&ground_release_lock);
    write(p,"F22_AG_GUIDANCE_BACKEND_READY",api.profile_valid && payload_original?1:0);
}
unsigned __fastcall record_payload_launch(void* self,unsigned station,unsigned sub,unsigned target,const float* point,bool armed) {
    using StoreType=const WeaponType* (__fastcall*)(void*,unsigned);
    unsigned type=0;
    const auto wt=reinterpret_cast<StoreType>(payload_original[20])(self,station);
    if (readable(reinterpret_cast<std::uintptr_t>(wt),sizeof(WeaponType))) type=wt->level4;
    const unsigned mode=launch_master_mode.load();
    AcquireSRWLockShared(&ground_release_lock);const auto ground=ground_release;ReleaseSRWLockShared(&ground_release_lock);
    // The stock guided bomb consumes a real world coordinate at release.
    // Never redirect an AA missile or substitute a fabricated ground point.
    if(armed && mode==7 && readable(reinterpret_cast<std::uintptr_t>(wt),sizeof(WeaponType)) &&
       wt->level1==4 && wt->level2==5 && wt->level3==36) {
        const double now=api.clock?api.clock():-100;
        if(!ground.valid || ground.station!=station || !std::isfinite(now) || now<ground.stamp || now-ground.stamp>.2 ||
           now<ground.solution_time || now-ground.solution_time>.2 ||
           !ground_identity_current(ground,now))return 0;
        point=ground.point.data();target=0;
    }
    const unsigned radar_track = (mode==2 || mode==3) ? NativeAesaRadar::track_for_host(target) : 0;
    auto estimate=launch_time_estimate(radar_track,type,mode,api.clock ? api.clock() : 0);
    auto id=reinterpret_cast<PayloadLaunch>(payload_original[50])(self,station,sub,target,point,armed);
    if (id && armed) {
        const double now=api.clock ? api.clock() : 0;
        estimate.stamp=now;
        AcquireSRWLockExclusive(&launch_lock);
        auto seq=++launched_sequence;
        launched[(seq-1)%launched.size()]={seq,id,radar_track,station,type,mode,now,estimate};
        ReleaseSRWLockExclusive(&launch_lock);
    }
    return id;
}
bool executable(std::uintptr_t p) {
    MEMORY_BASIC_INFORMATION m{};
    return VirtualQuery(reinterpret_cast<void*>(p),&m,sizeof(m)) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && (m.Protect&(PAGE_EXECUTE|PAGE_EXECUTE_READ|PAGE_EXECUTE_READWRITE|PAGE_EXECUTE_WRITECOPY));
}
// Exact CockpitBase profile: primary vtable RVA4656b8 contains 31 functions;
// next interface's RTTI is at4657b0. Preserve every original method and RTTI.
// get_current_pattern (slot27) preserves physical beam direction, while the
// original update_acquisition (slot23) receives matching scan-reference metrics.
void publish_launch_events(EDPARAM& p) {
    write(p,"F22_LAUNCH_EVENTS_READY",0);
    if (!api.profile_valid || !api.payload) return;
    auto payload=reinterpret_cast<std::uintptr_t>(api.payload());
    if (!readable(payload,8)) return;
    auto slot=reinterpret_cast<void**>(payload);auto original=reinterpret_cast<void**>(*slot);
    if (original!=payload_table.data()+1) {
        if (!readable(reinterpret_cast<std::uintptr_t>(original)-8,52*8)) return;
        unsigned count=0;
        while (count<192 && readable(reinterpret_cast<std::uintptr_t>(original+count),8) && executable(reinterpret_cast<std::uintptr_t>(original[count]))) ++count;
        if (count<51) return;
        payload_original=original;payload_table[0]=original[-1];
        for (unsigned i=0;i<count;++i) payload_table[i+1]=original[i];
        payload_table[51]=reinterpret_cast<void*>(&record_payload_launch);
        *slot=payload_table.data()+1;payload_slot=slot;
    }
    AcquireSRWLockShared(&launch_lock);
    const auto events=launched;const auto sequence=launched_sequence;
    ReleaseSRWLockShared(&launch_lock);
    for (unsigned i=0;i<events.size();++i) {
        char key[80];const auto& e=events[i];
        const char* fields[]={"SEQUENCE","ID","TARGET","STATION","TIME","TYPE","MODE"};
        double values[]={static_cast<double>(e.sequence),static_cast<double>(e.id),static_cast<double>(e.target),static_cast<double>(e.station),e.time,static_cast<double>(e.type),static_cast<double>(e.mode)};
        for (unsigned j=0;j<7;++j) {std::snprintf(key,sizeof(key),"F22_SHOT_%02u_%s",i+1,fields[j]);write(p,key,values[j]);}
        const char* predicted[]={"TOF_VALID","TOF","ACT_VALID","ACT","ESTIMATE_TIME","TOF_SOURCE","LIFETIME"};
        const double prediction[]={e.estimate.valid?1.0:0.0,e.estimate.tof,e.estimate.valid && e.estimate.act_valid?1.0:0.0,e.estimate.act,e.estimate.stamp,static_cast<double>(e.estimate.source),e.estimate.life};
        for (unsigned j=0;j<7;++j) {std::snprintf(key,sizeof(key),"F22_SHOT_%02u_%s",i+1,predicted[j]);write(p,key,prediction[j]);}
        // Only missiles returned by our payload launch call are eligible. Never
        // enumerate other weapons or query the target's hidden world state.
        bool valid=false;Direction point{};const float* velocity=nullptr;
        float active_range=0;bool active=false;bool active_valid=false;bool seeker_track=false;bool seeker_valid=false;unsigned model=0;
        if (e.id && api.find_object && api.missile_vtable && api.active_distance && api.clock && api.clock()-e.time<e.estimate.life+5) {
            auto object=reinterpret_cast<std::uintptr_t>(api.find_object(e.id));
            const bool legacy=readable(object,0x910) && *reinterpret_cast<const void**>(object)==api.missile_vtable;
            const bool guided=readable(object,1440) && api.guided_vtable && *reinterpret_cast<const void**>(object)==api.guided_vtable;
            const bool homing=readable(object,1576) && api.homing_vtable && *reinterpret_cast<const void**>(object)==api.homing_vtable;
            if (legacy || guided || homing) {
                model=legacy?1:homing?3:2;
                const auto vt=*reinterpret_cast<void***>(object);
                using Point=Direction* (__fastcall*)(void*,Direction*);
                using Velocity=const float* (__fastcall*)(void*);
                reinterpret_cast<Point>(vt[19])(reinterpret_cast<void*>(object),&point);
                velocity=reinterpret_cast<Velocity>(vt[38])(reinterpret_cast<void*>(object));
                active_range=legacy ? api.active_distance(reinterpret_cast<void*>(object)) : static_cast<float>(*reinterpret_cast<const double*>(object+1320));
                active=*reinterpret_cast<const bool*>(object+(legacy ? 0x8f0 : 1314));
                active_valid=legacy;
                if (homing) {
                    // The simulation scheme's actual seeker_on output, not a
                    // future command or the generic ammunition 'active' flag.
                    auto on=*reinterpret_cast<const std::uintptr_t*>(object+1512);
                    if (readable(on,1)) {active=*reinterpret_cast<const bool*>(on);active_valid=true;}
                    auto tracked=*reinterpret_cast<const std::uintptr_t*>(object+1296);
                    if (readable(tracked,1)) {seeker_track=*reinterpret_cast<const bool*>(tracked);seeker_valid=true;}
                }
                valid=readable(reinterpret_cast<std::uintptr_t>(velocity),12) && std::isfinite(point.x) && std::isfinite(point.y) && std::isfinite(point.z);
            }
        }
        std::snprintf(key,sizeof(key),"F22_SHOT_%02u_MODEL",i+1);write(p,key,model);
        std::snprintf(key,sizeof(key),"F22_SHOT_%02u_SEEKER_TRACK",i+1);write(p,key,seeker_track?1:0);
        // The checked scheme output can latch acquired-ever. It is diagnostic
        // game state and cannot establish continuous current seeker lock.
        std::snprintf(key,sizeof(key),"F22_SHOT_%02u_SEEKER_ACQUIRED_EVER",i+1);write(p,key,seeker_track?1:0);
        std::snprintf(key,sizeof(key),"F22_SHOT_%02u_CURRENT_LOCK_VALID",i+1);write(p,key,0);
        std::snprintf(key,sizeof(key),"F22_SHOT_%02u_STATE_SOURCE",i+1);write(p,key,valid?2:0);
        std::snprintf(key,sizeof(key),"F22_SHOT_%02u_SEEKER_VALID",i+1);write(p,key,seeker_valid?1:0);
        std::snprintf(key,sizeof(key),"F22_SHOT_%02u_ACTIVE_VALID",i+1);write(p,key,active_valid?1:0);
        std::snprintf(key,sizeof(key),"F22_SHOT_%02u_ALIVE",i+1);write(p,key,valid?1:0);
        if (valid) {
            const char* names[]={"N","U","E","VN","VU","VE","ACTIVE_RANGE","ACTIVE"};
            const double v[]={point.x,point.y,point.z,velocity[0],velocity[1],velocity[2],active_range,active?1.0:0.0};
            for (unsigned j=0;j<8;++j) {std::snprintf(key,sizeof(key),"F22_SHOT_%02u_%s",i+1,names[j]);write(p,key,v[j]);}
        }
    }
    write(p,"F22_LAUNCH_SEQUENCE",sequence);
    write(p,"F22_LAUNCH_EVENTS_READY",1);
}
std::uintptr_t selected_missile_descriptor=0;
void publish_missile_data(EDPARAM& p) {
    selected_missile_descriptor=0;
    write(p,"F22_MISSILE_DATA_VALID",0);write(p,"F22_DLZ_NATIVE_VALID",0);
    if (!api.ready || !api.weapon_vtable) return;
    auto context=api.binding_context();if (!context) return;
    auto weapon=reinterpret_cast<std::uintptr_t>(api.device(context,15));
    if (!readable(weapon,960) || *reinterpret_cast<const void**>(weapon)!=api.weapon_vtable) return;
    const auto descriptor=*reinterpret_cast<const std::uintptr_t*>(weapon+856);
    if (!readable(descriptor,324)) return;
    const auto type=*reinterpret_cast<const unsigned*>(descriptor+168);
    write(p,"F22_MISSILE_DESCRIPTOR_TYPE",type);
    double requested_type=0;
    if (!read(p,"F22_WEAPON_TYPE4",requested_type) || requested_type<1 || requested_type>UINT_MAX
        || requested_type!=std::floor(requested_type) || type!=static_cast<unsigned>(requested_type)) return;
    const double minimum=*reinterpret_cast<const double*>(weapon+832);
    const double maximum=*reinterpret_cast<const double*>(weapon+840);
    const double speed=*reinterpret_cast<const float*>(descriptor+292);
    const double life=*reinterpret_cast<const float*>(descriptor+276);
    if (!std::isfinite(minimum) || !std::isfinite(maximum) || minimum<0 || maximum<=minimum || maximum>600000 ||
        !std::isfinite(speed) || speed<100 || speed>5000 || !std::isfinite(life) || life<1 || life>1000) return;
    write(p,"F22_MISSILE_NATIVE_MIN",minimum);write(p,"F22_MISSILE_NATIVE_MAX",maximum);
    write(p,"F22_MISSILE_AVERAGE_SPEED",speed);write(p,"F22_MISSILE_LIFETIME",life);
    write(p,"F22_MISSILE_DATA_VALID",1);
    selected_missile_descriptor=descriptor;
    // Same exported DLZ used by the Hornet (FA18C 0x180426a5d): own altitude,
    // two unused scalars, target height minus own height, own/target velocity,
    // relative target position; returns RMAX, turn-away range, aerodynamic max.
    double target_valid=0;
    if (api.dlz && readable(descriptor,632) && *reinterpret_cast<const float*>(descriptor+584)>1
        && read(p,"F22_FC_TARGET_INPUT_VALID",target_valid) && target_valid==1) {
        WeaponFlightFrame::Snapshot<6> flight;
        if(!flight.load(p,WeaponFlightFrame::motion_names))return;
        float own[3],target[3],relative[3];char key[64];bool valid=true;
        const char* axes[]={"N","U","E"};
        for (unsigned i=0;i<3;++i) {
            own[i]=static_cast<float>(flight.values[i]);
            double velocity=0,position=0;
            std::snprintf(key,sizeof(key),"F22_FC_TARGET_V%s",axes[i]);
            if(!read(p,key,velocity) || std::abs(velocity)>1500)return;
            std::snprintf(key,sizeof(key),"F22_FC_TARGET_D%s",axes[i]);
            if(!read(p,key,position) || std::abs(position)>1e7)return;
            target[i]=static_cast<float>(velocity);relative[i]=static_cast<float>(position);
            valid=valid && std::isfinite(own[i]) && std::isfinite(target[i]) && std::isfinite(relative[i]);
        }
        double altitude=0,target_id=0;
        if(!read(p,"F22_FC_OWN_ALTITUDE",altitude) || altitude< -500 || altitude>30000
            || !read(p,"F22_FC_TARGET_INPUT_ID",target_id) || target_id<1 || target_id>UINT_MAX
            || target_id!=std::floor(target_id))return;
        if (valid && std::isfinite(altitude)) {
            float maximum=0,turn=0,aero=0;
            api.dlz(reinterpret_cast<const void*>(descriptor),static_cast<float>(altitude),0,0,relative[1],own,target,relative,&maximum,&turn,&aero);
            if (flight.current(p) && std::isfinite(maximum) && std::isfinite(turn) && std::isfinite(aero) && maximum>minimum && turn>=minimum && turn<=maximum && aero>=maximum && aero<600000) {
                write(p,"F22_DLZ_RMAX",maximum);write(p,"F22_DLZ_RTR",turn);write(p,"F22_DLZ_RAERO",aero);
                write(p,"F22_DLZ_RMIN",minimum);write(p,"F22_DLZ_TARGET_ID",target_id);write(p,"F22_DLZ_NATIVE_VALID",1);
            }
        }
    }
}
// Same body-vector convention as Radar_Display.body_observation. The native
// estimator expects target course and LOS azimuth in the aircraft frame, not
// absolute map headings. Its target-height input is absolute, its range slant.
Direction tof_body(const Direction& v,double pitch,double roll,double heading) {
    const double f=v.x*std::cos(heading)+v.z*std::sin(heading);
    const double right=-v.x*std::sin(heading)+v.z*std::cos(heading);
    const double up=-f*std::sin(pitch)+v.y*std::cos(pitch);
    return {f*std::cos(pitch)+v.y*std::sin(pitch),right*std::sin(roll)+up*std::cos(roll),right*std::cos(roll)-up*std::sin(roll)};
}
// This local publication consumes checked fields; unrelated legacy readers in
// the adapter remain explicitly tracked by P-INT-008 until their own cutover.
struct TofInputs {
    enum Field : unsigned { Type, Target, Mode, Power, MissileValid, TargetValid, RadarTarget,
        Life, DN, DU, DE, VN, VU, VE, Altitude, Pitch, Roll, Heading, Count };
    std::array<double,Count> value{};
    bool load(EDPARAM& p) {
        constexpr std::array<const char*,Count> names{
            "F22_WEAPON_TYPE4","F22_FC_TARGET_INPUT_ID","HUD_MODE","MAIN_POWER",
            "F22_MISSILE_DATA_VALID","F22_FC_TARGET_INPUT_VALID","F22_RADAR_WEAPON_TARGET_ID",
            "F22_MISSILE_LIFETIME","F22_FC_TARGET_DN","F22_FC_TARGET_DU","F22_FC_TARGET_DE",
            "F22_FC_TARGET_VN","F22_FC_TARGET_VU","F22_FC_TARGET_VE",
            "F22_FC_OWN_ALTITUDE","F22_FC_OWN_PITCH","F22_FC_OWN_ROLL","F22_FC_OWN_HEADING"};
        for(unsigned i=0;i<Count;++i)
            if(!p.getParamNumber(p.getParamHandle(names[i]),value[i]))return false;
        return true;
    }
    bool ids() const {
        for(unsigned field:{Type,Target})
            if(value[field]<1 || value[field]>UINT_MAX || value[field]!=std::floor(value[field]))return false;
        return true;
    }
    bool eligible() const {
        return ids() && (value[Mode]==2 || value[Mode]==3) && value[Power]==1
            && value[MissileValid]==1 && value[TargetValid]==1 && value[RadarTarget]==value[Target]
            && value[Life]>=1 && value[Life]<=1000;
    }
};
void retire_time_estimate() {
    AcquireSRWLockExclusive(&time_estimate_lock);time_estimate={};ReleaseSRWLockExclusive(&time_estimate_lock);
    last_tof_attempt=-1e9;last_tof_target=last_tof_type=0;
}
void publish_time_estimate(EDPARAM& p) {
    write(p,"F22_TOF_NATIVE_VALID",0);write(p,"F22_TOF_ACT_VALID",0);write(p,"F22_TOF_SOURCE",0);
    WeaponFlightFrame::Snapshot<1> flight;
    TofInputs input;
    if(!flight.load(p,WeaponFlightFrame::speed_names) || !input.load(p) || !input.eligible()) {
        retire_time_estimate();return;
    }
    api.resolve_tof();write(p,"F22_TOF_BACKEND_READY",api.aam_tof || api.descriptor_flight?1:0);
    const auto type=static_cast<unsigned>(input.value[TofInputs::Type]);
    const auto target_id=static_cast<unsigned>(input.value[TofInputs::Target]);
    const double now=api.clock ? api.clock() : -1;
    if(!std::isfinite(now)||now<0){retire_time_estimate();return;}
    const auto mode=input.value[TofInputs::Mode];const bool stock=mode==2 && (type==24 || type==106);
    const bool generic=api.descriptor_flight && selected_missile_descriptor &&
        readable(selected_missile_descriptor,324) && *reinterpret_cast<const unsigned*>(selected_missile_descriptor+168)==type;
    const bool eligible=(stock && api.aam_tof || generic) && api.clock;
    TimeEstimate value{};
    if (eligible) {
        AcquireSRWLockShared(&time_estimate_lock);value=time_estimate;ReleaseSRWLockShared(&time_estimate_lock);
        const bool source_changed=value.physical_generation!=flight.generation()
            || value.parameter_owner!=&p || value.parameter_epoch!=flight.parameter_epoch;
        if (source_changed || target_id!=last_tof_target || type!=last_tof_type || value.mode!=mode || now<last_tof_attempt || now-last_tof_attempt>=.2) {
            last_tof_attempt=now;last_tof_target=target_id;last_tof_type=type;
            value={};value.target=target_id;value.type=type;value.mode=static_cast<unsigned>(mode);value.stamp=now;
            value.physical_generation=flight.generation();value.parameter_owner=&p;
            value.parameter_epoch=flight.parameter_epoch;
            value.life=input.value[TofInputs::Life];
            Direction relative{input.value[TofInputs::DN],input.value[TofInputs::DU],input.value[TofInputs::DE]};
            Direction velocity{input.value[TofInputs::VN],input.value[TofInputs::VU],input.value[TofInputs::VE]};
            const double altitude=input.value[TofInputs::Altitude],speed=flight.values[0];
            const double pitch=input.value[TofInputs::Pitch],roll=input.value[TofInputs::Roll],heading=input.value[TofInputs::Heading];
            const double range=std::hypot(relative.x,relative.y,relative.z),target_speed=std::hypot(velocity.x,velocity.y,velocity.z);
            bool finite=true;for (double v:{altitude,speed,pitch,roll,heading,range,target_speed,relative.x,relative.y,relative.z,velocity.x,velocity.y,velocity.z}) finite=finite && std::isfinite(v);
            if (finite && altitude>=-500 && altitude<=30000 && speed>=0 && speed<1500 && target_speed<1500 &&
                range>=1 && range<300000 && altitude+relative.y>=-500 && altitude+relative.y<=30000 &&
                std::abs(pitch)<=3.15 && std::abs(roll)<=3.15 && std::abs(heading)<=6.29) {
                const auto body_relative=tof_body(relative,pitch,roll,heading),body_velocity=tof_body(velocity,pitch,roll,heading);
                double act=std::numeric_limits<double>::quiet_NaN();
                // FA18C 0x1804233d2 uses enum1 for AMRAAM-C and a 16000m
                // predicted activation crossing. This is a cockpit estimate,
                // never proof of the C5 simulation scheme's seeker state.
                double tof=0;
                if(stock && api.aam_tof){
                    if (!api.tof_constructed) {api.tof_construct(&api.tof_object);api.tof_constructed=true;}
                    tof=api.aam_tof(&api.tof_object,altitude,speed,pitch,target_speed,
                        std::atan2(body_velocity.z,body_velocity.x),std::atan2(body_relative.z,body_relative.x),
                        range,altitude+relative.y,16000,&act,type==106?1:0,false);
                    value.source=1;
                }else if(generic){
                    float average=0;double predicted=0;
                    const double cosine=target_speed>1e-6 ? std::clamp((relative.x*velocity.x+relative.y*velocity.y+relative.z*velocity.z)/(range*target_speed),-1.,1.) : 0;
                    const float distance=api.descriptor_flight(reinterpret_cast<const void*>(selected_missile_descriptor),
                        static_cast<float>(altitude),static_cast<float>(range),static_cast<float>(cosine),static_cast<float>(target_speed),&average,&predicted);
                    if(std::isfinite(distance)&&distance>0&&std::isfinite(average)&&average>=100&&average<=5000)tof=predicted;
                    value.source=2;
                    // Sensitivity range is not activation-command range. The
                    // real scheme telemetry, not this estimate, decides ACTIVE.
                }
                value.valid=std::isfinite(tof) && tof>0 && tof<=value.life;
                value.tof=value.valid ? tof : 0;
                value.act_valid=value.valid && std::isfinite(act) && act>=0 && act<=tof;
                value.act=value.act_valid ? act : 0;
            }
        }
    } else {last_tof_attempt=-1e9;last_tof_target=last_tof_type=0;}
    if(!flight.current(p)){retire_time_estimate();return;}
    AcquireSRWLockExclusive(&time_estimate_lock);time_estimate=value;ReleaseSRWLockExclusive(&time_estimate_lock);
    if (!value.valid) return;
    write(p,"F22_TOF_NATIVE_VALID",1);write(p,"F22_TOF_TARGET_ID",value.target);write(p,"F22_TOF_TYPE",value.type);
    write(p,"F22_TOF_TIME",value.stamp);write(p,"F22_TOF_SECONDS",value.tof);
    write(p,"F22_TOF_SOURCE",value.source);
    write(p,"F22_TOF_ACT_VALID",value.act_valid?1:0);write(p,"F22_TOF_ACT_SECONDS",value.act);
}
void reset_support() {
    NativeAesaRadar::reset();
    if (payload_slot && readable(reinterpret_cast<std::uintptr_t>(payload_slot),8) && *payload_slot==payload_table.data()+1) *payload_slot=payload_original;
    payload_slot=nullptr;
    AcquireSRWLockExclusive(&launch_lock);launched={};launched_sequence=0;ReleaseSRWLockExclusive(&launch_lock);
    AcquireSRWLockExclusive(&time_estimate_lock);time_estimate={};ReleaseSRWLockExclusive(&time_estimate_lock);
    last_tof_attempt=-1e9;last_tof_target=last_tof_type=0;
    if (api.tof_constructed) {api.tof_destroy(&api.tof_object);api.tof_constructed=false;api.tof_object=0;}
}
// Same payload/gun traversal as avArcadeRadar::get_shells_count (0x18032CB00).
// Read the real magazine; never estimate ammunition from trigger duration.
void publish_gun_ammunition(EDPARAM& p) {
    write(p,"F22_GUN_AMMO_VALID",0);write(p,"F22_GUN_AMMO_COUNT",0);
    if (!api.profile_valid || !api.payload) return;
    auto payload=reinterpret_cast<std::uintptr_t>(api.payload());
    if (!readable(payload,sizeof(void*))) return;
    auto table=*reinterpret_cast<std::uintptr_t*>(payload);
    if (!readable(table,568)) return;
    using Mount=void* (__fastcall*)(void*,unsigned char,unsigned char);
    using Count=unsigned (__fastcall*)(void*);
    auto get_mount=reinterpret_cast<Mount>(*reinterpret_cast<std::uintptr_t*>(table+560));
    if (!get_mount) return;
    unsigned total=0;
    for (unsigned i=0;i<32;++i) {
        auto mount=reinterpret_cast<std::uintptr_t>(get_mount(reinterpret_cast<void*>(payload),static_cast<unsigned char>(i),255));
        if (!mount) { write(p,"F22_GUN_AMMO_COUNT",total);write(p,"F22_GUN_AMMO_VALID",1);return; }
        if (!readable(mount,16)) return;
        auto gun=*reinterpret_cast<std::uintptr_t*>(mount+8);
        if (!readable(gun,sizeof(void*))) return;
        auto gun_table=*reinterpret_cast<std::uintptr_t*>(gun);
        if (!readable(gun_table,96)) return;
        auto count=reinterpret_cast<Count>(*reinterpret_cast<std::uintptr_t*>(gun_table+88));
        if (!count) return;
        unsigned rounds=count(reinterpret_cast<void*>(gun));
        if (rounds>100000 || total>100000-rounds) return;
        total+=rounds;
    }
}
}

void start_feedback() {
    const FeedbackGuard use(FeedbackAccess::Lifecycle);
    ir_feedback.accepting = true;
}

void reset(EDPARAM* parameters) {
    // Drain an in-flight IR update before invalidating/discarding its resources.
    const FeedbackGuard use(FeedbackAccess::Lifecycle);
    ground_target_reader.invalidate();ground_handles.invalidate();
    if (parameters && parameters->ed_param_api.pfn_ed_cockpit_get_parameter_handle &&
        parameters->ed_param_api.pfn_ed_cockpit_update_parameter_with_number) {
        auto handle = parameters->getParamHandle("F22_IR_SAMPLE_VALID");
        if (handle) parameters->setParamNumber(handle, 0);
    }
    ir_feedback.accepting = false;
    AcquireSRWLockExclusive(&ground_release_lock);ground_release={};ReleaseSRWLockExclusive(&ground_release_lock);
    reset_support();
    dispose();handles.clear();launch_sequence=0;launch_id=0;tick_sequence=0;
    ir_feedback = {};
}

bool read_store_configuration(EDPARAM& p,int& selected,WeaponType& type) {
    constexpr std::array<const char*,5> names{{"F22_IR_STATION","F22_IR_TYPE1",
        "F22_IR_TYPE2","F22_IR_TYPE3","F22_IR_TYPE4"}};
    std::array<double,5> values{};
    if(!read_fields(p,names,values))return false;
    constexpr std::array<double,5> maximum={10,255,255,255,4294967295.0};
    for (unsigned i=0;i<values.size();++i) {
        if (!std::isfinite(values[i]) || values[i]<0 || values[i]>maximum[i] ||
            values[i]!=std::floor(values[i])) return false;
    }
    selected=static_cast<int>(values[0]);
    type.level1=static_cast<std::uint8_t>(values[1]);
    type.level2=static_cast<std::uint8_t>(values[2]);
    type.level3=static_cast<std::uint8_t>(values[3]);
    type.level4=static_cast<std::uint32_t>(values[4]);
    return type.level1==4 && type.level2==4 && type.level3==7 && type.level4>0;
}

void update(EDPARAM& p,double dt) {
    const FeedbackGuard use(FeedbackAccess::Callback);
    if (!use) return; // A recurring callback never waits for teardown/another update.
    if (!ir_feedback.accepting) return; // Retired callback cannot revive either sensor.
    NativeAesaRadar::update(p); // Radar does not depend on IR fit, feedback handles or availability.
    const bool feedback_ready = ir_feedback.begin(p);
    if (!feedback_ready) return; // Release retires late callbacks until explicit spawn initialization.
    write(p,"F22_COMBAT_NATIVE_TICKS",++tick_sequence);
    api.resolve();
    IrControls controls;
    const bool controls_valid=controls.load(p);
    const auto& input=controls.value;
    launch_master_mode=controls_valid ? static_cast<unsigned>(input[IrControls::Mode]) : 0;
    publish_launch_events(p);
    update_ground_release(p);
    publish_missile_data(p);
    publish_time_estimate(p);
    publish_gun_ammunition(p);
    write(p,"F22_IR_API_READY",api.ready ? 1 : 0);
    write(p,"F22_IR_ABI_ERROR",api.error);
    write(p,"F22_IR_AVAILABLE",0);write(p,"F22_IR_LOCK",0);
    write(p,"F22_IR_STRENGTH",0);write(p,"F22_IR_STATE",0);
    write(p,"F22_IR_WORLD_VALID",0);write(p,"F22_IR_AIM9X_CONFIGURED",0);
    write(p,"F22_IR_HEAD_RELEASED",0);
    write(p,"F22_IR_LAUNCH_SEQUENCE",launch_sequence);
    write(p,"F22_IR_LAUNCH_ID",launch_id);
    if (!controls_valid) {dispose();return;}
    if (!api.ready || !std::isfinite(dt) || dt<=0 || dt>.1) return;
    void** context=*api.contexts;
    void* plane=context ? context[2] : nullptr;
    void* aircraft=api.aircraft();
    if (!plane || !aircraft) { dispose();return; }
    const bool enabled=input[IrControls::Mode]==3 && input[IrControls::Power]==1;
    int selected=-1;
    WeaponType type{};
    const bool loaded=read_store_configuration(p,selected,type);
    const double exposure_time=input[IrControls::ExposureTime];
    const double now=api.clock ? api.clock() : -100;
    const bool exposed=input[IrControls::ExposureValid]==1 && input[IrControls::Exposed]==1 &&
        std::isfinite(exposure_time) && std::isfinite(now) && now>=exposure_time-.05 && now-exposure_time<=.1;
    const double store_generation=input[IrControls::Generation];
    const bool generation_valid=std::isfinite(store_generation) && store_generation>=0 &&
        store_generation<=16777215 && store_generation==std::floor(store_generation);
    if (!enabled || !loaded || !exposed || !generation_valid) { dispose();return; }
    const bool aim9x=type.level4==136 || input[IrControls::Aim9x]==1;
    if (!constructed || selected!=current_station || !(type==current_type) || aim9x!=current_aim9x ||
        store_generation!=current_store_generation) {
        dispose();
        api.construct(object.data(),&type);constructed=true;
        api.initialize(object.data());api.station(object.data(),selected,0);
        if (aim9x) { // Hornet classifies capabilities separately from the payload's real wsType.
            constexpr double limit=1.4835298641951802;
            auto sensor=const_cast<void*>(api.seeker(object.data()));
            api.gimbal_limit(sensor,static_cast<float>(limit));
            api.motor_limits(static_cast<std::byte*>(sensor)+40,-limit,limit);
            api.motor_limits(static_cast<std::byte*>(sensor)+104,-limit,limit);
            api.sun_filter(sensor,1.f);
        }
        // IwoLA::getLauncherPoint, verified against both native weapon paths.
        LauncherPose launcher;
        auto vtable=*reinterpret_cast<void***>(aircraft);
        reinterpret_cast<Api::Launcher>(vtable[64])(aircraft,&launcher,static_cast<unsigned char>(selected),0);
        Pose pose;
        for (int i=0;i<16;++i) pose.m[i]=launcher.m[i];
        pose.m[3]=pose.m[7]=pose.m[11]=0;pose.m[15]=1;
        write(p,"F22_IR_MOUNT_FWD_NORM",std::hypot(pose.m[0],pose.m[1],pose.m[2]));
        if (!normalize_mount_pose(pose)) { dispose();write(p,"F22_IR_GEOMETRY_VALID",0);return; }
        write(p,"F22_IR_GEOMETRY_VALID",1);
        for (int i=0;i<3;++i) pose.m[12+i]+=1.5*pose.m[i];
        write(p,"F22_IR_APERTURE_TRAVEL",clear_observation_aperture(pose,model_min,model_max));
        api.boresight(object.data(),&pose);
        api.power(object.data(),true);api.status(object.data(),3);
        api.to_boresight(object.data());
        current_type=type;current_station=selected;current_aim9x=aim9x;
        current_store_generation=store_generation;
        // A held release is not a new press when stepping/changing stations.
        was_release=input[IrControls::Release]==1;
    }
    const bool caged=input[IrControls::Caged]==1;
    if (caged && !was_caged) {
        api.to_boresight(object.data());head_released=false;
    }
    was_caged=caged;
    api.consent(object.data(),!caged);
    // The pilot can request uncage before there is a radar/IR lock. Keep that
    // request and native tracking consent, but release the head only on a real
    // detection signal, as in the Hornet's 31C4A0 path. Unconditionally entering
    // native free-head state0 starts its explicit random walk (354610).
    if (!caged && !head_released && !api.tracking(object.data()) &&
        api.strength(object.data())>.8f) {
        api.uncage(object.data());head_released=true;
    }
    // Re-slaving an acquired seeker clears its track. Leave it autonomous once
    // tracking; radar cueing and IR acquisition are different states.
    double radar_valid=0;
    if (!caged && !api.tracking(object.data()) && read(p,"F22_RADAR_STT_VALID",radar_valid) && radar_valid==1) {
        double az=0,el=0;
        if (read(p,"F22N_RADAR_STT_AZIMUTH",az) && read(p,"F22N_RADAR_STT_ELEVATION",el)) {
            Direction direction{std::cos(el)*std::cos(az),std::sin(el),std::cos(el)*std::sin(az)};
            api.slave(object.data(),&direction);
            head_released=true;
        }
    }
    api.update(object.data(),dt);
    bool locked=api.tracking(object.data());
    if (locked) head_released=true;
    write(p,"F22_IR_HEAD_RELEASED",head_released ? 1 : 0);
    Pose local;api.local_pose(api.seeker(object.data()),&local);
    double az=std::atan2(local.m[2],local.m[0]);
    double el=std::atan2(local.m[1],std::hypot(local.m[0],local.m[2]));
    write(p,"F22_IR_AVAILABLE",1);write(p,"F22_IR_LOCK",locked ? 1 : 0);
    write(p,"F22_IR_STATE",locked ? 3 : caged ? 1 : 2);
    write(p,"F22_IR_STRENGTH",api.strength(object.data()));
    write(p,"F22_IR_AIM9X_CONFIGURED",current_aim9x ? 1 : 0);
    // Read-only diagnostics for the same checked object layout. These expose
    // real sensor search/geometry state; they never supply an IR target.
    const auto sensor=static_cast<const std::byte*>(api.seeker(object.data()));
    write(p,"F22_IR_SEARCH_ACTIVE",*reinterpret_cast<const unsigned char*>(sensor+648));
    write(p,"F22_IR_SENSOR_MODE",*reinterpret_cast<const int*>(sensor+644));
    write(p,"F22_IR_PARENT_VALID",*reinterpret_cast<const std::uintptr_t*>(sensor+32) ? 1 : 0);
    write(p,"F22_IR_NATIVE_TARGET_ID",*reinterpret_cast<const unsigned*>(sensor+712));
    write(p,"F22_IR_SUN",*reinterpret_cast<const unsigned char*>(sensor+649));
    write(p,"F22_IR_ELECTRIC",*reinterpret_cast<const unsigned char*>(object.data()+8));
    write(p,"F22_IR_SENSOR_POWER",*reinterpret_cast<const unsigned char*>(sensor+568));
    write(p,"F22_IR_INITIALIZED",*reinterpret_cast<const unsigned char*>(sensor+624));
    write(p,"F22_IR_APERTURE",*reinterpret_cast<const float*>(sensor+632));
    write(p,"F22_IR_NATIVE_TYPE",static_cast<double>(*reinterpret_cast<const std::uint64_t*>(sensor+1008)));
    write(p,"F22_IR_TIMER",*reinterpret_cast<const std::uintptr_t*>(sensor+616) ? 1 : 0);
    auto hits_begin=*reinterpret_cast<const std::uintptr_t*>(sensor+984);
    auto hits_end=*reinterpret_cast<const std::uintptr_t*>(sensor+992);
    write(p,"F22_IR_CONTACTS",hits_end>=hits_begin && (hits_end-hits_begin)/24<=4096 ? (hits_end-hits_begin)/24 : -1);
    if (api.platform_position) {
        const auto world=static_cast<const Pose*>(api.platform_position(sensor));
        if (readable(reinterpret_cast<std::uintptr_t>(world),sizeof(Pose))) {
            const double norm=std::hypot(world->m[0],world->m[1],world->m[2]);
            if (std::isfinite(norm) && norm>.9 && norm<1.1) {
                write(p,"F22_IR_WORLD_NORTH",world->m[12]);write(p,"F22_IR_WORLD_ALT",world->m[13]);write(p,"F22_IR_WORLD_EAST",world->m[14]);
                write(p,"F22_IR_WORLD_FWD_N",world->m[0]/norm);write(p,"F22_IR_WORLD_FWD_U",world->m[1]/norm);write(p,"F22_IR_WORLD_FWD_E",world->m[2]/norm);
                write(p,"F22_IR_WORLD_VALID",1);
            }
        }
    }
    write(p,"F22_IR_AZ",az);write(p,"F22_IR_EL",el);
    const bool release=input[IrControls::Release]==1;
    if (release && !was_release && locked && input[IrControls::MasterArm]==1 && input[IrControls::WoW]==0) {
        auto id=api.launch(object.data(),plane);
        if (id) { launch_id=id;++launch_sequence; }
    }
    was_release=release;
    write(p,"F22_IR_LAUNCH_SEQUENCE",launch_sequence);write(p,"F22_IR_LAUNCH_ID",launch_id);
    ir_feedback.commit(p, now, current_station, current_store_generation);
}
}
