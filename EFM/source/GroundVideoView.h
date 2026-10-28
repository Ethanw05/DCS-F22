// GPL-3.0-or-later. Geometry shared by the native image source and its tests.
#pragma once
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <initializer_list>
namespace GroundVideoView {
constexpr double pi = 3.14159265358979323846;
// Reference-derived mod antenna setting, not an APG-77 specification.
constexpr double map_depression = 13*pi/180;
// Binding is rechecked even when the same indicator already has our table.
struct Binding {
  std::uintptr_t context{}, controller{};
  unsigned target{};
};
inline bool matches(const Binding &candidate, const Binding &expected) {
  return candidate.context && candidate.controller &&
      candidate.context == expected.context && candidate.controller == expected.controller &&
      candidate.target == expected.target;
}
// Never call class-specific getters until the exact vtable has been accepted.
template<class ReadBinding>
inline bool verify_binding(std::uintptr_t actual, std::uintptr_t original,
                           std::uintptr_t clone, bool owned, const Binding &expected,
                           ReadBinding read) {
  if (!original || (actual != original && !(owned && clone && actual == clone))) return false;
  return matches(read(),expected);
}
// A bad host parameter buffer disables every render entry point until reset.
// Revalidating ownership or cycling source power must never clear this fault.
class Guard {
  std::atomic<bool> verified{};
  std::atomic<int> fault{};
public:
  void verify(bool value) { verified = value; }
  void fail(int reason) { int clear=0; fault.compare_exchange_strong(clear,reason); }
  bool available() const { return verified.load() && fault.load()==0; }
  int reason() const { return fault.load(); }
  void reset() { verified=false; fault=0; }
};
struct View {
  bool enabled{};
  bool frozen{};
  double stamp{}, north{}, altitude{}, east{}, heading{};
  double range_nm = 20, width_deg = 120;
  double scan_direction = 1, scan_fraction{}, gain = .5, collection{};
  double antenna_elevation{},scan_center{};
  bool gmt{},interleave{},tracking{},fast{},fan=true,qualified=true,stabilized{};
  int mode=1,expansion{};
  double center_m{},span_m{},antenna_offset{},view_epoch{};
  double patch_n{},patch_u{},patch_e{},patch_az{},patch_distance{};
  double erase_sequence{};
  double probe_forward{},probe_right{},probe_up{};
};
inline bool refresh(const View& current, const View& previous, bool have_previous) {
  // Geometry/UI changes can erase or reformat video; only completed RF work
  // can authorize new scene pixels. Partial work must not be rounded away.
  return !current.frozen && current.collection>0
      && (!have_previous || current.collection!=previous.collection);
}
// The common RBM renderer caches terrain across its three draw stages. Only
// a direction transition restarts that cache; DynamicParam5 is buildDBS and
// does nothing for MAP. This is a renderer transaction, not antenna motion.
// Coalesce completed RF work while a captured image traverses those stages.
class ImageCycle {
  static constexpr unsigned pipeline_submissions = 3;
  View image_{};
  unsigned submitted_{};
  int direction_ = 1;
  bool captured_{};
public:
  bool capture(const View& candidate) noexcept {
    if (!refresh(candidate, image_, captured_)) return false;
    const unsigned required = image_.expansion>0 && !image_.fast ? 2*pipeline_submissions : pipeline_submissions;
    if (captured_ && submitted_ < required) return false;
    if (captured_) direction_ = -direction_;
    image_ = candidate;
    image_.scan_direction = direction_;
    submitted_ = 0;
    captured_ = true;
    return true;
  }
  bool available() const noexcept { return captured_; }
  const View& image() const noexcept { return image_; }
  int direction() const noexcept { return direction_; }
  void submitted() noexcept { if (submitted_ < 2*pipeline_submissions) ++submitted_; }
};
// Physics supplies this value snapshot. Render callbacks never read scene
// objects or use the slower cockpit/INS coordinates as an antenna position.
struct Aircraft {
  bool valid{};
  double stamp{}, north{}, altitude{}, east{}, vn{}, vu{}, ve{};
  double fn=1, fu{}, fe{};
};
inline double renderer_depression(const View &v) {
  return std::fmin(pi/3,std::fmax(-pi/3,(v.fan?map_depression:0)-v.antenna_elevation));
}
inline View antenna(View v, const Aircraft &a, double now) {
  if (v.frozen) return v;
  const double age=now-a.stamp;
  if (!a.valid || !std::isfinite(age) || age<-.1 || age>.1) {
    v.enabled=false; return v;
  }
  // The shader's shadow camera must stay outside our own EDM at the render
  // time, including interpolation backwards to an older graphics frame.
  // Moving-flight A/B/A: 12m remained inside our rendered model's shadow;
  // 30m recovered the final texture in both 30m phases at 250m/s.
  constexpr double clearance=30;
  v.north=a.north+a.vn*age+a.fn*(clearance+v.probe_forward)-a.fe*v.probe_right;
  v.altitude=a.altitude+a.vu*age+a.fu*(clearance+v.probe_forward)+v.probe_up;
  v.east=a.east+a.ve*age+a.fe*(clearance+v.probe_forward)+a.fn*v.probe_right;
  v.heading=std::atan2(a.fe,a.fn);
  // FA18C 4A42D0: elevation center tracks -atan(height/range), with the
  // renderer basis an additional 13 degrees down (clamped to +/-60deg).
  v.antenna_elevation=-std::atan(v.altitude/(v.range_nm*1852))+v.antenna_offset;
  if(v.expansion>0) {
    const double pn=v.stabilized?v.patch_n:v.north+v.patch_distance*std::cos(v.heading+v.patch_az);
    const double pe=v.stabilized?v.patch_e:v.east+v.patch_distance*std::sin(v.heading+v.patch_az);
    double n=pn-v.north,e=pe-v.east,d=std::hypot(n,e);
    if(d<100){v.enabled=false;return v;}
    {
      // The magnified patch view is earth-stabilized. In a climb its look
      // direction can differ by more than 90deg from the aircraft's nose,
      // making the old nose-axis offset place our model in front of it.
      // Keep the renderer-only clearance along this camera's actual view.
      const double bearing=std::atan2(e,n);
      v.antenna_elevation=std::atan2(v.patch_u-v.altitude,d)+v.antenna_offset;
      const double depression=renderer_depression(v),horizontal=clearance*std::cos(depression);
      v.north=a.north+a.vn*age+horizontal*std::cos(bearing)+a.fn*v.probe_forward-a.fe*v.probe_right;
      v.altitude=a.altitude+a.vu*age-clearance*std::sin(depression)+v.probe_up+a.fu*v.probe_forward;
      v.east=a.east+a.ve*age+horizontal*std::sin(bearing)+a.fe*v.probe_forward+a.fn*v.probe_right;
      // Re-register the geographic patch from the displaced renderer origin.
      n=pn-v.north;e=pe-v.east;d=std::hypot(n,e);
      if(d<100){v.enabled=false;return v;}
    }
    v.scan_center=std::remainder(std::atan2(e,n)-v.heading,2*pi);
    const double fov=v.expansion==1?pi/4:v.expansion==2?12.6*pi/180:std::atan(2315/d);
    const double maximum=(v.expansion==3?30:40)*1852.;
    v.center_m=std::fmin(d,maximum/(1+std::tan(fov/2)));
    v.span_m=2*v.center_m*std::tan(fov/2);v.width_deg=fov*180/pi;
    v.antenna_elevation=std::atan2(v.patch_u-v.altitude,d)+v.antenna_offset;
    v.qualified=d<=maximum&&std::abs(v.scan_center)<=pi/3;
    v.enabled=v.enabled&&v.qualified;
  }
  v.stamp=now;
  return v;
}
inline bool valid(const View &v, double now) {
  for (double x : {v.stamp, now, v.north, v.altitude, v.east, v.heading,
                   v.range_nm, v.width_deg, v.scan_direction, v.scan_fraction,
                   v.gain, v.collection, v.erase_sequence, v.center_m, v.span_m, v.antenna_offset, v.view_epoch,
                   v.patch_n,v.patch_u,v.patch_e,v.patch_az,v.patch_distance})
    if (!std::isfinite(x)) return false;
  return v.enabled && now >= v.stamp && now - v.stamp <= .5 &&
      std::abs(v.north) < 3e7 && std::abs(v.east) < 3e7 &&
      v.altitude > -500 && v.altitude < 100000 &&
      v.mode>=1 && v.mode<=7 && v.expansion>=0 && v.expansion<=3 &&
      v.range_nm >= 5 && v.range_nm <= ((v.mode==2||v.mode==3)?40:(v.mode==4||v.mode==5)?80:v.mode==6?10:v.mode==7?5:160) &&
      v.width_deg >= (v.expansion>0?.01:20) && v.width_deg <= 120 &&
      (v.expansion==0||(v.center_m>10&&v.span_m>0&&v.span_m<148160)) &&
      (v.scan_direction == 1 || v.scan_direction == -1) &&
      v.scan_fraction >= 0 && v.scan_fraction <= 1 && v.gain >= 0 && v.gain <= 1;
}
struct Prepared {
  View view;
  bool accepted{};
};
inline Prepared prepare(const View &v, double now, bool ownership = true) {
  const bool accepted = ownership && valid(v, now);
  return {accepted ? v : View{}, accepted};
}
// Graphics::Camera::getProjectionDesc confirms these fields at+688..704.
// The native ABI uses near before far, in this exact order.
struct Projection { float fov_x{}, fov_y{}, aspect{}, near_clip{}, far_clip{}; };
static_assert(sizeof(Projection)==20);
inline Projection projection(const Prepared &frame) {
  const auto v=frame.accepted?frame.view:View{};
  const auto fov=static_cast<float>(v.width_deg*pi/180);
  // The native Hornet MAP camera uses a positive 10m renderer near plane.
  // This is a clip setting, not a radar minimum-detection-range claim.
  // Hornet 0x1804A3FC0: horizontal sector, 90deg vertical FOV, and their
  // tangent ratio. A square projection is not its camera contract.
  const float near_clip=v.expansion?static_cast<float>(std::fmax(10.,v.center_m-v.span_m/2)):
      v.mode==6?2963.2f:10.f;
  const float far_clip=v.expansion?static_cast<float>(v.center_m+v.span_m/2):static_cast<float>(v.range_nm*1852);
  // PEN uses the same 3.3deg bounded aperture as our native point query.
  // This mod aperture is not claimed as a recovered APG-77 beam specification.
  const float vertical=static_cast<float>(v.fan?pi/2:3.3*pi/180);
  return {fov,vertical,std::tan(fov/2)/std::tan(vertical/2),near_clip,far_clip};
}
inline std::array<double,3> point(const Prepared &frame) {
  const auto v = frame.accepted ? frame.view : View{};
  return {v.north,v.altitude,v.east};
}
inline std::array<float, 12> position(const Prepared &frame) {
  const auto v = frame.accepted ? frame.view : View{};
  const float c = static_cast<float>(std::cos(v.heading+v.scan_center));
  const float s = static_cast<float>(std::sin(v.heading+v.scan_center));
  const double depression=renderer_depression(v);
  const float down = static_cast<float>(std::sin(depression));
  const float level = static_cast<float>(std::cos(depression));
  // wPosition3<float>: forward, up, right and position, each 16-byte aligned.
  // Earth-stabilized depression follows the recovered Hornet MAP basis. The
  // common renderer still builds its own orthographic map from heading/range.
  return {c*level,-down,s*level, c*down,level,s*down, -s,0,c,
          static_cast<float>(v.north),static_cast<float>(v.altitude),static_cast<float>(v.east)};
}
union Param { std::uint64_t bits; float number; const char *text; };
static_assert(sizeof(Param) == 8);
inline const char *preset(const View &v) {
  if(v.mode==6)return "F18_TA";
  // Shared presets without the Hornet's five-degree DBS boresight blank.
  return v.expansion==1?"EXP_F16":v.expansion==2?"DBS1_F16":v.expansion==3?"DBS2_F16":"GM_F16";
}
inline std::array<Param,18> parameters(const View &v, bool erase, bool preset) {
  std::array<Param,18> p{};
  p[0].number = static_cast<float>(v.scan_direction);
  p[1].number = static_cast<float>(v.scan_fraction);
  // enlight::AGRadar::blurPass multiplies preset resolution by Param2, then
  // scales the DBS blur angle by min(19/resolution,1). This controls resolving
  // detail, not texture size. The factor2 is a mod estimate, not APG-77 data.
  const float detail = v.expansion>0 ? 2.f : 1.f;
  p[2].number = detail*(v.fast&&v.expansion>0?.5f:1.f);
  p[3].number = .5f;
  p[4].number = static_cast<float>(v.gain);
  p[6].bits = erase ? 1 : 0;
  // The Hornet uses the shared MAP preset. Its .09/.09/.82/.82 viewport
  // must also be cropped by the consuming MFD texture coordinates.
  if (preset) p[7].text = GroundVideoView::preset(v);
  // DynamicParam8 is FLOAT footprint intensity, NOT integer quantization.
  p[8].number = v.gmt&&!v.tracking?.5f:0.f;
  // 4A42D0 changes the GMT limits at sweep reversal. INTL substitutes
  // zero on the reverse sweep; the same shared renderer consumes these.
  p[9].number = v.gmt&&(!v.interleave||v.scan_direction>0)?50.f:0.f;
  p[10].number = v.gmt?55.f:50.f;
  return p;
}
}
