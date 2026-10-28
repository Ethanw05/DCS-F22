// GPL-3.0-or-later. No module-specific radar, renderer patch, scene query or
// copied shader. A dedicated owned ccIndicator supplies the shared engine's
// existing radar-video camera/parameters through its normal virtual interface.
#include "NativeGroundVideo.h"
#include "GroundVideoView.h"
#include "GroundVideoProbe.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <atomic>
#include <cstring>
#include <map>
#include <mutex>
#include <string>
#include <tuple>
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
bool version(HMODULE module, DWORD stamp, DWORD size) {
  IMAGE_DOS_HEADER dos{}; IMAGE_NT_HEADERS64 pe{};
  auto b = reinterpret_cast<std::uintptr_t>(module);
  return module && load(b,dos) && dos.e_magic == IMAGE_DOS_SIGNATURE && dos.e_lfanew >= 0 &&
      load(b+dos.e_lfanew,pe) && pe.Signature == IMAGE_NT_SIGNATURE &&
      pe.FileHeader.TimeDateStamp == stamp && pe.OptionalHeader.SizeOfImage == size;
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
  void initialize() {
    if (ready || incompatible) return;
    auto common=GetModuleHandleW(L"CockpitBase.dll"), world=GetModuleHandleW(L"World.dll"),
        graphics=GetModuleHandleW(L"GraphicsVista.dll");
    if (!common || !world || !graphics) return;
    for (const auto &v : {std::tuple{L"CockpitBase.dll",0x6ac12468u,0x59a000u},
                         std::tuple{L"Visualizer.dll",0x6ac12454u,0x312000u},
                         std::tuple{L"SceneRenderer.dll",0x6aae1e3eu,0x70000u},
                         std::tuple{L"enlight.dll",0x6aae1e38u,0xa9000u},
                         std::tuple{L"GraphicsVista.dll",0x6aae1df2u,0x62000u}}) {
      auto m=GetModuleHandleW(std::get<0>(v));
      if (!m) return;
      if (!version(m,std::get<1>(v),std::get<2>(v))) {
        incompatible=true; reason=2; return;
      }
    }
    context=reinterpret_cast<Context>(GetProcAddress(common,"?binding_context@cockpit@@YAPEAVccCockpitContext@1@XZ"));
    device=reinterpret_cast<Device>(GetProcAddress(common,"?get_wide_device@ccCockpitContext@cockpit@@QEAAPEAVavDevice@2@I@Z"));
    indicator_context=reinterpret_cast<Getter>(GetProcAddress(common,"?get_context@ccContextRelatedObject@cockpit@@QEBAPEAVccCockpitContext@2@XZ"));
    controller=reinterpret_cast<Getter>(GetProcAddress(common,"?get_controller@ccDrawable@cockpit@@QEAAPEAVavDevice@2@XZ"));
    clock=reinterpret_cast<Clock>(GetProcAddress(world,"?GetModelTime@wTime@@SANXZ"));
    camera=reinterpret_cast<Camera>(GetProcAddress(graphics,"??0Camera@Graphics@@QEAA@W4Type@01@@Z"));
    targets=reinterpret_cast<std::uintptr_t>(GetProcAddress(common,"?render_targets@ccDrawable@cockpit@@2V?$vector@PEAVccDrawable@cockpit@@V?$allocator@PEAVccDrawable@cockpit@@@ed@@@ed@@A"));
    table=reinterpret_cast<std::uintptr_t>(GetProcAddress(common,"??_7ccIndicator@cockpit@@6BccContextRelatedObject@1@@"));
    ready=context && device && indicator_context && controller && clock && camera && targets && table;
    reason=ready?0:3;
  }
} api;
std::mutex view_mutex;
View view;
View map_reference;
GroundVideoView::Aircraft aircraft;
std::array<double,3> previous_probe{};
double probe_erase{};
std::atomic<void *> owned{};
std::array<std::uintptr_t,method_count+1> clone{}; // Keep the original MSVC RTTI entry.
std::atomic<std::uint64_t> frames{};
std::atomic<std::uint64_t> condition_calls{},condition_accepted{},camera_calls{},camera_accepted{},parameter_calls{},parameter_rejected{},erase_calls{},preset_calls{};
std::atomic<bool> gpu_probe_enabled{};
std::atomic<std::uint64_t> epoch{1};
// Opt-in observations only. Clock acceptance is unchanged until native
// evidence establishes whether render/simulation snapshots are out of order.
std::atomic<bool> timing_enabled{};
std::atomic<std::uint64_t> clock_checks{}, future_rejects{}, stale_rejects{};
std::atomic<double> last_clock_delta_ms{}, max_clock_lead_ms{};
std::atomic<double> rendered_n{}, rendered_u{}, rendered_e{}, motion_age_ms{}, rendered_heading{};
GroundVideoView::Guard guard;
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
  return GroundVideoView::valid(v,now);
}
struct RenderFrame {
  alignas(16) std::array<std::byte,784> camera{};
  View current{};
  bool constructed{}, preset{}, valid{},refresh{};
  int preset_key=-1;
  double erased = -1;
  View last{};
  bool have_last{};
  std::uint64_t generation{};
  void *owner{};
};
thread_local RenderFrame render;
void restore(void *object) {
  auto p=reinterpret_cast<std::uintptr_t>(object); std::uintptr_t actual{};
  if (object && load(p,actual) && actual==reinterpret_cast<std::uintptr_t>(clone.data()+1) && writable(p,sizeof(void *)))
    InterlockedCompareExchangePointer(reinterpret_cast<void *volatile *>(object),reinterpret_cast<void *>(api.table),clone.data()+1);
  void *expected=object; owned.compare_exchange_strong(expected,nullptr);
}
void __fastcall release(void *object) {
  restore(object);
  if (original_release) original_release(object);
}
void *__fastcall destroy(void *object,unsigned flags) {
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
const void *__fastcall camera(void *object) {
  ++camera_calls;
  const double now=api.clock?api.clock():-1;
  View control; GroundVideoView::Aircraft motion;
  {std::lock_guard<std::mutex> lock(view_mutex);control=view;motion=aircraft;}
  const bool control_live=GroundVideoView::valid(control,now);
  auto current=GroundVideoView::antenna(control,motion,now);
  // Freeze the actual last native camera, never the lagging cockpit pose.
  if(control.frozen && render.have_last && render.owner==object && render.generation==epoch.load()) {
    current.north=render.last.north;current.altitude=render.last.altitude;
    current.east=render.last.east;current.heading=render.last.heading;
    current.antenna_elevation=render.last.antenna_elevation;current.scan_center=render.last.scan_center;
    current.center_m=render.last.center_m;current.span_m=render.last.span_m;current.width_deg=render.last.width_deg;
  }
  const auto safe=GroundVideoView::prepare(current,now,control_live && object==owned.load() && guard.available());
  if(safe.accepted)++camera_accepted;
  render.current=safe.view; render.valid=safe.accepted;
  if(safe.accepted) {
    rendered_n=current.north;rendered_u=current.altitude;rendered_e=current.east;
    rendered_heading=current.heading;motion_age_ms=(now-motion.stamp)*1000;
  }
  if (!render.constructed) { api.camera(render.camera.data(),0); render.constructed=true; }
  if (render.owner!=object || render.generation!=epoch.load()) {
    render.owner=object;render.generation=epoch.load();render.preset=false;render.erased=-1;
    render.have_last=false;
  }
  if(safe.accepted) {
    // Refresh on completed partial RF work. Camera motion and UI changes
    // cannot independently manufacture a new image observation.
    const auto&v=safe.view;
    if(GroundVideoView::refresh(v,render.last,render.have_last)) {
      render.refresh=true;
      std::lock_guard<std::mutex>lock(view_mutex);map_reference=v;
      map_reference.heading=v.heading+v.scan_center;map_reference.scan_center=0;
    }
    render.last=v;render.have_last=true;
  }
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
  const bool accepted=render.valid && object==render.owner && render.generation==epoch.load();
  const auto p=GroundVideoView::point({accepted?render.current:View{},accepted});
  if (out) std::memcpy(out,p.data(),sizeof(p));
  return out;
}
void __fastcall parameters(void *object,void *buffer) {
  ++parameter_calls;
  if (!guard.available() || object!=owned.load() || !render.valid || object!=render.owner || render.generation!=epoch.load() || !live(render.current)) {++parameter_rejected;return;}
  // Visualizer allocates/zeros 18 DynamicParam unions before this callback.
  // Never replace its allocator, pointer, count or capacity.
  auto b=reinterpret_cast<std::uintptr_t>(buffer);std::uintptr_t data{};int count{};
  if (!load(b,data) || !load(b+8,count) || count<18 || count>1024 || !writable(data,18*8)) {
    guard.fail(7); render.valid=false; return;
  }
  const int key=render.current.mode*10+render.current.expansion;
  auto params=GroundVideoView::parameters(render.current,render.erased!=render.current.erase_sequence,!render.preset||render.preset_key!=key);
  params[5].bits=render.refresh&&!render.current.frozen?1:0;render.refresh=false;render.preset_key=key;
  std::memcpy(reinterpret_cast<void *>(data),params.data(),sizeof(params));
  if(params[6].bits)++erase_calls;
  if(params[7].text)++preset_calls;
  render.erased=render.current.erase_sequence;render.preset=true;
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
std::map<std::string,void *> handles;
double get(EDPARAM &p,const std::string &name) {
  auto &h=handles[name];if (!h) h=p.getParamHandle(name.c_str());return p.getParamNumber(h);
}
void put(EDPARAM &p,const std::string &name,double value) {
  auto &h=handles[name];if (!h) h=p.getParamHandle(name.c_str());p.setParamNumber(h,value);
}
}
void reset() {
  timing_enabled=false;
  gpu_probe_enabled=false;
  previous_probe={};probe_erase=0;
  {std::lock_guard<std::mutex> lock(view_mutex);view={};map_reference={};aircraft={};}
  restore(owned.load());handles.clear();frames=0;guard.reset();epoch.fetch_add(1);
  clock_checks=0;future_rejects=0;stale_rejects=0;last_clock_delta_ms=0;max_clock_lead_ms=0;
  condition_calls=0;condition_accepted=0;camera_calls=0;camera_accepted=0;parameter_calls=0;parameter_rejected=0;erase_calls=0;preset_calls=0;
}
void set_aircraft(double n,double u,double e,double vn,double vu,double ve,
                  double qx,double qy,double qz,double qw) {
  const double norm=std::sqrt(qx*qx+qy*qy+qz*qz+qw*qw);
  if (!api.clock || !std::isfinite(norm) || norm<.9 || norm>1.1) return;
  for(double x:{n,u,e,vn,vu,ve})if(!std::isfinite(x))return;
  qx/=norm;qy/=norm;qz/=norm;qw/=norm;
  GroundVideoView::Aircraft a;
  a.valid=true;a.stamp=api.clock();a.north=n;a.altitude=u;a.east=e;
  a.vn=vn;a.vu=vu;a.ve=ve;
  a.fn=1-2*(qy*qy+qz*qz);a.fu=2*(qx*qy+qw*qz);a.fe=2*(qx*qz-qw*qy);
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
  View next;
  next.enabled=ready && get(p,"F22_AG_VIDEO_ENABLE")>.5 && get(p,"HUD_MODE")==7 &&
      get(p,"MAIN_POWER")>.5 && get(p,"RADAR_PWR")>.5;
  next.frozen=get(p,"F22_AG_VIDEO_FROZEN")>.5||get(p,"F22_AG_VIDEO_HOLD")>.5;
  next.stamp=get(p,"F22_AG_VIDEO_TIME");
  next.north=get(p,"F22_AG_VIDEO_NORTH"); next.altitude=get(p,"F22_AG_VIDEO_ALTITUDE");
  next.east=get(p,"F22_AG_VIDEO_EAST"); next.heading=get(p,"F22_AG_VIDEO_HEADING");
  next.range_nm=get(p,"F22_AG_RADAR_RANGE_NM");next.width_deg=get(p,"F22_AG_VIDEO_FOV_DEG");
  next.collection=get(p,"F22_AG_VIDEO_COLLECTION");
  next.scan_direction=get(p,"F22_AG_VIDEO_SCAN_DIRECTION");next.scan_fraction=get(p,"F22_AG_VIDEO_SCAN_FRACTION");
  next.gain=get(p,"F22_AG_VIDEO_GAIN");next.erase_sequence=get(p,"F22_AG_VIDEO_ERASE_SEQUENCE");
  next.mode=static_cast<int>(get(p,"F22_AG_MODE"));
  next.gmt=next.mode==2||next.mode==3||next.mode==4||next.mode==5;
  next.expansion=static_cast<int>(get(p,"F22_AG_VIDEO_EXPANSION"));
  next.center_m=get(p,"F22_AG_VIDEO_CENTER_M");next.span_m=get(p,"F22_AG_VIDEO_SPAN_M");
  next.antenna_offset=get(p,"F22_AG_VIDEO_ANTENNA_DEG")*GroundVideoView::pi/180;
  next.fast=get(p,"F22_AG_FAST")>.5;next.fan=get(p,"F22_AG_VIDEO_FAN")>.5;
  next.view_epoch=get(p,"F22_AG_VIDEO_EPOCH");
  next.stabilized=get(p,"F22_AG_VIDEO_STABILIZED")>.5;
  next.patch_n=get(p,"F22_AG_VIDEO_PATCH_N");next.patch_u=get(p,"F22_AG_VIDEO_PATCH_U");next.patch_e=get(p,"F22_AG_VIDEO_PATCH_E");
  next.patch_az=get(p,"F22_AG_VIDEO_PATCH_AZ");next.patch_distance=get(p,"F22_AG_VIDEO_PATCH_DISTANCE");next.interleave=get(p,"F22_AG_INTERLEAVE")>.5;
  next.tracking=get(p,"F22_AG_NATIVE_TRACK_VALID")>.5||get(p,"F22_AG_NATIVE_TRACK_ACQUIRING")>.5;
  next.scan_center=get(p,"F22_AG_RADAR_SCAN_CENTER_AZ_DEG")*GroundVideoView::pi/180;
  // Controlled self-occlusion experiment. These default-zero diagnostic
  // offsets affect only this renderer view, never ownship or sensor truth.
  std::array<double,3> probe{get(p,"F22_AG_VIDEO_PROBE_FORWARD_M"),get(p,"F22_AG_VIDEO_PROBE_RIGHT_M"),get(p,"F22_AG_VIDEO_PROBE_UP_M")};
  for(auto &v:probe)if(!std::isfinite(v)||std::abs(v)>100)v=0;
  if(probe!=previous_probe){previous_probe=probe;++probe_erase;}
  next.probe_forward=probe[0];next.probe_right=probe[1];next.probe_up=probe[2];
  next.north+=std::cos(next.heading)*probe[0]-std::sin(next.heading)*probe[1];
  next.east+=std::sin(next.heading)*probe[0]+std::cos(next.heading)*probe[1];
  next.altitude+=probe[2];next.erase_sequence+=probe_erase*1000000;
  put(p,"F22_AG_VIDEO_RENDER_NORTH",rendered_n);put(p,"F22_AG_VIDEO_RENDER_ALTITUDE",rendered_u);put(p,"F22_AG_VIDEO_RENDER_EAST",rendered_e);
  put(p,"F22_AG_VIDEO_RENDER_HEADING",rendered_heading);put(p,"F22_AG_VIDEO_MOTION_AGE_MS",motion_age_ms);
  put(p,"F22_AG_VIDEO_PROBE_EPOCH",probe_erase);
  timing_enabled=get(p,"F22_AG_VIDEO_TIMING_DIAGNOSTIC")>.5;
  gpu_probe_enabled=get(p,"F22_AG_VIDEO_GPU_DIAGNOSTIC")>.5;
  GroundVideoProbe::selected_target=static_cast<int>(std::clamp(get(p,"F22_AG_VIDEO_PROBE_TEXTURE"),0.,6.));
  {std::lock_guard<std::mutex> lock(view_mutex);view=next;}
  View reference;{std::lock_guard<std::mutex>lock(view_mutex);reference=map_reference;}
  put(p,"F22_AG_VIDEO_REFERENCE_VALID",ready&&reference.enabled?1:0);
  put(p,"F22_AG_VIDEO_REFERENCE_NORTH",reference.north);put(p,"F22_AG_VIDEO_REFERENCE_ALTITUDE",reference.altitude);
  put(p,"F22_AG_VIDEO_REFERENCE_EAST",reference.east);put(p,"F22_AG_VIDEO_REFERENCE_HEADING",reference.heading);
  put(p,"F22_AG_VIDEO_REFERENCE_TIME",reference.stamp);
  put(p,"F22_AG_VIDEO_REFERENCE_SCHEMA",2);
  put(p,"F22_AG_VIDEO_REFERENCE_RANGE_NM",reference.range_nm);
  put(p,"F22_AG_VIDEO_REFERENCE_MODE",reference.mode);
  put(p,"F22_AG_VIDEO_REFERENCE_EXPANSION",reference.expansion);
  put(p,"F22_AG_VIDEO_REFERENCE_CENTER_M",reference.center_m);put(p,"F22_AG_VIDEO_REFERENCE_SPAN_M",reference.span_m);
  put(p,"F22_AG_VIDEO_REFERENCE_EPOCH",reference.view_epoch);
  put(p,"F22_AG_VIDEO_READY",ready?1:0);
  put(p,"F22_AG_VIDEO_REASON",guard.reason()?guard.reason():ready?0:api.reason?api.reason:5);
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
