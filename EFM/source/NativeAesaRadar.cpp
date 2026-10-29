// GPL-3.0-or-later. Own AESA sensor behind DCS's shared spatial-object interface.
// No avSimpleRadar detection, observation cache, antenna phase or aircraft DLL calls.
#include "NativeAesaRadar.h"
#include "NativeIRST.h"
#include "AesaRadar.h"
#include "AesaReceiver.h"
#include "AesaHostProfile.h"
#include "NativeGroundSensor.h"
#include "NativeGroundVideo.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <functional>
#include <limits>
#include <utility>

namespace NativeAesaRadar { namespace {
using namespace AesaRadar;
struct FloatVector { float n{}, u{}, e{}; };
struct Box { FloatVector minimum{}, maximum{}; };
struct Scene {};
using Query = std::function<int(Scene&)>;
// Native owns/destroys each64-byte by-value callback. RAX traversal result is ignored.
using SceneSearch = int(__fastcall*)(void*, const Box&, unsigned, Query);
using SceneSegment = int(__fastcall*)(void*, const Vector&, const Vector&, unsigned, Query);
static_assert(sizeof(Query) == 64, "Inspected MSVC DCS query ABI");
static_assert(sizeof(Box) == 24 && sizeof(Vector) == 24);
bool readable(const void* pointer, std::size_t size) noexcept {
    MEMORY_BASIC_INFORMATION info{};
    const auto address = reinterpret_cast<std::uintptr_t>(pointer);
    if (!pointer || !VirtualQuery(pointer, &info, sizeof(info)) || info.State != MEM_COMMIT
        || (info.Protect & (PAGE_GUARD | PAGE_NOACCESS)) || size > info.RegionSize) return false;
    const auto base = reinterpret_cast<std::uintptr_t>(info.BaseAddress);
    return address >= base && address - base <= info.RegionSize - size;
}
bool writable(void* pointer) noexcept {
    MEMORY_BASIC_INFORMATION info{};
    return pointer && VirtualQuery(pointer, &info, sizeof(info)) && info.State == MEM_COMMIT
        && !(info.Protect & (PAGE_GUARD | PAGE_NOACCESS))
        && (info.Protect & (PAGE_READWRITE | PAGE_WRITECOPY | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY));
}
template<class Function> Function method(void* object, std::size_t index) noexcept {
    if (!readable(object, sizeof(void*))) return nullptr;
    auto table = *static_cast<void***>(object);
    if (!table || !readable(table + index, sizeof(void*))) return nullptr;
    MEMORY_BASIC_INFORMATION info{};
    const auto function = table[index];
    if (!VirtualQuery(function, &info, sizeof(info))
        || !(info.Protect & (PAGE_EXECUTE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE))) return nullptr;
    return reinterpret_cast<Function>(function);
}
bool module_profile(HMODULE module, AesaHostProfile::Image& image) noexcept {
    image = {};
    if (!readable(module, sizeof(IMAGE_DOS_HEADER))) return false;
    const auto base = reinterpret_cast<const std::byte*>(module);
    const auto dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(module);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE || dos->e_lfanew < 0 || dos->e_lfanew > 1048576) return false;
    const auto pe = reinterpret_cast<const IMAGE_NT_HEADERS64*>(base + dos->e_lfanew);
    if (!readable(pe, sizeof(*pe)) || pe->Signature != IMAGE_NT_SIGNATURE
        || pe->FileHeader.Machine != IMAGE_FILE_MACHINE_AMD64
        || pe->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC) return false;
    image = {pe->FileHeader.TimeDateStamp, pe->OptionalHeader.SizeOfImage};
    return true;
}
const AesaHostProfile::Profile* qualified_profile(HMODULE common, HMODULE objects,
                                               HMODULE world, HMODULE general) noexcept {
    AesaHostProfile::Modules modules{};
    if (!module_profile(common, modules.cockpit) || !module_profile(objects, modules.objects)
        || !module_profile(world, modules.world) || !module_profile(general, modules.general)) return nullptr;
    return AesaHostProfile::select(modules);
}
struct Api {
    using Clock = double(__cdecl*)();
    using Aircraft = void*(__cdecl*)();
    using Context = void*(__cdecl*)();
    using Device = void*(__fastcall*)(void*, unsigned);
    using Emitter = void(__cdecl*)(bool);
    using Point = Vector*(__fastcall*)(void*, Vector*);
    using Velocity = const FloatVector*(__fastcall*)(const void*);
    using Type = const unsigned char*(__fastcall*)(const void*);
    using Dead = bool(__fastcall*)(const void*);
    using Coalition = int(__fastcall*)(const void*);
    using Flag = bool(__fastcall*)(const void*, int);
    using Position = const float*(__fastcall*)(void*);
    using Intersection = const char*(__fastcall*)(const Scene&, const Vector&, const Vector&, Vector&, double&, Vector&);
    HMODULE common{}, objects{}, world{}, general{};
    Clock clock{}; Aircraft aircraft{}; Point point{}; Velocity velocity{};
    Context context{}; Device device{}; Emitter emitter{};
    void* lua_vtable{}; void* lua_update{};
    Type type{}; Dead dead{}; Position position{}; Intersection intersect{};
    Flag flag{};
    Coalition coalition{}; // Optional metadata; absence must not disable sensing.
    void** ecm_vtable{};
    void* ecm_active{}; void* ecm_strength{};
    void** manager{}; void** land{}; void** registry{};
    std::atomic<bool> ready{};
    unsigned reason = 1;
    bool initialize_ecm(const AesaHostProfile::Profile& selected) noexcept {
        flag = reinterpret_cast<Flag>(GetProcAddress(general, "?IsFlag@MovingObject@@QEBA?B_NH@Z"));
        const auto base = reinterpret_cast<std::byte*>(general);
        ecm_vtable = reinterpret_cast<void**>(base + selected.ecm_table);
        ecm_active = base + selected.ecm_active; ecm_strength = base + selected.ecm_strength;
        return flag && readable(ecm_vtable, 5 * sizeof(void*))
            && ecm_vtable[1] == ecm_active && ecm_vtable[4] == ecm_strength;
    }
    bool scene_exports() const noexcept {
        return clock && aircraft && point && velocity && type && dead && position && intersect && manager && land;
    }
    bool cockpit_exports() const noexcept {
        return context && device && emitter && lua_vtable && lua_update;
    }
    void initialize() noexcept {
        if (ready.load(std::memory_order_acquire) || reason >= 2) return;
        common = GetModuleHandleW(L"CockpitBase.dll"); objects = GetModuleHandleW(L"edObjects.dll");
        world = GetModuleHandleW(L"World.dll"); general = GetModuleHandleW(L"WorldGeneral.dll");
        if (!common || !objects || !world || !general) return;
        const auto selected = qualified_profile(common, objects, world, general);
        if (!selected) { reason = 2; return; }
        clock = reinterpret_cast<Clock>(GetProcAddress(world, "?GetModelTime@wTime@@SANXZ"));
        aircraft = reinterpret_cast<Aircraft>(GetProcAddress(common, "?c_LA@cockpit@@YAPEAVIwoLA@@XZ"));
        context = reinterpret_cast<Context>(GetProcAddress(common, "?binding_context@cockpit@@YAPEAVccCockpitContext@1@XZ"));
        device = reinterpret_cast<Device>(GetProcAddress(common,
            "?get_wide_device@ccCockpitContext@cockpit@@QEAAPEAVavDevice@2@I@Z"));
        emitter = reinterpret_cast<Emitter>(GetProcAddress(common, "?c_mark_radar_emitter_active@cockpit@@YAX_N@Z"));
        lua_vtable = GetProcAddress(common, "??_7avLuaDevice@cockpit@@6BccContextRelatedObject@1@@");
        lua_update = GetProcAddress(common, "?update@avLuaDevice@cockpit@@UEAAXXZ");
        point = reinterpret_cast<Point>(GetProcAddress(general, "?GetPoint@MovingObject@@UEAA?AVVec3d@osg@@XZ"));
        velocity = reinterpret_cast<Velocity>(GetProcAddress(general, "?VectorVelocity@MovingObject@@UEBAAEBVVec3f@osg@@XZ"));
        type = reinterpret_cast<Type>(GetProcAddress(general, "?Type@MovingObject@@QEBAAEBVwsType@@XZ"));
        dead = reinterpret_cast<Dead>(GetProcAddress(general, "?IsDead@MovingObject@@UEBA_NXZ"));
        coalition = reinterpret_cast<Coalition>(GetProcAddress(general,
            "?Coalition@MovingObject@@QEBA?BW4wcCoalitionName@@XZ"));
        position = reinterpret_cast<Position>(GetProcAddress(general, "?Position@MovingObject@@UEAAAEBV?$wPosition3@M@@XZ"));
        intersect = reinterpret_cast<Intersection>(GetProcAddress(objects,
            "?intersectSegment@@YAPEBDAEBVISceneObject@@AEBVVec3d@osg@@1AEAV23@AEAN2@Z"));
        manager = reinterpret_cast<void**>(GetProcAddress(objects, "?instance@viObjectManager@@2PEAV1@EA"));
        registry = reinterpret_cast<void**>(GetProcAddress(objects, "?instance@RegisterManager@@2PEAV1@EA"));
        land = reinterpret_cast<void**>(GetProcAddress(general, "?globalLand@@3PEAVwTerrain@@EA"));
        const bool available = initialize_ecm(*selected) && scene_exports() && cockpit_exports();
        reason = available ? 0u : 3u;
        ready.store(available, std::memory_order_release);
    }
} api;
// Qualified common base-ECM layout. Borrowed only during the synchronous scene
// callback; never create ECM objects, request emission, or retain their pointers.
struct EcmView { void** table{}; void* owner{}; double strength{}; };
static_assert(sizeof(EcmView) == 24 && offsetof(EcmView, strength) == 16);
bool effect_strength(void* unit, bool& active, double& strength) noexcept {
    active = false; strength = 0;
    if (!api.flag) return false;
    if (!api.flag(unit, 8)) return true;
    using GetEcm = void*(__fastcall*)(void*);
    const auto get = method<GetEcm>(unit, 57);
    void* ecm = get ? get(unit) : nullptr;
    if (!ecm || !readable(ecm, sizeof(EcmView)) || !readable(api.ecm_vtable, 5 * sizeof(void*))) return false;
    EcmView view{}; std::memcpy(&view, ecm, sizeof(view));
    if (view.table != api.ecm_vtable || view.owner != unit
        || view.table[1] != api.ecm_active || view.table[4] != api.ecm_strength) return false;
    if (!std::isfinite(view.strength) || view.strength < 0 || view.strength > 100) return false;
    active = true; strength = view.strength;
    return true;
}
void* moving(Scene& scene) noexcept {
    using Convert = void*(__fastcall*)(void*);
    const auto registered = method<Convert>(&scene, 6);
    void* object = registered ? registered(&scene) : nullptr;
    const auto convert = method<Convert>(object, 7);
    return convert ? convert(object) : nullptr;
}
struct TypeTextView {
    union { const char* pointer; char inline_text[16]; };
    std::size_t size{},capacity{};
};
static_assert(sizeof(TypeTextView)==32);
bool scene_type(void* unit,std::array<char,64>& output) noexcept {
    output.fill(0);
    if (!unit) return false;
    // Matched RWR insertion copies model type text from the borrowed object's
    // scene metadata at +296. This never reads a sensor's contact cache.
    constexpr std::size_t offset=296;
    const auto address=static_cast<const std::byte*>(unit)+offset;
    if (!readable(address,sizeof(TypeTextView))) return false;
    TypeTextView text{};std::memcpy(&text,address,sizeof(text));
    if (!text.size || text.size>=output.size() || text.capacity<text.size || text.capacity>1048576) return false;
    const auto source=text.capacity>15 ? text.pointer : text.inline_text;
    if (text.capacity>15 && !readable(source,text.size+1)) return false;
    if (source[text.size]!=0) return false;
    for (std::size_t i=0;i<text.size;++i) {
        const auto value=static_cast<unsigned char>(source[i]);
        if (value<32 || value>126) return false;
    }
    std::memcpy(output.data(),source,text.size);
    return true;
}
std::uint32_t identity(Scene& scene) noexcept {
    using Identity = unsigned(__fastcall*)(void*);
    const auto get = method<Identity>(&scene, 1);
    return get ? get(&scene) : 0;
}
Box bounds(const Pose& pose, const Beam& beam) noexcept {
    const auto end = pose.position + beam.direction * beam.range_m;
    const double width = std::tan(beam.half_angle) * beam.range_m;
    const double n = width * std::sqrt(std::max(0.0, 1 - beam.direction.n * beam.direction.n));
    const double u = width * std::sqrt(std::max(0.0, 1 - beam.direction.u * beam.direction.u));
    const double e = width * std::sqrt(std::max(0.0, 1 - beam.direction.e * beam.direction.e));
    return {{static_cast<float>(std::min(pose.position.n, end.n - n)),
        static_cast<float>(std::min(pose.position.u, end.u - u)),
        static_cast<float>(std::min(pose.position.e, end.e - e))},
        {static_cast<float>(std::max(pose.position.n, end.n + n)),
        static_cast<float>(std::max(pose.position.u, end.u + u)),
        static_cast<float>(std::max(pose.position.e, end.e + e))}};
}
int coalition_affiliation(void* own_unit, void* other_unit) noexcept {
    if (!api.coalition || !own_unit || !other_unit) return -1;
    const int own = api.coalition(own_unit), other = api.coalition(other_unit);
    if ((own != 1 && own != 2) || (other != 1 && other != 2)) return -1;
    return own == other ? 1 : 0;
}
class Provider final : public Environment {
    void* own_{};
    bool airborne(void* unit) const noexcept {
        // Shared scene searches include dormant late-activation units. The
        // matched DCS detection path requires MovingObject's presence flag32
        // before using position/velocity. Spawn definitions are not aircraft
        // currently present in the simulated world.
        if (!api.flag || !api.flag(unit, 32)) return false;
        const auto type=api.type(unit);
        return readable(type,2) && type[0]==1 && (type[1]==1 || type[1]==2);
    }
    int candidate(Scene& scene,std::span<Truth> out,std::size_t& count) noexcept {
        void* unit=moving(scene);
        if (!unit || unit==own_ || api.dead(unit)) return 0;
        if (!airborne(unit)) return 0;
        const auto velocity=api.velocity(unit);
        if (!readable(velocity,sizeof(*velocity)) || count>=out.size()) return 1;
        Truth truth{};truth.id=identity(scene);api.point(unit,&truth.position);
        truth.velocity={velocity->n,velocity->u,velocity->e};
        // Unknown type text is deliberately empty; it never gates sensing.
        (void)scene_type(unit,truth.type_name);
        truth.coalition_affiliation = coalition_affiliation(own_, unit);
        if (truth.id && finite(truth.position) && finite(truth.velocity)) out[count++]=truth;
        return 0;
    }
    struct ReceiverQuery {
        Provider* self{}; const Pose* pose{}; const Beam* beam{};
        Interference* result{}; QueryStats* stats{};
        unsigned visits{}, active{}; bool known = true;
    };
    bool receive_source(Scene& scene, void* unit, ReceiverQuery& query) noexcept {
        bool active = false; double strength = 0;
        if (!effect_strength(unit, active, strength)) return false;
        if (!active) return true;
        if (++query.active > AesaReceiver::maximum_sources) {
            query.stats->truncated = true; return false;
        }
        Truth source{}; source.id = identity(scene); api.point(unit, &source.position);
        if (!source.id || !finite(source.position)) return false;
        ++query.stats->visibility_queries;
        if (!visible(*query.pose, source, *query.stats)) return !query.stats->truncated;
        double noise = 0;
        if (!AesaReceiver::noise_ratio(*query.pose, *query.beam, source.position, strength, noise)) return false;
        query.result->noise_ratio += noise;
        ++query.result->sources;
        return true;
    }
    int receive(Scene& scene, ReceiverQuery& query) noexcept {
        if (++query.visits > AesaReceiver::maximum_visits) {
            query.stats->truncated = true; query.known = false; return 1;
        }
        void* unit = moving(scene);
        if (!unit || unit == own_ || api.dead(unit)) return 0;
        if (!airborne(unit)) return 0;
        Vector position{}; api.point(unit, &position);
        if (!finite(position)) { query.known = false; return 1; }
        if (length(position-query.pose->position) > AesaReceiver::survey_range_m) return 0;
        query.known = receive_source(scene, unit, query);
        return query.known ? 0 : 1;
    }
public:
    bool own_effect(bool& active, double& strength) const noexcept {
        return own_ && effect_strength(own_,active,strength);
    }
    bool interference(double now, const Pose& pose, const Beam& beam,
                      Interference& result, QueryStats& stats) noexcept override {
        using Terrain = bool(__fastcall*)(void*, const FloatVector&, const FloatVector&);
        result = {false, 0, now, 0};
        void* manager = readable(api.manager, sizeof(void*)) ? *api.manager : nullptr;
        void* land = readable(api.land, sizeof(void*)) ? *api.land : nullptr;
        const auto search = method<SceneSearch>(manager, 20);
        if (!search || !method<Terrain>(land, 15) || !method<SceneSegment>(manager, 24)) return false;
        ReceiverQuery context{this, &pose, &beam, &result, &stats};
        Query each = [c = &context](Scene& scene) { return c->self->receive(scene, *c); };
        constexpr double r = AesaReceiver::survey_range_m;
        const Box box{{static_cast<float>(pose.position.n-r), static_cast<float>(pose.position.u-r), static_cast<float>(pose.position.e-r)},
            {static_cast<float>(pose.position.n+r), static_cast<float>(pose.position.u+r), static_cast<float>(pose.position.e+r)}};
        (void)search(manager, box, 32, std::move(each));
        result.valid = context.known && !stats.truncated;
        return result.valid;
    }
    bool pose(Pose& p) noexcept {
        using Own = void*(__fastcall*)(void*);
        void* aircraft = api.aircraft();
        const auto get = method<Own>(aircraft, 40);
        own_ = get ? get(aircraft) : nullptr;
        if (!own_) return false;
        const auto basis = api.position(own_);
        const auto velocity = api.velocity(own_);
        if (!readable(basis, 64) || !readable(velocity, sizeof(*velocity))) return false;
        api.point(own_, &p.position);
        p.velocity = {velocity->n, velocity->u, velocity->e};
        p.forward = {basis[0], basis[1], basis[2]}; p.up = {basis[4], basis[5], basis[6]};
        p.right = {basis[8], basis[9], basis[10]};
        return finite(p.position) && finite(p.velocity);
    }
    bool query(const Pose& pose, const Beam& beam, std::span<Truth> out,
               std::size_t& count, QueryStats& stats) noexcept override {
        void* manager = readable(api.manager, sizeof(void*)) ? *api.manager : nullptr;
        const auto search = method<SceneSearch>(manager, 20);
        if (!search) return false;
        struct Context { Provider* self; std::span<Truth> out; std::size_t* count; QueryStats* stats; };
        Context context{this, out, &count, &stats};
        // One pointer capture fits the inspected std::function small buffer.
        Query each = [c = &context](Scene& scene) {
            if (++c->stats->visited > maximum_candidates) { c->stats->truncated = true; return 1; }
            return c->self->candidate(scene,c->out,*c->count);
        };
        const auto box = bounds(pose, beam);
        (void)search(manager, box, 32, std::move(each));
        return true;
    }
    bool visible(const Pose& pose, const Truth& target, QueryStats& stats) noexcept override {
        using Terrain = bool(__fastcall*)(void*, const FloatVector&, const FloatVector&);
        void* land = readable(api.land, sizeof(void*)) ? *api.land : nullptr;
        const auto terrain = method<Terrain>(land, 15);
        if (!terrain) return false;
        const FloatVector from{static_cast<float>(pose.position.n), static_cast<float>(pose.position.u),
            static_cast<float>(pose.position.e)};
        const FloatVector to{static_cast<float>(target.position.n), static_cast<float>(target.position.u),
            static_cast<float>(target.position.e)};
        if (!terrain(land, from, to)) { ++stats.terrain_blocked; return false; }
        return objects_visible(pose.position, target, stats);
    }
    bool objects_visible(Vector from, const Truth& target, QueryStats& stats) noexcept {
        void* manager = readable(api.manager, sizeof(void*)) ? *api.manager : nullptr;
        const auto segment = method<SceneSegment>(manager, 24);
        if (!segment) return false;
        struct Context { Provider* self; Vector from, to; unsigned target{}, visits{}; bool blocked{}; };
        Context context{this, from, target.position, target.id};
        Query each = [c = &context](Scene& scene) {
            if (++c->visits > 32) { c->blocked = true; return 1; }
            if (identity(scene) == c->target || moving(scene) == c->self->own_) return 0;
            Vector hit{}, normal{}; double fraction = 2;
            if (api.intersect(scene, c->from, c->to, hit, fraction, normal)
                && fraction > .00001 && fraction < .99999) c->blocked = true;
            return c->blocked ? 1 : 0;
        };
        (void)segment(manager, from, target.position, 35, std::move(each));
        if (context.blocked) ++stats.object_blocked;
        if (context.visits > 32) stats.truncated = true;
        return !context.blocked;
    }
};
struct Request { Controls controls{}; double stamp = -100; };
struct OwnEffect { bool valid{}, active{}; double time = -100; };
struct Snapshot { Status status{}; std::array<Measurement, maximum_tracks> measurements{}; std::array<Binding, maximum_tracks> bindings{}; std::uint64_t epoch{}; OwnEffect own_effect{}; };
SRWLOCK state_lock = SRWLOCK_INIT;
Request request;
Snapshot snapshot;
// Each scratch buffer has one callback owner. Large fixed snapshots never
// become automatic stack temporaries; state_lock protects only shared state.
Snapshot sensor_scratch, publication_scratch;
Model model;
std::atomic<void*> owner{};
std::atomic<std::uint64_t> epoch{1};
std::atomic<double> array_health{1};
std::uint64_t sampled_epoch{};
std::uint32_t publication{};
struct Parameters {
    static constexpr std::array input_names{
        "F22_AESA_REQUEST", "F22_AESA_CONTROL_TIME", "F22_AESA_CONTROL_SEQUENCE", "F22_AESA_CONTROL_EMIT",
        "F22_AESA_CONTROL_RESOURCE", "F22_AESA_CONTROL_SURFACE", "F22_AESA_CONTROL_AZ", "F22_AESA_CONTROL_EL",
        "F22_AESA_CONTROL_HALF_AZ", "F22_AESA_CONTROL_HALF_EL", "F22_AESA_CONTROL_RANGE",
        "F22_AESA_CONTROL_CUE_VALID", "F22_AESA_CONTROL_CUE_AZ", "F22_AESA_CONTROL_CUE_EL",
        "F22_AESA_CONTROL_TARGET", "F22_AESA_CONTROL_SURFACE_HALF_AZ",
        "F22_AESA_CONTROL_FC_TARGET", "F22_AESA_CONTROL_GUN_TRACK",
        "F22_AESA_CONTROL_CUE_HALF_AZ", "F22_AESA_CONTROL_CUE_HALF_EL", "F22_AESA_CONTROL_CUE_REQUEST", "F22_AESA_CONTROL_CUE_RANGE"};
    static constexpr std::array output_names{
        "F22_AESA_READY", "F22_AESA_REASON", "F22_AESA_TIME", "F22_AESA_SEQUENCE", "F22_AESA_COUNT",
        "F22_AESA_BEAM_AZ", "F22_AESA_BEAM_EL", "F22_AESA_DWELLS", "F22_AESA_SEARCH_DWELLS",
        "F22_AESA_TRACK_DWELLS", "F22_AESA_DETECTIONS", "F22_AESA_MISSES", "F22_AESA_PENDING",
        "F22_AESA_DROPS", "F22_AESA_TERRAIN_BLOCKED", "F22_AESA_OBJECT_BLOCKED", "F22_AESA_TRUNCATED",
        "F22_AESA_DRIVER_READY", "F22_TWS_GUIDANCE_BACKEND_READY", "F22_RADAR_WEAPON_TARGET_ID",
        "F22_AESA_SURFACE_SERVICE", "F22_AESA_SURFACE_AZ", "F22_AESA_SURFACE_SEQUENCE", "F22_AESA_ARRAY_KNOWN", "F22_AESA_ARRAY_HEALTH", "F22_AESA_RESOURCE", "F22_AESA_PROCESSING_S", "F22_AESA_GENERATION",
        "F22_AESA_FC_TARGET", "F22_AESA_FC_REVISIT_S", "F22_AESA_FC_LAST_LOOK", "F22_AESA_DEADLINE_MISSES",
        "F22_AESA_CUE_REQUEST", "F22_AESA_CUE_TIME", "F22_AESA_CUE_DWELLS",
        "F22_AESA_ASSOCIATION_AMBIGUOUS", "F22_AESA_ASSOCIATION_DROPPED",
        "F22_AESA_SURFACE_EL", "F22_AESA_SURFACE_HALF", "F22_AESA_SURFACE_RANGE", "F22_AESA_SURFACE_TIME",
        "F22_AESA_SURFACE_SEARCH", "F22_AESA_SURFACE_CELLS",
        "F22_AESA_INTERFERENCE_VALID", "F22_AESA_INTERFERENCE_JNR", "F22_AESA_INTERFERENCE_TIME", "F22_AESA_INTERFERENCE_SOURCES",
        "F22_AESA_SURFACE_DISCOVERY_SEQUENCE", "F22_AESA_SURFACE_DISCOVERY_WORK",
        "F22_NATIVE_ECM_VALID", "F22_NATIVE_ECM_ACTIVE", "F22_NATIVE_ECM_TIME", "F22_NATIVE_ECM_GENERATION"};
    static constexpr std::array fields{"VALID", "ID", "TIME", "N", "U", "E", "VN", "VU", "VE",
        "VELOCITY_VALID", "RANGE_SIGMA_M", "ANGLE_SIGMA_RAD", "HITS",
        "FILTER_VALID", "POSITION_SIGMA_M", "VELOCITY_SIGMA_MPS", "RAW_N", "RAW_U", "RAW_E",
        "MEASURED_RANGE", "MEASURED_AZ", "MEASURED_EL", "RANGE_RATE", "RATE_SIGMA_MPS",
        "ORIGIN_N", "ORIGIN_U", "ORIGIN_E", "OWN_VN", "OWN_VU", "OWN_VE",
        "FORWARD_N", "FORWARD_U", "FORWARD_E", "UP_N", "UP_U", "UP_E", "RIGHT_N", "RIGHT_U", "RIGHT_E",
        "COV_00", "COV_01", "COV_02", "COV_03", "COV_04", "COV_05",
        "COV_11", "COV_12", "COV_13", "COV_14", "COV_15", "COV_22", "COV_23", "COV_24", "COV_25",
        "COV_33", "COV_34", "COV_35", "COV_44", "COV_45", "COV_55", "ASSOCIATION_VALID",
        "COALITION_KNOWN", "COALITION_AFFILIATION"};
    std::array<void*, input_names.size()> inputs{};
    std::array<void*, output_names.size()> outputs{};
    std::array<void*, 10> priorities{};
    std::array<std::array<void*, fields.size()>, maximum_tracks> contacts{};
    std::array<void*,maximum_tracks> type_names{};
    std::array<std::array<char,64>,maximum_tracks> published_types{};
    std::array<bool,maximum_tracks> published_type_valid{};
    std::array<double, maximum_tracks> published_time{};
    std::array<unsigned, maximum_tracks> published_id{};
    std::atomic<bool> bound{};
    const EDPARAM* parameter_owner{};
    std::uint64_t parameter_epoch{};
    bool current_context(const EDPARAM& p) const noexcept {
        return bound && parameter_owner==&p && parameter_epoch==p.epoch() && p.numericReady()
            && p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number;
    }
    bool bind(EDPARAM& p) noexcept {
        if (current_context(p)) return true;
        bound = false;
        published_id.fill(0);
        published_type_valid.fill(false);
        if (!p.ed_param_api.pfn_ed_cockpit_get_parameter_handle
            || !p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number
            || !p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number) return false;
        for (std::size_t i = 0; i < inputs.size(); ++i) if (!(inputs[i] = p.getParamHandle(input_names[i]))) return false;
        for (std::size_t i = 0; i < outputs.size(); ++i) if (!(outputs[i] = p.getParamHandle(output_names[i]))) return false;
        char name[64]{};
        for (std::size_t i = 0; i < priorities.size(); ++i) {
            std::snprintf(name, sizeof(name), "F22_AESA_PRIORITY_%02u", static_cast<unsigned>(i + 1));
            if (!(priorities[i] = p.getParamHandle(name))) return false;
        }
        for (std::size_t i = 0; i < contacts.size(); ++i) for (std::size_t j = 0; j < fields.size(); ++j) {
            std::snprintf(name, sizeof(name), "F22A_%02u_%s", static_cast<unsigned>(i + 1), fields[j]);
            if (!(contacts[i][j] = p.getParamHandle(name))) return false;
        }
        for (std::size_t i=0;i<type_names.size();++i) {
            std::snprintf(name,sizeof(name),"F22A_%02u_TYPE_NAME",static_cast<unsigned>(i+1));
            type_names[i]=p.getParamHandle(name);
        }
        parameter_owner = &p;
        parameter_epoch = p.epoch();
        bound = true; return true;
    }
    double read(EDPARAM& p, void* handle) noexcept {
        double value = std::numeric_limits<double>::quiet_NaN();
        const auto convert = p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number;
        if (!handle || !convert || !convert(handle, value, false))
            return std::numeric_limits<double>::quiet_NaN();
        return value;
    }
    using CommandValues = std::array<double, input_names.size()>;
    static bool command_clock(const CommandValues& values, double now) noexcept {
        const double sequence = values[2], stamp = values[1];
        return std::isfinite(now) && std::isfinite(sequence) && sequence >= 2 && std::fmod(sequence, 2) == 0
            && std::isfinite(stamp) && now - stamp >= -.01 && now - stamp <= .5;
    }
    static bool identifier(double value, std::uint32_t& result) noexcept {
        if (!std::isfinite(value) || value < 0 || value >= 4294967295.0 || value != std::floor(value)) return false;
        result = static_cast<std::uint32_t>(value);
        return true;
    }
    static bool focus(Controls& controls, const CommandValues& values) noexcept {
        if (!identifier(values[16], controls.fire_control_id)) return false;
        if (values[17] != 0 && values[17] != 1) return false;
        controls.gun_tracking = values[17] == 1;
        return !controls.gun_tracking || controls.fire_control_id != 0;
    }
    bool copy_values(EDPARAM& p,CommandValues& values,double sequence) noexcept {
        values[2]=sequence;
        for (std::size_t i=0;i<values.size();++i) {
            if (i==2) continue;
            values[i]=read(p,inputs[i]);
            if (!std::isfinite(values[i])) return false;
        }
        for (const auto i : {0,3,5,11,17}) if (values[i]!=0 && values[i]!=1) return false;
        return true;
    }
    Request controls(EDPARAM& p, double now) noexcept {
        const auto generation = epoch.load(std::memory_order_acquire);
        const auto context_epoch = p.epoch();
        const double sequence = read(p, inputs[2]);
        if (!std::isfinite(sequence) || sequence < 2 || sequence >= 16000002
            || std::fmod(sequence,2) != 0) return {};
        CommandValues values{};
        if (!copy_values(p,values,sequence)) return {};
        Request r{};
        if (!command_clock(values, now)) return r;
        r.controls.enabled = values[0] == 1; r.controls.emit = values[3] == 1;
        r.controls.resource = values[4]; r.controls.surface = values[5] == 1;
        r.controls.azimuth = values[6]; r.controls.elevation = values[7];
        r.controls.half_azimuth = values[8]; r.controls.half_elevation = values[9];
        r.controls.range_m = values[10]; r.controls.cue_valid = values[11] == 1;
        r.controls.cue_azimuth = values[12]; r.controls.cue_elevation = values[13];
        r.controls.surface_half_azimuth = values[15];
        r.controls.cue_half_azimuth = values[18]; r.controls.cue_half_elevation = values[19];
        r.controls.cue_range_m = values[21];
        if (!identifier(values[20], r.controls.cue_request)) return {};
        const bool selected_valid = identifier(values[14], r.controls.selected_id);
        if (!selected_valid) return {};
        if (!focus(r.controls, values)) return {};
        for (std::size_t i = 0; i < priorities.size(); ++i) {
            const bool valid = identifier(read(p, priorities[i]), r.controls.priority_ids[i]);
            if (!valid) return {};
        }
        if (sequence != read(p, inputs[2]) || generation != epoch.load(std::memory_order_acquire)
            || context_epoch != p.epoch()) return {};
        r.stamp = values[1]; r.controls.generation = generation; return r;
    }
    bool numeric_complete = false;
    void invalidate_publication_cache() noexcept {
        published_id.fill(0);
        published_time.fill(-100);
        published_type_valid.fill(false);
        for (auto &type : published_types)
            type.fill(0);
    }
    void write_number(EDPARAM &p, void *handle, double value) noexcept {
        if (!current_context(p)) {
            numeric_complete = false;
            return;
        }
        const bool written = p.setParamNumber(handle, value);
        numeric_complete = written && current_context(p) && numeric_complete;
    }
    static bool snapshot_fresh(const Snapshot &s, double now, bool enabled) noexcept {
        const auto &q = s.status;
        return enabled && q.ready && q.interference.valid &&
               s.epoch == epoch.load(std::memory_order_acquire) && now - q.time >= -.01 &&
               now - q.time <= .5;
    }
    bool publication_current(const EDPARAM &p, std::uint64_t context_epoch,
                             std::uint64_t source_epoch) const noexcept {
        return current_context(p) && context_epoch == p.epoch() &&
               source_epoch == epoch.load(std::memory_order_acquire);
    }
    void withdraw_publication(EDPARAM &p) noexcept {
        invalidate_publication_cache();
        if (!current_context(p))
            return; // Never reuse handles after context loss.
        // Deliberate best effort: no even commit follows any failed publication.
        (void)p.setParamNumber(outputs[3], publication + 1);
        (void)p.setParamNumber(outputs[0], 0);
        (void)p.setParamNumber(outputs[4], 0);
        for (const auto &contact : contacts) {
            (void)p.setParamNumber(contact[0], 0);
            (void)p.setParamNumber(contact.back(), 0);
            (void)p.setParamNumber(contact[9], 0);
        }
    }
    void publish(EDPARAM &p, const Snapshot &s, double now, bool enabled) noexcept {
        numeric_complete = true;
        const auto context_epoch = p.epoch();
        publication = (publication + 2) % 16000000;
        write_number(p, outputs[3], publication + 1);
        if (!numeric_complete) {
            invalidate_publication_cache();
            return;
        }
        const bool fresh = snapshot_fresh(s, now, enabled);
        unsigned count = 0;
        for (std::size_t i = 0; i < s.measurements.size(); ++i)
            if (publish_contact(p, i, s.measurements[i], fresh))
                ++count;
        publish_status(p, s, fresh, count);
        publish_own_effect(p, s, now);
        if (!numeric_complete || !publication_current(p, context_epoch, s.epoch)) {
            withdraw_publication(p);
            return;
        }
        write_number(p, outputs[3], publication + 2);
        if (!numeric_complete || !publication_current(p, context_epoch, s.epoch))
            withdraw_publication(p);
    }
    void publish_authority(EDPARAM &p, std::size_t i, const Measurement &m, bool valid) noexcept {
        const bool associated = valid && m.association_valid;
        const bool identified = associated && (m.coalition_affiliation == 0 || m.coalition_affiliation == 1);
        write_number(p, contacts[i][fields.size() - 3], associated ? 1 : 0);
        write_number(p, contacts[i][fields.size() - 2], identified ? 1 : 0);
        write_number(p, contacts[i].back(), identified ? m.coalition_affiliation : -1);
        write_number(p, contacts[i][9], valid && m.association_valid && m.velocity_valid ? 1 : 0);
    }
    static auto contact_values(const Measurement &m) noexcept {
        return std::array{1.0,
                          static_cast<double>(m.id),
                          m.time,
                          m.position.n,
                          m.position.u,
                          m.position.e,
                          m.velocity.n,
                          m.velocity.u,
                          m.velocity.e,
                          m.velocity_valid && m.association_valid ? 1.0 : 0.0,
                          m.range_sigma_m,
                          m.angle_sigma_rad,
                          static_cast<double>(m.hits),
                          m.filter_valid ? 1.0 : 0.0,
                          m.position_sigma_m,
                          m.velocity_sigma_mps,
                          m.raw_position.n,
                          m.raw_position.u,
                          m.raw_position.e,
                          m.measured_range,
                          m.measured_azimuth,
                          m.measured_elevation,
                          m.measured_range_rate,
                          m.rate_sigma_mps,
                          m.sensor_origin.n,
                          m.sensor_origin.u,
                          m.sensor_origin.e,
                          m.sensor_velocity.n,
                          m.sensor_velocity.u,
                          m.sensor_velocity.e,
                          m.sensor_forward.n,
                          m.sensor_forward.u,
                          m.sensor_forward.e,
                          m.sensor_up.n,
                          m.sensor_up.u,
                          m.sensor_up.e,
                          m.sensor_right.n,
                          m.sensor_right.u,
                          m.sensor_right.e};
    }
    static bool finite_measurement(const Measurement &m) noexcept {
        for (const double value : contact_values(m))
            if (!std::isfinite(value))
                return false;
        for (const double value : m.covariance)
            if (!std::isfinite(value))
                return false;
        return true;
    }
    void write_contact_payload(EDPARAM &p, std::size_t i, const Measurement &m) noexcept {
        const auto values = contact_values(m);
        for (std::size_t j = 0; j < values.size(); ++j)
            write_number(p, contacts[i][j], values[j]);
        for (std::size_t j = 0; j < m.covariance.size(); ++j)
            write_number(p, contacts[i][values.size() + j], m.covariance[j]);
    }
    bool publish_contact(EDPARAM &p, std::size_t i, const Measurement &m, bool fresh) noexcept {
        bool valid = fresh && m.valid;
        if (valid && !finite_measurement(m)) {
            numeric_complete = false;
            valid = false;
        }
        publish_type(p, i, m, valid);
        write_number(p, contacts[i][0], valid ? 1 : 0);
        publish_authority(p, i, m, valid);
        if (!valid) {
            published_id[i] = 0;
            return false;
        }
        // Payload/covariance remain immutable between completed measurements.
        if (published_id[i] == m.id && published_time[i] == m.time)
            return true;
        write_contact_payload(p, i, m);
        if (numeric_complete) {
            published_id[i] = m.id;
            published_time[i] = m.time;
        }
        return true;
    }
    void gated(EDPARAM &p, std::size_t index, double value, bool valid) noexcept {
        write_number(p, outputs[index], valid ? value : 0);
    }
    void publish_unknown_type(EDPARAM &p, std::size_t i) noexcept {
        // The public numeric parameter setter replaces text with typed zero.
        // Actual Lua metadata/label readers treat a non-string type as unknown.
        write_number(p, type_names[i], 0);
        published_type_valid[i] = false;
        published_types[i].fill(0);
    }
    void publish_type(EDPARAM &p, std::size_t i, const Measurement &m, bool valid) noexcept {
        if (!current_context(p)) {
            numeric_complete = false;
            return;
        }
        if (!type_names[i]) {
            if (valid)
                numeric_complete = false;
            return;
        }
        if (!p.ed_param_api.pfn_ed_cockpit_update_parameter_with_string) {
            publish_unknown_type(p, i);
            return;
        }
        const char *name = valid ? m.type_name.data() : "";
        if (published_type_valid[i] &&
            std::strncmp(name, published_types[i].data(), published_types[i].size()) == 0)
            return;
        if (!p.setParamString(type_names[i], name)) {
            publish_unknown_type(p, i);
            return;
        }
        published_type_valid[i] = true;
        published_types[i].fill(0);
        if (valid)
            published_types[i] = m.type_name;
    }
    void publish_surface(EDPARAM &p, const Status &q, bool fresh) noexcept {
        const auto &beam = q.surface_beam;
        const double depression =
            std::atan2(beam.direction.u, std::hypot(beam.direction.n, beam.direction.e));
        const bool surface_known = fresh && q.surface_sequence > 0;
        gated(p, 37, depression, surface_known);
        gated(p, 38, beam.half_angle, surface_known);
        gated(p, 39, beam.range_m, surface_known);
        write_number(p, outputs[40], surface_known ? beam.completes : -100);
        gated(p, 41, beam.surface_search ? 1 : 0, surface_known);
        gated(p, 42, beam.surface_cells, surface_known);
        gated(p, 47, q.surface_discovery_sequence, surface_known);
        gated(p, 48, q.surface_discovery_work, surface_known);
    }
    void publish_interference(EDPARAM &p, const Status &q, bool fresh) noexcept {
        const bool known = fresh && q.interference.valid;
        gated(p, 43, 1, known);
        gated(p, 44, q.interference.noise_ratio, known);
        write_number(p, outputs[45], known ? q.interference.time : -100);
        gated(p, 46, q.interference.sources, known);
    }
    void publish_own_effect(EDPARAM &p, const Snapshot &s, double now) noexcept {
        // The shared native callback samples ECM even with radar OFF. Never
        // infer an effect from the cockpit switch or our receiver's readiness.
        const auto &effect = s.own_effect;
        const bool known = effect.valid && s.epoch == epoch.load(std::memory_order_acquire) &&
                           std::isfinite(now) && now >= effect.time && now - effect.time <= .25;
        gated(p, 49, 1, known);
        gated(p, 50, effect.active ? 1 : 0, known);
        write_number(p, outputs[51], known ? effect.time : -100);
        write_number(p, outputs[52], static_cast<double>(s.epoch));
    }
    void publish_status(EDPARAM &p, const Snapshot &s, bool fresh, unsigned count) noexcept {
        const auto &q = s.status;
        const std::array values{fresh ? 1.0 : 0.0,
                                fresh ? 0.0 : static_cast<double>(api.reason ? api.reason : 4),
                                q.time,
                                static_cast<double>(publication + 2),
                                static_cast<double>(count),
                                q.beam.azimuth,
                                q.beam.elevation,
                                static_cast<double>(q.dwells),
                                static_cast<double>(q.search_dwells),
                                static_cast<double>(q.track_dwells),
                                static_cast<double>(q.detections),
                                static_cast<double>(q.misses),
                                static_cast<double>(q.pending),
                                static_cast<double>(q.queue_drops),
                                static_cast<double>(q.terrain_blocked),
                                static_cast<double>(q.object_blocked),
                                q.truncated ? 1.0 : 0.0};
        for (std::size_t i = 0; i < values.size(); ++i)
            if (i != 3)
                write_number(p, outputs[i], values[i]);
        gated(p, 20, q.surface_service ? 1 : 0, fresh);
        write_number(p, outputs[21], q.surface_azimuth);
        write_number(p, outputs[22], q.surface_sequence);
        gated(p, 25, q.resource, fresh);
        gated(p, 26, q.processing_s, fresh);
        write_number(p, outputs[27], static_cast<double>(s.epoch));
        gated(p, 28, q.fire_control_id, fresh);
        gated(p, 29, q.fire_control_revisit_s, fresh);
        write_number(p, outputs[30], fresh ? q.fire_control_last_look : -100);
        write_number(p, outputs[31], q.deadline_misses);
        gated(p, 32, q.cue_request, fresh);
        write_number(p, outputs[33], fresh ? q.cue_time : -100);
        write_number(p, outputs[34], q.cue_dwells);
        write_number(p, outputs[35], q.association_ambiguous);
        write_number(p, outputs[36], q.association_dropped);
        publish_surface(p, q, fresh);
        publish_interference(p, q, fresh);
    }
} parameters;
bool fresh(double now, double stamp, double age) noexcept {
    return std::isfinite(now) && std::isfinite(stamp) && now >= stamp && now - stamp <= age;
}
bool request_current(const Request& value,double now,std::uint64_t generation) noexcept {
    return std::isfinite(now) && std::isfinite(value.stamp)
        && now-value.stamp>=-.01 && now-value.stamp<=.5 && value.controls.generation==generation;
}
bool bridge_ready(double now) noexcept {
    return request.controls.enabled && request.controls.emit && snapshot.status.ready && snapshot.status.interference.valid
        && snapshot.epoch == epoch.load(std::memory_order_acquire)
        && request.controls.generation == snapshot.epoch
        && fresh(now,request.stamp,.5) && fresh(now,snapshot.status.time,.5);
}
bool eligible(std::size_t index, double now) noexcept {
    const auto& t = snapshot.measurements[index];
    const auto& b = snapshot.bindings[index];
    return t.valid && t.association_valid && t.velocity_valid && t.hits >= 3 && fresh(now,t.time,6)
        && b.track == t.id && b.host && b.qualified;
}
bool unique_host(unsigned host, double now) noexcept {
    unsigned matches = 0;
    for (std::size_t index=0;index<snapshot.bindings.size();++index)
        if (snapshot.bindings[index].host == host && eligible(index,now)) ++matches;
    return matches == 1;
}
unsigned translate(unsigned id, bool to_host) noexcept {
    const double now = api.clock ? api.clock() : -100;
    unsigned result = 0;
    AcquireSRWLockShared(&state_lock);
    if (id && bridge_ready(now)) for (std::size_t index=0;index<snapshot.measurements.size();++index) {
        const auto& binding = snapshot.bindings[index];
        const auto source = to_host ? binding.track : binding.host;
        if (source != id || !eligible(index,now)) continue;
        if (result) { result = 0; break; } // Never choose between duplicate host bindings.
        result = to_host ? binding.host : binding.track;
    }
    if (to_host && result && !unique_host(result,now)) result = 0;
    ReleaseSRWLockShared(&state_lock);
    return result;
}
struct GunBinding { unsigned host{}; std::uint64_t generation{}; };
GunBinding gun_binding(unsigned track, std::uint64_t generation, double now) noexcept {
    GunBinding result{};
    AcquireSRWLockShared(&state_lock);
    if (bridge_ready(now) && generation == snapshot.epoch && request.controls.gun_tracking
        && request.controls.selected_id == track && request.controls.fire_control_id == track) {
        for (std::size_t index = 0; index < snapshot.measurements.size(); ++index) {
            const auto& t = snapshot.measurements[index];
            const auto& b = snapshot.bindings[index];
            if (t.id != track || !eligible(index, now) || !fresh(now, t.time, .5)) continue;
            if (result.host || !unique_host(b.host, now)) { result = {}; break; }
            result = {b.host, snapshot.epoch};
        }
    }
    ReleaseSRWLockShared(&state_lock);
    return result;
}
bool load_acceleration(void* unit, Vector& acceleration) noexcept {
    // Hornet 0x180382320..0x1803823FC: ALL THREE load returns are float
    // (mulss immediately follows each call). The decompiler's double is wrong.
    using Basis = const float*(__fastcall*)(void*);
    using Load = float(__fastcall*)(const void*);
    auto orientation = static_cast<std::byte*>(unit) + 48;
    const auto basis_method = method<Basis>(orientation, 3);
    const auto nx = method<Load>(unit, 73), ny = method<Load>(unit, 74), nz = method<Load>(unit, 75);
    if (!basis_method || !nx || !ny || !nz) return false;
    const auto basis = basis_method(orientation);
    if (!basis || !readable(basis, 12 * sizeof(float))) return false;
    Vector forward{basis[0], basis[1], basis[2]}, up{basis[4], basis[5], basis[6]}, right{basis[8], basis[9], basis[10]};
    if (!finite(forward) || !finite(up) || !finite(right)
        || std::abs(length(forward) - 1) > .01 || std::abs(length(up) - 1) > .01
        || std::abs(length(right) - 1) > .01) return false;
    const double x = nx(unit), y = ny(unit), z = nz(unit);
    if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(z)
        || std::abs(x) > 20 || std::abs(y) > 20 || std::abs(z) > 20) return false;
    acceleration = (forward * x + up * y + right * z) * 9.8 - Vector{0, 9.8, 0};
    return finite(acceleration) && length(acceleration) <= 150;
}
bool read_gun_motion(unsigned host, GunMotion& output) noexcept {
    using Lookup = void*(__fastcall*)(void*, unsigned);
    using Convert = void*(__fastcall*)(void*);
    void* registry = readable(api.registry, sizeof(void*)) ? *api.registry : nullptr;
    const auto lookup = method<Lookup>(registry, 2);
    void* registered = lookup ? lookup(registry, host) : nullptr;
    const auto convert = method<Convert>(registered, 7);
    void* unit = convert ? convert(registered) : nullptr;
    if (!unit || !api.dead || !api.type || !api.point || !api.flag
        || api.dead(unit) || !api.flag(unit, 32)) return false;
    const auto type = api.type(unit);
    if (!readable(type, 2) || type[0] != 1 || (type[1] != 1 && type[1] != 2)) return false;
    const auto get_velocity = method<Api::Velocity>(unit, 38);
    const auto velocity = get_velocity ? get_velocity(unit) : nullptr;
    if (!velocity || !readable(velocity, sizeof(*velocity))) return false;
    const Vector v{velocity->n, velocity->u, velocity->e};
    Vector p{}, a{}; api.point(unit, &p);
    if (!finite(p) || !finite(v) || length(v) > 1500 || !load_acceleration(unit, a)) return false;
    output.position = {p.n, p.u, p.e}; output.velocity = {v.n, v.u, v.e};
    output.acceleration = {a.n, a.u, a.e};
    return true;
}
unsigned selected_track() noexcept {
    AcquireSRWLockShared(&state_lock);
    const auto selected = request.controls.selected_id;
    ReleaseSRWLockShared(&state_lock);
    return selected && translate(selected,true) ? selected : 0;
}
// The host borrows this interface through ccCockpitContext+256. It owns no
// storage here. Its four virtual methods match the inspected shared responder ABI.
class Responder {
public:
    virtual ~Responder() = default;
    virtual bool tracking(unsigned host, unsigned /*weapon*/) const noexcept {
        return translate(host,false) != 0;
    }
    virtual unsigned target() const noexcept { return translate(selected_track(),true); }
    virtual double range() const noexcept {
        const auto selected = selected_track();
        if (!selected) return -1;
        double result = -1;
        AcquireSRWLockShared(&state_lock);
        for (const auto& t : snapshot.measurements) if (t.valid && t.id == selected) {
            // Range is measured geometry; no native target-truth lookup.
            result = length(t.position - origin); break;
        }
        ReleaseSRWLockShared(&state_lock); return result;
    }
    Vector origin{};
} responder;
void** responder_slot{};
std::array<void*, 65> driver_table{};
std::atomic<void**> driver_original{};
void** driver_slot{};
void __fastcall driver_update(void* self) noexcept {
    const auto original = driver_original.load(std::memory_order_acquire);
    if (owner.load(std::memory_order_acquire) != self || !original) return;
    using Update = void(__fastcall*)(void*);
    reinterpret_cast<Update>(original[6])(self);
    sample(self);
    NativeIRST::sample();
}
void __fastcall driver_final_release(void* self) noexcept {
    NativeIRST::retire();
    using FinalRelease = void(__fastcall*)(void*);
    const auto original = driver_original.load(std::memory_order_acquire);
    const auto release = original ? reinterpret_cast<FinalRelease>(original[0]) : nullptr;
    reset();
    if (release) release(self);
}
bool bind_driver() noexcept {
    void* context = api.context();
    void* driver = context ? api.device(context, 13) : nullptr;
    if (!driver || !readable(driver, sizeof(void*)) || !writable(driver)) return false;
    auto slot = static_cast<void***>(driver);
    if (*slot == driver_table.data() + 1) return owner.load(std::memory_order_acquire) == driver;
    if (driver_slot || *slot != api.lua_vtable) return false;
    auto original = *slot;
    if (!readable(original - 1, 9 * sizeof(void*)) || original[6] != api.lua_update) return false;
    std::size_t count = 0;
    for (; count < 64; ++count) if (!method<void(*)(void*)>(driver, count)) break;
    if (count < 7 || count == 64) return false;
    driver_table[0] = original[-1];
    for (std::size_t i = 0; i < count; ++i) driver_table[i + 1] = original[i];
    driver_table[1] = reinterpret_cast<void*>(&driver_final_release);
    driver_table[7] = reinterpret_cast<void*>(&driver_update);
    driver_original = original; driver_slot = reinterpret_cast<void**>(slot);
    attach(driver);
    const auto previous = InterlockedCompareExchangePointer(reinterpret_cast<PVOID volatile*>(slot),
        driver_table.data() + 1, original);
    if (previous == original) return true;
    driver_original = nullptr; driver_slot = nullptr; owner = nullptr;
    return false;
}
bool bind_responder() noexcept {
    auto context = static_cast<std::byte*>(api.context());
    if (!context || !readable(context, 264)) return false;
    auto slot = reinterpret_cast<void**>(context + 256);
    if (!writable(slot)) return false;
    const auto previous = InterlockedCompareExchangePointer(reinterpret_cast<PVOID volatile*>(slot), &responder, nullptr);
    if (previous && previous != &responder) return false;
    responder_slot = slot; return true;
}
}
unsigned host_for_track(unsigned track) noexcept { return translate(track,true); }
unsigned track_for_host(unsigned host) noexcept { return translate(host,false); }
bool gun_motion(unsigned track, std::uint64_t generation, GunMotion& output) noexcept {
    output = {};
    if (!api.ready.load(std::memory_order_acquire) || !api.clock) return false;
    const double now = api.clock();
    const auto binding = gun_binding(track, generation, now);
    if (!binding.host) return false;
    GunMotion value{};
    if (!read_gun_motion(binding.host, value)) return false;
    const double completed = api.clock();
    const auto checked = gun_binding(track, generation, completed);
    if (checked.host != binding.host || checked.generation != binding.generation
        || !fresh(completed, now, .01)) return false;
    value.time = now; value.generation = generation;
    output = value;
    return true;
}
void damage(int cell, double integrity) noexcept {
    if (cell != 0 || !std::isfinite(integrity) || integrity < 0 || integrity > 1) return;
    // F-22A.lua names cell0 NoseCenter. Its mapping to array effectiveness is
    // a declared game damage policy, not an APG-77 damage law.
    const double next = std::min(array_health.load(std::memory_order_acquire), integrity);
    array_health.store(next, std::memory_order_release);
    if (next < .1) epoch.fetch_add(1, std::memory_order_acq_rel);
}
void repair() noexcept {
    array_health.store(1, std::memory_order_release);
    epoch.fetch_add(1, std::memory_order_acq_rel);
    // Spawn/release also call repair: never bind or recreate a native owner here.
}
void attach(void* radar) noexcept { owner.store(radar, std::memory_order_release); }
void reset() noexcept {
    owner.store(nullptr, std::memory_order_release); epoch.fetch_add(1, std::memory_order_acq_rel);
    if (driver_slot && readable(driver_slot, sizeof(void*)) && *driver_slot == driver_table.data() + 1)
        InterlockedCompareExchangePointer(reinterpret_cast<PVOID volatile*>(driver_slot),
            driver_original.load(std::memory_order_acquire), driver_table.data() + 1);
    if (responder_slot && readable(responder_slot, sizeof(void*)) && *responder_slot == &responder)
        InterlockedCompareExchangePointer(reinterpret_cast<PVOID volatile*>(responder_slot), nullptr, &responder);
    driver_slot = nullptr; driver_original = nullptr; responder_slot = nullptr;
    AcquireSRWLockExclusive(&state_lock); request = {}; snapshot.status = {}; snapshot.epoch = 0; snapshot.own_effect = {};
    for (auto& measurement : snapshot.measurements) measurement = {};
    parameters.published_id.fill(0);
    parameters.published_type_valid.fill(false);
    parameters.bound = false;
    ReleaseSRWLockExclusive(&state_lock);
}
bool can_sample(void* radar) noexcept {
    return radar && owner.load(std::memory_order_acquire)==radar && api.ready.load(std::memory_order_acquire);
}
OwnEffect own_effect(Provider& provider,bool pose_valid,double now) noexcept {
    OwnEffect effect{};double strength=0;
    effect.valid=pose_valid && std::isfinite(now) && provider.own_effect(effect.active,strength);
    effect.time=now;
    return effect;
}
void sample(void* radar) noexcept {
    if (!can_sample(radar)) return;
    const auto generation = epoch.load(std::memory_order_acquire);
    if (sampled_epoch != generation) { model.reset(generation); sampled_epoch = generation; }
    AcquireSRWLockShared(&state_lock); Request r = request; ReleaseSRWLockShared(&state_lock);
    const double now = api.clock();
    if (!request_current(r,now,generation)) r.controls.enabled = false;
    Provider provider; Pose pose{};
    const bool pose_valid=provider.pose(pose);
    NativeGroundVideo::set_aircraft(pose_valid?&pose:nullptr,now);
    if (!pose_valid) r.controls.enabled = false;
    if(r.controls.surface)r.controls.surface_request=NativeGroundSensor::pointing(now,pose);
    const bool updated = model.update(now, r.controls, pose, provider);
    // Receiver qualification loss does not stop an otherwise commanded RF dwell.
    api.emitter(model.status().emitting && r.controls.emit);
    auto& next = sensor_scratch;
    next.own_effect=own_effect(provider,pose_valid,now);
    next.status = model.status(); next.measurements = model.measurements();
    next.bindings = model.bindings(); next.epoch = generation;
    if (!updated) next.status.ready = false;
    AcquireSRWLockExclusive(&state_lock);
    if (epoch.load(std::memory_order_acquire) == generation) { snapshot = next; responder.origin = pose.position; }
    ReleaseSRWLockExclusive(&state_lock);
    const NativeGroundSensor::ArrayService service{updated && next.status.surface_service,
        next.status.surface_azimuth, r.controls.resource, updated && r.controls.surface && r.controls.emit,
        next.status.surface_beam};
    NativeGroundSensor::sample(radar, service);
}
void update(EDPARAM& p) noexcept {
    if (!parameters.bind(p)) {
        AcquireSRWLockExclusive(&state_lock);
        request={};snapshot.status.ready=false;
        ReleaseSRWLockExclusive(&state_lock);
        return;
    }
    api.initialize();
    const bool available = api.ready.load(std::memory_order_acquire);
    const bool driver_ready = available && bind_driver();
    const bool support_ready = driver_ready && bind_responder();
    const double now = available ? api.clock() : -100;
    Request next = available ? parameters.controls(p, now) : Request{};
    next.controls.resource = std::min(next.controls.resource, array_health.load(std::memory_order_acquire));
    AcquireSRWLockExclusive(&state_lock); request = next; publication_scratch = snapshot;
    ReleaseSRWLockExclusive(&state_lock);
    parameters.publish(p, publication_scratch, now, available && next.controls.enabled);
    // These are shared compatibility endpoints backed entirely by our provider.
    p.setParamNumber(parameters.outputs[17], driver_ready ? 1 : 0);
    p.setParamNumber(parameters.outputs[18], support_ready ? 1 : 0);
    p.setParamNumber(parameters.outputs[19], support_ready ? selected_track() : 0);
    p.setParamNumber(parameters.outputs[23], available ? 1 : 0);
    p.setParamNumber(parameters.outputs[24], array_health.load(std::memory_order_acquire));
}
}
