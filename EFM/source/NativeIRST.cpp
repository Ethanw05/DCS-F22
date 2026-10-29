// GPL-3.0-or-later. Owned avIRSensor, not an aircraft-module service.
#include "NativeIRST.h"
#include "IRSTCore.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <array>
#include <cstdio>
#include <cstring>
#include <limits>

namespace NativeIRST {
namespace {
using namespace IRSTCore;
struct Pose {
    double m[16]{};
};
bool readable(const void *pointer, std::size_t bytes) noexcept {
    MEMORY_BASIC_INFORMATION info{};
    if (!pointer || !VirtualQuery(pointer, &info, sizeof(info)))
        return false;
    const auto offset =
        reinterpret_cast<std::uintptr_t>(pointer) - reinterpret_cast<std::uintptr_t>(info.BaseAddress);
    return info.State == MEM_COMMIT && !(info.Protect & (PAGE_NOACCESS | PAGE_GUARD)) &&
           bytes <= info.RegionSize && offset <= info.RegionSize - bytes;
}
template <class T> bool read(const void *source, T &out) noexcept {
    if (!readable(source, sizeof(T)))
        return false;
    std::memcpy(&out, source, sizeof(T));
    return true;
}
template <class T> T method(void *object, std::size_t slot) noexcept {
    void **table{};
    if (!read(object, table) || !readable(table, (slot + 1) * sizeof(void *)))
        return nullptr;
    return reinterpret_cast<T>(table[slot]);
}
struct Api {
    using Method = void(__fastcall *)(void *);
    using Power = void(__fastcall *)(void *, bool);
    using Carrier = void(__fastcall *)(void *, void *);
    using Mount = void(__fastcall *)(void *, const Pose &);
    using Aperture = void(__fastcall *)(void *, float);
    using Target = void(__fastcall *)(void *, void *);
    using Position = const Pose &(__fastcall *)(void *);
    using Aircraft = void *(__cdecl *)();
    using Clock = double(__cdecl *)();
    Method construct{}, destroy{}, initialize{}, update{}, search{};
    Power power{};
    Carrier carrier{};
    Mount mount{};
    Aperture aperture{};
    Target target{};
    Position position{};
    Aircraft aircraft{};
    Clock clock{};
    bool ready{};
    template <class T> void bind(HMODULE module, T &out, const char *name) noexcept {
        out = reinterpret_cast<T>(GetProcAddress(module, name));
        ready = out != nullptr && ready;
    }
    bool image_profile(HMODULE module, unsigned stamp, unsigned size) noexcept {
        const auto base = reinterpret_cast<const std::byte *>(module);
        IMAGE_DOS_HEADER dos{};
        IMAGE_NT_HEADERS64 pe{};
        if (!read(base, dos) || dos.e_magic != IMAGE_DOS_SIGNATURE || dos.e_lfanew < 0)
            return false;
        if (!read(base + dos.e_lfanew, pe) || pe.Signature != IMAGE_NT_SIGNATURE)
            return false;
        return pe.FileHeader.TimeDateStamp == stamp && pe.OptionalHeader.SizeOfImage == size;
    }
    bool profile(HMODULE module) noexcept {
        const auto base = reinterpret_cast<const std::byte *>(module);
        IMAGE_DOS_HEADER dos{};
        IMAGE_NT_HEADERS64 pe{};
        if (!read(base, dos) || dos.e_magic != IMAGE_DOS_SIGNATURE || dos.e_lfanew < 0 ||
            !read(base + dos.e_lfanew, pe) || pe.Signature != IMAGE_NT_SIGNATURE)
            return false;
        if (pe.FileHeader.TimeDateStamp != 0x6adbad09 || pe.OptionalHeader.SizeOfImage != 0x68e000)
            return false;
        // MCP/IDA: current constructor, first64 bytes, position-independent code.
        std::array<unsigned char, 64> code{};
        if (!read(base + 0x41e8f0, code))
            return false;
        std::uint64_t hash = 14695981039346656037ULL;
        for (const auto byte : code)
            hash = (hash ^ byte) * 1099511628211ULL;
        return hash == 0xe2450e42520e7477ULL;
    }
    bool resolve() noexcept {
        ready = false;
        auto module = GetModuleHandleW(L"CockpitBase.dll");
        auto world = GetModuleHandleW(L"World.dll");
        auto general = GetModuleHandleW(L"WorldGeneral.dll");
        if (!module || !world || !general || !profile(module))
            return false;
        if (!image_profile(general, 0x6adbace0, 0x127b000) || !image_profile(world, 0x6acb804e, 0x14000))
            return false;
        ready = true;
        bind(module, construct, "??0avIRSensor@cockpit@@QEAA@XZ");
        bind(module, destroy, "??1avIRSensor@cockpit@@UEAA@XZ");
        bind(module, initialize, "?initialize@avIRSensor@cockpit@@UEAAXXZ");
        bind(module, update, "?update_platform_position@avPlatform@cockpit@@QEAAXXZ");
        bind(module, search, "?search@avIRSensor@cockpit@@MEAAXXZ");
        bind(module, power, "?setElecPower@avIRSensor@cockpit@@UEAAX_N@Z");
        bind(module, carrier, "?set_carrier@avPlatform@cockpit@@UEAAXPEAVMovingObject@@@Z");
        bind(module, mount,
             "?setPlatformInitialLocalPosition@avPlatform@cockpit@@UEAAXAEBV?$wPosition3@N@@@Z");
        bind(module, aperture, "?setHalfApertureSize@avIRSensor@cockpit@@QEAAXM@Z");
        bind(module, target, "?setTarget@avIRSensor@cockpit@@MEAAXPEAVMovingObject@@@Z");
        bind(module, position, "?getPlatformInitialPosition@avPlatform@cockpit@@QEBAAEBV?$wPosition3@N@@XZ");
        bind(module, aircraft, "?c_LA@cockpit@@YAPEAVIwoLA@@XZ");
        bind(world, clock, "?GetModelTime@wTime@@SANXZ");
        return ready;
    }
} api;
constexpr std::array<const char *, 11> input_names{"SEQ",           "TIME", "GENERATION", "POWER", "PRESENT",
                                                   "STATION",       "AZ",   "EL",         "WIDTH", "SELECTED",
                                                   "PHYSICAL_VALID"};
constexpr std::array<const char *, 9> header_names{"SEQ",     "TIME",    "EPOCH",    "READY",    "REASON",
                                                   "SCAN_AZ", "SCAN_EL", "OVERFLOW", "AVAILABLE"};
constexpr std::array<const char *, 5> row_names{"VALID", "ID", "TIME", "AZ", "EL"};
struct Ports {
    std::array<void *, input_names.size()> inputs{};
    std::array<void *, header_names.size()> headers{};
    std::array<std::array<void *, row_names.size()>, capacity> rows{};
    std::uint64_t epoch{};
    bool bound{};
    bool bind(EDPARAM &p) noexcept {
        char name[80]{};
        bool ok = true;
        for (std::size_t i = 0; i < inputs.size(); ++i) {
            std::snprintf(name, sizeof(name), "F22_IRST_CONTROL_%s", input_names[i]);
            inputs[i] = p.getParamHandle(name);
            ok = inputs[i] && ok;
        }
        for (std::size_t i = 0; i < headers.size(); ++i) {
            std::snprintf(name, sizeof(name), "F22_IRST_NATIVE_%s", header_names[i]);
            headers[i] = p.getParamHandle(name);
            ok = headers[i] && ok;
        }
        for (std::size_t i = 0; i < capacity; ++i)
            for (std::size_t j = 0; j < row_names.size(); ++j) {
                std::snprintf(name, sizeof(name), "F22_IRST_NATIVE_%02u_%s", static_cast<unsigned>(i + 1),
                              row_names[j]);
                rows[i][j] = p.getParamHandle(name);
                ok = rows[i][j] && ok;
            }
        epoch = p.epoch();
        bound = ok;
        return ok;
    }
} ports;
struct Request {
    double time{}, generation{}, az{}, el{}, width{};
    unsigned station{}, selected{};
    bool valid{}, power{}, present{};
};
struct Snapshot {
    Memory memory{};
    double time{-100}, az{}, el{};
    unsigned epoch{1}, reason{4};
    bool ready{};
};
SRWLOCK state_lock = SRWLOCK_INIT;
alignas(16) std::array<std::byte, 1008> sensor{};
std::array<void *, 32> sensor_table{}; // RTTI prefix + verified31 avIRSensor slots.
float __fastcall sensitivity(void *self, void *target) noexcept {
    // Estimated 50km threshold for this optional mod pod. Native search still
    // applies angular, terrain, own-airframe and sun admission. This is not a
    // calibrated radiometric/atmospheric or real IRST21 performance model.
    return self == sensor.data() && target ? 50000.f : 0.f;
}
bool install_sensitivity() noexcept {
    void **original{};
    if (!read(sensor.data(), original) || !readable(original - 1, sensor_table.size() * sizeof(void *)))
        return false;
    for (std::size_t i = 0; i < sensor_table.size(); ++i)
        sensor_table[i] = original[static_cast<std::ptrdiff_t>(i) - 1];
    // IDA verifies slot19 is the abstract getLockonDistance(MovingObject*).
    sensor_table[20] = reinterpret_cast<void *>(&sensitivity);
    auto table = sensor_table.data() + 1;
    std::memcpy(sensor.data(), &table, sizeof(table));
    return true;
}
bool constructed{}, accepting{};
Request request{};
Snapshot snapshot{};
double last_sample{-100}, previous_generation{-1};
unsigned dwell{}, sequence{};
void dispose() noexcept {
    if (constructed) {
        api.power(sensor.data() + 560, false); // Export expects the electric base.
        api.destroy(sensor.data());
    }
    constructed = false;
}
void invalidate(unsigned reason) noexcept {
    snapshot.ready = false;
    snapshot.reason = reason;
    snapshot.memory.clear();
}
bool fresh(double now, double time, double maximum) noexcept {
    return std::isfinite(now) && std::isfinite(time) && now >= 0 && time >= 0 && now - time >= -.01 &&
           now - time <= maximum;
}
double number(EDPARAM &p, void *handle) noexcept {
    double value = std::numeric_limits<double>::quiet_NaN();
    return p.getParamNumber(handle, value) ? value : std::numeric_limits<double>::quiet_NaN();
}
bool identifier(double value, double low, double high) noexcept {
    return std::isfinite(value) && value >= low && value <= high && std::floor(value) == value;
}
bool even_sequence(double value) noexcept {
    return identifier(value, 2, 16000000) && std::fmod(value, 2) == 0;
}
using InputValues = std::array<double, input_names.size()>;
bool control_identifiers(const InputValues &v) noexcept {
    return identifier(v[2], 1, 4294967295.) && identifier(v[5], 0, 10) && identifier(v[9], 0, 4294967295.);
}
bool control_geometry(const InputValues &v) noexcept {
    if (std::abs(v[6]) > 75 * rad || v[7] < 0 || v[7] > 45 * rad)
        return false;
    for (const auto width : {30, 60, 90})
        if (std::abs(v[8] - width * rad) < 1e-12)
            return true;
    return false;
}
bool control_flags(const InputValues &v) noexcept {
    for (const auto i : {3, 4, 10})
        if (v[i] != 0 && v[i] != 1)
            return false;
    return v[10] == 1;
}
Request controls(EDPARAM &p, double now) noexcept {
    InputValues v{};
    v[0] = number(p, ports.inputs[0]);
    if (!even_sequence(v[0]))
        return {};
    for (std::size_t i = 1; i < v.size(); ++i) {
        v[i] = number(p, ports.inputs[i]);
        if (!std::isfinite(v[i]))
            return {};
    }
    if (v[0] != number(p, ports.inputs[0]) || !fresh(now, v[1], .35))
        return {};
    if (!control_flags(v) || !control_identifiers(v) || !control_geometry(v))
        return {};
    return {v[1], v[2],      v[6],     v[7], v[8], static_cast<unsigned>(v[5]), static_cast<unsigned>(v[9]),
            true, v[3] == 1, v[4] == 1};
}
bool frame_valid(const Frame &f) noexcept {
    return std::isfinite(dot(f.forward, f.forward)) && std::abs(dot(f.forward, f.forward) - 1) < .05 &&
           std::abs(dot(f.up, f.up) - 1) < .05 && std::abs(dot(f.right, f.right) - 1) < .05 &&
           std::abs(dot(f.forward, f.up)) < .05 && std::abs(dot(f.up, f.right)) < .05;
}
Frame frame(const Pose &p) noexcept {
    return {{p.m[0], p.m[1], p.m[2]}, {p.m[4], p.m[5], p.m[6]}, {p.m[8], p.m[9], p.m[10]}};
}
Pose mount_pose(void *aircraft, unsigned station, const Frame &basis, bool &valid) noexcept {
    using Launcher = void(__fastcall *)(void *, float *, unsigned char, unsigned char);
    Pose result{};
    float native[16]{};
    const auto launcher = method<Launcher>(aircraft, 64);
    valid = launcher != nullptr;
    if (!valid)
        return result;
    launcher(aircraft, native, static_cast<unsigned char>(station), 0);
    for (std::size_t i = 0; i < 16; ++i)
        result.m[i] = native[i];
    valid = frame_valid(frame(result));
    for (const auto i : {12, 13, 14})
        valid = valid && std::isfinite(result.m[i]) && std::abs(result.m[i]) < 50;
    // Estimated pod aperture relative to its mounting pivot, metres in body
    // axes. Place the observation point forward/below the wing attachment.
    result.m[12] += 1.5;
    result.m[13] -= .5;
    const std::array<Vector, 3> axes{basis.forward, basis.up, basis.right};
    for (std::size_t i = 0; i < 3; ++i) {
        result.m[i * 4] = axes[i].x;
        result.m[i * 4 + 1] = axes[i].y;
        result.m[i * 4 + 2] = axes[i].z;
        result.m[i * 4 + 3] = 0;
    }
    result.m[15] = 1;
    return result;
}
bool observe(void *object, double now, const Frame &beam, const Frame &body) noexcept {
    unsigned key{};
    if (!object || !read(static_cast<std::byte *>(object) + 28, key) || !key)
        return false;
    api.target(sensor.data(), object); // Object was admitted by THIS native IR query.
    double az{}, el{}, stamp{};
    if (!read(sensor.data() + 720, az) || !read(sensor.data() + 728, el) ||
        !read(sensor.data() + 920, stamp) || !fresh(now, stamp, .01) || !std::isfinite(az) ||
        !std::isfinite(el) || std::abs(az) > pi || std::abs(el) > pi / 2)
        return false;
    snapshot.memory.observe(key, stamp, world(beam, ray(az, el)), body);
    return true;
}
bool collect(double now, const Frame &beam, const Frame &body) noexcept {
    std::uintptr_t begin{}, end{};
    if (!read(sensor.data() + 984, begin) || !read(sensor.data() + 992, end) || end < begin ||
        (end - begin) % 24 != 0 || end - begin > 4096 * 24)
        return false;
    const auto count = (end - begin) / 24;
    if (count && !readable(reinterpret_cast<void *>(begin), static_cast<std::size_t>(end - begin)))
        return false;
    if (count > capacity)
        snapshot.memory.overflow = true;
    for (std::size_t i = 0; i < std::min<std::size_t>(count, capacity); ++i) {
        std::uintptr_t link{};
        if (read(reinterpret_cast<void *>(begin + i * 24 + 16), link) && link >= 256)
            observe(reinterpret_cast<void *>(link - 256), now, beam, body);
    }
    return true;
}
void measure(const Request &r, double now) noexcept {
    using Own = void *(__fastcall *)(void *);
    void *aircraft = api.aircraft();
    const auto own = method<Own>(aircraft, 40);
    void *moving = own ? own(aircraft) : nullptr;
    if (!moving) {
        invalidate(6);
        return;
    }
    Vector direction = scan(dwell++, r.az, r.el, r.width);
    const auto selected = snapshot.memory.find(r.selected);
    const bool tracking = selected && fresh(now, selected->time, 1.);
    if (tracking)
        direction = {selected->az, selected->el, 0};
    snapshot.az = direction.x;
    snapshot.el = direction.y;
    const auto local_basis = pointing(direction.x, direction.y);
    bool valid{};
    const auto mount = mount_pose(aircraft, r.station, local_basis, valid);
    if (!valid) {
        invalidate(6);
        return;
    }
    api.carrier(sensor.data(), moving);
    api.mount(sensor.data(), mount);
    api.power(sensor.data() + 560, true);
    api.aperture(sensor.data(), static_cast<float>(tracking ? 5 * rad : 16 * rad));
    api.update(sensor.data());
    Pose position{};
    if (!read(&api.position(sensor.data()), position)) {
        invalidate(6);
        return;
    }
    const auto beam = frame(position);
    const Frame body{world(beam, local(local_basis, {1, 0, 0})), world(beam, local(local_basis, {0, 1, 0})),
                     world(beam, local(local_basis, {0, 0, 1}))};
    if (!frame_valid(beam) || !frame_valid(body)) {
        invalidate(6);
        return;
    }
    snapshot.memory.project(now, body);
    api.search(sensor.data());
    if (!collect(now, beam, body)) {
        invalidate(6);
        return;
    }
    snapshot.time = now;
    snapshot.ready = true;
    snapshot.reason = 0;
}
void publish(EDPARAM &p, const Snapshot &s, double now) noexcept {
    sequence = (sequence % 15999998) + 2;
    bool ok = p.setParamNumber(ports.headers[0], sequence - 1);
    const bool ready = s.ready && fresh(now, s.time, .35);
    const std::array<double, 8> values{
        s.time, static_cast<double>(s.epoch), ready ? 1. : 0.,    static_cast<double>(s.reason), s.az,
        s.el,   s.memory.overflow ? 1. : 0.,  api.ready ? 1. : 0.};
    for (std::size_t i = 0; i < values.size(); ++i)
        ok = p.setParamNumber(ports.headers[i + 1], values[i]) && ok;
    for (std::size_t i = 0; i < capacity; ++i) {
        const auto &t = s.memory.tracks[i];
        const bool valid = ready && t.id && fresh(now, t.time, 2.5);
        const std::array<double, 5> row{valid ? 1. : 0., static_cast<double>(t.id), t.time, t.az, t.el};
        for (std::size_t j = 0; j < row.size(); ++j)
            ok = p.setParamNumber(ports.rows[i][j], row[j]) && ok;
    }
    if (ok && p.epoch() == ports.epoch)
        p.setParamNumber(ports.headers[0], sequence);
}
} // namespace
void initialize(EDPARAM &p) noexcept {
    retire();
    AcquireSRWLockExclusive(&state_lock);
    ports.bind(p);
    api = {};
    api.resolve();
    if (api.ready) {
        // Constructor extent1008 includes its embedded TrackData and LinkBase vector.
        // Native ctor/dtor own native vector allocation; no cross-CRT free.
        try {
            sensor.fill(std::byte{});
            api.construct(sensor.data());
            constructed = true;
            if (!install_sensitivity()) {
                dispose();
                api.ready = false;
            }
            if (!constructed) {
                accepting = false;
                ReleaseSRWLockExclusive(&state_lock);
                return;
            }
            api.initialize(sensor.data());
        } catch (...) {
            dispose();
            api.ready = false;
        }
    }
    request = {};
    snapshot = {};
    last_sample = -100;
    previous_generation = -1;
    dwell = 0;
    accepting = true;
    ReleaseSRWLockExclusive(&state_lock);
}
void update(EDPARAM &p) noexcept {
    AcquireSRWLockExclusive(&state_lock);
    if (!ports.bound || ports.epoch != p.epoch()) {
        ReleaseSRWLockExclusive(&state_lock);
        return;
    }
    const double now = api.clock ? api.clock() : -100;
    const auto next = controls(p, now);
    request = next;
    const auto copied = snapshot;
    publish(p, copied, now);
    ReleaseSRWLockExclusive(&state_lock);
}
void sample() noexcept {
    AcquireSRWLockExclusive(&state_lock);
    if (!accepting || !constructed || !api.ready) {
        ReleaseSRWLockExclusive(&state_lock);
        return;
    }
    const auto r = request;
    const double now = api.clock();
    if (now < last_sample || r.generation != previous_generation) {
        invalidate(5);
        ++snapshot.epoch;
        dwell = 0;
        last_sample = -100;
        previous_generation = r.generation;
    }
    unsigned reason = 0;
    if (!r.valid || !fresh(now, r.time, .35))
        reason = 5;
    else if (!r.present)
        reason = 2;
    else if (!r.power)
        reason = 1;
    if (reason) {
        api.power(sensor.data() + 560, false);
        invalidate(reason);
        snapshot.time = now;
        ReleaseSRWLockExclusive(&state_lock);
        return;
    }
    if (now - last_sample >= .099) {
        last_sample = now;
        try {
            measure(r, now);
        } catch (...) {
            invalidate(6);
        } // Native C++ exceptions cannot leave our callback.
    }
    ReleaseSRWLockExclusive(&state_lock);
}
void retire() noexcept {
    AcquireSRWLockExclusive(&state_lock);
    accepting = false;
    request = {};
    invalidate(5);
    ++snapshot.epoch;
    dispose();
    ports.bound = false;
    ReleaseSRWLockExclusive(&state_lock);
}
} // namespace NativeIRST
