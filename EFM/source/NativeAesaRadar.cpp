// GPL-3.0-or-later. Own AESA sensor behind DCS's shared spatial-object interface.
// No avSimpleRadar detection, observation cache, antenna phase or aircraft DLL calls.
#include "NativeAesaRadar.h"
#include "AesaRadar.h"
#include "NativeGroundSensor.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <functional>
#include <limits>

namespace NativeAesaRadar { namespace {
using namespace AesaRadar;
struct FloatVector { float n{}, u{}, e{}; };
struct Box { FloatVector minimum{}, maximum{}; };
struct Scene {};
using Query = std::function<int(Scene&)>;
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
bool profile(HMODULE module, DWORD stamp, DWORD size) noexcept {
    if (!readable(module, sizeof(IMAGE_DOS_HEADER))) return false;
    const auto base = reinterpret_cast<const std::byte*>(module);
    const auto dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(module);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE || dos->e_lfanew < 0 || dos->e_lfanew > 1048576) return false;
    const auto pe = reinterpret_cast<const IMAGE_NT_HEADERS64*>(base + dos->e_lfanew);
    return readable(pe, sizeof(*pe)) && pe->Signature == IMAGE_NT_SIGNATURE
        && pe->FileHeader.Machine == IMAGE_FILE_MACHINE_AMD64
        && pe->FileHeader.TimeDateStamp == stamp && pe->OptionalHeader.SizeOfImage == size;
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
    using Position = const float*(__fastcall*)(void*);
    using Intersection = const char*(__fastcall*)(const Scene&, const Vector&, const Vector&, Vector&, double&, Vector&);
    HMODULE common{}, objects{}, world{}, general{};
    Clock clock{}; Aircraft aircraft{}; Point point{}; Velocity velocity{};
    Context context{}; Device device{}; Emitter emitter{};
    void* lua_vtable{}; void* lua_update{};
    Type type{}; Dead dead{}; Position position{}; Intersection intersect{};
    void** manager{}; void** land{};
    std::atomic<bool> ready{};
    unsigned reason = 1;
    void initialize() noexcept {
        if (ready.load(std::memory_order_acquire) || reason >= 2) return;
        common = GetModuleHandleW(L"CockpitBase.dll"); objects = GetModuleHandleW(L"edObjects.dll");
        world = GetModuleHandleW(L"World.dll"); general = GetModuleHandleW(L"WorldGeneral.dll");
        if (!common || !objects || !world || !general) return;
        if (!profile(common, 0x6ac12468, 0x59a000) || !profile(objects, 0x6aae1e0e, 0x46000)
            || !profile(world, 0x6aae1d9b, 0x14000) || !profile(general, 0x6ac122f4, 0x125b000)) {
            reason = 2; return;
        }
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
        position = reinterpret_cast<Position>(GetProcAddress(general, "?Position@MovingObject@@UEAAAEBV?$wPosition3@M@@XZ"));
        intersect = reinterpret_cast<Intersection>(GetProcAddress(objects,
            "?intersectSegment@@YAPEBDAEBVISceneObject@@AEBVVec3d@osg@@1AEAV23@AEAN2@Z"));
        manager = reinterpret_cast<void**>(GetProcAddress(objects, "?instance@viObjectManager@@2PEAV1@EA"));
        land = reinterpret_cast<void**>(GetProcAddress(general, "?globalLand@@3PEAVwTerrain@@EA"));
        const bool available = clock && aircraft && point && velocity && type && dead && position
            && intersect && manager && land && context && device && emitter && lua_vtable && lua_update;
        reason = available ? 0u : 3u;
        ready.store(available, std::memory_order_release);
    }
} api;
void* moving(Scene& scene) noexcept {
    using Convert = void*(__fastcall*)(void*);
    const auto registered = method<Convert>(&scene, 6);
    void* object = registered ? registered(&scene) : nullptr;
    const auto convert = method<Convert>(object, 7);
    return convert ? convert(object) : nullptr;
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
class Provider final : public Environment {
    void* own_{};
public:
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
        using Search = void(__fastcall*)(void*, const Box&, unsigned, const Query&);
        void* manager = readable(api.manager, sizeof(void*)) ? *api.manager : nullptr;
        const auto search = method<Search>(manager, 20);
        if (!search) return false;
        struct Context { Provider* self; std::span<Truth> out; std::size_t* count; QueryStats* stats; };
        Context context{this, out, &count, &stats};
        // One pointer capture fits the inspected std::function small buffer.
        Query each = [c = &context](Scene& scene) {
            if (++c->stats->visited > maximum_candidates) { c->stats->truncated = true; return 1; }
            void* unit = moving(scene);
            if (!unit || unit == c->self->own_ || api.dead(unit)) return 0;
            const auto type = api.type(unit);
            if (!readable(type, 2) || type[0] != 1 || (type[1] != 1 && type[1] != 2)) return 0;
            const auto velocity = api.velocity(unit);
            if (!readable(velocity, sizeof(*velocity)) || *c->count >= c->out.size()) return 1;
            Truth truth{}; truth.id = identity(scene); api.point(unit, &truth.position);
            truth.velocity = {velocity->n, velocity->u, velocity->e};
            // Shared object kinematics, no coalition/classification truth. RCS=1m2 is a declared game baseline.
            if (truth.id && finite(truth.position) && finite(truth.velocity)) c->out[(*c->count)++] = truth;
            return 0;
        };
        const auto box = bounds(pose, beam);
        search(manager, box, 32, each);
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
        using Segment = void(__fastcall*)(void*, const Vector&, const Vector&, unsigned, const Query&);
        void* manager = readable(api.manager, sizeof(void*)) ? *api.manager : nullptr;
        const auto segment = method<Segment>(manager, 24);
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
        segment(manager, from, target.position, 35, each);
        if (context.blocked) ++stats.object_blocked;
        if (context.visits > 32) stats.truncated = true;
        return !context.blocked;
    }
};
struct Request { Controls controls{}; double stamp = -100; };
struct Snapshot { Status status{}; std::array<Measurement, maximum_tracks> measurements{}; std::uint64_t epoch{}; };
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
        "F22_AESA_CONTROL_TARGET", "F22_AESA_CONTROL_SURFACE_HALF_AZ"};
    static constexpr std::array output_names{
        "F22_AESA_READY", "F22_AESA_REASON", "F22_AESA_TIME", "F22_AESA_SEQUENCE", "F22_AESA_COUNT",
        "F22_AESA_BEAM_AZ", "F22_AESA_BEAM_EL", "F22_AESA_DWELLS", "F22_AESA_SEARCH_DWELLS",
        "F22_AESA_TRACK_DWELLS", "F22_AESA_DETECTIONS", "F22_AESA_MISSES", "F22_AESA_PENDING",
        "F22_AESA_DROPS", "F22_AESA_TERRAIN_BLOCKED", "F22_AESA_OBJECT_BLOCKED", "F22_AESA_TRUNCATED",
        "F22_AESA_DRIVER_READY", "F22_TWS_GUIDANCE_BACKEND_READY", "F22_RADAR_WEAPON_TARGET_ID",
        "F22_AESA_SURFACE_SERVICE", "F22_AESA_SURFACE_AZ", "F22_AESA_SURFACE_SEQUENCE", "F22_AESA_ARRAY_KNOWN", "F22_AESA_ARRAY_HEALTH", "F22_AESA_RESOURCE", "F22_AESA_PROCESSING_S", "F22_AESA_GENERATION"};
    static constexpr std::array fields{"VALID", "ID", "TIME", "N", "U", "E", "VN", "VU", "VE",
        "VELOCITY_VALID", "RANGE_SIGMA_M", "ANGLE_SIGMA_RAD", "HITS",
        "FILTER_VALID", "POSITION_SIGMA_M", "VELOCITY_SIGMA_MPS", "RAW_N", "RAW_U", "RAW_E",
        "MEASURED_RANGE", "MEASURED_AZ", "MEASURED_EL", "RANGE_RATE", "RATE_SIGMA_MPS",
        "ORIGIN_N", "ORIGIN_U", "ORIGIN_E", "OWN_VN", "OWN_VU", "OWN_VE",
        "FORWARD_N", "FORWARD_U", "FORWARD_E", "UP_N", "UP_U", "UP_E", "RIGHT_N", "RIGHT_U", "RIGHT_E",
        "COV_00", "COV_01", "COV_02", "COV_03", "COV_04", "COV_05",
        "COV_11", "COV_12", "COV_13", "COV_14", "COV_15", "COV_22", "COV_23", "COV_24", "COV_25",
        "COV_33", "COV_34", "COV_35", "COV_44", "COV_45", "COV_55"};
    std::array<void*, input_names.size()> inputs{};
    std::array<void*, output_names.size()> outputs{};
    std::array<void*, 10> priorities{};
    std::array<std::array<void*, fields.size()>, maximum_tracks> contacts{};
    std::array<double, maximum_tracks> published_time{};
    std::array<unsigned, maximum_tracks> published_id{};
    std::atomic<bool> bound{};
    bool bind(EDPARAM& p) noexcept {
        if (bound) return true;
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
        bound = true; return true;
    }
    double read(EDPARAM& p, void* handle) noexcept {
        double value = std::numeric_limits<double>::quiet_NaN();
        if (!p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number(handle, value, false))
            return std::numeric_limits<double>::quiet_NaN();
        return value;
    }
    Request controls(EDPARAM& p, double now) noexcept {
        std::array<double, input_names.size()> values{};
        for (std::size_t i = 0; i < values.size(); ++i) values[i] = read(p, inputs[i]);
        const double sequence = values[2];
        Request r{};
        if (!std::isfinite(sequence) || sequence < 2 || std::fmod(sequence, 2) != 0
            || !std::isfinite(values[1]) || now - values[1] < -.01 || now - values[1] > .5) return r;
        r.controls.enabled = values[0] == 1; r.controls.emit = values[3] == 1;
        r.controls.resource = values[4]; r.controls.surface = values[5] == 1;
        r.controls.azimuth = values[6]; r.controls.elevation = values[7];
        r.controls.half_azimuth = values[8]; r.controls.half_elevation = values[9];
        r.controls.range_m = values[10]; r.controls.cue_valid = values[11] == 1;
        r.controls.cue_azimuth = values[12]; r.controls.cue_elevation = values[13];
        r.controls.surface_half_azimuth = values[15];
        if (std::isfinite(values[14]) && values[14] > 0 && values[14] < 4294967295.0 && values[14] == std::floor(values[14]))
            r.controls.selected_id = static_cast<std::uint32_t>(values[14]);
        for (std::size_t i = 0; i < priorities.size(); ++i) {
            const double id = read(p, priorities[i]);
            if (std::isfinite(id) && id > 0 && id < 4294967295.0 && id == std::floor(id))
                r.controls.priority_ids[i] = static_cast<std::uint32_t>(id);
        }
        if (sequence != read(p, inputs[2])) return {};
        r.stamp = now; r.controls.generation = epoch.load(std::memory_order_acquire); return r;
    }
    void publish(EDPARAM& p, const Snapshot& s, double now, bool enabled) noexcept {
        publication = (publication + 2) % 16000000;
        p.setParamNumber(outputs[3], publication + 1);
        const auto& q = s.status;
        const bool fresh = enabled && q.ready && s.epoch == epoch.load(std::memory_order_acquire)
            && now - q.time >= -.01 && now - q.time <= .5;
        unsigned count = 0;
        for (std::size_t i = 0; i < s.measurements.size(); ++i) {
            const auto& m = s.measurements[i];
            const bool valid = fresh && m.valid;
            p.setParamNumber(contacts[i][0], valid ? 1 : 0);
            if (!valid) { published_id[i] = 0; continue; }
            ++count;
            // State and covariance change only on a completed measurement.
            // Producer heartbeat/VALID still update when physics runs faster.
            if (published_id[i] == m.id && published_time[i] == m.time) continue;
            published_id[i] = m.id; published_time[i] = m.time;
            const std::array values{valid ? 1.0 : 0.0, static_cast<double>(m.id), m.time,
                m.position.n, m.position.u, m.position.e, m.velocity.n, m.velocity.u, m.velocity.e,
                m.velocity_valid ? 1.0 : 0.0, m.range_sigma_m, m.angle_sigma_rad, static_cast<double>(m.hits),
                m.filter_valid ? 1.0 : 0.0, m.position_sigma_m, m.velocity_sigma_mps,
                m.raw_position.n, m.raw_position.u, m.raw_position.e, m.measured_range,
                m.measured_azimuth, m.measured_elevation, m.measured_range_rate, m.rate_sigma_mps,
                m.sensor_origin.n,m.sensor_origin.u,m.sensor_origin.e,m.sensor_velocity.n,m.sensor_velocity.u,m.sensor_velocity.e,
                m.sensor_forward.n,m.sensor_forward.u,m.sensor_forward.e,m.sensor_up.n,m.sensor_up.u,m.sensor_up.e,
                m.sensor_right.n,m.sensor_right.u,m.sensor_right.e};
            for (std::size_t j = 0; j < values.size(); ++j) p.setParamNumber(contacts[i][j], values[j]);
            for (std::size_t j = 0; j < m.covariance.size(); ++j)
                p.setParamNumber(contacts[i][values.size()+j], m.covariance[j]);
        }
        const std::array values{fresh ? 1.0 : 0.0, fresh ? 0.0 : static_cast<double>(api.reason ? api.reason : 4),
            q.time, static_cast<double>(publication + 2), static_cast<double>(count), q.beam.azimuth, q.beam.elevation,
            static_cast<double>(q.dwells), static_cast<double>(q.search_dwells), static_cast<double>(q.track_dwells),
            static_cast<double>(q.detections), static_cast<double>(q.misses), static_cast<double>(q.pending),
            static_cast<double>(q.queue_drops), static_cast<double>(q.terrain_blocked),
            static_cast<double>(q.object_blocked), q.truncated ? 1.0 : 0.0};
        for (std::size_t i = 0; i < values.size(); ++i) if (i != 3) p.setParamNumber(outputs[i], values[i]);
        p.setParamNumber(outputs[20], fresh && q.surface_service ? 1 : 0);
        p.setParamNumber(outputs[21], q.surface_azimuth);
        p.setParamNumber(outputs[22], q.surface_sequence);
        p.setParamNumber(outputs[25], fresh ? q.resource : 0);
        p.setParamNumber(outputs[26], fresh ? q.processing_s : 0);
        p.setParamNumber(outputs[27], static_cast<double>(s.epoch));
        p.setParamNumber(outputs[3], publication + 2);
    }
} parameters;
bool fresh(double now, double stamp, double age) noexcept {
    return std::isfinite(now) && std::isfinite(stamp) && now >= stamp && now - stamp <= age;
}
bool eligible(const Measurement& t, unsigned id, double now) noexcept {
    return t.valid && t.velocity_valid && t.id == id && t.hits >= 2 && fresh(now, t.time, 6);
}
// The host borrows this interface through ccCockpitContext+256. It owns no
// storage here. Its four virtual methods match the inspected shared responder ABI.
class Responder {
public:
    virtual ~Responder() = default;
    virtual bool tracking(unsigned id, unsigned /*weapon*/) const noexcept {
        const double now = api.clock ? api.clock() : -100;
        AcquireSRWLockShared(&state_lock);
        const bool enabled = request.controls.enabled && request.controls.emit && snapshot.status.ready
            && snapshot.epoch == epoch.load(std::memory_order_acquire)
            && fresh(now, request.stamp, .5) && fresh(now, snapshot.status.time, .5);
        bool found = false;
        if (enabled) for (const auto& t : snapshot.measurements)
            if (eligible(t, id, now)) { found = true; break; }
        ReleaseSRWLockShared(&state_lock); return found;
    }
    virtual unsigned target() const noexcept {
        AcquireSRWLockShared(&state_lock); const auto selected = request.controls.selected_id;
        ReleaseSRWLockShared(&state_lock);
        return selected && tracking(selected, 0) ? selected : 0;
    }
    virtual double range() const noexcept {
        const auto selected = target();
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
}
void* __fastcall driver_destroy(void* self, unsigned flags) noexcept {
    using Destroy = void*(__fastcall*)(void*, unsigned);
    const auto original = driver_original.load(std::memory_order_acquire);
    const auto destroy = original ? reinterpret_cast<Destroy>(original[0]) : nullptr;
    reset();
    return destroy ? destroy(self, flags) : nullptr;
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
    driver_table[1] = reinterpret_cast<void*>(&driver_destroy);
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
    AcquireSRWLockExclusive(&state_lock); request = {}; snapshot.status = {}; snapshot.epoch = 0;
    for (auto& measurement : snapshot.measurements) measurement = {};
    parameters.published_id.fill(0);
    parameters.bound = false;
    ReleaseSRWLockExclusive(&state_lock);
}
void sample(void* radar) noexcept {
    if (!radar || owner.load(std::memory_order_acquire) != radar || !api.ready.load(std::memory_order_acquire)) return;
    const auto generation = epoch.load(std::memory_order_acquire);
    if (sampled_epoch != generation) { model.reset(generation); sampled_epoch = generation; }
    AcquireSRWLockShared(&state_lock); Request r = request; ReleaseSRWLockShared(&state_lock);
    const double now = api.clock();
    if (!std::isfinite(now) || now - r.stamp < -.01 || now - r.stamp > .5) r.controls.enabled = false;
    Provider provider; Pose pose{};
    if (!provider.pose(pose)) r.controls.enabled = false;
    const bool updated = model.update(now, r.controls, pose, provider);
    api.emitter(updated && r.controls.emit);
    auto& next = sensor_scratch;
    next.status = model.status(); next.measurements = model.measurements(); next.epoch = generation;
    if (!updated) next.status.ready = false;
    AcquireSRWLockExclusive(&state_lock);
    if (epoch.load(std::memory_order_acquire) == generation) { snapshot = next; responder.origin = pose.position; }
    ReleaseSRWLockExclusive(&state_lock);
    const NativeGroundSensor::ArrayService service{updated && next.status.surface_service,
        next.status.surface_azimuth, r.controls.resource, updated && r.controls.surface && r.controls.emit};
    NativeGroundSensor::sample(radar, &service);
}
void update(EDPARAM& p) noexcept {
    if (!parameters.bind(p)) return;
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
    p.setParamNumber(parameters.outputs[19], support_ready ? responder.target() : 0);
    p.setParamNumber(parameters.outputs[23], available ? 1 : 0);
    p.setParamNumber(parameters.outputs[24], array_health.load(std::memory_order_acquire));
}
}
