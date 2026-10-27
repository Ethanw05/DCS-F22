// GPL-3.0-or-later. Independent terminal over the audited shared DCS radio ABI.
// No aircraft-module dependency, mission scripts, export truth or world scans.
#include "NativeDatalink.h"
#include <Cockpit/CockpitAPI_Declare.h>
#include <Windows.h>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <sstream>
#include <string>
#include <vector>
#include <algorithm>

namespace NativeDatalink { namespace {
struct Vec { double n{},u{},e{}; };
struct StringView {
  union { const char *pointer; char inline_text[16]; };
  std::size_t size{},capacity{15};
};
static_assert(sizeof(StringView)==32);
struct NativeText : StringView {
  ~NativeText() { if(capacity>15)std::free(const_cast<char*>(pointer)); }
};
bool readable(const void *p,std::size_t n) {
  MEMORY_BASIC_INFORMATION m{};
  if(!p||!VirtualQuery(p,&m,sizeof m))return false;
  auto a=reinterpret_cast<std::uintptr_t>(p),b=reinterpret_cast<std::uintptr_t>(m.BaseAddress);
  return m.State==MEM_COMMIT&&!(m.Protect&(PAGE_GUARD|PAGE_NOACCESS))&&n<=m.RegionSize&&a>=b&&a-b<=m.RegionSize-n;
}
template<class T> bool load(const void *p,T &v) {
  if(!readable(p,sizeof v))return false;std::memcpy(&v,p,sizeof v);return true;
}
template<class F> F method(void *p,unsigned i) {
  void **v{};if(!load(p,v)||!readable(v+i,sizeof(void*)))return nullptr;
  return reinterpret_cast<F>(v[i]);
}
bool profile(HMODULE m,DWORD stamp,DWORD size) {
  IMAGE_DOS_HEADER d{};IMAGE_NT_HEADERS64 p{};
  if(!load(m,d)||d.e_magic!=IMAGE_DOS_SIGNATURE||d.e_lfanew<0||!load(reinterpret_cast<char*>(m)+d.e_lfanew,p))return false;
  return p.Signature==IMAGE_NT_SIGNATURE&&p.FileHeader.TimeDateStamp==stamp&&p.OptionalHeader.SizeOfImage==size;
}
bool finite(double x) {return std::isfinite(x)&&std::abs(x)<1e9;}
bool valid(const Vec &v) {return finite(v.n)&&finite(v.u)&&finite(v.e);}
struct Report {
  unsigned source{},reporter{};int link{2};double time{};Vec position{},velocity{};
  int affiliation{-1};bool flight{},ppli{};
};
// The common AI terminal can space surveillance reports about a minute apart.
// Retain bounded SA memory; the original observation time is never renewed.
double lifetime(const Report &q) {return q.ppli?26.:75.;}
std::map<unsigned,Report> reports;
std::map<unsigned,Report> participants;
std::map<std::string,void*> handles;
double get(EDPARAM &p,const std::string &n) {auto &h=handles[n];if(!h)h=p.getParamHandle(n.c_str());return p.getParamNumber(h);}
void put(EDPARAM &p,const std::string &n,double v) {auto &h=handles[n];if(!h)h=p.getParamHandle(n.c_str());p.setParamNumber(h,v);}

struct API {
  using Construct=void*(__fastcall*)(void*,void*,unsigned,unsigned,void*,unsigned,void*);
  using RadioConstruct=void*(__fastcall*)(void*,bool);
  using StatusConstruct=void*(__fastcall*)(void*,unsigned,void*);
  using Method=void(__fastcall*)(void*);
  using LinkSet=void(__fastcall*)(void*,void*);
  using Object=void*(__cdecl*)();
  using Find=void*(__fastcall*)(unsigned);
  using Ptr=void*(__fastcall*)(void*);
  using Transiver=void*(__fastcall*)(void*,int);
  using Devices=void(__fastcall*)(void*,double,double);
  using Scalar=void(__fastcall*)(void*,double);
  using Set=void(__fastcall*)(void*,bool);
  using SetBits=void(__fastcall*)(void*,const unsigned&);
  using Modulation=void(__fastcall*)(void*,int);
  using Selectivity=void(__fastcall*)(void*,bool,bool);
  using Coalition=int(__fastcall*)(const void*);
  using Type=const unsigned char*(__fastcall*)(const void*);
  using Coordinates=void(__cdecl*)(double,double,Vec&);
  using Parse=bool(__cdecl*)(const StringView&);
  using Unpack=int(__cdecl*)(void*);
  using Extension=int(__cdecl*)(const StringView&,StringView&);
  using FighterTrack=void(__cdecl*)(const StringView&,void*);
  using Kind=int(__cdecl*)(int);
  using Clock=double(__cdecl*)();
  using Point=Vec*(__fastcall*)(void*,Vec*);
  using Velocity=const float*(__fastcall*)(const void*);
  using Send=void(__fastcall*)(void*,const void*);
  Construct construct{};RadioConstruct radio_construct{};StatusConstruct status_construct{};
  Method destroy{},link_construct{},link_destroy{},radio_update{},radio_destroy{};
  Ptr queue{};
  LinkSet link_set{},body{};Object aircraft{};Find find{};Ptr communicator{},group{};
  Transiver transiver{};Devices devices{};Scalar frequency{},bandwidth{};Set receiver{},transmitter{};
  Modulation modulation{};Selectivity selectivity{};Coalition coalition{};Type type{};
  Coordinates coordinates{};Parse parse{};Unpack ppli{},track{};Kind kind{};Clock clock{};
  Unpack free_text{};Extension extension{};FighterTrack fighter_track{};
  SetBits receivers{},defaults{};
  Point point{};Velocity velocity{};Send send{};void ***contexts{};
  bool ready{};int reason{1};
  template<class F> bool bind(HMODULE m,F &f,const char *n) {f=reinterpret_cast<F>(GetProcAddress(m,n));return f!=nullptr;}
  void resolve() {
    if(ready||reason>1)return;
    auto c=GetModuleHandleW(L"CockpitBase.dll"),r=GetModuleHandleW(L"wRadio.dll"),
      g=GetModuleHandleW(L"WorldGeneral.dll"),e=GetModuleHandleW(L"edCore.dll"),w=GetModuleHandleW(L"World.dll");
    if(!c||!r||!g||!e||!w)return;
    if(!profile(c,0x6ac12468,0x59a000)||!profile(r,0x6aae1f77,0x144000)||
       !profile(g,0x6ac122f4,0x125b000)||!profile(e,0x6aae1d76,0xaad000)){reason=2;return;}
    bool ok=true;
#define B(M,F,N) ok=bind(M,F,N)&&ok
    B(r,construct,"??0wDatalinkCommunicator@@QEAA@V?$cPointerTemplate@VMovingObject@@@@IIPEAVIwTransiver@@W4DatalinkTypes@@PEAVNetSendTransiverStatus@0@@Z");
    B(r,destroy,"??1wDatalinkCommunicator@@UEAA@XZ");
    B(r,radio_construct,"??0wTransiverOwner@@QEAA@_N@Z");
    B(r,radio_destroy,"??1wTransiverOwner@@UEAA@XZ");
    B(r,status_construct,"??0DlinkNetSendTransiverStatusCmn@@QEAA@W4DatalinkTypes@@V?$cPointerTemplate@VMovingObject@@@@@Z");
    B(r,queue,"?get_msgs_gueue@wDatalinkCommunicator@@UEAAAEAV?$list@Udatalink_msg@@V?$allocator@Udatalink_msg@@@ed@@@ed@@XZ");
    B(r,receivers,"?setEnabledReceiverBits@wDatalinkCommunicator@@UEAAXAEBV?$bitset@$0CA@@std@@@Z");
    B(r,defaults,"?setDefaultTransceiversBits@wCommunicator@@UEAAXAEBV?$bitset@$0CA@@std@@@Z");
    B(e,link_construct,"??0LinkBase@@QEAA@XZ");B(e,link_destroy,"??1LinkBase@@QEAA@XZ");
    B(e,link_set,"?Set@LinkBase@@IEAAXPEAVLinkHost@@@Z");
    B(c,aircraft,"?c_LA@cockpit@@YAPEAVIwoLA@@XZ");
    B(r,communicator,"?getCommunicator@wDatalinkCommunicator@@UEAAAEAVwCommunicator@@XZ");
    B(r,transiver,"?getTransiver@wCommunicator@@QEBAPEAVIwTransiver@@H@Z");
    B(r,devices,"?setDevices@wTransiver@@UEAAXNN@Z");
    B(r,body,"?setBody@wTransiver@@UEAAXPEAVviObject@@@Z");
    B(r,frequency,"?setExactFrequency@wTransiver@@UEAAXN@Z");
    B(r,bandwidth,"?setBandWidth@wTransiver@@UEAAXN@Z");
    B(r,modulation,"?setModulation@wTransiver@@UEAAXW4wModulation@@@Z");
    B(r,selectivity,"?setUseFrequencySelectivity@wTransiver@@UEAAX_N0@Z");
    B(r,receiver,"?setReceiverOnOff@wTransiver@@UEAAX_N@Z");
    B(r,transmitter,"?setTransmitterOnOff@wTransiver@@UEAAX_N@Z");
    B(r,radio_update,"?update@wTransiver@@UEAAXXZ");
    B(r,send,"?send_msg@wDatalinkCommunicator@@UEAAXAEBUdatalink_msg@@@Z");
    B(g,coalition,"?Coalition@MovingObject@@QEBA?BW4wcCoalitionName@@XZ");
    B(g,type,"?Type@MovingObject@@QEBAAEBVwsType@@XZ");
    B(g,group,"?getGroup@@YAPEAVwControl@@PEBVMovingObject@@@Z");
    B(g,coordinates,"?GetCoords@MapCoords@MapCoordsSpace@@SAXNNAEAVVec3d@osg@@@Z");
    B(g,point,"?GetPoint@MovingObject@@UEAA?AVVec3d@osg@@XZ");
    B(g,velocity,"?VectorVelocity@MovingObject@@UEBAAEBVVec3f@osg@@XZ");
    B(r,parse,"?parse@msgParser@TADIL_J@@SA_NAEBV?$basic_string@D@ed@@@Z");
    B(r,kind,"?getInt@msgParser@TADIL_J@@SA?BHW4DataElement@2@@Z");
    B(r,ppli,"?unpackAirPPLI@msgPacker@TADIL_J@@SAHAEAUDataAirPPLI@2@@Z");
    B(r,track,"?unpackAirTrack@msgPacker@TADIL_J@@SAHAEAUDataAirTrack@2@@Z");
    B(r,free_text,"?unpackFreeText@msgPacker@TADIL_J@@SAHAEAV?$basic_string@D@ed@@@Z");
    B(r,extension,"?parseExtensionMessage@TADIL_J@@YA?AW4ExtensionMessage@1@AEBV?$basic_string@D@ed@@AEAV34@@Z");
    B(r,fighter_track,"?extract_FighterToFighterAirTrack@TADIL_J@@YAXAEBV?$basic_string@D@ed@@AEAUDataAirTrack@1@@Z");
    B(w,clock,"?GetModelTime@wTime@@SANXZ");
#undef B
    contexts=reinterpret_cast<void***>(GetProcAddress(c,"?contexts_ptr@ccCockpitContext@cockpit@@0PAPEAV12@A"));
    find=reinterpret_cast<Find>(reinterpret_cast<char*>(c)+0x2165d0);
    ready=ok&&contexts;reason=ready?0:3;
  }
} api;
alignas(16) std::array<std::byte,0x340> terminal{};
alignas(16) std::array<std::byte,0x2b8> transiver_storage{};
alignas(16) std::array<std::byte,40> status_storage{};
void *radio{},*owner{},*registered_interface{};unsigned own_id{};bool constructed{},registered{};
double previous=-1,last_send=-1;unsigned long long sequence{},epoch{1},received{},sent{},rejected{},raw_received{};
unsigned last_sender{};int last_kind{-1};
int published_rx=-1,published_tx=-1;

void accept(Report q,double now) {
  if(!q.source||q.source==own_id||!q.reporter||!finite(q.time)||q.time<0||now-q.time<-.05||now-q.time>lifetime(q)||
     !valid(q.position)||!valid(q.velocity)||std::hypot(q.velocity.n,q.velocity.u,q.velocity.e)>1500)return;
  auto i=reports.find(q.source);
  if(i!=reports.end()&&(i->second.time>q.time||(i->second.time==q.time&&i->second.link<q.link)))return;
  if(i==reports.end()&&reports.size()>=64)return;
  if(q.ppli)participants[q.source]=q;
  else if(auto p=participants.find(q.source);p!=participants.end()&&now-p->second.time<=26)q.affiliation=1;
  reports[q.source]=q;
}
bool unpack_fighter_track(void *decoded) {
  // Native packFighterToFighterAirTrack uses free text (kind 91),
  // extension 0. The native extractor itself does not report parse failures.
  // Validate the inspected eleven-number CSV envelope before invoking it.
  NativeText free{},body{};
  if(!api.free_text(&free)||api.extension(free,body)!=0||body.size==0||body.size>1024||body.capacity<body.size)return false;
  auto data=body.capacity>15?body.pointer:body.inline_text;
  if(!readable(data,body.size))return false;
  std::istringstream input(std::string(data,body.size));
  for(int i=0;i<11;++i) {
    double value{};char separator{};
    if(!(input>>value)||!finite(value)||(i>=5&&std::floor(value)!=value))return false;
    if(i<10&&(!(input>>separator)||separator!=','))return false;
  }
  input>>std::ws;if(!input.eof())return false;
  api.fighter_track(body,decoded);return true;
}
void receive(void*,const void *message) {

  ++raw_received;
  if(!constructed||!owner||!readable(message,160))return;
  auto b=static_cast<const char*>(message);unsigned sender{};std::memcpy(&sender,b,4);
  last_sender=sender;
  if(!sender||sender==own_id)return;
  // Resolve ONLY the address of this received sender, for network membership.
  // Target position/velocity always come from the message, never its world object.
  void *peer=api.find(sender);
  if(!readable(peer,640)||api.coalition(peer)!=api.coalition(owner)){++rejected;return;}
  StringView text{};std::memcpy(&text,b+120,32);
  if(text.size==0||text.size>16384||text.capacity<text.size)return;
  auto data=text.capacity>15?text.pointer:text.inline_text;
  if(!readable(data,text.size)||b[117]==0)return;
  const double now=api.clock();
  if(text.size>=9&&std::memcmp(data,"F22IFDL1;",9)==0) {
    const auto a=api.type(owner),p=api.type(peer);
    if(!readable(a,4)||!readable(p,4)||std::memcmp(a,p,4)!=0){++rejected;return;}
    std::istringstream input(std::string(data+9,text.size-9));
    std::string row;unsigned count=0;
    while(std::getline(input,row,';')&&count++<33) {
      std::replace(row.begin(),row.end(),',',' ');std::istringstream fields(row);
      Report q;q.reporter=sender;q.link=1;int ppli{},affiliation{};
      if(!(fields>>q.source>>q.time>>q.position.n>>q.position.u>>q.position.e>>q.velocity.n>>q.velocity.u>>q.velocity.e>>affiliation>>ppli))continue;
      fields>>std::ws;if(!fields.eof()||(ppli!=0&&ppli!=1)||(affiliation!=-1&&affiliation!=0&&affiliation!=1))continue;
      q.ppli=ppli==1;q.affiliation=affiliation;
      if(q.ppli) {if(q.source!=sender)continue;q.affiliation=1;q.flight=api.group(peer)==api.group(owner)&&api.group(owner)!=nullptr;}
      accept(q,now);
    }
    ++received;return;
  }
  // Native TADIL-J decoder state is used serially in the cockpit callback.
  if(!api.parse(text))return;
  const int kind=api.kind(1);last_kind=kind;alignas(16) std::array<std::byte,96> decoded{};
  const bool ppli=kind==16;
  if(kind==91) {if(!unpack_fighter_track(decoded.data()))return;}
  else if((!ppli&&kind!=23)||!(ppli?api.ppli(decoded.data()):api.track(decoded.data())))return;
  auto d=decoded.data();Report q;q.reporter=sender;q.time=now;q.ppli=ppli;
  std::memcpy(&q.source,d+40,4);
  double altitude{},latitude{},longitude{},course{},speed{};
  std::memcpy(&altitude,d,8);std::memcpy(&latitude,d+8,8);std::memcpy(&longitude,d+16,8);
  std::memcpy(&course,d+24,8);std::memcpy(&speed,d+32,8);
  if(!finite(altitude)||!finite(latitude)||!finite(longitude)||!finite(course)||!finite(speed)||
     std::abs(latitude)>180||std::abs(longitude)>360||speed<0||speed>3000)return;
  api.coordinates(latitude,longitude,q.position);q.position.u=altitude*.3048;
  const double angle=course*.017453292519943295;q.velocity={std::cos(angle)*speed*.5144444444444444,0,std::sin(angle)*speed*.5144444444444444};
  const auto own_type=api.type(owner),peer_type=api.type(peer);
  const bool raptor=readable(own_type,4)&&readable(peer_type,4)&&std::memcmp(own_type,peer_type,4)==0;
  // AI Raptors use DCS's common terminal rather than running our player EFM.
  // Treat their native peer reports as the mod's IFDL channel. This is a
  // semantic adapter, not an implementation of the classified RF waveform.
  q.link=raptor?1:2;
  if(ppli) {q.source=sender;q.affiliation=1;q.flight=raptor&&api.group(peer)==api.group(owner)&&api.group(owner)!=nullptr;}
  // J3.2 identity is retained conservatively until its enumeration is qualified.
  accept(q,now);++received;
}
// Only our terminal's bounded native queue is consumed. Both sides use the
// qualified /MD UCRT malloc/free ABI (wRadio's heap import was checked).
void drain() {
  struct List {void *head;std::size_t count;};
  auto list=static_cast<List*>(api.queue(terminal.data()));
  if(!readable(list,sizeof(List))||list->count>100||!readable(list->head,16))return;
  while(list->count) {
    void *node{};std::memcpy(&node,list->head,8);
    if(node==list->head||!readable(node,176))return;
    auto bytes=static_cast<char*>(node);void *next{},*prev{};
    std::memcpy(&next,bytes,8);std::memcpy(&prev,bytes+8,8);
    if(!readable(next,16)||!readable(prev,16))return;
    receive(nullptr,bytes+16);
    StringView text{};std::memcpy(&text,bytes+136,32);
    if(text.capacity>15&&!readable(text.pointer,text.size+1))return;
    std::memcpy(prev,&next,8);std::memcpy(static_cast<char*>(next)+8,&prev,8);--list->count;
    if(text.capacity>15)std::free(const_cast<char*>(text.pointer));
    std::free(node);
  }
}

bool start(void *aircraft) {
  void **contexts{};if(!load(api.contexts,contexts)||!readable(contexts,6*sizeof(void*)))return false;
  auto cockpit_interface=contexts[2];
  using Register=void(__fastcall*)(void*,unsigned char,void*);
  auto reg=method<Register>(cockpit_interface,37);if(!reg)return false;
  alignas(8) std::array<std::byte,24> link{};api.link_construct(link.data());
  api.link_set(link.data(),static_cast<char*>(aircraft)+256);
  api.status_construct(status_storage.data(),2,link.data());
  radio=api.radio_construct(transiver_storage.data(),false);
  api.body(radio,aircraft);api.devices(radio,.0000025,100.);
  api.frequency(radio,1092500000.);api.bandwidth(radio,3000000.);
  api.modulation(radio,0);api.selectivity(radio,false,false);
  api.link_construct(link.data());api.link_set(link.data(),static_cast<char*>(aircraft)+256);
  api.construct(terminal.data(),link.data(),0x400,0x400,radio,2,status_storage.data());
  // The by-value cPointerTemplate is consumed by the native constructor.
  constructed=true;owner=aircraft;registered_interface=cockpit_interface;
  std::memcpy(&own_id,static_cast<char*>(aircraft)+28,4);
  reg(cockpit_interface,2,terminal.data());
  registered=true;
  return true;
}
void transmit(EDPARAM &p,double now) {
  if(last_send>=0&&now-last_send<1)return;
  last_send=now;
  std::ostringstream text;text.precision(15);text<<"F22IFDL1;";
  Vec position{};api.point(owner,&position);const float *velocity=api.velocity(owner);
  if(!valid(position)||!readable(velocity,12))return;
  text<<own_id<<','<<now<<','<<position.n<<','<<position.u<<','<<position.e<<','<<velocity[0]<<','<<velocity[1]<<','<<velocity[2]<<",1,1;";
  const auto seq=get(p,"F22_RADAR_TACTICAL_SEQUENCE"),stamp=get(p,"F22_RADAR_TACTICAL_TIME");
  if(finite(stamp)&&now-stamp>=-.05&&now-stamp<=.25) {
    unsigned count=0;
    for(unsigned i=1;i<=64&&count<32;++i) {
      char prefix[64];std::snprintf(prefix,sizeof prefix,"F22_RADAR_TACTICAL_%02u_",i);std::string s=prefix;
      if(get(p,s+"VALID")<.5||get(p,s+"POSITION_VALID")<.5)continue;
      const double age=get(p,s+"AGE");if(!finite(age)||age<0||age>6)continue;
      const int affiliation=get(p,s+"FRIENDLY")>.5?1:get(p,s+"HOSTILE")>.5?0:-1;
      text<<static_cast<unsigned>(get(p,s+"SOURCE"))<<','<<stamp-age;
      for(auto field:{"N","U","E","VN","VU","VE"})text<<','<<get(p,s+field);
      text<<','<<affiliation<<",0;";++count;
    }
    if(seq!=get(p,"F22_RADAR_TACTICAL_SEQUENCE"))return;
  }
  auto payload=text.str();alignas(8) std::array<std::byte,160> message{};
  std::memcpy(message.data(),&own_id,4);message[117]=std::byte{1};
  StringView v{};v.pointer=payload.data();v.size=payload.size();v.capacity=payload.size();
  std::memcpy(message.data()+120,&v,sizeof v);
  // Only our own PPLI and genuine onboard radar reports; never relay remote tracks.
  api.send(terminal.data(),message.data());++sent;
}
} // namespace
void reset() {
  if(constructed) {
    if(radio)api.receiver(radio,false);
    using Register=void(__fastcall*)(void*,unsigned char,void*);
    if(registered)if(auto reg=method<Register>(registered_interface,37))reg(registered_interface,2,nullptr);
    api.destroy(terminal.data());
    api.radio_destroy(transiver_storage.data());
    using DestroyStatus=void(__fastcall*)(void*,unsigned);
    if(auto destroy_status=method<DestroyStatus>(status_storage.data(),0))destroy_status(status_storage.data(),0);
  }
  constructed=registered=false;radio=owner=registered_interface=nullptr;own_id=0;
  reports.clear();participants.clear();previous=last_send=-1;received=sent=rejected=0;++epoch;
  published_rx=published_tx=-1;raw_received=0;last_sender=0;last_kind=-1;
}
void update(EDPARAM &p) {
  api.resolve();put(p,"F22_DATALINK_NATIVE_READY",api.ready?1:0);put(p,"F22_DATALINK_NATIVE_REASON",api.reason);
  if(!api.ready)return;
  auto la=api.aircraft();using Own=void*(__fastcall*)(void*);
  auto own_get=method<Own>(la,40);auto aircraft=own_get?own_get(la):nullptr;const double now=api.clock();
  if(!finite(now)||!readable(aircraft,640))return;
  if((previous>=0&&now<previous)||(owner&&owner!=aircraft))reset();previous=now;
  const bool power=get(p,"MAIN_POWER")>.5&&get(p,"F22_DATALINK_ENABLE")>.5;
  if(power&&!constructed&&!start(aircraft)){put(p,"F22_DATALINK_NATIVE_REASON",4);return;}
  if(constructed) {
    api.receiver(radio,power);api.radio_update(radio);drain();
    const bool tx=power&&get(p,"F22_IFDL_ENABLE")>.5;
    api.transmitter(radio,tx);
    if(published_rx!=int(power)) {const unsigned bits=power?1:0;api.receivers(terminal.data(),bits);published_rx=int(power);}
    if(published_tx!=int(tx)) {
      const unsigned value=tx?1:0;api.defaults(api.communicator(terminal.data()),value);
      published_tx=int(tx);
    }
    if(power&&get(p,"F22_IFDL_ENABLE")>.5)transmit(p,now);
  }
  if(!power){reports.clear();participants.clear();}
  for(auto i=participants.begin();i!=participants.end();) {
    if(now-i->second.time>26||now<i->second.time-.05)i=participants.erase(i);else ++i;
  }
  for(auto i=reports.begin();i!=reports.end();) {
    if(now-i->second.time>lifetime(i->second)||now<i->second.time-.05||(i->second.link==1&&get(p,"F22_IFDL_ENABLE")<.5))i=reports.erase(i);
    else ++i;
  }
  put(p,"F22_DL_RX_SEQUENCE",0);unsigned index=0;
  for(const auto &[id,q]:reports) {
    char prefix[48];std::snprintf(prefix,sizeof prefix,"F22_DL_RX_%02u_",++index);std::string s=prefix;
    const std::pair<const char*,double> fields[]={{"SOURCE",double(q.source)},{"REPORTER",double(q.reporter)},
      {"LINK",double(q.link)},{"TIME",q.time},{"N",q.position.n},{"U",q.position.u},{"E",q.position.e},
      {"VN",q.velocity.n},{"VU",q.velocity.u},{"VE",q.velocity.e},{"AFFILIATION",double(q.affiliation)},
      {"FLIGHT",q.flight?1.:0.},{"PPLI",q.ppli?1.:0.}};
    for(const auto &[key,value]:fields)put(p,s+key,value);
  }
  put(p,"F22_DL_RX_COUNT",index);put(p,"F22_DL_RX_TIME",now);put(p,"F22_DL_RX_OWN",own_id);
  put(p,"F22_DL_RX_EPOCH",double(epoch));put(p,"F22_DL_RX_SEQUENCE",double(++sequence));
  put(p,"F22_DATALINK_RX_MESSAGES",double(received));put(p,"F22_IFDL_TX_MESSAGES",double(sent));
  put(p,"F22_DATALINK_REJECTED",double(rejected));
  put(p,"F22_DATALINK_RAW_MESSAGES",double(raw_received));
  put(p,"F22_DATALINK_LAST_SENDER",last_sender);put(p,"F22_DATALINK_LAST_KIND",last_kind);
}
} // namespace NativeDatalink
