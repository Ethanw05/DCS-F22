// GPL-3.0-or-later. Own radar's native terrain returns; no world-object
// queries.
#include "NativeGroundRadar.h"
#include "NativeGroundVideo.h"
#include "NativeGroundReturns.h"
#include "NativeGroundSensor.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <algorithm>
#include <map>
#include <string>
#include <vector>
namespace NativeGroundRadar {
namespace {
bool readable(std::uintptr_t address, std::size_t bytes) {
  MEMORY_BASIC_INFORMATION m{};
  if (!address ||
      !VirtualQuery(reinterpret_cast<void *>(address), &m, sizeof(m)))
    return false;
  const auto base = reinterpret_cast<std::uintptr_t>(m.BaseAddress);
  return m.State == MEM_COMMIT && !(m.Protect & (PAGE_GUARD | PAGE_NOACCESS)) &&
         bytes <= m.RegionSize && address >= base &&
         address - base <= m.RegionSize - bytes;
}
template <class T> bool load(std::uintptr_t address, T &out) {
  if (!readable(address, sizeof(T)))
    return false;
  std::memcpy(&out, reinterpret_cast<const void *>(address), sizeof(T));
  return true;
}
struct Api {
  using Context = void *(__cdecl *)();
  using Device = void *(__fastcall *)(void *, unsigned);
  using Clock = double(__cdecl *)();
  Context context{};
  Device device{};
  Clock clock{};
  std::uintptr_t table{};
  bool ready{};
  int reason = 1;
  void initialize() {
    if (ready || reason == 2)
      return;
    auto module = GetModuleHandleW(L"CockpitBase.dll"),
         world = GetModuleHandleW(L"World.dll");
    if (!module || !world)
      return;
    const auto base = reinterpret_cast<std::uintptr_t>(module);
    IMAGE_DOS_HEADER dos{};
    IMAGE_NT_HEADERS64 pe{};
    if (!load(base, dos) || dos.e_magic != IMAGE_DOS_SIGNATURE ||
        dos.e_lfanew < 0 || !load(base + dos.e_lfanew, pe) ||
        pe.Signature != IMAGE_NT_SIGNATURE ||
        pe.FileHeader.TimeDateStamp != 0x6ac12468 ||
        pe.OptionalHeader.SizeOfImage != 0x59a000) {
      reason = 2;
      return;
    }
    context = reinterpret_cast<Context>(GetProcAddress(
        module, "?binding_context@cockpit@@YAPEAVccCockpitContext@1@XZ"));
    device = reinterpret_cast<Device>(GetProcAddress(
        module,
        "?get_wide_device@ccCockpitContext@cockpit@@QEAAPEAVavDevice@2@I@Z"));
    clock = reinterpret_cast<Clock>(
        GetProcAddress(world, "?GetModelTime@wTime@@SANXZ"));
    table = reinterpret_cast<std::uintptr_t>(GetProcAddress(
        module, "??_7avSimpleRadar@cockpit@@6BccContextRelatedObject@1@@"));
    ready = context && device && clock && table;
    reason = ready ? 0 : 3;
  }
  bool owned(std::uintptr_t instance) const {
    std::uintptr_t actual{}, original_rtti{}, actual_rtti{};
    if (!readable(instance, 2560) || !load(instance, actual))
      return false;
    if (actual == table)
      return true;
    // Our existing coordinate adapter clones this owned radar's vtable.
    // Verify its unchanged RTTI and non-overridden methods, not a Lua pointer.
    if (!load(table - 8, original_rtti) || !load(actual - 8, actual_rtti) ||
        original_rtti != actual_rtti)
      return false;
    for (auto index : {0u, 1u, 2u, 16u, 20u, 30u}) {
      std::uintptr_t a{}, b{};
      if (!load(table + index * 8, a) || !load(actual + index * 8, b) || a != b)
        return false;
    }
    return true;
  }
} api;
std::map<std::string, void *> handles;
double last = -100;
void put(EDPARAM &p, const std::string &n, double value) {
  auto &h = handles[n];
  if (!h)
    h = p.getParamHandle(n.c_str());
  p.setParamNumber(h, value);
}
double get(EDPARAM &p, const std::string &n) {
  auto &h = handles[n];
  if (!h)
    h = p.getParamHandle(n.c_str());
  return p.getParamNumber(h);
}
} // namespace
void reset() {
  NativeGroundSensor::reset();
  NativeGroundVideo::reset();
  api = {};
  handles.clear();
  last = -100;
}
void update(EDPARAM &p) {
  NativeGroundVideo::update(p);
  NativeGroundSensor::update(p);
  const auto unavailable=[&](int reason) {
    put(p,"F22_AG_RADAR_NATIVE_READY",0);
    put(p,"F22_AG_RADAR_NATIVE_REASON",reason);
    put(p,"F22_AG_RETURN_COUNT",0);
  };
  const auto available=[&] {
    put(p,"F22_AG_RADAR_NATIVE_REASON",0);
    put(p,"F22_AG_RADAR_NATIVE_READY",1);
  };
  api.initialize();
  if (!api.ready) {
    unavailable(api.reason);
    return;
  }
  const double now = api.clock();
  if (!std::isfinite(now)) {
    unavailable(5);
    return;
  }
  if (now >= last && now - last < .1)
    return;
  last = now;
  // Keep the previous healthy publication while validating/reading this one.
  // A manufactured READY0 pulse can be sampled by cockpit Lua and erase video.
  auto context = api.context();
  const double id = get(p, "F22_RADAR_DEVICE_ID");
  if (!context || id != 13) {
    unavailable(5);
    return; // The one declared sensor; never arbitrary devices.
  }
  auto instance = reinterpret_cast<std::uintptr_t>(api.device(context, 13));
  if (!api.owned(instance)) {
    unavailable(4);
    return;
  }
  const bool active = get(p, "HUD_MODE") == 7 && get(p, "MAIN_POWER") > .5 &&
                      get(p, "RADAR_PWR") > .5;
  const double range = get(p, "F22_AG_RADAR_RANGE_NM");
  // The shared air detector's anonymous noise is neither MAP video nor GMT.
  // The core image renderer and the owned ground scene sensor now supply them.
  const float distance = 0;
  MEMORY_BASIC_INFORMATION m{};
  if (!VirtualQuery(reinterpret_cast<void *>(instance + 2532), &m, sizeof(m)) ||
      !(m.Protect & (PAGE_READWRITE | PAGE_WRITECOPY | PAGE_EXECUTE_READWRITE |
                     PAGE_EXECUTE_WRITECOPY))) {
    unavailable(5);
    return;
  }
  // Native ground_clutter.max_distance, gated to A/G; coefficients stay in Lua.
  std::memcpy(reinterpret_cast<void *>(instance + 2532), &distance,
              sizeof(distance));
  if (!active) {
    put(p,"F22_AG_RETURN_COUNT",0);
    available();
    return;
  }
  std::uintptr_t begin{}, end{};
  if (!load(instance + 2168, begin) || !load(instance + 2176, end) ||
      end < begin || (end - begin) % 144 || end - begin > 4096 * 144 ||
      (end > begin && !readable(begin, end - begin))) {
    // The adapter can remain available when there is no usable return snapshot.
    put(p,"F22_AG_RETURN_COUNT",0);
    available();
    return;
  }
  std::vector<NativeGroundReturns::Return> returns;
  for (auto record = begin; record < end; record += 144) {
    NativeGroundReturns::Return r;
    if (NativeGroundReturns::decode(reinterpret_cast<const std::byte *>(record),
                                    144, now, r))
      returns.push_back(r);
  }
  std::stable_sort(
      returns.begin(), returns.end(),
      [](const auto &a, const auto &b) { return a.stamp > b.stamp; });
  const auto count = std::min<std::size_t>(256, returns.size());
  for (std::size_t i = 0; i < count; ++i) {
    const auto prefix = "F22G_" + std::to_string(i + 1) + "_";
    const auto &r = returns[i];
    put(p, prefix + "N", r.north);
    put(p, prefix + "U", r.altitude);
    put(p, prefix + "E", r.east);
    put(p, prefix + "TIME", r.stamp);
    put(p, prefix + "RCS", r.rcs);
  }
  put(p, "F22_AG_RETURN_TIME", now);
  put(p, "F22_AG_RETURN_COUNT", static_cast<double>(count));
  available();
}
} // namespace NativeGroundRadar
