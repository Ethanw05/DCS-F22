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
namespace NativeGroundSensor {
unsigned samples{};
AesaRadar::SurfaceRequest pointing(double,const AesaRadar::Pose&) noexcept { return {}; }
void sample(void*, const ArrayService&) { ++samples; }
}
#define CHECK(x) do { if (!(x)) throw std::runtime_error(#x); } while (false)
namespace {
using namespace NativeAesaRadar;
std::map<std::string, double> values;
std::map<void*,std::string> text_values;
std::array<void*,4> effect_handles{};
bool coherent_effect=true;
void* handle(const char* name) { return &values[name]; }
void put(void* h, double v) {
    for (const auto effect:effect_handles) if (h==effect && static_cast<unsigned>(values["F22_AESA_SEQUENCE"])%2!=1)
        coherent_effect=false;
    *static_cast<double*>(h) = v;
}
void put_text(void* h,const char* v) {text_values[h]=v;}
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
std::array<void*,76> target_methods{};
std::array<void*,4> orientation_methods{};
std::array<void*,3> registry_methods{};
Object registry{registry_methods.data()};
void* registry_pointer = &registry;
float load_x{}, load_y = 1, load_z{};
bool invalidate_during_lookup{};
struct SceneUnit { void** table{};std::array<std::byte,288> prefix{};TypeTextView type{}; };
static_assert(offsetof(SceneUnit,type)==296);
SceneUnit own_unit{},target_unit{target_methods.data()};
std::array<void*,5> ecm_methods{};
EcmView target_ecm{ecm_methods.data(),&target_unit,1};
bool ecm_on{}, own_ecm_on{}, target_present = true;
EcmView own_ecm{ecm_methods.data(),&own_unit,1};
void* borrowed_ecm = &target_ecm;
unsigned receiver_visits = 1, ecm_reads{};
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
void* lookup(void*, unsigned host) {
    if (invalidate_during_lookup) epoch.fetch_add(1, std::memory_order_acq_rel);
    return host == 42 ? &registered : nullptr;
}
float nx(const void*) { return load_x; }
float ny(const void*) { return load_y; }
float nz(const void*) { return load_z; }
bool flag(const void* object, int mask) {
    if (mask == 32) return object != &target_unit || target_present;
    return mask==8 && ((object==&target_unit && ecm_on) || (object==&own_unit && own_ecm_on));
}
void* get_ecm(void* object) { ++ecm_reads; return object==&own_unit ? &own_ecm : borrowed_ecm; }
void query(void*, const Box&, unsigned, const Query& visitor) {
    ++queries;
    for(unsigned i=0;i<receiver_visits;++i)if(visitor(*reinterpret_cast<Scene*>(&scene)))break;
}
void segment(void*, const Vector&, const Vector&, unsigned, const Query&) {}
bool terrain(void*, const FloatVector&, const FloatVector&) { return terrain_clear; }
const char* intersection(const Scene&, const Vector&, const Vector&, Vector&, double&, Vector&) { return nullptr; }
void emitter(bool value) { emitting = value; }
void fixture() {
    reset(); repair(); values.clear();
    text_values.clear();coherent_effect=true;
    const std::array names{"F22_NATIVE_ECM_VALID","F22_NATIVE_ECM_ACTIVE","F22_NATIVE_ECM_TIME","F22_NATIVE_ECM_GENERATION"};
    for (std::size_t i=0;i<names.size();++i) effect_handles[i]=handle(names[i]);
    target_unit.type={};std::memcpy(target_unit.type.inline_text,"MiG-29S",8);
    target_unit.type.size=7;target_unit.type.capacity=15;
    ecm_on=false;own_ecm_on=false;target_present=true;own_unit.table=target_methods.data();own_ecm={ecm_methods.data(),&own_unit,1};
    for (auto& function : driver_methods) function = reinterpret_cast<void*>(&nothing);
    driver_methods[0] = nullptr; driver_methods[1] = reinterpret_cast<void*>(&destroy);
    driver_methods[7] = reinterpret_cast<void*>(&tick); driver_methods[16] = nullptr;
    driver.table = driver_methods.data()+1;
    la_methods[40] = reinterpret_cast<void*>(&own);
    scene_methods[1] = reinterpret_cast<void*>(&id); scene_methods[6] = reinterpret_cast<void*>(&registration);
    registered_methods[7] = reinterpret_cast<void*>(&unit);
    registry_methods[2] = reinterpret_cast<void*>(&lookup);
    orientation_methods[3] = reinterpret_cast<void*>(&basis);
    void* orientation_table = orientation_methods.data();
    std::memcpy(reinterpret_cast<std::byte*>(&target_unit) + 48, &orientation_table, sizeof(void*));
    target_methods[38] = reinterpret_cast<void*>(&velocity);
    target_methods[73] = reinterpret_cast<void*>(&nx);
    target_methods[74] = reinterpret_cast<void*>(&ny);
    target_methods[75] = reinterpret_cast<void*>(&nz);
    load_x = load_z = 0; load_y = 1;
    manager_methods[20] = reinterpret_cast<void*>(&query); manager_methods[24] = reinterpret_cast<void*>(&segment);
    land_methods[15] = reinterpret_cast<void*>(&terrain);
    api.clock=clock_value; api.aircraft=aircraft; api.context=cockpit; api.device=device;
    api.point=point; api.velocity=velocity; api.position=basis; api.type=type; api.dead=dead;
    api.manager=&manager_pointer; api.land=&land_pointer; api.intersect=intersection;
    api.registry=&registry_pointer;
    api.flag=flag; target_methods[57]=reinterpret_cast<void*>(&get_ecm);
    ecm_methods[1]=reinterpret_cast<void*>(&flag); ecm_methods[4]=reinterpret_cast<void*>(&get_ecm);
    api.ecm_vtable=ecm_methods.data(); api.ecm_active=ecm_methods[1]; api.ecm_strength=ecm_methods[4];
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
    parameters_api.ed_param_api.pfn_ed_cockpit_update_parameter_with_string=put_text;
    parameters_api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=get;
    update(parameters_api);
    CHECK(values["F22_AESA_DRIVER_READY"]==1 && driver.table != api.lua_vtable);
    auto pointer = *reinterpret_cast<void**>(context.data()+256);
    CHECK(pointer == &responder);
    for (int i=0;i<30;++i) {
        now=10+i*.021; values["F22_AESA_CONTROL_TIME"]=now;
        if (values["F22A_01_VALID"]==1) {
            const auto track=values["F22A_01_ID"];
            values["F22_AESA_CONTROL_TARGET"]=track;
            values["F22_AESA_CONTROL_FC_TARGET"]=track;
            values["F22_AESA_PRIORITY_01"]=track;
        }
        update(parameters_api);
        AllocationProbe::enabled=true;driver_update(&driver);AllocationProbe::enabled=false;
        update(parameters_api);
    }
    CHECK(AllocationProbe::count==0);
    CHECK(updates==30 && queries>0 && emitting && values["F22_AESA_COUNT"]==1);
    CHECK(text_values[handle("F22A_01_TYPE_NAME")]=="MiG-29S");
    const auto track=static_cast<unsigned>(values["F22A_01_ID"]);
    CHECK(track>0 && track!=42 && values["F22A_01_HITS"]>=3);
    CHECK(host_for_track(track)==42 && track_for_host(42)==track);
    GunMotion motion{};
    const auto generation = static_cast<std::uint64_t>(values["F22_AESA_GENERATION"]);
    AllocationProbe::enabled = true;
    const auto allocations = AllocationProbe::count;
    const bool motion_valid = gun_motion(track, generation, motion);
    AllocationProbe::enabled = false;
    CHECK(motion_valid && AllocationProbe::count == allocations);
    CHECK(motion.generation == generation && motion.time == now && motion.velocity[0] == 250);
    CHECK(motion.acceleration[0] == 0 && motion.acceleration[1] == 0 && motion.acceleration[2] == 0);
    CHECK(motion.position[0] == 20000 + 250 * (now - 10));
    // Native weapon state is not the noisy radar posterior, nor a derivative
    // of it. Forward/right load and gravity are transformed in world axes.
    load_x = 2; load_y = 4; load_z = -1;
    CHECK(gun_motion(track, generation, motion));
    CHECK(std::abs(motion.acceleration[0] - 19.6) < 1e-9);
    CHECK(std::abs(motion.acceleration[1] - 29.4) < 1e-9);
    CHECK(std::abs(motion.acceleration[2] + 9.8) < 1e-9);
    load_y = NAN; CHECK(!gun_motion(track, generation, motion)); load_y = 1; load_x = load_z = 0;
    CHECK(!gun_motion(track, generation + 1, motion));
    CHECK(!gun_motion(track + 1, generation, motion));
    request.controls.emit = false; CHECK(!gun_motion(track, generation, motion));
    request.controls.emit = true;
    target_present = false; CHECK(!gun_motion(track, generation, motion)); target_present = true;
    void* saved_load = target_methods[73]; target_methods[73] = nullptr;
    CHECK(!gun_motion(track, generation, motion)); target_methods[73] = saved_load;
    const auto original_epoch = epoch.load(); invalidate_during_lookup = true;
    CHECK(!gun_motion(track, generation, motion) && motion.generation == 0);
    invalidate_during_lookup = false; epoch.store(original_epoch);
    request.controls.gun_tracking = false; CHECK(!gun_motion(track, generation, motion));
    request.controls.gun_tracking = true;
    const auto measurement_time = snapshot.measurements[0].time;
    snapshot.measurements[0].time = now - .501; CHECK(!gun_motion(track, generation, motion));
    snapshot.measurements[0].time = measurement_time;
    void* saved_registry = registry_pointer; registry_pointer = nullptr;
    CHECK(!gun_motion(track, generation, motion)); registry_pointer = saved_registry;
    CHECK(values["F22A_01_FILTER_VALID"]==1 && values["F22A_01_COV_00"]>0 && values["F22A_01_COV_55"]>0);
    CHECK(values["F22A_01_OWN_VN"]==250 && values["F22A_01_FORWARD_N"]==1);
    CHECK(std::abs(values["F22A_01_RANGE_RATE"])<3*values["F22A_01_RATE_SIGMA_MPS"]);
    CHECK(values["F22_AESA_GENERATION"]>0);
    CHECK(values["F22_AESA_FC_TARGET"]==track && values["F22_AESA_FC_REVISIT_S"]==.025);
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
    CHECK(values["F22_RADAR_WEAPON_TARGET_ID"]==track);
    CHECK(values["F22_TWS_GUIDANCE_BACKEND_READY"]==1);
    const auto saved=snapshot.measurements[0];
    snapshot.measurements[0].association_valid=false;
    update(parameters_api);
    CHECK(values["F22A_01_TIME"]==saved.time && values["F22A_01_VELOCITY_VALID"]==0);
    CHECK(values["F22A_01_ASSOCIATION_VALID"]==0 && !responder.tracking(42,9001));
    CHECK(!host_for_track(track) && !track_for_host(42));
    CHECK(!gun_motion(track, generation, motion));
    snapshot.measurements[0]=saved;
    snapshot.measurements[1]=saved;snapshot.measurements[1].id=track+100;
    snapshot.bindings[1]=snapshot.bindings[0];snapshot.bindings[1].track=track+100;
    CHECK(!host_for_track(track) && !track_for_host(42));
    CHECK(!gun_motion(track, generation, motion));
    snapshot.measurements[1]={};snapshot.bindings[1]={};
    update(parameters_api);
    CHECK(values["F22A_01_VELOCITY_VALID"]==1 && responder.target()==42);

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
void receiver_scenarios() {
    fixture(); Provider provider;Pose p{};CHECK(provider.pose(p));Beam beam{};
    Interference noise{};QueryStats stats{};
    CHECK(provider.interference(now,p,beam,noise,stats));
    CHECK(noise.valid && noise.noise_ratio==0 && ecm_reads==0);
    ecm_on=true;stats={};
    const auto allocations=AllocationProbe::count;
    AllocationProbe::enabled=true;
    const bool received=provider.interference(now,p,beam,noise,stats);
    AllocationProbe::enabled=false;
    CHECK(received && AllocationProbe::count==allocations);
    CHECK(noise.valid && noise.sources==1 && std::abs(noise.noise_ratio-64)<1e-10);
    CHECK(stats.visibility_queries==1);
    terrain_clear=false;stats={};CHECK(provider.interference(now,p,beam,noise,stats));
    CHECK(noise.valid && noise.noise_ratio==0 && noise.sources==0);
    terrain_clear=true;target_ecm.owner=&own_unit;stats={};
    CHECK(!provider.interference(now,p,beam,noise,stats) && !noise.valid);
    target_ecm.owner=&target_unit;target_ecm.strength=NAN;stats={};
    CHECK(!provider.interference(now,p,beam,noise,stats));target_ecm.strength=1;
    borrowed_ecm=nullptr;stats={};CHECK(!provider.interference(now,p,beam,noise,stats));
    borrowed_ecm=&target_ecm;target_ecm.table=nullptr;stats={};
    CHECK(!provider.interference(now,p,beam,noise,stats));
    // Unsupported inactive instances are known to have no common ECM effect.
    ecm_on=false;stats={};CHECK(provider.interference(now,p,beam,noise,stats));
    CHECK(noise.valid && noise.noise_ratio==0);
    target_ecm.table=ecm_methods.data();ecm_on=true;receiver_visits=9;stats={};
    CHECK(!provider.interference(now,p,beam,noise,stats) && stats.truncated);
    CHECK(stats.visibility_queries==AesaReceiver::maximum_sources);
    ecm_on=false;receiver_visits=AesaReceiver::maximum_visits+1;stats={};
    CHECK(!provider.interference(now,p,beam,noise,stats) && stats.truncated);
    receiver_visits=1;
}
void receiver_authority() {
    fixture();EDPARAM p;
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=handle;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=put;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=get;
    update(p);ecm_on=true;borrowed_ecm=nullptr;
    for(unsigned tick=0;tick<20;++tick) {
        now+=.005;values["F22_AESA_CONTROL_TIME"]=now;
        update(p);driver_update(&driver);update(p);
    }
    CHECK(values["F22_AESA_INTERFERENCE_VALID"]==0 && values["F22_AESA_COUNT"]==0);
    CHECK(values["F22_AESA_READY"]==0 && emitting && !responder.target());
    borrowed_ecm=&target_ecm;ecm_on=false;
    for(unsigned tick=0;tick<20;++tick) {
        now+=.005;values["F22_AESA_CONTROL_TIME"]=now;
        update(p);driver_update(&driver);update(p);
    }
    CHECK(values["F22_AESA_INTERFERENCE_VALID"]==1 && values["F22_AESA_READY"]==1);
    CHECK(values["F22_AESA_INTERFERENCE_JNR"]==0 && values["F22_AESA_INTERFERENCE_TIME"]<=now);
}
void surface_publication() {
    fixture();EDPARAM p;
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=handle;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=put;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=get;
    CHECK(parameters.bind(p));
    static Snapshot state;state.status={};state.epoch=epoch.load();state.own_effect={};
    auto& status=state.status;status.ready=true;status.time=now;status.interference.valid=true;
    status.surface_sequence=9;status.surface_service=false;
    status.surface_beam.surface_search=true;status.surface_beam.surface_cells=308;
    status.surface_beam.completes=now-.01;
    status.surface_discovery_sequence=7;status.surface_discovery_work=7.0/308;
    parameters.publish(p,state,now,true);
    CHECK(values["F22_AESA_SURFACE_SERVICE"]==0);
    CHECK(values["F22_AESA_SURFACE_SEARCH"]==1);
    CHECK(values["F22_AESA_SURFACE_DISCOVERY_SEQUENCE"]==7);
    CHECK(values["F22_AESA_SURFACE_DISCOVERY_WORK"]==7.0/308);
}
void own_effect_publication() {
    fixture();static EDPARAM p;
    p.ed_param_api.pfn_ed_cockpit_get_parameter_handle=handle;
    p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=put;
    p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=get;
    values["F22_AESA_REQUEST"]=0;values["F22_AESA_CONTROL_EMIT"]=0;
    update(p);driver_update(&driver);update(p);
    CHECK(values["F22_AESA_READY"]==0 && values["F22_NATIVE_ECM_VALID"]==1);
    CHECK(values["F22_NATIVE_ECM_ACTIVE"]==0 && values["F22_NATIVE_ECM_TIME"]==now);
    own_ecm_on=true;now+=.01;driver_update(&driver);update(p);
    CHECK(values["F22_NATIVE_ECM_VALID"]==1 && values["F22_NATIVE_ECM_ACTIVE"]==1);
    CHECK(!emitting); // Own ECM effect is independent of radar emission.
    now+=.3;update(p);CHECK(values["F22_NATIVE_ECM_VALID"]==0);
    own_ecm.owner=&target_unit;driver_update(&driver);update(p);
    CHECK(values["F22_NATIVE_ECM_VALID"]==0 && values["F22_NATIVE_ECM_ACTIVE"]==0);
    own_ecm.owner=&own_unit;own_ecm_on=false;now+=.01;driver_update(&driver);update(p);
    CHECK(values["F22_NATIVE_ECM_VALID"]==1 && values["F22_NATIVE_ECM_ACTIVE"]==0);
    reset();update(p);CHECK(values["F22_NATIVE_ECM_VALID"]==0);
    CHECK(coherent_effect);
}
void type_metadata() {
    fixture();std::array<char,64> name{};
    CHECK(scene_type(&target_unit,name) && std::string(name.data())=="MiG-29S");
    const char extended[]="FA-18C_hornet_long";
    target_unit.type.pointer=extended;target_unit.type.size=sizeof(extended)-1;target_unit.type.capacity=31;
    CHECK(scene_type(&target_unit,name) && std::string(name.data())==extended);
    target_unit.type.size=64;CHECK(!scene_type(&target_unit,name) && name[0]==0);
    target_unit.type.size=17;target_unit.type.pointer=nullptr;CHECK(!scene_type(&target_unit,name));
    CHECK(!scene_type(nullptr,name));
}
void dormant_units() {
    fixture();Provider provider;Pose pose{};CHECK(provider.pose(pose));
    static std::array<Truth,maximum_candidates> reports{};
    Beam beam{};beam.direction={1,0,0};beam.half_angle=degree;beam.range_m=80000;
    std::size_t count=0;QueryStats stats{};
    // DCS keeps a dormant aircraft's spawn position and initial velocity in
    // the common scene. Neither is an actual present radar/jammer target.
    target_present=false;ecm_on=true;Interference noise{};
    CHECK(provider.query(pose,beam,reports,count,stats) && count==0);
    CHECK(provider.interference(now,pose,beam,noise,stats) && noise.sources==0 && noise.noise_ratio==0);
    target_present=true;count=0;stats={};
    CHECK(provider.query(pose,beam,reports,count,stats) && count==1);
    CHECK(reports[0].id==42 && reports[0].velocity.n==250);
    target_present=false;count=0;stats={};
    CHECK(provider.query(pose,beam,reports,count,stats) && count==0);
}
}
int main() {
    try { scenarios(); receiver_scenarios(); receiver_authority(); surface_publication(); own_effect_publication(); type_metadata(); dormant_units(); std::cout << "Owned native AESA: scene presence/activation, noisy reports, avLua clock lifetime, "
        "context responder registration, actual virtual target/support calls, expiry and teardown PASS\n"; return 0; }
    catch (const std::exception& error) { std::cerr<<error.what()<<'\n'; return 1; }
}
