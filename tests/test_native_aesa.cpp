#include <cstdlib>
#include <new>
namespace AllocationProbe { bool enabled{};unsigned count{}; }
_Use_decl_annotations_ void* operator new(std::size_t size) {
    if(AllocationProbe::enabled)++AllocationProbe::count;
    if(void* p=std::malloc(size))return p;
    throw std::bad_alloc();
}
void operator delete(void* p) noexcept { std::free(p); }
void operator delete(void* p,std::size_t) noexcept { std::free(p); }
// Actual provider, callback registration and shared responder with a synthetic DCS scene.
#include "../EFM/source/NativeAesaRadar.cpp"
#include <iostream>
#include <map>
#include <stdexcept>
namespace NativeGroundSensor { unsigned samples{}; void sample(void*, const ArrayService*) { ++samples; } }
#define CHECK(x) do { if (!(x)) throw std::runtime_error(#x); } while (false)
namespace {
using namespace NativeAesaRadar;
std::map<std::string, double> values;
void* handle(const char* name) { return &values[name]; }
void put(void* h, double v) { *static_cast<double*>(h) = v; }
bool get(const void* h, double& v, bool) { v = *static_cast<const double*>(h); return true; }
double now = 10;
double clock_value() { return now; }
struct Object { void** table; };
std::array<void*, 17> driver_methods{};
std::array<void*, 41> la_methods{};
std::array<void*, 25> manager_methods{};
std::array<void*, 16> land_methods{};
std::array<void*, 8> scene_methods{}, registered_methods{};
Object driver{driver_methods.data()+1}, la{la_methods.data()}, manager{manager_methods.data()},
    land{land_methods.data()}, scene{scene_methods.data()}, registered{registered_methods.data()};
void* driver_pointer=&driver;
int own_unit{}, target_unit{};
void* manager_pointer = &manager;
void* land_pointer = &land;
alignas(8) std::array<std::byte, 272> context{};
unsigned updates{}, queries{};
bool terrain_clear = true, emitting{};
void* cockpit() { return context.data(); }
void* device(void*, unsigned id) { return id == 13 ? driver_pointer : nullptr; }
void* aircraft() { return &la; }
void* own(void*) { return &own_unit; }
void nothing(void*) {}
void tick(void*) { ++updates; }
void* destroy(void* p, unsigned) { return p; }
const float* basis(void*) { static const float data[16]{1,0,0,0,0,1,0,0,0,0,1,0}; return data; }
Vector* point(void* p, Vector* out) { *out = p == &own_unit ? Vector{250*(now-10),3000,0} : Vector{20000+250*(now-10),3000,0}; return out; }
const FloatVector* velocity(const void*) { static const FloatVector value{250,0,0}; return &value; }
const unsigned char* type(const void*) { static const unsigned char value[]{1,1}; return value; }
bool dead(const void*) { return false; }
unsigned id(void*) { return 42; }
void* registration(void*) { return &registered; }
void* unit(void*) { return &target_unit; }
void query(void*, const Box&, unsigned, const Query& visitor) { ++queries; visitor(*reinterpret_cast<Scene*>(&scene)); }
void segment(void*, const Vector&, const Vector&, unsigned, const Query&) {}
bool terrain(void*, const FloatVector&, const FloatVector&) { return terrain_clear; }
const char* intersection(const Scene&, const Vector&, const Vector&, Vector&, double&, Vector&) { return nullptr; }
void emitter(bool value) { emitting = value; }
void fixture() {
    reset(); repair(); values.clear();
    for (auto& function : driver_methods) function = reinterpret_cast<void*>(&nothing);
    driver_methods[0] = nullptr; driver_methods[1] = reinterpret_cast<void*>(&destroy);
    driver_methods[7] = reinterpret_cast<void*>(&tick); driver_methods[16] = nullptr;
    driver.table = driver_methods.data()+1;
    la_methods[40] = reinterpret_cast<void*>(&own);
    scene_methods[1] = reinterpret_cast<void*>(&id); scene_methods[6] = reinterpret_cast<void*>(&registration);
    registered_methods[7] = reinterpret_cast<void*>(&unit);
    manager_methods[20] = reinterpret_cast<void*>(&query); manager_methods[24] = reinterpret_cast<void*>(&segment);
    land_methods[15] = reinterpret_cast<void*>(&terrain);
    api.clock=clock_value; api.aircraft=aircraft; api.context=cockpit; api.device=device;
    api.point=point; api.velocity=velocity; api.position=basis; api.type=type; api.dead=dead;
    api.manager=&manager_pointer; api.land=&land_pointer; api.intersect=intersection;
    api.lua_vtable=driver.table; api.lua_update=reinterpret_cast<void*>(&tick); api.emitter=emitter;
    api.reason=0; api.ready=true;
    for (auto name : {"F22_AESA_REQUEST","F22_AESA_CONTROL_EMIT","F22_AESA_CONTROL_RESOURCE"}) values[name]=1;
    values["F22_AESA_CONTROL_TIME"]=now; values["F22_AESA_CONTROL_SEQUENCE"]=2;
    values["F22_AESA_CONTROL_HALF_AZ"]=degree; values["F22_AESA_CONTROL_HALF_EL"]=degree;
    values["F22_AESA_CONTROL_RANGE"]=80000; values["F22_AESA_CONTROL_TARGET"]=42;
    values["F22_AESA_CONTROL_FC_TARGET"]=42; values["F22_AESA_CONTROL_GUN_TRACK"]=1;
    values["F22_AESA_PRIORITY_01"]=42;
}
void scenarios() {
    fixture(); EDPARAM parameters_api;
    parameters_api.ed_param_api.pfn_ed_cockpit_get_parameter_handle=handle;
    parameters_api.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=put;
    parameters_api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=get;
    update(parameters_api);
    CHECK(values["F22_AESA_DRIVER_READY"]==1 && driver.table != api.lua_vtable);
    auto pointer = *reinterpret_cast<void**>(context.data()+256);
    CHECK(pointer == &responder);
    for (int i=0;i<30;++i) {
        now=10+i*.021; values["F22_AESA_CONTROL_TIME"]=now;
        update(parameters_api);
        AllocationProbe::enabled=true;driver_update(&driver);AllocationProbe::enabled=false;
        update(parameters_api);
    }
    CHECK(AllocationProbe::count==0);
    CHECK(updates==30 && queries>0 && emitting && values["F22_AESA_COUNT"]==1);
    CHECK(values["F22A_01_ID"]==42 && values["F22A_01_HITS"]>=2);
    CHECK(values["F22A_01_FILTER_VALID"]==1 && values["F22A_01_COV_00"]>0 && values["F22A_01_COV_55"]>0);
    CHECK(values["F22A_01_OWN_VN"]==250 && values["F22A_01_FORWARD_N"]==1);
    CHECK(std::abs(values["F22A_01_RANGE_RATE"])<3*values["F22A_01_RATE_SIGMA_MPS"]);
    CHECK(values["F22_AESA_GENERATION"]>0);
    CHECK(values["F22_AESA_FC_TARGET"]==42 && values["F22_AESA_FC_REVISIT_S"]==.025);
    CHECK(values["F22_AESA_FC_LAST_LOOK"]>10 && values["F22_AESA_PROCESSING_S"]==.012);
    values["F22_AESA_CONTROL_GUN_TRACK"]=2;
    CHECK(!parameters.controls(parameters_api,now).controls.enabled);
    values["F22_AESA_CONTROL_GUN_TRACK"]=1;
    CHECK(std::abs(values["F22A_01_N"]-(20000+250*(values["F22A_01_TIME"]-10)))>1e-6 && values["F22A_01_RANGE_SIGMA_M"]>0);
    using Target = unsigned(__fastcall*)(const void*);
    using Tracking = bool(__fastcall*)(const void*,unsigned,unsigned);
    auto table = *static_cast<void***>(pointer);
    CHECK(reinterpret_cast<Target>(table[2])(pointer)==42);
    CHECK(reinterpret_cast<Tracking>(table[1])(pointer,42,9001));
    CHECK(values["F22_RADAR_WEAPON_TARGET_ID"]==42);
    CHECK(values["F22_TWS_GUIDANCE_BACKEND_READY"]==1);
    const auto dwells = values["F22_AESA_DWELLS"];
    driver_update(&driver); update(parameters_api); CHECK(values["F22_AESA_DWELLS"]==dwells);
    now+=.6; driver_update(&driver); update(parameters_api);
    CHECK(values["F22_AESA_COUNT"]==0 && !responder.tracking(42,9001) && !emitting);
    repair();
    CHECK(!responder.tracking(42,9001));
    damage(3,0);CHECK(array_health.load()==1);
    damage(0,.5);CHECK(array_health.load()==.5);
    damage(0,.8);CHECK(array_health.load()==.5);
    damage(0,std::numeric_limits<double>::quiet_NaN());CHECK(array_health.load()==.5);
    damage(0,0);CHECK(!responder.target());
    update(parameters_api);CHECK(values["F22_AESA_ARRAY_HEALTH"]==0);
    reset();
    CHECK(driver.table==api.lua_vtable && *reinterpret_cast<void**>(context.data()+256)==nullptr);
    CHECK(!responder.target());
    // Wrong device instances and torn command snapshots cannot grant authority.
    sample(&target_unit); CHECK(!snapshot.status.ready);
    values["F22_AESA_CONTROL_TIME"]=now; values["F22_AESA_CONTROL_SEQUENCE"]=3;
    CHECK(!parameters.controls(parameters_api,now).controls.enabled);
    // Registration never overwrites another responder or a read-only device.
    *reinterpret_cast<void**>(context.data()+256)=&target_unit;
    CHECK(!bind_responder());reset();
    CHECK(*reinterpret_cast<void**>(context.data()+256)==&target_unit);
    *reinterpret_cast<void**>(context.data()+256)=nullptr;
    void* read_only=VirtualAlloc(nullptr,4096,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE);
    CHECK(read_only);*static_cast<void***>(read_only)=driver.table;
    DWORD protection{};CHECK(VirtualProtect(read_only,4096,PAGE_READONLY,&protection));
    driver_pointer=read_only;CHECK(!bind_driver());driver_pointer=&driver;
    CHECK(VirtualFree(read_only,0,MEM_RELEASE));
}
}
int main() {
    try { scenarios(); std::cout << "Owned native AESA: scene provider, noisy reports, avLua clock lifetime, "
        "context responder registration, actual virtual target/support calls, expiry and teardown PASS\n"; return 0; }
    catch (const std::exception& error) { std::cerr<<error.what()<<'\n'; return 1; }
}
