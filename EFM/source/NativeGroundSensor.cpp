// GPL-3.0-or-later. Independent bounded GMT detector using shared DCS services.
// Scene access occurs on the owned avLuaDevice clock after the AESA scheduler.
// No mission/export truth, global enumeration, or FA18C runtime dependency.
#include "NativeGroundSensor.h"
#include "GroundMovingTargets.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <atomic>
#include <array>
#include <functional>
#include <map>
#include <mutex>
#include <string>
#include <cstring>
namespace NativeGroundSensor { namespace {
using namespace GroundMovingTargets;
struct VecF {float n,u,e;};
struct Scene {};
using Query=std::function<int(Scene&)>;
static_assert(sizeof(Query)==64,"Qualified MSVC scene callback ABI");
bool readable(std::uintptr_t a,std::size_t n) {
  MEMORY_BASIC_INFORMATION m{};
  return a&&VirtualQuery(reinterpret_cast<void*>(a),&m,sizeof(m))&&m.State==MEM_COMMIT&&
    !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS))&&n<=m.RegionSize&&a>=reinterpret_cast<std::uintptr_t>(m.BaseAddress)&&
    a-reinterpret_cast<std::uintptr_t>(m.BaseAddress)<=m.RegionSize-n;
}
template<class F> F method(void *object,unsigned index) {
  const auto p=reinterpret_cast<std::uintptr_t>(object);
  if(!readable(p,8))return nullptr;
  auto table=*reinterpret_cast<std::uintptr_t*>(p);
  if(!readable(table+index*8,8))return nullptr;
  return reinterpret_cast<F>(*reinterpret_cast<std::uintptr_t*>(table+index*8));
}
bool profile(HMODULE m,DWORD stamp,DWORD size) {
  if(!m)return false;auto b=reinterpret_cast<const std::byte*>(m);
  const auto dos=reinterpret_cast<const IMAGE_DOS_HEADER*>(b);
  if(dos->e_magic!=IMAGE_DOS_SIGNATURE||dos->e_lfanew<0)return false;
  const auto pe=reinterpret_cast<const IMAGE_NT_HEADERS64*>(b+dos->e_lfanew);
  return pe->Signature==IMAGE_NT_SIGNATURE&&pe->FileHeader.TimeDateStamp==stamp&&pe->OptionalHeader.SizeOfImage==size;
}
struct Api {
  using Clock=double(__cdecl*)();using Aircraft=void*(__cdecl*)();
  using Point=Vec*(__fastcall*)(void*,Vec*);
  using Velocity=const VecF*(__fastcall*)(const void*);
  using Type=const unsigned char*(__fastcall*)(const void*);
  using Dead=bool(__fastcall*)(const void*);
  using Flag=bool(__fastcall*)(const void*,int);
  using Position=const float*(__fastcall*)(void*);
  using Camera=void*(__fastcall*)(void*,int);
  using Clip=const void*(__fastcall*)(const void*);
  using Intersect=const char*(__fastcall*)(const Scene&,const Vec&,const Vec&,Vec&,double&,Vec&);
  Clock clock{};Aircraft aircraft{};Point point{};Velocity velocity{};Type type{};Dead dead{};Flag flag{};Position position{};Intersect intersect{};Camera camera{};Clip clip{};
  void **manager{},**land{};
  std::atomic<bool> ready{};int reason=1;
  void initialize() {
    if(ready||reason==2)return;
    auto common=GetModuleHandleW(L"CockpitBase.dll"),objects=GetModuleHandleW(L"edObjects.dll"),
      world=GetModuleHandleW(L"World.dll"),general=GetModuleHandleW(L"WorldGeneral.dll"),graphics=GetModuleHandleW(L"GraphicsVista.dll");
    if(!common||!objects||!world||!general||!graphics)return;
    if(!profile(common,0x6ac12468,0x59a000)||!profile(objects,0x6aae1e0e,0x46000)||
       !profile(general,0x6ac122f4,0x125b000)||!profile(world,0x6aae1d9b,0x14000)||
       !profile(graphics,0x6aae1df2,0x62000)){reason=2;return;}
    clock=reinterpret_cast<Clock>(GetProcAddress(world,"?GetModelTime@wTime@@SANXZ"));
    aircraft=reinterpret_cast<Aircraft>(GetProcAddress(common,"?c_LA@cockpit@@YAPEAVIwoLA@@XZ"));
    point=reinterpret_cast<Point>(GetProcAddress(general,"?GetPoint@MovingObject@@UEAA?AVVec3d@osg@@XZ"));
    velocity=reinterpret_cast<Velocity>(GetProcAddress(general,"?VectorVelocity@MovingObject@@UEBAAEBVVec3f@osg@@XZ"));
    type=reinterpret_cast<Type>(GetProcAddress(general,"?Type@MovingObject@@QEBAAEBVwsType@@XZ"));
    dead=reinterpret_cast<Dead>(GetProcAddress(general,"?IsDead@MovingObject@@UEBA_NXZ"));
    flag=reinterpret_cast<Flag>(GetProcAddress(general,"?IsFlag@MovingObject@@QEBA?B_NH@Z"));
    camera=reinterpret_cast<Camera>(GetProcAddress(graphics,"??0Camera@Graphics@@QEAA@W4Type@01@@Z"));
    clip=reinterpret_cast<Clip>(GetProcAddress(graphics,"?getClipVolume@Camera@Graphics@@QEBAPEBVClipVolume@@XZ"));
    position=reinterpret_cast<Position>(GetProcAddress(general,"?Position@MovingObject@@UEAAAEBV?$wPosition3@M@@XZ"));
    manager=reinterpret_cast<void**>(GetProcAddress(objects,"?instance@viObjectManager@@2PEAV1@EA"));
    land=reinterpret_cast<void**>(GetProcAddress(general,"?globalLand@@3PEAVwTerrain@@EA"));
    intersect=reinterpret_cast<Intersect>(GetProcAddress(objects,"?intersectSegment@@YAPEBDAEBVISceneObject@@AEBVVec3d@osg@@1AEAV23@AEAN2@Z"));
    const bool ok=clock&&aircraft&&point&&velocity&&type&&dead&&flag&&position&&manager&&land&&intersect&&camera&&clip;
    reason=ok?0:3;ready.store(ok,std::memory_order_release);
  }
} api;
struct Controls {bool active{},search{},request{},sea{},ranging{},fan{},illuminated=true;double resource=1,elevation{},stamp{},range=37040,az{},request_sequence{};Vec request_point{};unsigned selected{};};
struct Output {
  bool ready{};int reason=4;double stamp{};unsigned queries{},candidates{},terrain_rejects{},object_rejects{},speed_rejects{},ground_candidates{},truncated{};
  Vec origin{};double heading{},az{},dt{},aspect{};Contacts contacts;
  bool agr_valid{};double agr_range{},agr_rate{},agr_stamp=-100;Vec agr_point{};
  Contact selected{};bool acquiring{},memory{},fixed{};unsigned rcs_rejects{},selected_type{};double request_sequence=-1;
};
std::mutex state_mutex;
Controls controls;
Output output;
std::atomic<std::uint64_t> epoch{1};
Tracks tracks;
Measurements measurements;
struct RangeReport { double stamp=-100, release{}, range{}, rate{};bool valid{}; };
std::array<RangeReport, 4> range_pending{};
RangeReport range_report;
Contact selected;
Vec acquisition_point{};
bool acquiring{},fixed{};
unsigned selected_type{};
double request_sequence=-1,acquisition_time{};
std::uint64_t sampled_epoch{};
double last_query=-1;
std::map<std::string,void*> handles;
double get(EDPARAM&p,const std::string&n){auto&h=handles[n];if(!h)h=p.getParamHandle(n.c_str());return p.getParamNumber(h);}
void put(EDPARAM&p,const std::string&n,double v){auto&h=handles[n];if(!h)h=p.getParamHandle(n.c_str());p.setParamNumber(h,v);}
void *moving(Scene &s) {
  using Registered=void*(__fastcall*)(void*);auto reg=method<Registered>(&s,6);
  void *r=reg?reg(&s):nullptr;
  auto cast=method<Registered>(r,7);return cast?cast(r):nullptr;
}
unsigned id(Scene&s){using ID=unsigned(__fastcall*)(void*);auto f=method<ID>(&s,1);return f?f(&s):0;}
bool terrain_visible(const Vec&from,const Vec&to) {
  // FA18C 4A12B0 -> globalLand virtual+104: intersect a normalized ray,
  // then require the terrain hit within 500m on EACH axis of the target.
  using Ray=bool(__fastcall*)(void*,const VecF&,const VecF&,float,VecF*);
  void *land=api.land?*api.land:nullptr;auto terrain=method<Ray>(land,13);
  const Vec delta=to-from;const double distance=length(delta);
  if(!terrain||distance<=0)return false;
  const VecF a{static_cast<float>(from.n),static_cast<float>(from.u),static_cast<float>(from.e)},
      direction{static_cast<float>(delta.n/distance),static_cast<float>(delta.u/distance),static_cast<float>(delta.e/distance)};
  VecF hit{};
  return terrain(land,a,direction,185200.f,&hit)&&std::abs(hit.n-to.n)<=500&&
      std::abs(hit.u-to.u)<=500&&std::abs(hit.e-to.e)<=500;
}
bool visible(const Vec&from,const Vec&to,unsigned target,unsigned own,Output&stats) {
  if(!terrain_visible(from,to)){++stats.terrain_rejects;return false;}
  using Segment=void(__fastcall*)(void*,const Vec&,const Vec&,unsigned,const Query&);
  void *manager=*api.manager;auto query=method<Segment>(manager,24);if(!query)return false;
  struct SegmentState { const Vec* from;const Vec* to;Output* stats;unsigned own{},tested{},nearest_id{};
    double distance{},nearest{}; };
  SegmentState context{&from,&to,&stats,own,0,0,length(to-from),length(to-from)};
  Query each=[c=&context](Scene& object) {
    const unsigned object_id=id(object);
    if(object_id==c->own)return 0;
    if(++c->tested>32){++c->stats->truncated;return 1;}
    Vec point{},normal{};double fraction=2;
    if(api.intersect(object,*c->from,*c->to,point,fraction,normal)&&fraction>=0&&fraction<=1&&fraction*c->distance<c->nearest){
      c->nearest=fraction*c->distance;c->nearest_id=object_id;
    }
    return 0;
  };
  // Same separate scene-object obstruction query used by APG-73 AG visibility.
  query(manager,from,to,35,each);
  const bool accepted=context.tested<=32&&(context.nearest_id==target||context.distance-context.nearest<10);
  if(!accepted)++stats.object_rejects;
  return accepted;
}
bool positive_response(void *unit) {
  using Response=void*(__fastcall*)(void*);
  using RCS=float(__fastcall*)(void*,float,const VecF&);
  auto getter=method<Response>(unit,59);void *response=getter?getter(unit):nullptr;
  auto value=method<RCS>(response,6);
  return value&&value(response,0.f,VecF{1,0,0})>0;
}
// Graphics::Camera::getClipVolume builds ClipVolumeCamera using the SAME
// shared constructor as the Hornet's 5DEBD0. Query manager+152, not an AABB.
const void *volume(Vec origin,double heading,double elevation,double half_az,double half_el) {
  struct CameraState {alignas(16) std::array<std::byte,784> data{};bool initialized{};};
  thread_local CameraState c;
  if(!c.initialized){api.camera(c.data.data(),0);c.initialized=true;}
  const float h=static_cast<float>(heading),el=static_cast<float>(elevation),ch=std::cos(h),sh=std::sin(h),ce=std::cos(el),se=std::sin(el);
  const std::array<float,12> pose{ch*ce,se,sh*ce,-ch*se,ce,-sh*se,-sh,0,ch,
    static_cast<float>(origin.n),static_cast<float>(origin.u),static_cast<float>(origin.e)};
  for(unsigned row=0;row<4;++row)std::memcpy(c.data.data()+560+16*row,pose.data()+row*3,12);
  // Native ClipVolumeCamera aspect is half-angle ratio, not tangent ratio.
  const std::array<float,5> projection{static_cast<float>(2*half_az),static_cast<float>(2*half_el),
    static_cast<float>(half_az/half_el),0,185200.f};
  std::memcpy(c.data.data()+688,projection.data(),sizeof(projection));c.data[776]=std::byte{1};
  return api.clip(c.data.data());
}
}
void reset(){epoch.fetch_add(1);std::lock_guard<std::mutex>lock(state_mutex);controls={};output={};handles.clear();}
void sample(void *owned_radar, const ArrayService* service) {
  if(!owned_radar||!api.ready.load(std::memory_order_acquire))return;
  const auto generation=epoch.load();
  if(generation!=sampled_epoch){range_pending={};range_report={};measurements.clear();tracks.clear();selected={};selected_type=0;acquiring=false;fixed=false;request_sequence=-1;last_query=-1;sampled_epoch=generation;}
  Controls c;Output stats;
  {std::lock_guard<std::mutex>lock(state_mutex);c=controls;stats=output;}
  if(service){c.illuminated=service->granted;c.az=service->azimuth;c.resource=service->resource;c.active=c.active&&service->active;}
  const double now=api.clock();
  stats.ready=true;stats.reason=0;stats.stamp=now;
  // FRZ holds the video, not the transmitter or ground sensor. MAP can
  // request the same native acquisition/FTT path without enabling GMT search.
  if(!std::isfinite(now)||!c.active||now-c.stamp<-.05||now-c.stamp>.5) {
    if(!c.active){range_pending={};range_report={};measurements.clear();tracks.clear();selected={};acquiring=false;fixed=false;}stats.agr_valid=false;stats.contacts.clear();stats.selected={};stats.fixed=false;
    std::lock_guard<std::mutex>lock(state_mutex);if(epoch.load()==generation)output=stats;return;
  }
  // A completed array grant is an RF event, not an optional coast refresh.
  if(!c.illuminated&&now>=last_query&&now-last_query<.015)return;
  const double dt=last_query<0?.02:std::clamp(now-last_query,0.,.1);
  last_query=now;tracks.advance(now);
  measurements.release(now,[&](const Contact& measured,bool for_track) {
    if(for_track){
      if(acquiring||selected.id==measured.id){
        selected=measured;acquiring=false;fixed=false;
        selected_type=measured.velocity_valid&&length(measured.velocity)>3?2:1;tracks.clear();
      }
    }else tracks.observe(measured);
  });
  for(auto& report:range_pending)if(report.valid&&now>=report.release){range_report=report;report.valid=false;}
  stats.agr_valid=c.ranging&&range_report.valid&&now>=range_report.stamp&&now-range_report.stamp<=.5;
  stats.agr_stamp=range_report.stamp;stats.agr_range=range_report.range;stats.agr_rate=range_report.rate;
  if(!c.illuminated) {
    // Background air jobs own these intervals. Acquisition, tracking and
    // ranging cannot bypass the common array service budget.
    if((selected.id||fixed)&&now-selected.stamp>5){selected={};fixed=false;}
    stats.contacts=tracks.contacts();stats.selected=selected;stats.selected_type=selected_type;
    stats.fixed=fixed;stats.memory=selected.id||fixed;stats.acquiring=acquiring;
    std::lock_guard<std::mutex>lock(state_mutex);if(epoch.load()==generation)output=std::move(stats);return;
  }
  void *la=api.aircraft();using Own=void*(__fastcall*)(void*);auto own_get=method<Own>(la,40);
  void *own=own_get?own_get(la):nullptr;
  const auto basis=own?api.position(own):nullptr;
  if(!own||!readable(reinterpret_cast<std::uintptr_t>(basis),64))return;
  Vec origin{};api.point(own,&origin);
  const auto own_speed=api.velocity(own);
  if(!own_speed)return;
  const Vec own_velocity{own_speed->n,own_speed->u,own_speed->e};
  if(!std::isfinite(length(own_velocity)))return;
  const double heading=std::atan2(basis[2],basis[0]);
  if(c.ranging) {
    // Native beam/terrain measurement. This is independent of the bomb
    // ballistic trajectory and is invalid when the beam does not hit ground.
    using Ray=bool(__fastcall*)(void*,const VecF&,const VecF&,float,VecF*);
    void *land=api.land?*api.land:nullptr;auto ray=method<Ray>(land,13);
    const double elevation=std::atan2(basis[1],std::hypot(basis[0],basis[2]))+c.elevation;
    const VecF from{static_cast<float>(origin.n),static_cast<float>(origin.u),static_cast<float>(origin.e)},
      direction{static_cast<float>(std::cos(heading)*std::cos(elevation)),static_cast<float>(std::sin(elevation)),static_cast<float>(std::sin(heading)*std::cos(elevation))};
    VecF hit{};
    if(ray&&elevation<-pi/180&&ray(land,from,direction,static_cast<float>(c.range),&hit)) {
      const Vec point{hit.n,hit.u,hit.e};const double distance=length(point-origin);
      if(distance>=10&&distance<=c.range) {
        // Bounded game-estimate range error and finite processing; no exact
        // terrain-ray distance is published as a radar measurement.
        RangeReport measured{now,now+.06/std::clamp(c.resource,.1,1.),distance+3*std::sin(now*11.2),0,true};
        if(const auto velocity=api.velocity(own))
          measured.rate=-(velocity->n*direction.n+velocity->u*direction.u+velocity->e*direction.e)+.4*std::sin(now*7.3);
        for(auto& report:range_pending)if(!report.valid){report=measured;break;}
      }
    }
    stats.contacts.clear();stats.selected={};stats.fixed=false;stats.acquiring=false;
    std::lock_guard<std::mutex>lock(state_mutex);if(epoch.load()==generation)output=std::move(stats);return;
  }

  using ID=unsigned(__fastcall*)(void*);void *own_vi=static_cast<std::byte*>(own)+120;
  auto own_id_get=method<ID>(own_vi,1);const unsigned own_id=own_id_get?own_id_get(own_vi):0;
  if(c.request_sequence!=request_sequence){
    request_sequence=c.request_sequence;measurements.clear();selected={};selected_type=0;fixed=false;acquiring=c.request;
    acquisition_point=c.request_point;acquisition_time=now;tracks.clear();
  }
  stats.request_sequence=request_sequence;
  if(fixed){
    const auto relative=selected.point-origin;
    const bool measured=std::abs(difference(bearing(relative),heading))<=pi/3&&
      std::atan2(relative.u,std::hypot(relative.n,relative.e))<-pi/180&&terrain_visible(origin,selected.point);
    if(measured)selected.stamp=now;
    else if(now-selected.stamp>=5+2*dt){fixed=false;selected={};}
    stats.contacts.clear();stats.selected=selected;stats.selected_type=selected_type;stats.fixed=fixed;
    stats.memory=fixed&&!measured;stats.acquiring=false;stats.dt=dt;
    std::lock_guard<std::mutex>lock(state_mutex);if(epoch.load()==generation)output=std::move(stats);return;
  }
  if(selected.id&&now-selected.stamp>=2*dt+5)selected={};
  const bool memory=selected.id&&now-selected.stamp>=2*dt;
  if(memory){selected.point.n+=dt*selected.velocity.n;selected.point.u+=dt*selected.velocity.u;selected.point.e+=dt*selected.velocity.e;}
  double az=c.az;
  const bool tracking=selected.id!=0;
  if(!c.search&&!acquiring&&!tracking){
    stats.contacts.clear();stats.selected={};stats.fixed=false;stats.acquiring=false;
    std::lock_guard<std::mutex>lock(state_mutex);if(epoch.load()==generation)output=std::move(stats);return;
  }
  const Vec aim=tracking?selected.point:acquisition_point;
  if(acquiring||tracking)az=difference(bearing(aim-origin),heading);
  // Acquired tracking still respects the forward antenna field of regard.
  // A target crossing behind must coast/expire rather than being seen through
  // the aircraft by a scene query steered outside the physical radar sector.
  if(std::abs(az)>pi/3) {
    stats.contacts=tracks.contacts();stats.selected=selected;stats.selected_type=selected_type;stats.memory=memory;stats.acquiring=acquiring;
    std::lock_guard<std::mutex>lock(state_mutex);
    if(epoch.load()==generation)output=std::move(stats);return;
  }
  // Electronic pointing does not illuminate the angles between consecutive
  // commands. Search beam width is independent of a large steering jump.
  const double half=(acquiring||tracking)?1.65*pi/180:3*pi/180;
  const double look=-std::atan(origin.u/c.range)+c.elevation;
  const double half_el=(acquiring||tracking||!c.fan)?1.65*pi/180:std::max(.001,look+pi/2);
  const double elevation=(acquiring||tracking)?std::atan2(aim.u-origin.u,std::hypot(aim.n-origin.n,aim.e-origin.e)):(c.fan?-half_el*.5:look);
  const void *clip=volume(origin,heading+az,elevation,half,half_el);
  if(!clip)return;
  struct SearchState { Controls* controls;Output* stats;Vec origin,own_velocity;double heading{};unsigned own_id{},visited{},visibility{};double now{};bool tracking{};
    double nearest=1e6;Contact candidate{}; };
  SearchState context{&c,&stats,origin,own_velocity,heading,own_id,0,0,now,tracking};
  Query each=[state=&context](Scene& object) {
    auto& c=*state->controls;auto& stats=*state->stats;
    const auto& origin=state->origin;const double heading=state->heading;
    const unsigned own_id=state->own_id;const double now=state->now;const bool tracking=state->tracking;
    auto& candidate=state->candidate;auto& nearest=state->nearest;
    if(++state->visited>128){++stats.truncated;return 1;}
    ++stats.candidates;const auto object_id=id(object);
    if(!object_id||object_id==own_id)return 0;
    void *unit=moving(object);if(!unit||api.dead(unit))return 0;
    const auto type=api.type(unit);if(!type)return 0;
    if(acquiring||tracking){if(type[0]<1||type[0]>3||tracking&&object_id!=selected.id)return 0;}
    else if(c.sea?(type[0]!=3):(type[0]<1||type[0]>2||!api.flag(unit,32)))return 0;
    ++stats.ground_candidates;
    const auto speed=api.velocity(unit);if(!speed)return 0;
    const Vec velocity{speed->n,speed->u,speed->e};
    if(!acquiring&&!tracking&&!GroundMovingTargets::moving(velocity)){++stats.speed_rejects;return 0;}
    Vec point{};api.point(unit,&point);
    const auto relative=point-origin;
    if(!acquiring&&!tracking&&std::hypot(relative.n,relative.e)>c.range)return 0;
    // Native callback rejects contacts at/above -1deg even inside the frustum.
    if(std::atan2(relative.u,std::hypot(relative.n,relative.e))>=-pi/180)return 0;
    if(acquiring){const auto d=point-acquisition_point;if(std::abs(d.n)>500||std::abs(d.u)>500||std::abs(d.e)>500||length(d)>=nearest)return 0;}
    if(state->visibility>=16){++stats.truncated;return 0;}
    ++state->visibility;
    if(!visible(origin,point,object_id,own_id,stats))return 0;
    Contact hit{object_id,point,velocity,now,1,difference(bearing(relative),heading),std::hypot(relative.n,relative.e)};
    if(acquiring||tracking){if(!positive_response(unit)){++stats.rcs_rejects;return 0;}candidate=hit;nearest=length(point-acquisition_point);}
    else (void)measurements.queue(hit,origin,heading,c.resource,false,state->own_velocity);
    return 0;
  };
  using VolumeQuery=void(__fastcall*)(void*,const void*,unsigned,const Query&);
  void *manager=*api.manager;auto query=method<VolumeQuery>(manager,19);
  if(!query){stats.ready=false;stats.reason=5;return;}
  ++stats.queries;query(manager,clip,c.sea?34:32,each);
  if(context.candidate.id)(void)measurements.queue(context.candidate,origin,heading,c.resource,true,own_velocity);
  // 4A4B80 initializes the acquisition timer to 3 seconds; 4A02E0 falls
  // back to a fixed terrain designation only if the same terrain LOS passes.
  if(acquiring&&now-acquisition_time>=3){
    acquiring=false;fixed=terrain_visible(origin,acquisition_point);
    if(fixed){selected={0,acquisition_point,{},now};selected_type=3;}
  }
  stats.origin=origin;stats.heading=heading;stats.az=az;stats.dt=dt;stats.contacts=tracks.contacts();
  stats.selected=selected;stats.selected_type=selected_type;stats.memory=selected.id&&now-selected.stamp>=2*dt;stats.acquiring=acquiring;stats.fixed=fixed;
  std::lock_guard<std::mutex>lock(state_mutex);if(epoch.load()==generation)output=std::move(stats);
}
void update(EDPARAM &p) {
  api.initialize();const double now=api.ready?api.clock():-1;
  Controls c;const int mode=static_cast<int>(get(p,"F22_AG_MODE"));
  c.search=mode==2||mode==3||mode==4||mode==5;c.sea=mode==4||mode==5;c.ranging=mode==7;
  c.elevation=get(p,"F22_AG_VIDEO_ANTENNA_DEG")*pi/180;c.fan=get(p,"F22_AG_VIDEO_FAN")>.5;
  c.illuminated=get(p,"F22_AESA_SURFACE_SERVICE")>.5;
  c.resource=get(p,"F22_AESA_CONTROL_RESOURCE");
  c.request=get(p,"F22_AG_TRACK_REQUEST_ACTIVE")>.5;
  c.active=get(p,"HUD_MODE")==7&&get(p,"MAIN_POWER")>.5&&get(p,"RADAR_PWR")>.5&&
    get(p,"F22_AG_RADAR_OPERATING")>.5&&(c.search||c.request||c.ranging)&&
    (get(p,"F22_AG_SILENT")<.5||get(p,"F22_AG_ACTIVE")>.5);
  c.stamp=now;c.range=get(p,"F22_AG_RADAR_RANGE_NM")*1852;
  c.az=get(p,"F22_AESA_SURFACE_AZ");
  c.request_sequence=get(p,"F22_AG_TRACK_REQUEST_SEQUENCE");c.request=get(p,"F22_AG_TRACK_REQUEST_ACTIVE")>.5;
  c.request_point={get(p,"F22_AG_TRACK_REQUEST_NORTH"),get(p,"F22_AG_TRACK_REQUEST_ALTITUDE"),get(p,"F22_AG_TRACK_REQUEST_EAST")};
  Output result;{std::lock_guard<std::mutex>lock(state_mutex);controls=c;result=output;}
  const bool fresh=api.ready&&result.ready&&now-result.stamp>=-.05&&now-result.stamp<.5;
  put(p,"F22_AG_AGR_VALID",fresh&&c.active&&result.agr_valid?1:0);
  put(p,"F22_AG_AGR_RANGE_FT",result.agr_range*3.280839895);put(p,"F22_AG_AGR_VELOCITY_KT",result.agr_rate*1.94384449);
  put(p,"F22_AG_AGR_TIME",result.agr_stamp);
  put(p,"F22_AG_GMT_READY",fresh?1:0);put(p,"F22_AG_GMT_REASON",fresh?0:api.reason?api.reason:4);
  put(p,"F22_AG_GMT_LAST_TIME",result.stamp);put(p,"F22_AG_GMT_COUNT",fresh&&c.active?result.contacts.size():0);
  put(p,"F22_AG_GMT_QUERY_COUNT",result.queries);put(p,"F22_AG_GMT_CANDIDATES",result.candidates);
  put(p,"F22_AG_GMT_GROUND_CANDIDATES",result.ground_candidates);put(p,"F22_AG_GMT_TRUNCATED",result.truncated);
  put(p,"F22_AG_GMT_TERRAIN_REJECTS",result.terrain_rejects);put(p,"F22_AG_GMT_OBJECT_REJECTS",result.object_rejects);put(p,"F22_AG_GMT_SPEED_REJECTS",result.speed_rejects);
  put(p,"F22_AG_GMT_RCS_REJECTS",result.rcs_rejects);put(p,"F22_AG_GMT_ACTIVITY_DT",result.dt);
  const auto&t=result.selected;const bool tracked=fresh&&c.active&&(t.id||result.fixed);
  put(p,"F22_AG_NATIVE_TRACK_VALID",tracked?1:0);put(p,"F22_AG_NATIVE_TRACK_ID",tracked?t.id:0);
  put(p,"F22_AG_NATIVE_TRACK_REQUEST_SEQUENCE",fresh?result.request_sequence:-1);
  put(p,"F22_AG_NATIVE_TRACK_ACQUIRING",fresh&&c.active&&result.acquiring?1:0);
  put(p,"F22_AG_NATIVE_TRACK_MEMORY",tracked&&result.memory?1:0);
  put(p,"F22_AG_NATIVE_TRACK_TYPE",tracked?result.selected_type:0);
  put(p,"F22_AG_NATIVE_TRACK_TIME",t.stamp);
  put(p,"F22_AG_NATIVE_TRACK_MEASUREMENT_SOURCE",2);
  put(p,"F22_AG_NATIVE_TRACK_VELOCITY_VALID",tracked&&t.velocity_valid?1:0);
  put(p,"F22_AG_NATIVE_TRACK_FILTER_VALID",tracked&&t.filter_valid?1:0);
  put(p,"F22_AG_NATIVE_TRACK_POSITION_SIGMA_M",t.position_sigma_m);
  put(p,"F22_AG_NATIVE_TRACK_VELOCITY_SIGMA_MPS",t.velocity_sigma_mps);
  put(p,"F22_AG_NATIVE_TRACK_RANGE_RATE",t.range_rate);
  put(p,"F22_AG_NATIVE_TRACK_RATE_SIGMA_MPS",t.rate_sigma_mps);
  put(p,"F22_AG_NATIVE_TRACK_ASPECT",result.aspect);
  const double tv[]={t.point.n,t.point.u,t.point.e,t.velocity.n,t.velocity.u,t.velocity.e};
  const char*tn[]={"N","U","E","VN","VU","VE"};
  for(unsigned j=0;j<6;++j)put(p,std::string("F22_AG_NATIVE_TRACK_")+tn[j],tv[j]);
  for(std::size_t i=0;i<result.contacts.size()&&fresh&&c.active;++i) {
    const auto&contact=result.contacts[i];const auto prefix="F22_AG_GMT_"+std::to_string(i+1)+"_";
    put(p,prefix+"ID",contact.id);put(p,prefix+"TIME",contact.stamp);
    put(p,prefix+"AZ",contact.observed_az);put(p,prefix+"RANGE",contact.horizontal_range);
    const double values[]={contact.point.n,contact.point.u,contact.point.e,contact.velocity.n,contact.velocity.u,contact.velocity.e};
    const char*names[]={"N","U","E","VN","VU","VE"};
    for(unsigned j=0;j<6;++j)put(p,prefix+names[j],values[j]);
  }
}
}
