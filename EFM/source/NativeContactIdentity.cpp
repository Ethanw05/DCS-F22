// GPL-3.0-or-later. Game coalition metadata, not a simulated IFF reply.
// Resolve only IDs already supplied by the passive receiver. No positions,
// velocities, global object enumeration or radar-track ID matching.
#include "NativeContactIdentity.h"
#include "NativeSidewinderHost.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <limits>
namespace NativeContactIdentity {
namespace {
bool readable(const void *address, std::size_t bytes) {
  MEMORY_BASIC_INFORMATION memory{};
  if (!address || !VirtualQuery(address, &memory, sizeof(memory)))
    return false;
  const auto base = reinterpret_cast<std::uintptr_t>(memory.BaseAddress);
  const auto value = reinterpret_cast<std::uintptr_t>(address);
  return memory.State == MEM_COMMIT && !(memory.Protect & (PAGE_GUARD | PAGE_NOACCESS)) &&
         bytes <= memory.RegionSize && value >= base && value - base <= memory.RegionSize - bytes;
}
template <class F> F method(void *object, unsigned index) {
  if (!readable(object, sizeof(void *)))
    return nullptr;
  void **table{};
  std::memcpy(&table, object, sizeof(table));
  if (!table || !readable(table + index, sizeof(void *)))
    return nullptr;
  return reinterpret_cast<F>(table[index]);
}
bool profile(HMODULE module, DWORD stamp, DWORD size) {
  if (!readable(module, sizeof(IMAGE_DOS_HEADER)))
    return false;
  IMAGE_DOS_HEADER dos{};
  std::memcpy(&dos, module, sizeof(dos));
  if (dos.e_magic != IMAGE_DOS_SIGNATURE || dos.e_lfanew < 0)
    return false;
  const auto pe = reinterpret_cast<const std::byte *>(module) + dos.e_lfanew;
  if (!readable(pe, sizeof(IMAGE_NT_HEADERS64)))
    return false;
  IMAGE_NT_HEADERS64 header{};
  std::memcpy(&header, pe, sizeof(header));
  return header.Signature == IMAGE_NT_SIGNATURE && header.FileHeader.TimeDateStamp == stamp &&
         header.OptionalHeader.SizeOfImage == size;
}
struct Api {
  using Clock = double(__cdecl *)();
  using Aircraft = void *(__cdecl *)();
  using Find = void *(__fastcall *)(unsigned);
  using Coalition = int(__fastcall *)(const void *);
  using Flag = bool(__fastcall *)(const void *, int);
  using Dead = bool(__fastcall *)(const void *);
  Clock clock{};
  Aircraft aircraft{};
  Find find{};
  Coalition coalition{};
  Flag flag{};
  Dead dead{};
  bool ready{};
  int reason = 1;
  bool exports_ready() const {
    return clock && aircraft && coalition && flag && dead && find;
  }
  static bool qualified(HMODULE common, HMODULE general, HMODULE world) {
    const bool legacy = profile(common, 0x6ac12468, 0x59a000) && profile(general, 0x6ac122f4, 0x125b000)
      && profile(world, 0x6aae1d9b, 0x14000);
    const bool current = profile(common, 0x6adbad09, 0x68e000) && profile(general, 0x6adbace0, 0x127b000)
      && profile(world, 0x6acb804e, 0x14000);
    return legacy || current;
  }
  void initialize() {
    if (ready || reason > 1)
      return;
    const auto common = GetModuleHandleW(L"CockpitBase.dll"), general = GetModuleHandleW(L"WorldGeneral.dll"),
               world = GetModuleHandleW(L"World.dll");
    if (!common || !general || !world)
      return;
    if (!qualified(common, general, world)) {
      reason = 2;
      return;
    }
    clock = reinterpret_cast<Clock>(GetProcAddress(world, "?GetModelTime@wTime@@SANXZ"));
    aircraft = reinterpret_cast<Aircraft>(GetProcAddress(common, "?c_LA@cockpit@@YAPEAVIwoLA@@XZ"));
    coalition = reinterpret_cast<Coalition>(
        GetProcAddress(general, "?Coalition@MovingObject@@QEBA?BW4wcCoalitionName@@XZ"));
    flag = reinterpret_cast<Flag>(GetProcAddress(general, "?IsFlag@MovingObject@@QEBA?B_NH@Z"));
    dead = reinterpret_cast<Dead>(GetProcAddress(general, "?IsDead@MovingObject@@UEBA_NXZ"));
    // Same build-qualified object resolver used for received datalink senders.
    const bool current = profile(common, 0x6adbad09, 0x68e000);
    const auto host = NativeSidewinderHost::select(current ? 0x6adbad09 : 0x6ac12468,
                                                current ? 0x68e000 : 0x59a000);
    const auto lookup = reinterpret_cast<const std::byte*>(common) + host->object_lookup_rva;
    const auto code = std::span(lookup, NativeSidewinderHost::object_lookup_size);
    if (!readable(lookup, code.size()) || !NativeSidewinderHost::matches(*host, code)) {
      reason = 2;
      return;
    }
    find = reinterpret_cast<Find>(const_cast<std::byte*>(lookup));
    ready = exports_ready();
    reason = ready ? 0 : 3;
  }
} api;
double read(EDPARAM &p, void *handle) {
  double value = std::numeric_limits<double>::quiet_NaN();
  if (!p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number(handle, value, false))
    return std::numeric_limits<double>::quiet_NaN();
  return value;
}
bool source_id(double source) {
  return std::isfinite(source) && source > 0 && source < 4294967296. && std::floor(source) == source;
}
bool observed(double source, double age) {
  return source_id(source) && std::isfinite(age) && age >= 0 && age <= 12;
}
bool combat_side(int side) {
  return side == 1 || side == 2;
}
int affiliation(unsigned source, void *owner) {
  void *target = api.find(source);
  if (!readable(target, 640) || target == owner || api.dead(target) || !api.flag(target, 32))
    return -1;
  using Identity = unsigned(__fastcall *)(void *);
  void *scene = static_cast<std::byte *>(target) + 120;
  const auto identity = method<Identity>(scene, 1);
  if (!identity || identity(scene) != source)
    return -1;
  const int own = api.coalition(owner), other = api.coalition(target);
  // DCS Scripts/Database/db_countries.lua: 0 neutral, 1 red, 2 blue.
  if (!combat_side(own) || !combat_side(other))
    return -1;
  return own == other ? 1 : 0;
}
struct Bridge {
  struct Slot {
    void *source{}, *age{}, *out_source{}, *sample{}, *affiliation{};
  };
  std::array<Slot, 16> slots{};
  void *power{}, *receiver{}, *sequence{}, *stamp{}, *ready{}, *reason{};
  bool bound{};
  unsigned serial{};
  double previous = -1;
  static bool valid(const Slot &slot) {
    return slot.source && slot.age && slot.out_source && slot.sample && slot.affiliation;
  }
  bool bind_status(EDPARAM &p) {
    power = p.getParamHandle("F22_RWR_POWER");
    receiver = p.getParamHandle("F22_RWR_READY");
    sequence = p.getParamHandle("F22_RWR_META_SEQUENCE");
    stamp = p.getParamHandle("F22_RWR_META_TIME");
    ready = p.getParamHandle("F22_RWR_META_READY");
    reason = p.getParamHandle("F22_RWR_META_REASON");
    return power && receiver && sequence && stamp && ready && reason;
  }
  bool bind(EDPARAM &p) {
    if (bound)
      return true;
    if (!p.ed_param_api.pfn_ed_cockpit_get_parameter_handle ||
        !p.ed_param_api.pfn_ed_cockpit_parameter_value_to_number ||
        !p.ed_param_api.pfn_ed_cockpit_update_parameter_with_number)
      return false;
    if (!bind_status(p))
      return false;
    char name[64]{};
    for (std::size_t i = 0; i < slots.size(); ++i) {
      auto &slot = slots[i];
      const auto index = static_cast<unsigned>(i + 1);
      std::snprintf(name, sizeof(name), "RWR_CONTACT_%02u_SOURCE", index);
      slot.source = p.getParamHandle(name);
      std::snprintf(name, sizeof(name), "RWR_CONTACT_%02u_TIME", index);
      slot.age = p.getParamHandle(name);
      std::snprintf(name, sizeof(name), "F22_RWR_META_%02u_SOURCE", index);
      slot.out_source = p.getParamHandle(name);
      std::snprintf(name, sizeof(name), "F22_RWR_META_%02u_SAMPLE_TIME", index);
      slot.sample = p.getParamHandle(name);
      std::snprintf(name, sizeof(name), "F22_RWR_META_%02u_AFFILIATION", index);
      slot.affiliation = p.getParamHandle(name);
      if (!valid(slot))
        return false;
    }
    bound = true;
    return true;
  }
  void publish_slot(EDPARAM &p, const Slot &slot, void *owner, double now, bool enabled) {
    const double source = read(p, slot.source), age = read(p, slot.age);
    int side = -1;
    const bool accepted = enabled && observed(source, age);
    if (accepted)
      side = affiliation(static_cast<unsigned>(source), owner);
    const bool coherent = accepted && source == read(p, slot.source) && age == read(p, slot.age);
    p.setParamNumber(slot.out_source, coherent ? source : 0);
    p.setParamNumber(slot.sample, coherent ? now - age : -100);
    p.setParamNumber(slot.affiliation, coherent ? side : -1);
  }
  void publish(EDPARAM &p, void *owner, double now, bool enabled) {
    serial = (serial + 2) % 16000000;
    p.setParamNumber(sequence, serial + 1);
    for (const auto &slot : slots)
      publish_slot(p, slot, owner, now, enabled);
    p.setParamNumber(stamp, std::isfinite(now) ? now : -100);
    p.setParamNumber(ready, enabled ? 1 : 0);
    p.setParamNumber(reason, enabled ? 0 : api.reason ? api.reason : 4);
    p.setParamNumber(sequence, serial + 2);
  }
} bridge;
} // namespace
void update(EDPARAM &p) {
  api.initialize();
  if (!bridge.bind(p))
    return;
  const double now = api.clock ? api.clock() : -1;
  const bool clock_valid = std::isfinite(now) && now >= 0;
  if (clock_valid && now >= bridge.previous && now - bridge.previous < .05)
    return;
  bridge.previous = now;
  void *la = api.ready ? api.aircraft() : nullptr;
  using Own = void *(__fastcall *)(void *);
  const auto own = method<Own>(la, 40);
  void *owner = own ? own(la) : nullptr;
  const bool available = api.ready && clock_valid && readable(owner, 640);
  const bool enabled = available && read(p, bridge.power) == 1 && read(p, bridge.receiver) == 1;
  bridge.publish(p, owner, now, enabled);
}
void reset() {
  bridge = {};
}
} // namespace NativeContactIdentity
