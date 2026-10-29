// GPL-3.0-or-later. Actual owning Api against allocated, inert PE fixtures.
#include <Windows.h>
#include "../../EFM/source/AesaHostProfile.h"
#include <array>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <string_view>
#include <type_traits>
#include <utility>
#include <vector>

namespace {
using AesaHostProfile::Image;
using AesaHostProfile::Modules;
constexpr Modules host_prior_images{{0x6ac12468,0x59a000},{0x6aae1e0e,0x46000},{0x6aae1d9b,0x14000},{0x6ac122f4,0x125b000}};
constexpr Modules host_current_images{{0x6adbad09,0x68e000},{0x6ad87426,0x46000},{0x6acb804e,0x14000},{0x6adbace0,0x127b000}};
unsigned checks{},failures{};
void check(bool ok,const char* reason) {
    ++checks;
    if(!ok){++failures;std::printf("FAIL %s\n",reason);}
}
struct Fixture {
    std::array<std::vector<std::byte>,4> modules;
    std::string_view denied{};
    int missing=-1;
    Fixture() {
        const std::array<std::size_t,4> capacity{0x68e000,0x46000,0x14000,0x127b000};
        for(unsigned i=0;i<4;++i)modules[i].resize(capacity[i]);
    }
    IMAGE_DOS_HEADER* dos(unsigned i){return reinterpret_cast<IMAGE_DOS_HEADER*>(modules[i].data());}
    IMAGE_NT_HEADERS64* nt(unsigned i){return reinterpret_cast<IMAGE_NT_HEADERS64*>(modules[i].data()+128);}
    void table(std::size_t rva,std::size_t active,std::size_t strength) {
        auto values=reinterpret_cast<void**>(modules[3].data()+rva);
        for(unsigned i=0;i<5;++i)values[i]=nullptr;
        values[1]=modules[3].data()+active;values[4]=modules[3].data()+strength;
    }
    void reset(const Modules& images) {
        const std::array<Image,4> fields{images.cockpit,images.objects,images.world,images.general};
        denied={};missing=-1;
        for(unsigned i=0;i<4;++i) {
            std::memset(modules[i].data(),0,512);
            dos(i)->e_magic=IMAGE_DOS_SIGNATURE;dos(i)->e_lfanew=128;
            nt(i)->Signature=IMAGE_NT_SIGNATURE;nt(i)->FileHeader.Machine=IMAGE_FILE_MACHINE_AMD64;
            nt(i)->OptionalHeader.Magic=IMAGE_NT_OPTIONAL_HDR64_MAGIC;
            nt(i)->FileHeader.TimeDateStamp=fields[i].stamp;nt(i)->OptionalHeader.SizeOfImage=fields[i].size;
        }
        table(0x1d0778,0x65bd0,0x65bc0);table(0x1ef6a8,0x80c70,0x80c60);
    }
} fixture;
void inert_export(){std::abort();} // A real export invocation fails this fixture.
HMODULE WINAPI fixture_module(LPCWSTR name) {
    constexpr std::array names{L"CockpitBase.dll",L"edObjects.dll",L"World.dll",L"WorldGeneral.dll"};
    for(unsigned i=0;i<names.size();++i)
        if(std::wcscmp(name,names[i])==0)return fixture.missing==static_cast<int>(i)?nullptr:reinterpret_cast<HMODULE>(fixture.modules[i].data());
    return nullptr;
}
FARPROC WINAPI fixture_export(HMODULE,LPCSTR name) {
    return fixture.denied==name?nullptr:reinterpret_cast<FARPROC>(&inert_export);
}
}
#define GetModuleHandleW fixture_module
#define GetProcAddress fixture_export
#ifdef RADAR_CURRENT_HOST_CANDIDATE
#include "NativeAesaRadar-current.cpp"
#else
#include "../../EFM/source/NativeAesaRadar.cpp"
#endif
#undef GetModuleHandleW
#undef GetProcAddress
namespace NativeGroundSensor {
AesaRadar::SurfaceRequest pointing(double,const AesaRadar::Pose&) noexcept {std::abort();}
void sample(void*,const ArrayService&){std::abort();}
}
namespace NativeGroundVideo {
void set_aircraft(const AesaRadar::Pose*,double) noexcept {std::abort();}
}
namespace {
struct QueryScene { void** table{}; };
unsigned __fastcall fixture_scene_id(void*) {return 84;}
void* __fastcall fixture_registered(void*) {return nullptr;}
std::array<void*,7> query_scene_table{nullptr,reinterpret_cast<void*>(&fixture_scene_id),nullptr,nullptr,nullptr,nullptr,reinterpret_cast<void*>(&fixture_registered)};
QueryScene query_scene{query_scene_table.data()};
unsigned search_calls{},segment_calls{},callback_calls{};
int __fastcall fixture_search(void*,const NativeAesaRadar::Box& box,unsigned mask,NativeAesaRadar::Query callback) {
    ++search_calls;
    check(mask==32&&box.minimum.n<=box.maximum.n,"actualProvider search passes bounded floatbox and mask");
    check(static_cast<bool>(callback),"search receives owned callable value");
    check(callback(*reinterpret_cast<NativeAesaRadar::Scene*>(&query_scene))==0,"search callback retains own synchronous source context");
    ++callback_calls;
    return -37; // Traversal result is deliberately ignored by the existing adapter.
}
int __fastcall fixture_segment(void*,const AesaRadar::Vector& from,const AesaRadar::Vector& to,unsigned mask,NativeAesaRadar::Query callback) {
    ++segment_calls;
    check(mask==35&&from.n==1&&to.n==4,"actualProvider segment passes double endpoints and mask");
    check(static_cast<bool>(callback),"segment receives owned callable value");
    check(callback(*reinterpret_cast<NativeAesaRadar::Scene*>(&query_scene))==0,"target's own scene object remains excluded as occluder");
    ++callback_calls;
    return -53;
}
void provider_query_abi() {
    struct Manager {void** table{};};
    std::array<void*,25> table{};
    table[20]=reinterpret_cast<void*>(&fixture_search);table[24]=reinterpret_cast<void*>(&fixture_segment);
    Manager manager{table.data()};void* object=&manager;NativeAesaRadar::api.manager=&object;
    NativeAesaRadar::Provider provider;AesaRadar::Pose pose;pose.position={1,2,3};
    AesaRadar::Beam beam;beam.direction={1,0,0};beam.range_m=1000;beam.half_angle=.01;
    std::array<AesaRadar::Truth,1> output{};std::size_t count=0;AesaRadar::QueryStats stats;
    check(provider.query(pose,beam,output,count,stats),"native integer traversal result is not promoted to new policy");
    check(count==0&&stats.visited==1&&search_calls==1,"actual source callback runs exactly once without native object execution");
    AesaRadar::Truth target;target.id=84;target.position={4,5,6};
    check(provider.objects_visible({1,2,3},target,stats),"segment ignored integer return preserves source visibility policy");
    check(segment_calls==1&&callback_calls==2&&stats.object_blocked==0,"both actualProvider call sites dispatch synchronous owned callback");
    NativeAesaRadar::api.manager=nullptr;
}
#if defined(RADAR_CURRENT_HOST_CANDIDATE) || defined(RADAR_CURRENT_HOST_REVIEWED)
using ExpectedSearch=int(__fastcall*)(void*,const NativeAesaRadar::Box&,unsigned,NativeAesaRadar::Query);
using ExpectedSegment=int(__fastcall*)(void*,const AesaRadar::Vector&,const AesaRadar::Vector&,unsigned,NativeAesaRadar::Query);
static_assert(std::is_same_v<NativeAesaRadar::SceneSearch,ExpectedSearch>);
static_assert(std::is_same_v<NativeAesaRadar::SceneSegment,ExpectedSegment>);
struct TrackedCallback {
    int* alive{};
    explicit TrackedCallback(int& n):alive(&n){++*alive;}
    TrackedCallback(const TrackedCallback& x):alive(x.alive){++*alive;}
    TrackedCallback(TrackedCallback&& x) noexcept:alive(x.alive){++*alive;}
    ~TrackedCallback(){--*alive;}
    int operator()(NativeAesaRadar::Scene&) const{return 0;}
};
void by_value_lifetime() {
    int alive=0;
    NativeAesaRadar::Query search_value=TrackedCallback(alive);
    check(alive==1,"one owned callable before query transfer");
    const NativeAesaRadar::SceneSearch search=&fixture_search;
    const NativeAesaRadar::Box box{{0,0,0},{1,1,1}};
    check(search(nullptr,box,32,std::move(search_value))==-37,"typed exact native return remains integer");
    check(!search_value&&alive==0,"by-value move retires caller and callee destroys exactly once");
    NativeAesaRadar::Query segment_value=TrackedCallback(alive);
    const NativeAesaRadar::SceneSegment segment=&fixture_segment;
    check(segment(nullptr,{1,2,3},{4,5,6},35,std::move(segment_value))==-53,"typed segment also receives owned value");
    check(!segment_value&&alive==0,"segment callback ownership retires without reuse or double destruction");
}
static_assert(std::is_same_v<decltype(&NativeAesaRadar::driver_final_release),void(__fastcall*)(void*) noexcept>);
void** release_expected_table{};
void* release_expected_self{};
std::uint64_t release_expected_epoch{};
unsigned release_calls{};
void __fastcall fixture_final_release(void* self) {
    ++release_calls;
    check(self==release_expected_self&&*static_cast<void***>(self)==release_expected_table,"FinalRelease forwards exactself after original table restoration");
    check(!NativeAesaRadar::owner.load()&&!NativeAesaRadar::driver_slot&&!NativeAesaRadar::driver_original.load(),"ownership and hook state retire before nativeforward");
    check(NativeAesaRadar::epoch.load()==release_expected_epoch+1&&!NativeAesaRadar::snapshot.epoch&&
          !NativeAesaRadar::parameters.bound&&NativeAesaRadar::request.stamp==-100,"source and publication context retire before forwardcall");
}
void final_release_order() {
    struct Driver {void** table{};};
    std::array<void*,2> original{reinterpret_cast<void*>(&fixture_final_release),reinterpret_cast<void*>(&inert_export)};
    Driver object{NativeAesaRadar::driver_table.data()+1};
    release_expected_table=original.data();release_expected_self=&object;release_expected_epoch=NativeAesaRadar::epoch.load();release_calls=0;
    NativeAesaRadar::driver_slot=reinterpret_cast<void**>(&object.table);
    NativeAesaRadar::driver_original=original.data();NativeAesaRadar::owner=&object;
    NativeAesaRadar::snapshot.epoch=123;NativeAesaRadar::parameters.bound=true;NativeAesaRadar::request.stamp=77;
    NativeAesaRadar::driver_final_release(&object);
    check(release_calls==1&&object.table[1]==original[1],"exactlyone voidFinalRelease; deletingdestructor slot1 untouched");
    NativeAesaRadar::driver_final_release(&object);
    check(release_calls==1,"missingretired original cannot forward secondrelease");
}
#endif
void coherent_and_mixed() {
    for(unsigned mask=0;mask<16;++mask) {
        Modules candidate=host_prior_images;
        if(mask&1)candidate.cockpit=host_current_images.cockpit;
        if(mask&2)candidate.objects=host_current_images.objects;
        if(mask&4)candidate.world=host_current_images.world;
        if(mask&8)candidate.general=host_current_images.general;
        fixture.reset(candidate);NativeAesaRadar::Api api;
        api.initialize();
        const bool expected=mask==0||mask==15;
        check(api.ready.load()==expected,"actual Api accepts only complete old/current bundle");
        check(api.reason==(expected?0u:2u),"actual Api reports profile refusal independently of export failure");
        if(expected) {
            const auto base=fixture.modules[3].data();
            check(api.ecm_vtable==reinterpret_cast<void**>(base+(mask==0?0x1d0778:0x1ef6a8)),"selected ECM table belongs to same complete bundle");
            check(api.ecm_active==base+(mask==0?0x65bd0:0x80c70)&&api.ecm_strength==base+(mask==0?0x65bc0:0x80c60),"selected ECM methods match the exact current/previous layout");
        }
    }
}
void malformed_headers() {
    for(unsigned module=0;module<4;++module) {
        for(unsigned fault=0;fault<8;++fault) {
            fixture.reset(host_current_images);
            if(fault==0)fixture.dos(module)->e_magic=0;
            if(fault==1)fixture.dos(module)->e_lfanew=-1;
            if(fault==2)fixture.dos(module)->e_lfanew=1048577;
            if(fault==3)fixture.nt(module)->Signature=0;
            if(fault==4)fixture.nt(module)->FileHeader.Machine=IMAGE_FILE_MACHINE_I386;
            if(fault==5)fixture.nt(module)->OptionalHeader.Magic=IMAGE_NT_OPTIONAL_HDR32_MAGIC;
            if(fault==6)fixture.nt(module)->FileHeader.TimeDateStamp^=1;
            if(fault==7)fixture.nt(module)->OptionalHeader.SizeOfImage^=0x1000;
            NativeAesaRadar::Api api;api.initialize();
            check(!api.ready.load()&&api.reason==2,"malformed current PE metadata withdraws before exports");
            check(!api.clock&&!api.ecm_vtable,"failed image admission never resolves a callable host interface");
        }
    }
}
void exports_and_ecm() {
    constexpr std::array required{
        "?GetModelTime@wTime@@SANXZ","?c_LA@cockpit@@YAPEAVIwoLA@@XZ",
        "?binding_context@cockpit@@YAPEAVccCockpitContext@1@XZ",
        "?get_wide_device@ccCockpitContext@cockpit@@QEAAPEAVavDevice@2@I@Z",
        "?c_mark_radar_emitter_active@cockpit@@YAX_N@Z",
        "??_7avLuaDevice@cockpit@@6BccContextRelatedObject@1@@","?update@avLuaDevice@cockpit@@UEAAXXZ",
        "?GetPoint@MovingObject@@UEAA?AVVec3d@osg@@XZ","?VectorVelocity@MovingObject@@UEBAAEBVVec3f@osg@@XZ",
        "?Type@MovingObject@@QEBAAEBVwsType@@XZ","?IsDead@MovingObject@@UEBA_NXZ",
        "?Position@MovingObject@@UEAAAEBV?$wPosition3@M@@XZ",
        "?intersectSegment@@YAPEBDAEBVISceneObject@@AEBVVec3d@osg@@1AEAV23@AEAN2@Z",
        "?instance@viObjectManager@@2PEAV1@EA","?globalLand@@3PEAVwTerrain@@EA","?IsFlag@MovingObject@@QEBA?B_NH@Z"};
    for(const auto& images:{host_prior_images,host_current_images}) {
        for(const auto name:required) {
            fixture.reset(images);fixture.denied=name;NativeAesaRadar::Api api;api.initialize();
            check(!api.ready.load()&&api.reason==3,"missing required export withdraws a supported image bundle");
        }
        for(unsigned index:{1u,4u}) {
            fixture.reset(images);const auto offset=images.general.stamp==host_current_images.general.stamp?0x1ef6a8:0x1d0778;
            reinterpret_cast<void**>(fixture.modules[3].data()+offset)[index]=nullptr;
            NativeAesaRadar::Api api;api.initialize();
            check(!api.ready.load()&&api.reason==3,"bad ECM method entry withdraws rather than guessing a layout");
        }
    }
}
void lifecycle_retries() {
    fixture.reset(host_current_images);fixture.missing=2;NativeAesaRadar::Api waiting;waiting.initialize();
    check(!waiting.ready.load()&&waiting.reason==1,"not loaded module remains unavailable and retryable");
    fixture.missing=-1;waiting.initialize();check(waiting.ready.load(),"coherent bundle can bind after missing module arrives");
    fixture.reset(host_current_images);fixture.nt(0)->FileHeader.TimeDateStamp^=1;NativeAesaRadar::Api refused;refused.initialize();
    fixture.reset(host_current_images);refused.initialize();
    check(!refused.ready.load()&&refused.reason==2,"profile refusal remains latched until owning lifecycle reset");
}
}
int main() {
    coherent_and_mixed();malformed_headers();exports_and_ecm();lifecycle_retries();
    provider_query_abi();
#if defined(RADAR_CURRENT_HOST_CANDIDATE) || defined(RADAR_CURRENT_HOST_REVIEWED)
    by_value_lifetime();
    final_release_order();
#endif
    std::printf("actual Api profile checks=%u failures=%u (inert modules; no native export invoked)\n",checks,failures);
    return failures?1:0;
}
