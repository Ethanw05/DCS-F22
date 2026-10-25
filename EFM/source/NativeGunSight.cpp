// GPL-3.0-or-later. Original director using installed DCS shell integration.
// ABI evidence: GUN_TARGET_MOTION.md. Reject builds outside the audited profile.
#include "NativeGunSight.h"
#include "GunIntercept.h"
#include "GunTargetMotion.h"
#include "GunManeuver.h"
#include <chrono>
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <array>
#include <map>
#include <string>
#include <limits>
#include <cstdio>
namespace NativeGunSight {
namespace {
using GunIntercept::V;
std::map<std::string, void *> handles;
void *handle(EDPARAM &p, const char *n) {
    auto &h = handles[n];
    if (!h)
        h = p.getParamHandle(n);
    return h;
}
double get(EDPARAM &p, const char *n) {
    return p.getParamNumber(handle(p, n));
}
void put(EDPARAM &p, const char *n, double v) {
    p.setParamNumber(handle(p, n), v);
}
bool readable(const void *p, std::size_t n) {
    MEMORY_BASIC_INFORMATION m{};
    if (!p || !VirtualQuery(p, &m, sizeof(m)))
        return false;
    return m.State == MEM_COMMIT && !(m.Protect & (PAGE_GUARD | PAGE_NOACCESS)) &&
           reinterpret_cast<std::uintptr_t>(p) + n <=
               reinterpret_cast<std::uintptr_t>(m.BaseAddress) + m.RegionSize;
}
bool profile(HMODULE m, unsigned stamp, unsigned size) {
    if (!m)
        return false;
    auto base = reinterpret_cast<const std::byte *>(m);
    auto dos = reinterpret_cast<const IMAGE_DOS_HEADER *>(base);
    if (!readable(base, sizeof(*dos)) || dos->e_magic != IMAGE_DOS_SIGNATURE)
        return false;
    auto pe = reinterpret_cast<const IMAGE_NT_HEADERS64 *>(base + dos->e_lfanew);
    return readable(pe, sizeof(*pe)) && pe->Signature == IMAGE_NT_SIGNATURE &&
           pe->FileHeader.TimeDateStamp == stamp && pe->OptionalHeader.SizeOfImage == size;
}
struct WindVector {
    float x, y, z;
};
struct Wind {
    void **table;
    WindVector value;
};
void wind_destroy(void *) {
}
WindVector *wind_value(Wind *self, WindVector *out, const float *) {
    *out = self->value;
    return out;
}
void *wind_table[] = {reinterpret_cast<void *>(&wind_destroy),
                      reinterpret_cast<void *>(&wind_value)};
struct Api {
    using Context = void *(__cdecl *)();
    using Clock = double(__cdecl *)();
    using Device = void *(__fastcall *)(void *, unsigned);
    using Shell = const void *(__fastcall *)(void *);
    using Ctor = void *(__fastcall *)(void *, const void *);
    using Dtor = void(__fastcall *)(void *);
    using Time = int(__fastcall *)(void *, double, double, const V *, Wind *, V *, double);
    Context context{};
    Clock clock{};
    Device device{};
    Shell shell{};
    Ctor ctor{};
    Dtor dtor{};
    Time time{};
    const void *vtable{};
    bool ready{};
    bool resolve() {
        if (ready)
            return true;
        auto c = GetModuleHandleW(L"CockpitBase.dll"), w = GetModuleHandleW(L"Weapons.dll");
        if (!profile(c, 0x6ac12468, 0x59a000) || !profile(w, 0x6ac12438, 0x21f000))
            return false;
        context = reinterpret_cast<Context>(
            GetProcAddress(c, "?binding_context@cockpit@@YAPEAVccCockpitContext@1@XZ"));
        device = reinterpret_cast<Device>(
            GetProcAddress(c, "?get_wide_device@ccCockpitContext@cockpit@@QEAAPEAVavDevice@2@I@Z"));
        shell = reinterpret_cast<Shell>(GetProcAddress(
            c, "?get_cannon_shell@avSimpleWeaponSystem@cockpit@@AEAAPEBVwShellDescriptor@@XZ"));
        vtable =
            GetProcAddress(c, "??_7avSimpleWeaponSystem@cockpit@@6BccContextRelatedObject@1@@");
        ctor = reinterpret_cast<Ctor>(
            GetProcAddress(w, "??0CannonSight@@QEAA@AEBVwShellDescriptor@@@Z"));
        dtor = reinterpret_cast<Dtor>(GetProcAddress(w, "??1CannonSight@@QEAA@XZ"));
        time = reinterpret_cast<Time>(GetProcAddress(
            w,
            "?sightTime@CannonSight@@QEAAHNNAEBVVec3d@osg@@QEAV?$IWindTable@MV?$Vector@$02M@Math@@@weapon_base@@AEAV23@N@Z"));
        auto world = GetModuleHandleW(L"World.dll");
        clock = world ? reinterpret_cast<Clock>(GetProcAddress(world, "?GetModelTime@wTime@@SANXZ"))
                      : nullptr;
        return ready = context && device && shell && vtable && ctor && dtor && time && clock;
    }
} api;
// Same world gun pose request as avSimpleWeaponSystem::update_sight.
bool gun_pose(void *weapon, V &position, V &forward) {
    auto b = static_cast<const std::byte *>(weapon);
    if (!readable(b, 32))
        return false;
    auto context = *reinterpret_cast<void *const *>(b + 24);
    if (!readable(context, 24))
        return false;
    auto human = *reinterpret_cast<void *const *>(static_cast<const std::byte *>(context) + 16);
    if (!readable(human, 8))
        return false;
    auto vt = *reinterpret_cast<void ***>(human);
    if (!readable(vt, 328))
        return false;
    using LA = void *(__fastcall *)(void *);
    auto aircraft = reinterpret_cast<LA>(vt[40])(human);
    if (!readable(aircraft, 8))
        return false;
    vt = *reinterpret_cast<void ***>(aircraft);
    if (!readable(vt, 416))
        return false;
    using Pose = void(__fastcall *)(void *, float *, unsigned char, unsigned, unsigned);
    float m[16];
    for (auto &v : m)
        v = std::numeric_limits<float>::quiet_NaN();
    reinterpret_cast<Pose>(vt[51])(aircraft, m, 255, 0, 0);
    forward = {m[0], m[1], m[2]};
    position = {m[12], m[13], m[14]};
    double n = forward.norm();
    if (!std::isfinite(n) || n < .9 || n > 1.1 || !std::isfinite(position.norm()))
        return false;
    forward = forward * (1 / n);
    return true;
}
bool failed = false;
GunManeuver::CueSet maneuver_cues;
GunIntercept::Result previous;
double previous_time = -1, previous_id = -1;
void calculate(EDPARAM &p) {
    put(p, "F22_GUN_SOLUTION_VALID", 0);
    put(p, "F22_GUN_MNV_VALID", 0);
    put(p, "F22_GUN_SOLVER_REASON", 1);
    if (failed || get(p, "F22_GUN_REQUEST_VALID") < .5)
        return;
    if (!api.resolve()) {
        put(p, "F22_GUN_SOLVER_REASON", 2);
        return;
    }
    auto context = api.context();
    auto id = get(p, "F22_GUN_DEVICE_ID");
    if (!context || !std::isfinite(id) || id < 1 || id > 255)
        return;
    auto device = api.device(context, static_cast<unsigned>(id));
    put(p, "F22_GUN_SOLVER_REASON", 3);
    if (!readable(device, 32) || *reinterpret_cast<const void **>(device) != api.vtable)
        return;
    auto shell = api.shell(device);
    put(p, "F22_GUN_SOLVER_REASON", 4);
    if (!readable(shell, 184))
        return;
    double speed = *reinterpret_cast<const double *>(static_cast<const std::byte *>(shell) + 176);
    if (!std::isfinite(speed) || speed < 100 || speed > 2000)
        return;
    V muzzle, bore;
    put(p, "F22_GUN_SOLVER_REASON", 5);
    if (!gun_pose(device, muzzle, bore))
        return;
    V own_position{get(p, "F22_GUN_OWN_N"), get(p, "F22_GUN_OWN_U"), get(p, "F22_GUN_OWN_E")};
    if ((muzzle - own_position).norm() > 30)
        return;
    V target{get(p, "F22_GUN_TARGET_N"), get(p, "F22_GUN_TARGET_U"), get(p, "F22_GUN_TARGET_E")};
    V velocity{get(p, "F22_GUN_VN"), get(p, "F22_GUN_VU"), get(p, "F22_GUN_VE")};
    V acceleration{get(p, "F22_GUN_AN"), get(p, "F22_GUN_AU"), get(p, "F22_GUN_AE")};
    V own{get(p, "EFM_HUD_VN"), get(p, "EFM_HUD_VU"), get(p, "EFM_HUD_VE")};
    V air{get(p, "EFM_HUD_WN"), get(p, "EFM_HUD_WU"), get(p, "EFM_HUD_WE")};
    if (!std::isfinite(own.norm()) || own.norm() > 1500 || !std::isfinite(air.norm()) ||
        air.norm() > 300)
        return;
    Wind wind{wind_table,
              {static_cast<float>(air.x), static_cast<float>(air.y), static_cast<float>(air.z)}};
    alignas(16) std::array<std::byte, 80> sight{};
    api.ctor(sight.data(), shell);
    auto trajectory = [&](V dir, double t, V &out) {
        V launch = dir * speed + own;
        int ok = api.time(sight.data(), muzzle.y, t, &launch, &wind, &out, 4.0);
        out.y -= muzzle.y;
        return ok != 0 && std::isfinite(out.norm());
    };
    const double requested = get(p, "F22_GUN_REQUEST_TIME"), now = api.clock();
    const double delay = now - requested;
    double age = get(p, "F22_GUN_MEASUREMENT_AGE") + std::max(0.0, delay);
    const double identity = get(p, "F22_GUN_TRACK_ID");
    put(p, "F22_GUN_QUEUE_DELAY", delay);
    if (!std::isfinite(now) || !std::isfinite(delay) || delay < -.01 || delay > .15 ||
        !std::isfinite(age) || age < 0 || age > .15) {
        put(p, "F22_GUN_SOLVER_REASON", 8);
        api.dtor(sight.data());
        return;
    }
    GunTargetMotion::Model motion(target, velocity, acceleration);
    V current = motion.at(age), current_velocity = motion.velocity(age);
    const auto *seed = (identity == previous_id && now > previous_time && now - previous_time < .15)
                           ? &previous
                           : nullptr;
    auto prediction = [&](double t) { return motion.at(age + t) - muzzle; };
    auto result = GunIntercept::solve(current - muzzle, current_velocity, acceleration, own, speed,
                                      trajectory, prediction, seed);
    V actual_endpoint{};
    bool actual_valid = result.valid && trajectory(bore, result.time, actual_endpoint);
    if (result.valid && (identity != maneuver_cues.identity || now < maneuver_cues.time ||
                         now - maneuver_cues.time >= .1)) {
        const auto began = std::chrono::steady_clock::now();
        maneuver_cues = {};
        maneuver_cues.identity = identity;
        maneuver_cues.time = now;
        maneuver_cues.base = result.direction;
        auto references = GunManeuver::references(current_velocity, motion.acceleration(age));
        maneuver_cues.observed_load = references.observed_load;
        maneuver_cues.valid = references.valid;
        for (unsigned i = 0; i < references.acceleration.size() && maneuver_cues.valid; ++i) {
            auto acceleration_case = references.acceleration[i];
            GunTargetMotion::Model hypothetical(current, current_velocity, acceleration_case);
            auto alternative = GunIntercept::solve(current - muzzle, current_velocity,
                acceleration_case, own, speed, trajectory,
                [&](double t) { return hypothetical.at(t) - muzzle; }, &result);
            maneuver_cues.valid = alternative.valid;
            maneuver_cues.aim[i] = alternative.direction;
        }
        maneuver_cues.cost_ms = std::chrono::duration<double, std::milli>(
            std::chrono::steady_clock::now() - began).count();
    }

    api.dtor(sight.data());
    previous = result;
    previous_time = now;
    previous_id = identity;
    put(p, "F22_GUN_ACTUAL_ENDPOINT_VALID", actual_valid ? 1 : 0);
    if (actual_valid) {
        actual_endpoint = actual_endpoint + muzzle;
        put(p, "F22_GUN_ACTUAL_END_N", actual_endpoint.x);
        put(p, "F22_GUN_ACTUAL_END_U", actual_endpoint.y);
        put(p, "F22_GUN_ACTUAL_END_E", actual_endpoint.z);
    }
    if (result.valid) {
        V predicted = motion.at(age + result.time);
        put(p, "F22_GUN_PREDICTED_N", predicted.x);
        put(p, "F22_GUN_PREDICTED_U", predicted.y);
        put(p, "F22_GUN_PREDICTED_E", predicted.z);
        put(p, "F22_GUN_CURRENT_N", current.x);
        put(p, "F22_GUN_CURRENT_U", current.y);
        put(p, "F22_GUN_CURRENT_E", current.z);
    }

    put(p, "F22_GUN_SOLVER_REASON", 6);
    if (!result.valid)
        return;
    put(p, "F22_GUN_AIM_N", result.direction.x);
    put(p, "F22_GUN_AIM_U", result.direction.y);
    put(p, "F22_GUN_AIM_E", result.direction.z);
    put(p, "F22_GUN_BORE_N", bore.x);
    put(p, "F22_GUN_BORE_U", bore.y);
    put(p, "F22_GUN_BORE_E", bore.z);
    put(p, "F22_GUN_MUZZLE_N", muzzle.x);
    put(p, "F22_GUN_MUZZLE_U", muzzle.y);
    put(p, "F22_GUN_MUZZLE_E", muzzle.z);
    put(p, "F22_GUN_TOF", result.time);
    put(p, "F22_GUN_RESIDUAL", result.miss);
    put(p, "F22_GUN_MUZZLE_SPEED", speed);
    put(p, "F22_GUN_SOLUTION_SEQUENCE", get(p, "F22_GUN_REQUEST_SEQUENCE"));
    put(p, "F22_GUN_RESULT_TIME", now);
    put(p, "F22_GUN_RESULT_TRACK_ID", identity);
    if (maneuver_cues.valid && maneuver_cues.identity == identity && now - maneuver_cues.time <= .2) {
        const char* names[] = {"LOW", "HIGH", "LEFT", "RIGHT"};
        const char* axes[] = {"N", "U", "E"};
        char key[80];
        for (unsigned i = 0; i < maneuver_cues.aim.size(); ++i) {
            const auto direction = maneuver_cues.aim[i];
            const double values[] = {direction.x, direction.y, direction.z};
            for (int k = 0; k < 3; ++k) {
                std::snprintf(key, sizeof(key), "F22_GUN_MNV_%s_%s", names[i], axes[k]);
                put(p, key, values[k]);
            }
        }
        put(p, "F22_GUN_MNV_BASE_N", maneuver_cues.base.x);
        put(p, "F22_GUN_MNV_BASE_U", maneuver_cues.base.y);
        put(p, "F22_GUN_MNV_BASE_E", maneuver_cues.base.z);
        put(p, "F22_GUN_MNV_TIME", maneuver_cues.time);
        put(p, "F22_GUN_MNV_ID", maneuver_cues.identity);
        put(p, "F22_GUN_MNV_OBSERVED_G", maneuver_cues.observed_load);
        put(p, "F22_GUN_MNV_COST_MS", maneuver_cues.cost_ms);
        put(p, "F22_GUN_MNV_VALID", 1);
    }
    put(p, "F22_GUN_SOLVER_REASON", 0);
    put(p, "F22_GUN_SOLUTION_VALID", 1);
}
} // namespace
void reset() {
    handles.clear();
    previous = {};
    maneuver_cues = {};
    previous_time = -1;
    previous_id = -1;
    failed = false;
}
void update(EDPARAM &p) {
    double sequence = 0;
    __try {
        sequence = get(p, "F22_GUN_REQUEST_SEQUENCE");
        calculate(p);
    } __except (EXCEPTION_EXECUTE_HANDLER) {
        failed = true;
        put(p, "F22_GUN_SOLUTION_VALID", 0);
        put(p, "F22_GUN_SOLVER_REASON", 7);
    }
    // Publish completion last, including failed solves. Lua may consume this next tick.
    put(p, "F22_GUN_RESPONSE_SEQUENCE", sequence);
}
} // namespace NativeGunSight
