// GPL-3.0-or-later. Current ground Api and borrowed-call ports, inert modules.
#include <Windows.h>
#include "../../EFM/source/GroundSensorHostProfile.h"
#include <array>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <limits>
#include <map>
#include <string>
#include <string_view>
#include <vector>
namespace {
using GroundSensorHostProfile::Modules;
using AesaHostProfile::Image;
constexpr Modules ground_previous{{{0x6ac12468,0x59a000},{0x6aae1e0e,0x46000},{0x6aae1d9b,0x14000},{0x6ac122f4,0x125b000}},{0x6aae1df2,0x62000}};
constexpr Modules ground_current{{{0x6adbad09,0x68e000},{0x6ad87426,0x46000},{0x6acb804e,0x14000},{0x6adbace0,0x127b000}},{0x6acb8063,0x62000}};
unsigned checks{},failures{};
void check(bool ok,const char* reason){++checks;if(!ok){++failures;std::printf("FAIL %s\n",reason);}}
std::array<Image*,5> images(Modules& m){return {&m.scene.cockpit,&m.scene.objects,&m.scene.world,&m.scene.general,&m.graphics};}
struct GroundFixture {
    std::array<std::vector<std::byte>,5> memory;
    std::string_view denied{};int absent=-1;
    GroundFixture(){const std::array<std::size_t,5> capacity{0x68e000,0x46000,0x14000,0x127b000,0x62000};for(unsigned i=0;i<5;++i)memory[i].resize(capacity[i]);}
    IMAGE_DOS_HEADER* dos(unsigned i){return reinterpret_cast<IMAGE_DOS_HEADER*>(memory[i].data());}
    IMAGE_NT_HEADERS64* nt(unsigned i){return reinterpret_cast<IMAGE_NT_HEADERS64*>(memory[i].data()+128);}
    void reset(Modules m){
        denied={};absent=-1;const auto entries=images(m);
        for(unsigned i=0;i<5;++i){
            std::memset(memory[i].data(),0,512);dos(i)->e_magic=IMAGE_DOS_SIGNATURE;dos(i)->e_lfanew=128;
            nt(i)->Signature=IMAGE_NT_SIGNATURE;nt(i)->FileHeader.Machine=IMAGE_FILE_MACHINE_AMD64;nt(i)->OptionalHeader.Magic=IMAGE_NT_OPTIONAL_HDR64_MAGIC;
            nt(i)->FileHeader.TimeDateStamp=entries[i]->stamp;nt(i)->OptionalHeader.SizeOfImage=entries[i]->size;
        }
    }
} ground_fixture;
void ground_inert_export(){std::abort();}
HMODULE WINAPI ground_module(LPCWSTR name){
    constexpr std::array names{L"CockpitBase.dll",L"edObjects.dll",L"World.dll",L"WorldGeneral.dll",L"GraphicsVista.dll"};
    for(unsigned i=0;i<names.size();++i)if(std::wcscmp(name,names[i])==0)return ground_fixture.absent==static_cast<int>(i)?nullptr:reinterpret_cast<HMODULE>(ground_fixture.memory[i].data());
    return nullptr;
}
FARPROC WINAPI ground_export(HMODULE,LPCSTR name){return ground_fixture.denied==name?nullptr:reinterpret_cast<FARPROC>(&ground_inert_export);}
}
#define GetModuleHandleW ground_module
#define GetProcAddress ground_export
#ifdef GROUND_CURRENT_HOST_CANDIDATE
#include "NativeGroundSensor-current.cpp"
#else
#include "../../EFM/source/NativeGroundSensor.cpp"
#endif
#undef GetModuleHandleW
#undef GetProcAddress
namespace {
void exact_and_mixed_bundles(){
    for(unsigned mask=0;mask<32;++mask){
        auto candidate=ground_previous;auto next=ground_current;const auto target=images(candidate),source=images(next);
        for(unsigned i=0;i<5;++i)if(mask&(1u<<i))*target[i]=*source[i];
        const bool permitted=mask==0||mask==31;
        check((GroundSensorHostProfile::select(candidate)!=nullptr)==permitted,"pure selector rejects every mixed five-module bundle");
        ground_fixture.reset(candidate);NativeGroundSensor::Api adapter;adapter.initialize();
        check(adapter.ready.load()==permitted,"actual ground Api accepts only matching old/current five-module bundle");
        check(adapter.reason==(permitted?0:2),"actual ground Api distinguishes unsupported bundle");
    }
}
void header_and_export_failures(){
    for(unsigned module=0;module<5;++module){
        for(unsigned fault=0;fault<9;++fault){
            ground_fixture.reset(ground_current);
            if(fault==0)ground_fixture.dos(module)->e_magic=0;
            if(fault==1)ground_fixture.dos(module)->e_lfanew=-1;
            if(fault==2)ground_fixture.dos(module)->e_lfanew=1048577;
            if(fault==3)ground_fixture.nt(module)->Signature=0;
            if(fault==4)ground_fixture.nt(module)->FileHeader.Machine=IMAGE_FILE_MACHINE_I386;
            if(fault==5)ground_fixture.nt(module)->OptionalHeader.Magic=IMAGE_NT_OPTIONAL_HDR32_MAGIC;
            if(fault==6)ground_fixture.nt(module)->FileHeader.TimeDateStamp^=1;
            if(fault==7)ground_fixture.nt(module)->OptionalHeader.SizeOfImage^=0x1000;
            if(fault==8)ground_fixture.nt(module)->OptionalHeader.SizeOfImage=0;
            NativeGroundSensor::Api adapter;adapter.initialize();
            check(!adapter.ready.load()&&adapter.reason==2&&!adapter.clock,"malformed metadata withdraws before native export lookup");
        }
    }
    constexpr std::array required{
        "?GetModelTime@wTime@@SANXZ","?c_LA@cockpit@@YAPEAVIwoLA@@XZ",
        "?GetPoint@MovingObject@@UEAA?AVVec3d@osg@@XZ","?Type@MovingObject@@QEBAAEBVwsType@@XZ",
        "?IsDead@MovingObject@@UEBA_NXZ","?IsFlag@MovingObject@@QEBA?B_NH@Z",
        "??0Camera@Graphics@@QEAA@W4Type@01@@Z","?getClipVolume@Camera@Graphics@@QEBAPEBVClipVolume@@XZ",
        "?Position@MovingObject@@UEAAAEBV?$wPosition3@M@@XZ","?instance@viObjectManager@@2PEAV1@EA",
        "?globalLand@@3PEAVwTerrain@@EA","?intersectSegment@@YAPEBDAEBVISceneObject@@AEBVVec3d@osg@@1AEAV23@AEAN2@Z"};
    for(const auto& bundle:{ground_previous,ground_current})for(const auto name:required){
        ground_fixture.reset(bundle);ground_fixture.denied=name;NativeGroundSensor::Api adapter;adapter.initialize();
        check(!adapter.ready.load()&&adapter.reason==3,"every required scene/camera export independently gates readiness");
    }
    for(int absent=0;absent<5;++absent){
        ground_fixture.reset(ground_current);ground_fixture.absent=absent;NativeGroundSensor::Api adapter;adapter.initialize();
        check(!adapter.ready.load()&&adapter.reason==1,"unloaded module remains unavailable and retryable");
        ground_fixture.absent=-1;adapter.initialize();check(adapter.ready.load(),"coherent five-module arrival permits retry");
    }
    ground_fixture.reset(ground_current);ground_fixture.nt(4)->FileHeader.TimeDateStamp^=1;NativeGroundSensor::Api adapter;adapter.initialize();
    ground_fixture.reset(ground_current);adapter.initialize();check(!adapter.ready.load()&&adapter.reason==2,"profile rejection cannot be cleared by a later status-only retry");
}
struct VirtualObject{void** table{};};
NativeGroundSensor::VecF motion_sample{30,-4,7};
bool motion_present=true;
const NativeGroundSensor::VecF* __fastcall fixture_motion(const void*){return motion_present?&motion_sample:nullptr;}
float response_value=4;
unsigned response_calls{};
float __fastcall fixture_response(void*,float frequency,const NativeGroundSensor::VecF& direction){
    ++response_calls;check(frequency==0&&direction.n==1&&direction.u==0&&direction.e==0,"actual response call uses the independently evidenced frequency/vector ABI");return response_value;
}
VirtualObject* response_object{};
void* __fastcall fixture_get_response(void*){return response_object;}
bool ray_present=true;
GroundMovingTargets::Vec ray_hit{1000,0,0};
bool __fastcall fixture_ray(void*,const NativeGroundSensor::VecF& from,const NativeGroundSensor::VecF& direction,float maximum,NativeGroundSensor::VecF* hit){
    check(from.n==0&&from.u==1000&&from.e==0&&maximum==185200,"actual terrain ray passes float origin and maximum");
    check(std::abs(direction.n-std::sqrt(.5f))<1e-6&&std::abs(direction.u+std::sqrt(.5f))<1e-6,"actual ray direction is normalized in declared world frame");
    *hit={static_cast<float>(ray_hit.n),static_cast<float>(ray_hit.u),static_cast<float>(ray_hit.e)};return ray_present;
}
void borrowed_ports_and_method_guards(){
    std::array<void*,60> unit_table{};std::array<void*,7> response_table{};
    unit_table[38]=reinterpret_cast<void*>(&fixture_motion);unit_table[59]=reinterpret_cast<void*>(&fixture_get_response);
    response_table[6]=reinterpret_cast<void*>(&fixture_response);VirtualObject unit{unit_table.data()},response{response_table.data()};response_object=&response;
    GroundMovingTargets::Vec velocity{};
    check(NativeGroundSensor::motion(&unit,velocity)&&velocity.n==30&&velocity.u==-4&&velocity.e==7,"virtual38 preserves three float components without promoting missing to zero");
    motion_sample={0,0,0};check(NativeGroundSensor::motion(&unit,velocity)&&GroundMovingTargets::length(velocity)==0,"legitimate measured zero motion remains available");
    motion_present=false;check(!NativeGroundSensor::motion(&unit,velocity),"missing velocity remains unavailable");motion_present=true;
    motion_sample={std::numeric_limits<float>::infinity(),0,0};check(!NativeGroundSensor::motion(&unit,velocity),"nonfinite velocity rejected");
    for(float scalar:{4.f,0.f,-1.f,std::numeric_limits<float>::quiet_NaN(),std::numeric_limits<float>::infinity()}){
        response_value=scalar;check(NativeGroundSensor::positive_response(&unit)==(std::isfinite(scalar)&&scalar>0),"borrowed response59/6 requires finite positive measured scalar");
    }
    response_object=nullptr;check(!NativeGroundSensor::positive_response(&unit),"missing response object cannot satisfy acquisition");
    std::array<void*,14> land_table{};land_table[13]=reinterpret_cast<void*>(&fixture_ray);VirtualObject land{land_table.data()};void* land_pointer=&land;NativeGroundSensor::api.land=&land_pointer;
    check(NativeGroundSensor::terrain_visible({0,1000,0},{1000,0,0}),"typed terrain13 hit is accepted in target tolerance");
    ray_present=false;check(!NativeGroundSensor::terrain_visible({0,1000,0},{1000,0,0}),"negative terrain status does not become valid zero hit");ray_present=true;
    ray_hit.n=std::numeric_limits<double>::quiet_NaN();check(!NativeGroundSensor::terrain_visible({0,1000,0},{1000,0,0}),"nonfinite terrain output cannot satisfy geometry");
    NativeGroundSensor::api.land=nullptr;
    std::array<std::byte,16> data{};std::array<void*,1> bad_table{data.data()};VirtualObject bad{bad_table.data()};
    check(!NativeGroundSensor::method<void(*)()>(&bad,0),"readable data page is never admitted as callable native method");
    check(!NativeGroundSensor::method<void(*)()>(nullptr,0),"missing native instance is rejected before virtual lookup");
}
std::map<std::string,double> published;
void* parameter_handle(const char* name){return &published[name];}
void parameter_write(void* handle,double value){*static_cast<double*>(handle)=value;}
bool parameter_read(const void*,double&,bool){return false;}
double __cdecl publication_clock(){return 10;}
void actual_publication_reason_priority(){
    EDPARAM port;
    port.ed_param_api.pfn_ed_cockpit_get_parameter_handle=&parameter_handle;
    port.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=&parameter_write;
    port.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=&parameter_read;
    struct Case{bool api_ready;int api_reason,snapshot_reason;bool snapshot_ready;double stamp;int expected;};
    const std::array cases{Case{false,1,4,false,0,1},Case{false,2,4,false,0,2},Case{false,3,4,false,0,3},
        Case{true,0,4,false,10,4},Case{true,0,5,true,10,0},Case{true,0,5,true,9,5},Case{true,0,0,false,10,4}};
    for(const auto& c:cases){
        ground_fixture.reset(ground_current);
        if(c.api_reason==1)ground_fixture.absent=0;
        if(c.api_reason==3)ground_fixture.denied="?GetModelTime@wTime@@SANXZ";
        NativeGroundSensor::api.ready=c.api_ready;NativeGroundSensor::api.reason=c.api_reason;NativeGroundSensor::api.clock=&publication_clock;
        NativeGroundSensor::Output report;report.reason=c.snapshot_reason;report.ready=c.snapshot_ready;report.stamp=c.stamp;report.generation=NativeGroundSensor::epoch.load();
        {std::lock_guard<std::mutex> lock(NativeGroundSensor::state_mutex);NativeGroundSensor::output=report;}
        NativeGroundSensor::update(port);
        check(published["F22_AG_GMT_REASON"]==c.expected,"actual completed publisher prioritizes unavailable API reason over default snapshot reason");
        check(published["F22_AG_GMT_READY"]==(c.expected==0?1:0),"diagnostic change does not fabricate readiness");
        check(published["F22_AG_GMT_LAST_TIME"]==c.stamp,"reason publication does not refresh original source time");
        check(std::fmod(published["F22_AG_NATIVE_SEQUENCE"],2)==0,"reason case publishes complete protected packet");
    }
    NativeGroundSensor::api.ready=false;NativeGroundSensor::api.reason=2;
}
}
int main(){
    exact_and_mixed_bundles();header_and_export_failures();borrowed_ports_and_method_guards();
    actual_publication_reason_priority();
    std::printf("ground host checks=%u failures=%u (inert PE modules; no DCS export invoked)\n",checks,failures);
    return failures?1:0;
}
