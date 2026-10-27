// GPL-3.0-or-later. Own common navigation receivers. Audited DCS PE only.
#include "NativeNavigation.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <map>
#include <string>
namespace NativeNavigation {
namespace {
bool readable(const void *p, std::size_t n) {
  MEMORY_BASIC_INFORMATION m{};
  if (!p || !VirtualQuery(p, &m, sizeof m))
    return false;
  auto a = reinterpret_cast<std::uintptr_t>(p),
       b = reinterpret_cast<std::uintptr_t>(m.BaseAddress);
  return m.State == MEM_COMMIT && !(m.Protect & (PAGE_GUARD | PAGE_NOACCESS)) &&
         n <= m.RegionSize && a >= b && a - b <= m.RegionSize - n;
}
template <class T> bool load(const void *p, T &v) {
  if (!readable(p, sizeof v))
    return false;
  std::memcpy(&v, p, sizeof v);
  return true;
}
struct API {
  using Construct = void *(__fastcall *)(void *);
  using Destroy = void(__fastcall *)(void *);
  using Allocate = void *(__cdecl *)(std::size_t);
  using Free = void(__cdecl *)(void *);
  struct StringView {
    union {
      const char *pointer;
      char inline_text[16];
    };
    std::size_t size{}, capacity{};
  };
  using Initialize = void(__fastcall *)(void *, unsigned char,
                                        const StringView &, const StringView &);
  using Connect = void(__fastcall *)(void *, void *, void *);
  using Bus = void *(__fastcall *)(void *, int);
  using Generator = void(__fastcall *)(void *, bool, int);
  using Context = void *(__cdecl *)();
  using Device = void *(__fastcall *)(void *, unsigned);
  using Set = void(__fastcall *)(void *, int);
  using Power = void(__fastcall *)(void *, bool);
  using Number = double(__fastcall *)(const void *);
  using Valid = bool(__fastcall *)(void *);
  using Declination = float(__cdecl *)(float, float);
  using Coordinates = void(__cdecl *)(double, double, double &, double &);
  Construct construct{};
  Destroy destroy{}, release{}, post{};
  Initialize initialize{};
  Allocate allocate{};
  Free free{};
  void *component{};
  void *component_context{};
  void *connected_ils{};
  Set start{};
  Valid tacan_power{}, ils_power_state{};
  void *electrical_table{};
  Connect connect_tacan{}, connect_ils{};
  Bus ac_bus{}, dc_bus{};
  Generator generator{};

  Context context{};
  Device device{};
  Set channel{}, xy{}, mode{}, mhz{}, khz{};
  Power ils_power{};
  Number bearing{}, range{}, loc{}, gs{};
  Valid bv{}, rv{}, lv{}, gv{};
  Declination decl{};
  Coordinates coordinates{};
  void *tacan_table{}, *ils_table{}, *compass_table{};
  bool ready{};
  int reason = 1;
  void init() {
    if (ready || reason == 2)
      return;
    auto m = GetModuleHandleW(L"CockpitBase.dll");
    if (!m)
      return;
    IMAGE_DOS_HEADER dos{};
    IMAGE_NT_HEADERS64 pe{};
    auto b = reinterpret_cast<const char *>(m);
    if (!load(b, dos) || dos.e_magic != IMAGE_DOS_SIGNATURE ||
        dos.e_lfanew < 0 || !load(b + dos.e_lfanew, pe) ||
        pe.Signature != IMAGE_NT_SIGNATURE ||
        pe.FileHeader.TimeDateStamp != 0x6ac12468 ||
        pe.OptionalHeader.SizeOfImage != 0x59a000) {
      reason = 2;
      return;
    }
#define BIND(field, type, symbol)                                              \
  field = reinterpret_cast<type>(GetProcAddress(m, symbol))
    BIND(start, Set, "?start@avDevice@cockpit@@QEAAXI@Z");
    BIND(tacan_power, Valid, "?getElecPower@avTACAN@cockpit@@UEBA_NXZ");
    BIND(ils_power_state, Valid, "?getElecPower@avILS@cockpit@@UEBA_NXZ");
    electrical_table = GetProcAddress(
        m, "??_7avSimpleElectricSystem@cockpit@@6BccContextRelatedObject@1@@");
    BIND(connect_tacan, Connect,
         "?connectElecPower@avTACAN@cockpit@@QEAAXAEAVItemBase@Elec@EagleFM@@0@"
         "Z");
    BIND(
        connect_ils, Connect,
        "?connectElecPower@avILS@cockpit@@UEAAXAEAVItemBase@Elec@EagleFM@@0@Z");
    BIND(ac_bus, Bus,
         "?getACbus@avSimpleElectricSystem@cockpit@@QEAAAEAVWire@Elec@EagleFM@@"
         "H@Z");
    BIND(dc_bus, Bus,
         "?getDCbus@avSimpleElectricSystem@cockpit@@QEAAAEAVWire@Elec@EagleFM@@"
         "H@Z");
    BIND(generator, Generator,
         "?switchGenerator@avSimpleElectricSystem@cockpit@@QEAAX_NH@Z");
    BIND(construct, Construct, "??0avTACAN@cockpit@@QEAA@XZ");
    BIND(destroy, Destroy, "??1avTACAN@cockpit@@UEAA@XZ");
    BIND(release, Destroy, "?release@avDevice@cockpit@@UEAAXXZ");
    BIND(post, Destroy, "?post_initialize@avTACAN@cockpit@@UEAAXXZ");
    BIND(initialize, Initialize,
         "?initialize@avTACAN@cockpit@@UEAAXEAEBV?$basic_string@D@ed@@0@Z");
    load(b + 0x449470, allocate);
    load(b + 0x449460, free);
    BIND(context, Context,
         "?binding_context@cockpit@@YAPEAVccCockpitContext@1@XZ");
    BIND(device, Device,
         "?get_wide_device@ccCockpitContext@cockpit@@QEAAPEAVavDevice@2@I@Z");
    BIND(channel, Set, "?setChannel@avTACAN@cockpit@@UEAAXH@Z");
    BIND(xy, Set, "?setChannelXYMode@avTACAN@cockpit@@UEAAXH@Z");
    BIND(mode, Set, "?setMode@avTACAN@cockpit@@UEAAXH@Z");
    BIND(mhz, Set, "?setFrequencyMHz@avILS@cockpit@@QEAAXH@Z");
    BIND(khz, Set, "?setFrequencyKHz@avILS@cockpit@@QEAAXH@Z");
    BIND(ils_power, Power, "?setElecPower@avILS@cockpit@@QEAAX_N@Z");
    BIND(bearing, Number, "?getMagneticBearing@avTACAN@cockpit@@UEAANXZ");
    BIND(range, Number, "?getRange@avTACAN@cockpit@@UEAANXZ");
    BIND(loc, Number, "?getLocalizerDeviation@avILS@cockpit@@QEBANXZ");
    BIND(gs, Number, "?getGlideslopeDeviation@avILS@cockpit@@QEBANXZ");
    BIND(bv, Valid, "?isBearingValid@avTACAN@cockpit@@UEAA_NXZ");
    BIND(rv, Valid, "?isRangeValid@avTACAN@cockpit@@UEAA_NXZ");
    BIND(lv, Valid, "?isLocalizerValid@avILS@cockpit@@QEBA_NXZ");
    BIND(gv, Valid, "?isGlideslopeValid@avILS@cockpit@@QEBA_NXZ");
    if (auto world = GetModuleHandleW(L"WorldGeneral.dll")) {
      decl = reinterpret_cast<Declination>(
          GetProcAddress(world, "?get_mag_decl@magvar@@YAMMM@Z"));
      coordinates = reinterpret_cast<Coordinates>(GetProcAddress(
          world, "?LatLon@MapCoords@MapCoordsSpace@@SAXNNAEAN0@Z"));
    }
    tacan_table =
        GetProcAddress(m, "??_7avTACAN@cockpit@@6BccContextRelatedObject@1@@");
    ils_table =
        GetProcAddress(m, "??_7avILS@cockpit@@6BccContextRelatedObject@1@@");

#undef BIND
    ready = start && tacan_power && ils_power_state && electrical_table &&
            connect_tacan && connect_ils && ac_bus && dc_bus && generator &&
            construct && destroy && release && post && initialize && allocate &&
            free && context && device && channel && xy && mode && mhz && khz &&
            ils_power && bearing && range && loc && gs && bv && rv && lv &&
            gv && tacan_table && ils_table;
    reason = ready ? 0 : 3;
  }
} api;
std::map<std::string, void *> handles;
void put(EDPARAM &p, const std::string &k, double v) {
  auto &h = handles[k];
  if (!h)
    h = p.getParamHandle(k.c_str());
  p.setParamNumber(h, v);
}
double get(EDPARAM &p, const std::string &k) {
  auto &h = handles[k];
  if (!h)
    h = p.getParamHandle(k.c_str());
  return p.getParamNumber(h);
}
void *tlast{}, *ilast{};
int ch = -1, band = -1, mode = -1, freq = -1, power = -1;
void *owned(void *context, unsigned id, const void *table, std::size_t n) {
  if (!context || !table)
    return nullptr;
  void *d = api.device(context, id);
  void *v{};
  return readable(d, n) && load(d, v) && v == table ? d : nullptr;
}
int integer(double v, int fallback, int lo, int hi) {
  return std::isfinite(v) && v >= lo && v <= hi ? int(std::lround(v))
                                                : fallback;
}
bool ils_frequency(int f) {
  return f >= 108100 && f <= 111950 && ((f % 200) == 100 || (f % 200) == 150);
}
} // namespace
void reset() {
  if (api.component && api.release && api.destroy && api.free) {
    api.release(api.component);
    api.destroy(api.component);
    api.free(api.component);
  }
  api = API{};
  handles.clear();
  tlast = ilast = nullptr;
  ch = band = mode = freq = power = -1;
}
void update(EDPARAM &p) {
  for (const char *k :
       {"F22_TCN_BRG_VALID", "F22_TCN_RANGE_VALID", "F22_ILS_LOC_VALID",
        "F22_ILS_GS_VALID", "F22_MAG_VALID"})
    put(p, k, 0);
  api.init();
  put(p, "F22_RADIONAV_AVAILABLE", api.ready ? 1 : 0);
  put(p, "F22_RADIONAV_REASON", api.reason);
  if (!api.ready)
    return;
  auto context = api.context();
  if (!context)
    return;
  if (!api.component) {
    auto &path_handle = handles["F22_NAV_CONFIG_PATH"];
    if (!path_handle)
      path_handle = p.getParamHandle("F22_NAV_CONFIG_PATH");
    char path[4096]{};
    p.getParamString(path_handle, path, sizeof path);
    if (!path[0]) {
      put(p, "F22_RADIONAV_REASON", 5);
      return;
    }
    void *memory = api.allocate(2856);
    if (!memory) {
      put(p, "F22_RADIONAV_REASON", 6);
      return;
    }
    api.component = api.construct(memory);
    api.component_context = context;
    // ccContextRelatedObject::get_context is [this+24], verified in IDA.
    std::memcpy(static_cast<char *>(memory) + 24, &context, sizeof context);
    API::StringView name{};
    std::memcpy(name.inline_text, "F22_TACAN", 10);
    name.size = 9;
    name.capacity = 15;
    API::StringView config{};
    config.pointer = path;
    config.size = std::strlen(path);
    config.capacity = config.size > 15 ? config.size : 16;
    api.initialize(memory, 23, name, config);
    api.start(memory, 0);
    if (auto electrical = owned(context, 26, api.electrical_table, 5800)) {
      api.connect_tacan(memory, api.dc_bus(electrical, 1),
                        api.ac_bus(electrical, 1));
    }
  }
  void *t = api.component;
  auto i = owned(context, 24, api.ils_table, 3352);
  void *table{};
  if (!load(t, table) || table != api.tacan_table)
    t = nullptr;
  if (!t || !i) {
    put(p, "F22_RADIONAV_AVAILABLE", 0);
    put(p, "F22_RADIONAV_REASON", 4);
    return;
  }
  if (i != api.connected_ils) {
    if (auto electrical = owned(context, 26, api.electrical_table, 5800)) {
      api.connect_ils(i, api.dc_bus(electrical, 1), api.ac_bus(electrical, 1));
      api.connected_ils = i;
    }
  }
  int on = get(p, "MAIN_POWER") > .5 ? 1 : 0;
  if (auto electrical = owned(context, 26, api.electrical_table, 5800)) {
    api.generator(electrical, on != 0, 1);
    api.generator(electrical, on != 0, 2);
  }
  int wanted_ch = integer(get(p, "F22_TCN_CHANNEL"), 1, 1, 126),
      wanted_band = integer(get(p, "F22_TCN_BAND"), 0, 0, 1);
  int wanted_mode = on ? integer(get(p, "F22_TCN_MODE"), 2, 0, 4) : 0;
  int wanted_freq = integer(get(p, "F22_ILS_FREQ_KHZ"), 110300, 108100, 111950);
  if (!ils_frequency(wanted_freq))
    wanted_freq = 110300;
  if (t != tlast) {
    ch = band = mode = -1;
    tlast = t;
  }
  if (i != ilast) {
    freq = power = -1;
    ilast = i;
  }
  if (ch != wanted_ch) {
    api.channel(t, wanted_ch);
    ch = wanted_ch;
  }
  if (band != wanted_band) {
    api.xy(t, wanted_band);
    band = wanted_band;
  }
  if (mode != wanted_mode) {
    api.mode(t, wanted_mode);
    mode = wanted_mode;
  }
  if (freq != wanted_freq) {
    api.mhz(i, wanted_freq / 1000);
    api.khz(i, wanted_freq % 1000);
    freq = wanted_freq;
  }
  if (power != on) {
    api.ils_power(i, on != 0);
    power = on;
  }
  put(p, "F22_TCN_POWER", api.tacan_power(t) ? 1 : 0);
  put(p, "F22_ILS_POWER", api.ils_power_state(i) ? 1 : 0);
  if (!on)
    return;
  const bool b = api.bv(t), r = api.rv(t), l = api.lv(i), g = api.gv(i);
  double bearing = api.bearing(t), range = api.range(t), loc = api.loc(i),
         gs = api.gs(i);
  if (b && std::isfinite(bearing)) {
    put(p, "F22_TCN_BRG_MAG", bearing);
    put(p, "F22_TCN_BRG_VALID", 1);
  }
  if (r && std::isfinite(range) && range >= 0) {
    put(p, "F22_TCN_RANGE_M", range * 1852.0);
    put(p, "F22_TCN_RANGE_VALID", 1);
  }
  if (l && std::isfinite(loc)) {
    put(p, "F22_ILS_LOC", loc);
    put(p, "F22_ILS_LOC_VALID", 1);
  }
  if (g && std::isfinite(gs)) {
    put(p, "F22_ILS_GS", gs);
    put(p, "F22_ILS_GS_VALID", 1);
  }
  if (api.decl && api.coordinates && get(p, "F22_NAV_OWN_VALID") > .5) {
    double latitude{}, longitude{};
    api.coordinates(get(p, "F22_NAV_OWN_N"), get(p, "F22_NAV_OWN_E"), latitude,
                    longitude);
    const double d =
        api.decl(static_cast<float>(latitude), static_cast<float>(longitude));
    if (std::isfinite(d) && std::abs(d) < 1.57) {
      put(p, "F22_MAG_DECL", d);
      put(p, "F22_MAG_VALID", 1);
    }
  }
}
} // namespace NativeNavigation
