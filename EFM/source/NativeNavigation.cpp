// GPL-3.0-or-later. Own common navigation receivers. Audited DCS PE only.
#include "NativeNavigation.h"
#include "NativeNavigationHost.h"
#include "NativeAltimetry.h"
#include "CniPower.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <map>
#include <limits>
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
bool audited_image(const void* image) {
  IMAGE_DOS_HEADER dos{};
  IMAGE_NT_HEADERS64 pe{};
  if (!load(image,dos) || dos.e_magic != IMAGE_DOS_SIGNATURE
      || !RaptorNavigationHost::header_offset(dos.e_lfanew)) return false;
  const auto base = static_cast<const char*>(image);
  return load(base+dos.e_lfanew,pe) && RaptorNavigationHost::headers(pe);
}
using NativeAllocate = void*(__cdecl*)(std::size_t);
using NativeFree = void(__cdecl*)(void*);
bool native_allocators(const void* image, HMODULE crt, NativeAllocate& allocate, NativeFree& free) {
  allocate = nullptr;
  free = nullptr;
  if (!crt || !audited_image(image)) return false;
  const auto base = static_cast<const char*>(image);
  NativeAllocate candidate_allocate = nullptr;
  NativeFree candidate_free = nullptr;
  if (!load(base+RaptorNavigationHost::malloc_iat_rva,candidate_allocate)
      || !load(base+RaptorNavigationHost::free_iat_rva,candidate_free)) return false;
  const auto expected_allocate = reinterpret_cast<NativeAllocate>(GetProcAddress(crt,"malloc"));
  const auto expected_free = reinterpret_cast<NativeFree>(GetProcAddress(crt,"free"));
  if (!expected_allocate || !expected_free || candidate_allocate != expected_allocate
      || candidate_free != expected_free) return false;
  allocate = candidate_allocate;
  free = candidate_free;
  return true;
}
struct API {
  using Construct = void *(__fastcall *)(void *);
  using Destroy = void(__fastcall *)(void *);
  using Allocate = NativeAllocate;
  using Free = NativeFree;
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
  Power receiver_squelch{};
  Valid receiver_squelch_state{};
  Power receiver_mute{};
  Valid receiver_mute_state{};
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
    auto b = reinterpret_cast<const char *>(m);
    if (!audited_image(b)) {
      reason = 2;
      return;
    }
#define BIND(field, type, symbol)                                              \
  field = reinterpret_cast<type>(GetProcAddress(m, symbol))
    BIND(start, Set, "?start@avDevice@cockpit@@QEAAXI@Z");
    BIND(tacan_power, Valid, "?getElecPower@avTACAN@cockpit@@UEBA_NXZ");
    BIND(ils_power_state, Valid, "?getElecPower@avILS@cockpit@@UEBA_NXZ");
    BIND(receiver_squelch, Power, "?setSquelchOnOff@avReceiver@cockpit@@QEAAX_N@Z");
    BIND(receiver_squelch_state, Valid, "?getSquelchIsOn@avReceiver@cockpit@@QEBA_NXZ");
    BIND(receiver_mute, Power, "?mute@avReceiver@cockpit@@QEAAX_N@Z");
    BIND(receiver_mute_state, Valid, "?getMuteIsOn@avReceiver@cockpit@@QEBA_NXZ");
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
    // Read the native module's verified CRT imports; never guess an allocator
    // from an old image offset or mix it with this mod's allocation routines.
    (void)native_allocators(b,GetModuleHandleW(L"ucrtbase.dll"),allocate,free);
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
static_assert(sizeof(API::StringView) == 32);
static_assert(offsetof(API::StringView,size) == 16);
static_assert(offsetof(API::StringView,capacity) == 24);
RaptorCni::Supply supply;
std::map<std::string, void *, std::less<>> handles;
void* handle(EDPARAM& p, const char* key) {
  const auto found = handles.find(key); // Heterogeneous lookup; no temporary string allocation.
  if (found != handles.end()) {
    if (!found->second) found->second = p.getParamHandle(key);
    return found->second;
  }
  if (handles.size() >= 64) return nullptr;
  return handles.emplace(key,p.getParamHandle(key)).first->second;
}
bool put(EDPARAM &p, const char* key, double value) {
  return p.setParamNumber(handle(p,key),value);
}
bool get(EDPARAM &p, const char* key, double& value) {
  return p.getParamNumber(handle(p,key),value);
}
unsigned magnetic_sequence=0;
bool magnetic_generation(EDPARAM& p,double& generation) {
  double valid=0;
  return get(p,"EFM_PHYSICAL_VALID",valid) && valid==1
      && get(p,"EFM_PHYSICAL_GENERATION",generation) && generation>=1
      && generation<=4294967295.0 && generation==std::floor(generation);
}
bool commit_magnetic(EDPARAM& p,unsigned sequence,double generation,std::uint64_t epoch) {
  double after=0;
  if (!magnetic_generation(p,after) || after!=generation || p.epoch()!=epoch) return false;
  if (!put(p,"F22_MAG_VALID",1) || !put(p,"F22_MAG_SEQUENCE",sequence)) return false;
  magnetic_sequence=sequence;
  return true;
}
bool publish_magnetic(EDPARAM& p,double declination,double now) {
  if (!std::isfinite(now) || now<0 || !std::isfinite(declination) || std::abs(declination)>=1.57) return false;
  double generation=0;
  if (!magnetic_generation(p,generation)) return false;
  const auto epoch=p.epoch();
  const unsigned next=magnetic_sequence>=16777212 ? 2 : magnetic_sequence+2;
  if (!put(p,"F22_MAG_SEQUENCE",next-1) || !put(p,"F22_MAG_VALID",0)) return false;
  const std::pair<const char*,double> fields[]={{"F22_MAG_SCHEMA",1},{"F22_MAG_CLOCK_KIND",2},
      {"F22_MAG_GENERATION",generation},{"F22_MAG_STAMP",now},{"F22_MAG_DECL",declination}};
  for (const auto& field:fields) if (!put(p,field.first,field.second)) return false;
  return commit_magnetic(p,next,generation,epoch);
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
bool integer(double value, int& result, int lo, int hi) {
  if (!std::isfinite(value) || value < lo || value > hi || value != std::floor(value)) return false;
  result = static_cast<int>(value);
  return true;
}
bool ils_frequency(int f) {
  return f >= 108100 && f <= 111950 && ((f % 200) == 100 || (f % 200) == 150);
}
struct Controls {
  int channel = 0, band = 0, mode = 0, frequency_khz = 0;
  bool tacan_valid = false, ils_valid = false;
};
bool requested_controls(EDPARAM& p, Controls& result) {
  constexpr std::array<const char*,4> names{{"F22_TCN_CHANNEL","F22_TCN_BAND",
      "F22_TCN_MODE","F22_ILS_FREQ_KHZ"}};
  std::array<double,4> values{};
  std::array<bool,4> complete{};
  for (std::size_t i = 0; i < names.size(); ++i)
    complete[i] = get(p,names[i],values[i]);
  Controls candidate;
  if (complete[0] && complete[1] && complete[2])
    candidate.tacan_valid = integer(values[0],candidate.channel,1,126)
        && integer(values[1],candidate.band,0,1) && integer(values[2],candidate.mode,0,4);
  if (complete[3]) candidate.ils_valid = integer(values[3],candidate.frequency_khz,108100,111950)
      && ils_frequency(candidate.frequency_khz);
  result = candidate;
  return candidate.tacan_valid && candidate.ils_valid;
}
// Observation of the current native receiver state, not the RF measurement time.
// No station identity or acquisition guarantee is inferred from a tuning command.
struct Reception {
  Controls controls;
  void* context = nullptr;
  std::uint64_t parameter_epoch = 0;
  double generation = 0;
  double bearing = 0, range_m = 0, localizer = 0, glideslope = 0;
  bool tacan_power = false, ils_power = false;
  bool bearing_valid = false, range_valid = false;
  bool localizer_valid = false, glideslope_valid = false;
};
unsigned reception_sequence = 0;
double reception_generation = 0;
struct SignalAdmission {
  bool waiting_for_clear = true;
  bool observe(bool native_valid) {
    if (waiting_for_clear) {
      if (!native_valid) waiting_for_clear = false;
      return false;
    }
    return native_valid;
  }
};
SignalAdmission bearing_admission, range_admission, loc_admission, gs_admission;
bool receiver_context_retired = false;
bool reception_current(EDPARAM& p, const Reception& sample) {
  double generation = 0;
  return api.context && api.context() == sample.context && sample.context
      && p.epoch() == sample.parameter_epoch && magnetic_generation(p,generation)
      && generation == sample.generation;
}
bool begin_reception(EDPARAM& p, const Reception& sample, double observed, unsigned& next) {
  if (!std::isfinite(observed) || observed < 0 || observed >= 1e9
      || !reception_current(p,sample)) return false;
  if (sample.generation != reception_generation) {
    reception_generation = sample.generation;
    reception_sequence = 0;
  }
  if (reception_sequence >= 16777214) return false; // No marker reuse in one generation.
  next = reception_sequence + 2;
  return put(p,"F22_RADIONAV_SEQUENCE",next-1) && put(p,"F22_RADIONAV_VALID",0);
}
bool commit_reception(EDPARAM& p, const Reception& sample, unsigned next) {
  if (!reception_current(p,sample) || !put(p,"F22_RADIONAV_VALID",1)
      || !put(p,"F22_RADIONAV_SEQUENCE",next)) return false;
  reception_sequence = next;
  return true;
}
bool publish_reception(EDPARAM& p, const Reception& sample, double observed) {
  unsigned next = 0;
  if (!begin_reception(p,sample,observed,next)) return false;
  const auto& c = sample.controls;
  const std::pair<const char*,double> fields[] = {
    {"F22_RADIONAV_SCHEMA",1},{"F22_RADIONAV_CLOCK_KIND",2},
    {"F22_RADIONAV_GENERATION",sample.generation},{"F22_RADIONAV_STAMP",observed},
    {"F22_RADIONAV_TCN_CHANNEL",c.channel},{"F22_RADIONAV_TCN_BAND",c.band},
    {"F22_RADIONAV_TCN_MODE",c.mode},{"F22_RADIONAV_ILS_FREQ_KHZ",c.frequency_khz},
    {"F22_TCN_POWER",sample.tacan_power},{"F22_ILS_POWER",sample.ils_power},
    {"F22_TCN_BRG_MAG",sample.bearing},{"F22_TCN_RANGE_M",sample.range_m},
    {"F22_ILS_LOC",sample.localizer},{"F22_ILS_GS",sample.glideslope},
    {"F22_TCN_BRG_VALID",sample.bearing_valid},{"F22_TCN_RANGE_VALID",sample.range_valid},
    {"F22_ILS_LOC_VALID",sample.localizer_valid},{"F22_ILS_GS_VALID",sample.glideslope_valid}};
  for (const auto& field:fields) if (!put(p,field.first,field.second)) return false;
  return commit_reception(p,sample,next);
}
bool bounded(double value, double lo, double hi) {
  return std::isfinite(value) && value >= lo && value <= hi;
}
void observe_tacan(Reception& sample, void* tacan) {
  const auto& c = sample.controls;
  if (!c.tacan_valid || !sample.tacan_power) return;
  const bool b = bearing_admission.observe(api.bv(tacan));
  const bool r = range_admission.observe(api.rv(tacan));
  if (b) sample.bearing = api.bearing(tacan);
  if (r) sample.range_m = api.range(tacan) * 1852.0;
  constexpr double circle = 2*3.141592653589793;
  sample.bearing_valid = b && (c.mode == 1 || c.mode == 2) && bounded(sample.bearing,-circle,circle);
  sample.range_valid = r && c.mode >= 2 && bounded(sample.range_m,0,999999999);
}
void observe_ils(Reception& sample, void* ils) {
  if (!sample.controls.ils_valid || !sample.ils_power) return;
  const bool l = loc_admission.observe(api.lv(ils));
  const bool g = gs_admission.observe(api.gv(ils));
  if (l) sample.localizer = api.loc(ils);
  if (g) sample.glideslope = api.gs(ils);
  constexpr double half_circle = 3.141592653589793;
  sample.localizer_valid = l && bounded(sample.localizer,-half_circle,half_circle);
  sample.glideslope_valid = g && bounded(sample.glideslope,-half_circle,half_circle);
}
void observe_reception(Reception& sample, void* tacan, void* ils, bool powered) {
  sample.tacan_power = api.tacan_power(tacan);
  sample.ils_power = api.ils_power_state(ils);
  if (!powered) return;
  observe_tacan(sample,tacan);
  observe_ils(sample,ils);
  // Invalid payloads remain finite transport values behind independent false flags.
  if (!sample.bearing_valid) sample.bearing = 0;
  if (!sample.range_valid) sample.range_m = 0;
  if (!sample.localizer_valid) sample.localizer = 0;
  if (!sample.glideslope_valid) sample.glideslope = 0;
}
bool configure_squelch(void *tacan, void *ils) {
  if (!api.receiver_squelch || !api.receiver_squelch_state)
    return false;
  // Matched common receiver subobjects, verified in initialize/post methods.
  // Squelch gates receiver noise; tuned-station identification remains audio.
  auto t = static_cast<char *>(tacan) + RaptorNavigationHost::tacan_receiver_offset;
  auto i = static_cast<char *>(ils) + RaptorNavigationHost::ils_receiver_offset;
  api.receiver_squelch(t, true);
  api.receiver_squelch(i, true);
  return api.receiver_squelch_state(t) && api.receiver_squelch_state(i);
}
bool mute_identification(void *tacan, void *ils) {
  if (!api.receiver_mute || !api.receiver_mute_state) return false;
  // The mod has no selected NAV identification monitor. The native receiver
  // mute only closes Sounder::Switcher (+152); measurement/power are separate.
  // Audited CockpitBase 0x1802E7C60, getMuteIsOn 0x1802E6950.
  auto t = static_cast<char *>(tacan) + RaptorNavigationHost::tacan_receiver_offset;
  auto i = static_cast<char *>(ils) + RaptorNavigationHost::ils_receiver_offset;
  api.receiver_mute(t, true);
  api.receiver_mute(i, true);
  return api.receiver_mute_state(t) && api.receiver_mute_state(i);
}
bool unavailable(EDPARAM& p, int reason) {
  (void)put(p,"F22_RADIONAV_AVAILABLE",0);
  (void)put(p,"F22_RADIONAV_REASON",reason);
  return false;
}
void* current_context(EDPARAM& p) {
  auto context = api.context();
  if (receiver_context_retired || !context || (api.component && api.component_context != context)) {
    if (api.component) receiver_context_retired = true;
    (void)unavailable(p,8);
    return nullptr;
  }
  // Readability/reused addresses cannot restore a retired context. Callback
  // drain and matched destruction at reset still require host qualification.
  return context;
}
bool create_tacan(EDPARAM& p, void* context) {
  if (api.component) return true;
  char path[4096]{};
  if (!p.getParamString(handle(p,"F22_NAV_CONFIG_PATH"),path,sizeof path) || !path[0])
    return unavailable(p,5);
  void* memory = api.allocate(RaptorNavigationHost::tacan_bytes);
  if (!memory) return unavailable(p,6);
  api.component = api.construct(memory);
  if (!api.component) {
    api.free(memory);
    return unavailable(p,6);
  }
  api.component_context = context;
  // ccContextRelatedObject::get_context is [this+24], verified in IDA.
  std::memcpy(static_cast<char*>(memory)+RaptorNavigationHost::context_offset,&context,sizeof context);
  API::StringView name{};
  std::memcpy(name.inline_text,"F22_TACAN",10);
  name.size = 9;
  name.capacity = 15;
  API::StringView config{};
  config.pointer = path;
  config.size = std::strlen(path);
  config.capacity = config.size > 15 ? config.size : 16;
  api.initialize(memory,23,name,config);
  api.start(memory,0);
  if (auto electrical = owned(context,26,api.electrical_table,RaptorNavigationHost::electrical_probe_bytes)) {
    api.connect_tacan(memory,api.dc_bus(electrical,1),api.ac_bus(electrical,1));
  }
  return true;
}
bool receivers(EDPARAM& p, void* context, void*& tacan, void*& ils) {
  if (!create_tacan(p,context)) return false;
  tacan = api.component;
  ils = owned(context,24,api.ils_table,RaptorNavigationHost::ils_bytes);
  void* table = nullptr;
  if (!load(tacan,table) || table != api.tacan_table || !ils) return unavailable(p,4);
  return true;
}
void connect_receivers(void* context, void* ils, const RaptorCni::Power& feed) {
  auto electrical = owned(context,26,api.electrical_table,RaptorNavigationHost::electrical_probe_bytes);
  if (!electrical) return;
  if (ils != api.connected_ils) {
    api.connect_ils(ils,api.dc_bus(electrical,1),api.ac_bus(electrical,1));
    api.connected_ils = ils;
  }
  api.generator(electrical,feed.left,1);
  api.generator(electrical,feed.right,2);
}
bool tacan_changed(const Controls& wanted, int desired_mode) {
  return ch != wanted.channel || band != wanted.band || mode != desired_mode;
}
void tune_tacan(void* tacan, const Controls& wanted, bool on) {
  if (tacan != tlast) {
    ch = band = mode = -1;
    tlast = tacan;
  }
  const int desired_mode = on && wanted.tacan_valid ? wanted.mode : 0;
  if (tacan_changed(wanted,desired_mode)) bearing_admission = range_admission = SignalAdmission{};
  if (wanted.tacan_valid && ch != wanted.channel) {
    api.channel(tacan,wanted.channel);
    ch = wanted.channel;
  }
  if (wanted.tacan_valid && band != wanted.band) {
    api.xy(tacan,wanted.band);
    band = wanted.band;
  }
  if (mode != desired_mode) {
    api.mode(tacan,desired_mode);
    mode = desired_mode;
  }
}
void tune_ils(void* ils, const Controls& wanted, bool on) {
  if (ils != ilast) {
    freq = power = -1;
    ilast = ils;
  }
  const int desired_power = on && wanted.ils_valid ? 1 : 0;
  if (freq != wanted.frequency_khz || power != desired_power) loc_admission = gs_admission = SignalAdmission{};
  if (wanted.ils_valid && freq != wanted.frequency_khz) {
    api.mhz(ils,wanted.frequency_khz/1000);
    api.khz(ils,wanted.frequency_khz%1000);
    freq = wanted.frequency_khz;
  }
  if (power != desired_power) {
    api.ils_power(ils,desired_power != 0);
    power = desired_power;
  }
}
void update_reception(EDPARAM& p, void* context, void* tacan, void* ils, bool on) {
  Reception sample;
  if (!requested_controls(p,sample.controls)) (void)put(p,"F22_RADIONAV_REASON",7);
  tune_tacan(tacan,sample.controls,on);
  tune_ils(ils,sample.controls,on);
  sample.context = context;
  sample.parameter_epoch = p.epoch();
  if (!magnetic_generation(p,sample.generation)) return;
  if (sample.generation != reception_generation) {
    bearing_admission = range_admission = loc_admission = gs_admission = SignalAdmission{};
  }
  observe_reception(sample,tacan,ils,on);
  double observed = 0;
  if (NativeAltimetry::model_time(observed)) (void)publish_reception(p,sample,observed);
}
bool own_position(EDPARAM& p, double& north, double& east) {
  double valid = 0;
  return get(p,"F22_NAV_OWN_VALID",valid) && valid == 1
      && get(p,"F22_NAV_OWN_N",north) && get(p,"F22_NAV_OWN_E",east);
}
void update_magnetic(EDPARAM& p) {
  double north = 0, east = 0;
  if (!api.decl || !api.coordinates || !own_position(p,north,east)) return;
  double latitude = NAN, longitude = NAN;
  api.coordinates(north,east,latitude,longitude);
  constexpr double maximum = std::numeric_limits<float>::max();
  if (!bounded(latitude,-maximum,maximum) || !bounded(longitude,-maximum,maximum)) return;
  const auto lat = static_cast<float>(latitude), lon = static_cast<float>(longitude);
  if (!std::isfinite(lat) || !std::isfinite(lon)) return;
  const double declination = api.decl(lat,lon);
  double observed = 0;
  if (NativeAltimetry::model_time(observed)) (void)publish_magnetic(p,declination,observed);
}
RaptorCni::Power begin_update(EDPARAM& p) {
  (void)put(p,"F22_RADIONAV_VALID",0);
  (void)put(p,"F22_NAV_SQUELCH_VALID",0);
  (void)put(p,"F22_NAV_IDENT_MUTED",0);
  const auto feed = supply.sample(p);
  (void)put(p,"F22_CNI_SUPPLY_VALID",feed.valid ? 1 : 0);
  (void)put(p,"F22_CNI_RECEIVER_FEED",feed.receiver ? 1 : 0);
  (void)put(p,"F22_CNI_THERMAL_INHIBIT",feed.thermal ? 1 : 0);
  for (const char* key:{"F22_TCN_BRG_VALID","F22_TCN_RANGE_VALID","F22_ILS_LOC_VALID",
      "F22_ILS_GS_VALID","F22_MAG_VALID"}) (void)put(p,key,0);
  api.init();
  (void)put(p,"F22_RADIONAV_AVAILABLE",api.ready ? 1 : 0);
  (void)put(p,"F22_RADIONAV_REASON",api.reason);
  return feed;
}
} // namespace
void reset() {
  if (api.component && api.release && api.destroy && api.free) {
    api.release(api.component);
    api.destroy(api.component);
    api.free(api.component);
  }
  api = API{};
  supply = RaptorCni::Supply{};
  handles.clear();
  tlast = ilast = nullptr;
  ch = band = mode = freq = power = -1;
  magnetic_sequence=0;
  reception_sequence=0;
  reception_generation=0;
  bearing_admission = range_admission = loc_admission = gs_admission = SignalAdmission{};
  receiver_context_retired = false;
}
void update(EDPARAM &p) {
  const auto feed = begin_update(p);
  if (!api.ready)
    return;
  auto context = current_context(p);
  if (!context) return;
  void* tacan = nullptr;
  void* ils = nullptr;
  if (!receivers(p,context,tacan,ils)) return;
  (void)put(p,"F22_NAV_SQUELCH_VALID",configure_squelch(tacan,ils) ? 1 : 0);
  connect_receivers(context,ils,feed);
  (void)put(p,"F22_NAV_IDENT_MUTED",mute_identification(tacan,ils) ? 1 : 0);
  update_reception(p,context,tacan,ils,feed.receiver);
  if (feed.receiver) update_magnetic(p);
}
} // namespace NativeNavigation
