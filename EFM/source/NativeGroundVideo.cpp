// GPL-3.0-or-later. No module-specific radar, renderer patch, scene query or
// copied shader. A dedicated owned ccIndicator supplies the shared engine's
// existing radar-video camera/parameters through its normal virtual interface.
#include "NativeGroundVideo.h"
#include "GroundVideoView.h"
#include "AesaRadar.h"
#include "GroundVideoHostProfile.h"
#include "GroundVideoProbe.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <atomic>
#include <array>
#include <cstring>
#include <map>
#include <limits>
#include <mutex>
#include <string>
#include <string_view>
namespace NativeGroundVideo {
namespace {
using View = GroundVideoView::View;
constexpr unsigned render_target = 8, controller_device = 14, method_count = 41;
constexpr char source_marker[] = "F22_AG_VIDEO_SOURCE_PRESENT";
bool readable(std::uintptr_t address, std::size_t bytes) {
  MEMORY_BASIC_INFORMATION m{};
  if (!address || !VirtualQuery(reinterpret_cast<void *>(address), &m, sizeof(m))) return false;
  const auto base = reinterpret_cast<std::uintptr_t>(m.BaseAddress);
  return m.State == MEM_COMMIT && !(m.Protect & (PAGE_GUARD | PAGE_NOACCESS)) &&
      bytes <= m.RegionSize && address >= base && address-base <= m.RegionSize-bytes;
}
template<class T> bool load(std::uintptr_t address, T &value) {
  if (!readable(address,sizeof(T))) return false;
  std::memcpy(&value,reinterpret_cast<void *>(address),sizeof(T)); return true;
}
bool writable(std::uintptr_t address, std::size_t bytes) {
  MEMORY_BASIC_INFORMATION m{};
  return readable(address,bytes) && VirtualQuery(reinterpret_cast<void *>(address), &m, sizeof(m)) &&
      (m.Protect & (PAGE_READWRITE|PAGE_WRITECOPY|PAGE_EXECUTE_READWRITE|PAGE_EXECUTE_WRITECOPY));
}
bool module_image(HMODULE module, GroundVideoHostProfile::Image& image) {
  image={};
  IMAGE_DOS_HEADER dos{}; IMAGE_NT_HEADERS64 pe{};
  auto b = reinterpret_cast<std::uintptr_t>(module);
  if (!module || !load(b,dos) || dos.e_magic!=IMAGE_DOS_SIGNATURE || dos.e_lfanew<0
      || dos.e_lfanew>1048576 || !load(b+dos.e_lfanew,pe) || pe.Signature!=IMAGE_NT_SIGNATURE
      || pe.FileHeader.Machine!=IMAGE_FILE_MACHINE_AMD64
      || pe.OptionalHeader.Magic!=IMAGE_NT_OPTIONAL_HDR64_MAGIC) return false;
  image={pe.FileHeader.TimeDateStamp,pe.OptionalHeader.SizeOfImage};
  return true;
}
bool supported_images(const std::array<HMODULE,6>& modules) {
  GroundVideoHostProfile::Modules images{};
  return module_image(modules[0],images.cockpit) && module_image(modules[1],images.visualizer)
      && module_image(modules[2],images.renderer) && module_image(modules[3],images.enlight)
      && module_image(modules[4],images.graphics) && GroundVideoHostProfile::select(images);
}
struct Api {
  using Context = void *(__cdecl *)();
  using Device = void *(__fastcall *)(void *,unsigned);
  using Getter = void *(__fastcall *)(void *);
  using Clock = double(__cdecl *)();
  using Camera = void *(__fastcall *)(void *,int);
  Context context{}; Device device{}; Getter indicator_context{}, controller{};
  Clock clock{}; Camera camera{};
  std::uintptr_t targets{}, table{};
  bool ready{}, incompatible{};
  int reason = 1;
  bool exports_ready() const {
    return context && device && indicator_context && controller && clock && camera && targets && table;
  }
  void initialize() {
    if (ready || incompatible) return;
    const std::array<HMODULE,6> modules{GetModuleHandleW(L"CockpitBase.dll"),GetModuleHandleW(L"Visualizer.dll"),
      GetModuleHandleW(L"SceneRenderer.dll"),GetModuleHandleW(L"enlight.dll"),
      GetModuleHandleW(L"GraphicsVista.dll"),GetModuleHandleW(L"World.dll")};
    for (const auto module:modules) if (!module) {reason=1;return;}
    if (!supported_images(modules)) {incompatible=true;reason=2;return;}
    const auto common=modules[0],graphics=modules[4],world=modules[5];
    context=reinterpret_cast<Context>(GetProcAddress(common,"?binding_context@cockpit@@YAPEAVccCockpitContext@1@XZ"));
    device=reinterpret_cast<Device>(GetProcAddress(common,"?get_wide_device@ccCockpitContext@cockpit@@QEAAPEAVavDevice@2@I@Z"));
    indicator_context=reinterpret_cast<Getter>(GetProcAddress(common,"?get_context@ccContextRelatedObject@cockpit@@QEBAPEAVccCockpitContext@2@XZ"));
    controller=reinterpret_cast<Getter>(GetProcAddress(common,"?get_controller@ccDrawable@cockpit@@QEAAPEAVavDevice@2@XZ"));
    clock=reinterpret_cast<Clock>(GetProcAddress(world,"?GetModelTime@wTime@@SANXZ"));
    camera=reinterpret_cast<Camera>(GetProcAddress(graphics,"??0Camera@Graphics@@QEAA@W4Type@01@@Z"));
    targets=reinterpret_cast<std::uintptr_t>(GetProcAddress(common,"?render_targets@ccDrawable@cockpit@@2V?$vector@PEAVccDrawable@cockpit@@V?$allocator@PEAVccDrawable@cockpit@@@ed@@@ed@@A"));
    table=reinterpret_cast<std::uintptr_t>(GetProcAddress(common,"??_7ccIndicator@cockpit@@6BccContextRelatedObject@1@@"));
    ready=exports_ready();
    reason=ready?0:3;
  }
} api;
std::mutex view_mutex;
View view;
View map_reference;
std::uint64_t reference_generation{}; // Protected with map_reference by view_mutex.
GroundVideoView::Aircraft aircraft;
std::array<double,3> previous_probe{};
double probe_erase{};
std::atomic<void *> owned{};
std::array<std::uintptr_t,method_count+1> clone{}; // Keep the original MSVC RTTI entry.
std::atomic<std::uint64_t> frames{};
std::atomic<std::uint64_t> condition_calls{},condition_accepted{},camera_calls{},camera_accepted{},parameter_calls{},parameter_rejected{},erase_calls{},preset_calls{};
std::atomic<std::uint64_t> image_captures{},rbm_restarts{},dbs_requests{};
std::atomic<bool> gpu_probe_enabled{};
std::atomic<std::uint64_t> epoch{1};
// Opt-in observations only. Clock acceptance is unchanged until native
// evidence establishes whether render/simulation snapshots are out of order.
std::atomic<bool> timing_enabled{};
std::atomic<std::uint64_t> clock_checks{}, future_rejects{}, stale_rejects{};
std::atomic<double> last_clock_delta_ms{}, max_clock_lead_ms{};
std::atomic<double> rendered_n{}, rendered_u{}, rendered_e{}, motion_age_ms{}, rendered_heading{};
GroundVideoView::Guard guard;
struct ImageState {
  GroundVideoView::ImageCycle cycle;
  std::uint64_t generation{}, serial{};
  void* owner{};
  bool refresh{};
} image_state; // Protected by view_mutex; camera getters may use different threads.
using Release = void(__fastcall *)(void *);
using Destroy = void *(__fastcall *)(void *,unsigned);
Release original_release{}; Destroy original_destroy{};
View snapshot() { std::lock_guard<std::mutex> lock(view_mutex); return view; }
bool live(const View &v) {
  if (!api.clock) return false;
  const double now=api.clock();
  if (timing_enabled.load() && v.enabled && std::isfinite(now) && std::isfinite(v.stamp)) {
    const double delta=now-v.stamp;
    clock_checks.fetch_add(1,std::memory_order_relaxed);
    last_clock_delta_ms.store(delta*1000,std::memory_order_relaxed);
    if (delta<0) {
      future_rejects.fetch_add(1,std::memory_order_relaxed);
      const double lead=-delta*1000;
      double previous=max_clock_lead_ms.load(std::memory_order_relaxed);
      while (lead>previous && !max_clock_lead_ms.compare_exchange_weak(previous,lead,std::memory_order_relaxed)) {}
    } else if (delta>.5) stale_rejects.fetch_add(1,std::memory_order_relaxed);
  }
  return GroundVideoView::prepare(v,now).accepted;
}
struct RenderFrame {
  alignas(16) std::array<std::byte,784> camera{};
  View current{};
  std::uint64_t image_serial{};
  int direction=1;
  bool constructed{}, preset{}, valid{};
  int preset_key=-1;
  double erased = -1;
  std::uint64_t generation{};
  void *owner{};
};
thread_local RenderFrame render;
void withdraw_callbacks() {
  guard.verify(false);
  epoch.fetch_add(1);
}
void restore(void *object) {
  auto p=reinterpret_cast<std::uintptr_t>(object); std::uintptr_t actual{};
  if (object && load(p,actual) && actual==reinterpret_cast<std::uintptr_t>(clone.data()+1) && writable(p,sizeof(void *)))
    InterlockedCompareExchangePointer(reinterpret_cast<void *volatile *>(object),reinterpret_cast<void *>(api.table),clone.data()+1);
  void *expected=object; owned.compare_exchange_strong(expected,nullptr);
}
void __fastcall release(void *object) {
  if (object==owned.load()) withdraw_callbacks();
  restore(object);
  if (original_release) original_release(object);
}
void *__fastcall destroy(void *object,unsigned flags) {
  if (object==owned.load()) withdraw_callbacks();
  restore(object);
  return original_destroy?original_destroy(object,flags):object;
}
int __fastcall condition(void *object) {
  ++condition_calls;
  const bool accepted=guard.available() && object==owned.load() && live(snapshot());
  if(accepted)++condition_accepted;
  return accepted?3:0; // TVScreenCondition radar -> DCSMFD mode11.
}
bool __fastcall always(void *object) { return condition(object)!=0; }
GroundVideoView::Prepared capture_image(void *object,const View& control,
                                       const GroundVideoView::Aircraft& motion,double now) {
  const bool current=GroundVideoView::prepare(control,now).accepted && object==owned.load() && guard.available();
  if (!current) return {};
  if (render.owner!=object || render.generation!=epoch.load()) {
    // Camera has a native constructor and remains alive on this render
    // thread. Reset only our transaction state, never overwrite that object.
    render.preset=false;render.preset_key=-1;
    render.erased=-1;
    render.owner=object;render.generation=epoch.load();
  }
  const auto candidate=GroundVideoView::antenna(control,motion,now);
  std::lock_guard<std::mutex> lock(view_mutex);
  if (render.generation!=epoch.load() || object!=owned.load() || !guard.available()) return {};
  if (image_state.owner!=object || image_state.generation!=render.generation) {
    image_state={};image_state.owner=object;image_state.generation=render.generation;
  }
  if (GroundVideoView::prepare(candidate,now).accepted && image_state.cycle.capture(candidate)) {
    image_state.refresh=true;++image_state.serial;++image_captures;
    map_reference=candidate;
    reference_generation=render.generation;
    map_reference.heading=candidate.heading+candidate.scan_center;map_reference.scan_center=0;
  }
  if (!image_state.cycle.available()) return {};
  // An image retained between RF updates keeps its actual capture epoch.
  // Fresh control/ownership admits its display, never a fresh sensor report.
  const auto& image=image_state.cycle.image();
  render.image_serial=image_state.serial;render.direction=image_state.cycle.direction();
  return GroundVideoView::prepare(image,image.stamp,current);
}
const void *__fastcall camera(void *object) {
  ++camera_calls;
  const double now=api.clock?api.clock():-1;
  View control; GroundVideoView::Aircraft motion;
  {std::lock_guard<std::mutex> lock(view_mutex);control=view;motion=aircraft;}
  const auto safe=capture_image(object,control,motion,now);
  if(safe.accepted)++camera_accepted;
  render.current=safe.view; render.valid=safe.accepted;
  if(safe.accepted) motion_age_ms=(now-motion.stamp)*1000;
  if (!render.constructed) { api.camera(render.camera.data(),0); render.constructed=true; }
  const auto p=GroundVideoView::position(safe);
  for (unsigned row=0;row<4;++row)
    std::memcpy(render.camera.data()+560+16*row,p.data()+3*row,3*sizeof(float));
  const auto projection=GroundVideoView::projection(safe);
  std::memcpy(render.camera.data()+688,&projection,sizeof(projection));
  render.camera[776]=std::byte{1}; // Camera matrices/clip volume dirty, as common ccIndicator does.
  return render.camera.data();
}
void *__fastcall point(void *object,void *out) {
  // camera(), point(), and parameters() describe ONE captured frame, even if
  // a physics update occurs between these calls.
  const bool accepted=guard.available() && render.valid && object==owned.load() &&
      object==render.owner && render.generation==epoch.load() && live(snapshot());
  const auto p=GroundVideoView::point({accepted?render.current:View{},accepted});
  if (out) std::memcpy(out,p.data(),sizeof(p));
  return out;
}
bool submit_parameters(void* object,std::array<GroundVideoView::Param,18>& params,std::uintptr_t data,bool& refresh) {
  std::lock_guard<std::mutex> lock(view_mutex);
  if (!guard.available() || object!=owned.load() || object!=render.owner
      || render.generation!=epoch.load() || image_state.generation!=render.generation
      || image_state.serial!=render.image_serial) return false;
  refresh=image_state.refresh;
  params[0].number=static_cast<float>(render.direction);
  params[5].bits=refresh&&render.current.expansion>0?1:0;
  std::memcpy(reinterpret_cast<void *>(data),params.data(),sizeof(params));
  image_state.refresh=false;
  image_state.cycle.submitted();
  return true;
}
void __fastcall parameters(void *object,void *buffer) {
  ++parameter_calls;
  if (!guard.available() || object!=owned.load() || !render.valid || object!=render.owner || render.generation!=epoch.load() || !live(snapshot())) {++parameter_rejected;return;}
  // Visualizer allocates/zeros 18 DynamicParam unions before this callback.
  // Never replace its allocator, pointer, count or capacity.
  auto b=reinterpret_cast<std::uintptr_t>(buffer);std::uintptr_t data{};int count{};
  if (!load(b,data) || !load(b+8,count) || count<18 || count>1024 || !writable(data,18*8)) {
    guard.fail(7); render.valid=false; return;
  }
  const int key=render.current.mode*10+render.current.expansion;
  auto params=GroundVideoView::parameters(render.current,render.erased!=render.current.erase_sequence,!render.preset||render.preset_key!=key);
  bool refresh{};
  // DynamicParam5 requests DBS work. MAP cache renewal uses parameter0;
  // retain one captured camera/point/parameter set for the entire pipeline.
  if (!submit_parameters(object,params,data,refresh)) {++parameter_rejected;return;}
  if(params[5].bits)++dbs_requests;
  if(refresh && render.current.expansion==0)++rbm_restarts;
  render.preset_key=key;
  if(params[6].bits)++erase_calls;
  if(params[7].text)++preset_calls;
  render.erased=render.current.erase_sequence;render.preset=true;
  rendered_n=render.current.north;rendered_u=render.current.altitude;rendered_e=render.current.east;
  rendered_heading=render.current.heading;
  frames.fetch_add(1,std::memory_order_relaxed);
  if(gpu_probe_enabled.load()){
    View ref;{std::lock_guard<std::mutex>lock(view_mutex);ref=map_reference;}
    const double shift=ref.expansion?ref.center_m-ref.span_m/2:0;
    GroundVideoProbe::request({api.clock(),ref.north+shift*std::cos(ref.heading),ref.east+shift*std::sin(ref.heading),
      ref.heading,ref.expansion?ref.span_m/1852:ref.range_nm});
  }
}
bool install(void *context) {
  std::uintptr_t begin{},end{},object{},actual{}; int target{};
  if (!load(api.targets,begin) || !load(api.targets+8,end) || end<begin ||
      end-begin<8*(render_target+1) || end-begin>32*8 ||
      !load(begin+8*render_target,object) || !readable(object,1536) || !load(object,actual)) return false;
  if (!load(object+1136,target)) { api.reason=4;return false; }
  const GroundVideoView::Binding expected{reinterpret_cast<std::uintptr_t>(context),
      reinterpret_cast<std::uintptr_t>(api.device(context,controller_device)),render_target};
  const auto read_binding=[&] {
    return GroundVideoView::Binding{
      reinterpret_cast<std::uintptr_t>(api.indicator_context(reinterpret_cast<void *>(object))),
      reinterpret_cast<std::uintptr_t>(api.controller(reinterpret_cast<void *>(object))),
      static_cast<unsigned>(target)};
  };
  if (!GroundVideoView::verify_binding(actual,api.table,reinterpret_cast<std::uintptr_t>(clone.data()+1),
      object==reinterpret_cast<std::uintptr_t>(owned.load()),expected,read_binding)) {
    api.reason=4;return false;
  }
  if (object==reinterpret_cast<std::uintptr_t>(owned.load()) && actual==reinterpret_cast<std::uintptr_t>(clone.data()+1)) {
    api.reason=0;return true;
  }
  if (actual!=api.table || !writable(object,8) || !readable(api.table-8,sizeof(clone))) {
    api.reason=4;return false;
  }
  if (owned.load()) return false;
  std::memcpy(clone.data(),reinterpret_cast<void *>(api.table-8),sizeof(clone));
  original_destroy=reinterpret_cast<Destroy>(clone[2]);original_release=reinterpret_cast<Release>(clone[5]);
  clone[2]=reinterpret_cast<std::uintptr_t>(&destroy);clone[5]=reinterpret_cast<std::uintptr_t>(&release);
  clone[22]=reinterpret_cast<std::uintptr_t>(&camera);clone[23]=reinterpret_cast<std::uintptr_t>(&point);
  clone[24]=reinterpret_cast<std::uintptr_t>(&condition);clone[25]=reinterpret_cast<std::uintptr_t>(&parameters);
  clone[26]=reinterpret_cast<std::uintptr_t>(&always);
  owned=reinterpret_cast<void *>(object);
  auto previous=InterlockedCompareExchangePointer(reinterpret_cast<void *volatile *>(object),clone.data()+1,reinterpret_cast<void *>(api.table));
  if (previous!=reinterpret_cast<void *>(api.table)) { owned=nullptr;return false; }
  epoch.fetch_add(1);
  api.reason=0;return true;
}
std::map<std::string,void *,std::less<>> handles;
const EDPARAM* parameter_owner{};
std::uint64_t parameter_epoch{};
void* parameter(EDPARAM& p,std::string_view name) {
  if (parameter_owner != &p || parameter_epoch != p.epoch()) {
    handles.clear();parameter_owner=&p;parameter_epoch=p.epoch();
  }
  auto found=handles.find(name);
  if (found==handles.end()) found=handles.try_emplace(std::string(name),nullptr).first;
  auto& handle=found->second;
  if (!handle) handle=p.getParamHandle(found->first.c_str());
  return handle;
}
double get(EDPARAM &p,std::string_view name) {
  double value = std::numeric_limits<double>::quiet_NaN();
  if (!p.getParamNumber(parameter(p,name),value)) return std::numeric_limits<double>::quiet_NaN();
  return value;
}
void put(EDPARAM &p,const std::string &name,double value) {
  const bool dispatched=p.setParamNumber(parameter(p,name),value);
  (void)dispatched; // Telemetry dispatch grants no rendering or target authority.
}
bool integer(double raw,int minimum,int maximum,int& result) {
  if (!std::isfinite(raw) || raw<minimum || raw>maximum || raw!=std::floor(raw)) return false;
  result=static_cast<int>(raw);
  return true;
}
bool flag(EDPARAM& p,const char* name,bool& valid) {
  const double raw=get(p,name);
  if (raw!=0 && raw!=1) valid=false;
  return raw==1;
}
bool committed(double sequence) {
  return std::isfinite(sequence) && sequence>=2 && sequence<=16777214
      && std::fmod(sequence,2)==0;
}
bool source_epoch_valid(double value) {
  return std::isfinite(value) && value>=1 && value<=16777215
      && value==std::floor(value);
}
bool source_recent(double now,double stamp) {
  return std::isfinite(now) && std::isfinite(stamp) && now>=stamp && now-stamp<=.5;
}
struct Tracking { bool current{}, active{};double source_epoch{},stamp{},sequence{}; };
Tracking tracking(EDPARAM& p,double now) {
  const auto context=p.epoch();
  const double sequence=get(p,"F22_AG_NATIVE_SEQUENCE");
  if (!committed(sequence)) return {};
  const double schema=get(p,"F22_AG_NATIVE_SCHEMA");
  const double source_epoch=get(p,"F22_AG_NATIVE_SOURCE_EPOCH");
  const double stamp=get(p,"F22_AG_GMT_LAST_TIME");
  bool valid=true;
  const bool ready=flag(p,"F22_AG_GMT_READY",valid);
  const bool selected=flag(p,"F22_AG_NATIVE_TRACK_VALID",valid);
  const bool acquiring=flag(p,"F22_AG_NATIVE_TRACK_ACQUIRING",valid);
  if (schema!=1 || !source_epoch_valid(source_epoch) || !source_recent(now,stamp)) return {};
  if (source_epoch!=get(p,"F22_AG_NATIVE_SOURCE_EPOCH")
      || sequence!=get(p,"F22_AG_NATIVE_SEQUENCE") || context!=p.epoch()) return {};
  // A coherent unavailable source still identifies its epoch. Track flag
  // conversion failure withdraws tracking, not independent scene imagery.
  return {valid && ready,valid && ready && (selected || acquiring),source_epoch,stamp,sequence};
}
struct ControlHeader {
  double sequence{},schema{},source_epoch{},stamp{};
  std::uint64_t context{};
};
const EDPARAM* control_owner{};
std::uint64_t control_context{},control_source_epoch{};
void retire_image_locked() {
  epoch.fetch_add(1);
  view={};map_reference={};reference_generation=0;image_state={};
}
void observe_control_context(EDPARAM& p) {
  std::lock_guard<std::mutex> lock(view_mutex);
  if (control_owner==&p && control_context==p.epoch()) return;
  retire_image_locked();
  control_owner=&p;control_context=p.epoch();control_source_epoch=0;
}
void observe_source_epoch(double source_epoch) {
  if (!source_epoch_valid(source_epoch)) return;
  const auto source=static_cast<std::uint64_t>(source_epoch);
  std::lock_guard<std::mutex> lock(view_mutex);
  if (control_source_epoch && control_source_epoch!=source) retire_image_locked();
  control_source_epoch=source;
}
ControlHeader control_header(EDPARAM& p,double now) {
  ControlHeader header;
  header.context=p.epoch();
  header.sequence=get(p,"F22_AG_NATIVE_CONTROL_SEQUENCE");
  if (!committed(header.sequence)) return {};
  header.schema=get(p,"F22_AG_NATIVE_CONTROL_SCHEMA");
  header.source_epoch=get(p,"F22_AG_NATIVE_CONTROL_EPOCH");
  header.stamp=get(p,"F22_AG_NATIVE_CONTROL_TIME");
  if (header.schema!=1 || !source_epoch_valid(header.source_epoch)
      || !source_recent(now,header.stamp)) return {};
  return header;
}
bool control_current(EDPARAM& p,const ControlHeader& header,const Tracking& observed) {
  const double sequence=get(p,"F22_AG_NATIVE_CONTROL_SEQUENCE");
  const double schema=get(p,"F22_AG_NATIVE_CONTROL_SCHEMA");
  const double source_epoch=get(p,"F22_AG_NATIVE_CONTROL_EPOCH");
  const double stamp=get(p,"F22_AG_NATIVE_CONTROL_TIME");
  const double source_present=get(p,source_marker);
  const double native_sequence=get(p,"F22_AG_NATIVE_SEQUENCE");
  const double native_epoch=get(p,"F22_AG_NATIVE_SOURCE_EPOCH");
  return header.sequence==sequence && header.schema==schema
      && header.source_epoch==source_epoch && header.stamp==stamp
      && observed.source_epoch==header.source_epoch && observed.sequence==native_sequence
      && observed.source_epoch==native_epoch && source_present==1 && header.context==p.epoch();
}
bool read_probe(EDPARAM& p,std::array<double,3>& probe) {
  probe={get(p,"F22_AG_VIDEO_PROBE_FORWARD_M"),get(p,"F22_AG_VIDEO_PROBE_RIGHT_M"),get(p,"F22_AG_VIDEO_PROBE_UP_M")};
  for (double value:probe) if (!std::isfinite(value) || std::abs(value)>100) return false;
  return true;
}
void apply_probe(const std::array<double,3>& probe,View& next) {
  // Controlled self-occlusion experiment. These default-zero diagnostic
  // offsets affect only this renderer view, never ownship or sensor truth.
  const double erase=probe_erase+(probe!=previous_probe?1:0);
  next.probe_forward=probe[0];next.probe_right=probe[1];next.probe_up=probe[2];
  next.north+=std::cos(next.heading)*probe[0]-std::sin(next.heading)*probe[1];
  next.east+=std::sin(next.heading)*probe[0]+std::cos(next.heading)*probe[1];
  next.altitude+=probe[2];next.erase_sequence+=erase*1000000;
}
void finish_probe(View& next,double now,const std::array<double,3>& probe,bool valid_probe) {
  if (valid_probe) apply_probe(probe,next);
  if (GroundVideoView::prepare(next,now).accepted && probe!=previous_probe) {
    previous_probe=probe;++probe_erase;
  }
}
bool video_requested(EDPARAM& p,bool ready,bool& valid) {
  const bool source_present=flag(p,source_marker,valid);
  const bool enabled=flag(p,"F22_AG_VIDEO_ENABLE",valid);
  const bool supply=flag(p,"MAIN_POWER",valid);
  const bool radar_power=flag(p,"RADAR_PWR",valid);
  const double master_mode=get(p,"HUD_MODE");
  if (!std::isfinite(master_mode)) valid=false;
  return ready && source_present && enabled && master_mode==7 && supply && radar_power;
}
View read_view(EDPARAM& p,bool ready,bool& malformed) {
  malformed=true;
  observe_control_context(p);
  const double now=api.clock?api.clock():-1;
  const auto header=control_header(p,now);
  if (!committed(header.sequence)) {
    observe_control_context(p);
    return {};
  }
  View next;
  bool geometry_flags_valid=true;
  next.enabled=video_requested(p,ready,geometry_flags_valid);
  const bool frozen=flag(p,"F22_AG_VIDEO_FROZEN",geometry_flags_valid);
  const bool hold=flag(p,"F22_AG_VIDEO_HOLD",geometry_flags_valid);
  next.frozen=frozen||hold;
  next.stamp=get(p,"F22_AG_VIDEO_TIME");
  next.north=get(p,"F22_AG_VIDEO_NORTH"); next.altitude=get(p,"F22_AG_VIDEO_ALTITUDE");
  next.east=get(p,"F22_AG_VIDEO_EAST"); next.heading=get(p,"F22_AG_VIDEO_HEADING");
  next.range_nm=get(p,"F22_AG_RADAR_RANGE_NM");next.width_deg=get(p,"F22_AG_VIDEO_FOV_DEG");
  next.collection=get(p,"F22_AG_VIDEO_COLLECTION");
  next.scan_direction=get(p,"F22_AG_VIDEO_SCAN_DIRECTION");next.scan_fraction=get(p,"F22_AG_VIDEO_SCAN_FRACTION");
  next.gain=get(p,"F22_AG_VIDEO_GAIN");next.erase_sequence=get(p,"F22_AG_VIDEO_ERASE_SEQUENCE");
  const bool mode_valid=integer(get(p,"F22_AG_MODE"),1,7,next.mode);
  next.gmt=next.mode==2||next.mode==3||next.mode==4||next.mode==5;
  const bool expansion_valid=integer(get(p,"F22_AG_VIDEO_EXPANSION"),0,3,next.expansion);
  next.enabled=next.enabled && mode_valid && expansion_valid;
  next.center_m=get(p,"F22_AG_VIDEO_CENTER_M");next.span_m=get(p,"F22_AG_VIDEO_SPAN_M");
  next.antenna_offset=get(p,"F22_AG_VIDEO_ANTENNA_DEG")*GroundVideoView::pi/180;
  next.fast=flag(p,"F22_AG_FAST",geometry_flags_valid);next.fan=flag(p,"F22_AG_VIDEO_FAN",geometry_flags_valid);
  next.view_epoch=get(p,"F22_AG_VIDEO_EPOCH");
  next.stabilized=flag(p,"F22_AG_VIDEO_STABILIZED",geometry_flags_valid);
  next.patch_n=get(p,"F22_AG_VIDEO_PATCH_N");next.patch_u=get(p,"F22_AG_VIDEO_PATCH_U");next.patch_e=get(p,"F22_AG_VIDEO_PATCH_E");
  next.patch_az=get(p,"F22_AG_VIDEO_PATCH_AZ");next.patch_distance=get(p,"F22_AG_VIDEO_PATCH_DISTANCE");next.interleave=flag(p,"F22_AG_INTERLEAVE",geometry_flags_valid);
  const auto observed=tracking(p,now);
  observe_source_epoch(observed.source_epoch);
  next.tracking=observed.current && observed.active;
  next.scan_center=get(p,"F22_AG_RADAR_SCAN_CENTER_AZ_DEG")*GroundVideoView::pi/180;
  std::array<double,3> probe{};
  const bool probe_valid=read_probe(p,probe);
  if (!control_current(p,header,observed)) {
    observe_control_context(p);
    return {};
  }
  malformed=!mode_valid || !expansion_valid || !geometry_flags_valid || !probe_valid;
  next.enabled=next.enabled && !malformed;
  finish_probe(next,now,probe,probe_valid);
  return next;
}
void publish_reference(EDPARAM& p,bool frame_available) {
  View reference;std::uint64_t reference_epoch{};
  {std::lock_guard<std::mutex>lock(view_mutex);reference=map_reference;reference_epoch=reference_generation;}
  put(p,"F22_AG_VIDEO_REFERENCE_VALID",frame_available&&reference.enabled&&reference_epoch==epoch.load()?1:0);
  put(p,"F22_AG_VIDEO_REFERENCE_NORTH",reference.north);put(p,"F22_AG_VIDEO_REFERENCE_ALTITUDE",reference.altitude);
  put(p,"F22_AG_VIDEO_REFERENCE_EAST",reference.east);put(p,"F22_AG_VIDEO_REFERENCE_HEADING",reference.heading);
  put(p,"F22_AG_VIDEO_REFERENCE_TIME",reference.stamp);
  put(p,"F22_AG_VIDEO_REFERENCE_SCHEMA",2);
  put(p,"F22_AG_VIDEO_REFERENCE_RANGE_NM",reference.range_nm);
  put(p,"F22_AG_VIDEO_REFERENCE_MODE",reference.mode);
  put(p,"F22_AG_VIDEO_REFERENCE_EXPANSION",reference.expansion);
  put(p,"F22_AG_VIDEO_REFERENCE_CENTER_M",reference.center_m);put(p,"F22_AG_VIDEO_REFERENCE_SPAN_M",reference.span_m);
  put(p,"F22_AG_VIDEO_REFERENCE_EPOCH",reference.view_epoch);
}
int availability_reason(bool ready,bool malformed,bool enabled,bool frame_available) {
  if (guard.reason()) return guard.reason();
  if (!ready) return api.reason?api.reason:5;
  if (malformed || (enabled && !frame_available)) return 7;
  return 0;
}
}
void reset() {
  withdraw_callbacks();
  timing_enabled=false;
  gpu_probe_enabled=false;
  previous_probe={};probe_erase=0;
  {std::lock_guard<std::mutex> lock(view_mutex);view={};map_reference={};reference_generation=0;aircraft={};image_state={};
    control_owner=nullptr;control_context=0;control_source_epoch=0;}
  restore(owned.load());handles.clear();frames=0;guard.reset();
  clock_checks=0;future_rejects=0;stale_rejects=0;last_clock_delta_ms=0;max_clock_lead_ms=0;
  condition_calls=0;condition_accepted=0;camera_calls=0;camera_accepted=0;parameter_calls=0;parameter_rejected=0;erase_calls=0;preset_calls=0;
  image_captures=0;rbm_restarts=0;dbs_requests=0;
}
void set_aircraft(const AesaRadar::Pose* pose,double stamp) noexcept {
  GroundVideoView::Aircraft a;
  if (pose && std::isfinite(stamp)) {
    a={true,stamp,pose->position.n,pose->position.u,pose->position.e,
       pose->velocity.n,pose->velocity.u,pose->velocity.e,
       pose->forward.n,pose->forward.u,pose->forward.e};
    for (double value:{a.north,a.altitude,a.east,a.vn,a.vu,a.ve,a.fn,a.fu,a.fe})
      if (!std::isfinite(value)) a.valid=false;
    const double norm=std::hypot(a.fn,a.fu,a.fe);
    a.valid=a.valid && norm>.99 && norm<1.01;
  }
  std::lock_guard<std::mutex> lock(view_mutex);aircraft=a;
}
void update(EDPARAM &p) {
  api.initialize();
  bool ready=false;
  if (api.ready && get(p,source_marker)>.5) {
    auto context=api.context();
    if (context) ready=install(context);
  }
  guard.verify(ready);
  ready=guard.available();
  bool malformed=false;
  const View next=read_view(p,ready,malformed);
  put(p,"F22_AG_VIDEO_RENDER_NORTH",rendered_n);put(p,"F22_AG_VIDEO_RENDER_ALTITUDE",rendered_u);put(p,"F22_AG_VIDEO_RENDER_EAST",rendered_e);
  put(p,"F22_AG_VIDEO_RENDER_HEADING",rendered_heading);put(p,"F22_AG_VIDEO_MOTION_AGE_MS",motion_age_ms);
  put(p,"F22_AG_VIDEO_PROBE_EPOCH",probe_erase);
  timing_enabled=get(p,"F22_AG_VIDEO_TIMING_DIAGNOSTIC")>.5;
  gpu_probe_enabled=get(p,"F22_AG_VIDEO_GPU_DIAGNOSTIC")>.5;
  int probe_target=0;
  const bool probe_target_valid=integer(get(p,"F22_AG_VIDEO_PROBE_TEXTURE"),0,6,probe_target);
  gpu_probe_enabled=gpu_probe_enabled.load() && probe_target_valid;
  GroundVideoProbe::selected_target=probe_target;
  const double now=api.clock?api.clock():-1;
  const bool frame_available=GroundVideoView::prepare(next,now).accepted;
  {std::lock_guard<std::mutex> lock(view_mutex);view=next;}
  publish_reference(p,frame_available);
  put(p,"F22_AG_VIDEO_READY",ready?1:0);
  put(p,"F22_AG_VIDEO_REASON",availability_reason(ready,malformed,next.enabled,frame_available));
  put(p,"F22_AG_VIDEO_FRAMES",static_cast<double>(frames.load()));
  put(p,"F22_AG_VIDEO_CLOCK_CHECKS",static_cast<double>(clock_checks.load()));
  put(p,"F22_AG_VIDEO_FUTURE_REJECTS",static_cast<double>(future_rejects.load()));
  put(p,"F22_AG_VIDEO_STALE_REJECTS",static_cast<double>(stale_rejects.load()));
  put(p,"F22_AG_VIDEO_CLOCK_DELTA_MS",last_clock_delta_ms.load());
  put(p,"F22_AG_VIDEO_MAX_LEAD_MS",max_clock_lead_ms.load());
  for(const auto &item:{std::pair{"CONDITION_CALLS",condition_calls.load()}, {"CONDITION_ACCEPTED",condition_accepted.load()},
      {"CAMERA_CALLS",camera_calls.load()},{"CAMERA_ACCEPTED",camera_accepted.load()},
      {"PARAMETER_CALLS",parameter_calls.load()},{"PARAMETER_REJECTED",parameter_rejected.load()},
      {"ERASE_CALLS",erase_calls.load()},{"PRESET_CALLS",preset_calls.load()},
      {"IMAGE_CAPTURES",image_captures.load()},{"RBM_RESTARTS",rbm_restarts.load()},{"DBS_REQUESTS",dbs_requests.load()},
      {"GPU_OBSERVATIONS",GroundVideoProbe::observations.load()},{"GPU_CHANGES",GroundVideoProbe::changes.load()}})
    put(p,std::string("F22_AG_VIDEO_")+item.first,static_cast<double>(item.second));
  put(p,"F22_AG_VIDEO_GPU_STATUS",GroundVideoProbe::status.load());
  put(p,"F22_AG_VIDEO_GPU_TARGET",GroundVideoProbe::observed_target.load());
  put(p,"F22_AG_VIDEO_GPU_RENDER_THREAD",GroundVideoProbe::render_thread.load());
  put(p,"F22_AG_VIDEO_GPU_WIDTH",GroundVideoProbe::width.load());put(p,"F22_AG_VIDEO_GPU_HEIGHT",GroundVideoProbe::height.load());
  put(p,"F22_AG_VIDEO_GPU_FORMAT",GroundVideoProbe::format.load());put(p,"F22_AG_VIDEO_GPU_SAMPLES",GroundVideoProbe::samples.load());
  put(p,"F22_AG_VIDEO_GPU_NONZERO",GroundVideoProbe::nonzero.load());put(p,"F22_AG_VIDEO_GPU_MIN",GroundVideoProbe::minimum.load());
  put(p,"F22_AG_VIDEO_GPU_MAX",GroundVideoProbe::maximum.load());put(p,"F22_AG_VIDEO_GPU_MEAN",GroundVideoProbe::mean.load());
  put(p,"F22_AG_VIDEO_GPU_VARIANCE",GroundVideoProbe::variance.load());
  put(p,"F22_AG_VIDEO_GPU_CAPTURE_TIME",GroundVideoProbe::observed_time);
  for(unsigned i=0;i<3;++i) {
    const auto prefix=std::string("F22_AG_VIDEO_GPU_")+"RGB"[i]+"_";
    put(p,prefix+"NONZERO",GroundVideoProbe::channel_nonzero[i]);put(p,prefix+"MEAN",GroundVideoProbe::channel_mean[i]);put(p,prefix+"MAX",GroundVideoProbe::channel_max[i]);
  }
  {
    static std::string published;
    std::lock_guard<std::mutex> hold(GroundVideoProbe::resources_mutex);
    if(published!=GroundVideoProbe::resources) {
      published=GroundVideoProbe::resources;
      p.setParamString(p.getParamHandle("F22_AG_VIDEO_GPU_RESOURCES"),published.c_str());
    }
    static std::string published_grid;
    if(published_grid!=GroundVideoProbe::grid){published_grid=GroundVideoProbe::grid;
      p.setParamString(p.getParamHandle("F22_AG_VIDEO_GPU_GRID"),published_grid.c_str());}
  }
}
}
