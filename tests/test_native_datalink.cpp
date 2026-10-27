// Actual native adapter receive path, synthetic radio messages (no running DCS).
#include "../EFM/source/NativeDatalink.cpp"
#include <cassert>
using namespace NativeDatalink;
namespace {
alignas(16) std::array<std::byte,800> self_object{},peer_object{};
unsigned char self_type[4]={1,1,1,77},peer_type[4]={1,1,1,77};
double test_time=20;bool enemy=false;int message_kind=23;unsigned decode_source=500;
int native_parse_calls=0,world_position_reads=0;
int extension_kind=0,fighter_extract_calls=0;
std::string fighter_body="10000,1,2,90,300,800,32767,7,48,75,4093";
int decode(void *p);
void native_text(StringView &v,const std::string &s){
  v.size=s.size();v.capacity=std::max(std::size_t(16),s.size());
  auto b=static_cast<char*>(std::malloc(v.capacity+1));std::memcpy(b,s.c_str(),s.size()+1);v.pointer=b;
}
int unpack_text(void *p){native_text(*static_cast<StringView*>(p),"0,"+fighter_body);return 1;}
int extension_of(const StringView&,StringView&v){native_text(v,fighter_body);return extension_kind;}
void extract_fighter(const StringView&,void*p){++fighter_extract_calls;decode_source=800;decode(p);}
void *find_peer(unsigned id){return id==200?peer_object.data():nullptr;}
int side(const void *p){return enemy&&p==peer_object.data()?2:1;}
const unsigned char *type_of(const void *p){return p==peer_object.data()?peer_type:self_type;}
void *group_of(void*){return self_object.data();}
double clock_now(){return test_time;}
bool parse_message(const StringView&){++native_parse_calls;return true;}
int kind_of(int){return message_kind;}
int decode(void *p){
  double values[]={10000,1,2,90,300};std::memcpy(p,values,sizeof values);
  std::memcpy(static_cast<char*>(p)+40,&decode_source,4);return 1;
}
void coordinates(double a,double b,Vec &v){v={a*1000,0,b*1000};}
Vec *forbidden_position(void*,Vec*){++world_position_reads;return nullptr;}
void deliver(const std::string &payload,unsigned source=200){
  alignas(8) std::array<std::byte,160> message{};std::memcpy(message.data(),&source,4);
  message[117]=std::byte{1};StringView v{};
  v.pointer=payload.data();v.size=payload.size();v.capacity=payload.size();
  std::memcpy(message.data()+120,&v,32);receive(nullptr,message.data());
}
struct List {void *head;std::size_t count;};List queue_fixture{};
void *queue_of(void*){return &queue_fixture;}
}
int main(){
  api.find=find_peer;api.coalition=side;api.type=type_of;api.group=group_of;
  api.clock=clock_now;api.parse=parse_message;api.kind=kind_of;
  api.track=api.ppli=decode;api.coordinates=coordinates;api.point=forbidden_position;
  api.free_text=unpack_text;api.extension=extension_of;api.fighter_track=extract_fighter;
  owner=self_object.data();own_id=100;constructed=true;
  deliver("F22IFDL1;500,20,10000,3000,2000,100,0,20,-1,0;");
  assert(reports.size()==1&&reports.at(500).link==1&&reports.at(500).reporter==200);
  assert(native_parse_calls==0&&world_position_reads==0);
  deliver("F22IFDL1;200,20,10000,3000,2000,100,0,20,1,1;");
  assert(reports.at(200).flight&&reports.at(200).affiliation==1);
  deliver("F22IFDL1;600,20,10000,3000,2000,0,0,0,1,1;");assert(!reports.contains(600));
  deliver("F22IFDL1;600,21,10000,3000,2000,0,0,0,-1,0;");assert(!reports.contains(600));
  deliver("F22IFDL1;600,-10,10000,3000,2000,0,0,0,-1,0;");assert(!reports.contains(600));
  deliver("F22IFDL1;600,20,10000,3000,2000,1600,0,0,-1,0;");assert(!reports.contains(600));
  enemy=true;deliver("F22IFDL1;600,20,10000,3000,2000,0,0,0,-1,0;");assert(!reports.contains(600));enemy=false;
  peer_type[3]=5;deliver("F22IFDL1;600,20,10000,3000,2000,0,0,0,-1,0;");assert(!reports.contains(600));peer_type[3]=77;
  test_time=21;peer_type[3]=5;deliver("native TADIL-J air track");
  auto &r=reports.at(500);assert(r.link==2&&r.position.n==1000&&r.position.u==3048&&r.position.e==2000);
  assert(std::abs(r.velocity.e-154.3333333333)<.00001&&r.affiliation==-1);
  assert(world_position_reads==0&&native_parse_calls==1);
  message_kind=16;deliver("native TADIL-J air PPLI");assert(reports.at(200).ppli&&reports.at(200).affiliation==1);
  message_kind=91;deliver("native fighter donation");
  assert(reports.at(800).link==2&&!reports.at(800).ppli&&fighter_extract_calls==1);
  extension_kind=1;deliver("unrelated native free text");assert(fighter_extract_calls==1);extension_kind=0;
  const auto valid_body=fighter_body;
  for(const auto &bad:{"10000,1,2,90,300,800", "10000,1,2,90,300,800,32767,7,48,75,4093 trailing",
                       "10000,1,2,90,300,800,32767,7,48,nan,4093", "10000,1,2,90,300,800.5,32767,7,48,75,4093"}) {
    fighter_body=bad;deliver("malformed native fighter donation");assert(fighter_extract_calls==1);
  }
  fighter_body=valid_body;assert(world_position_reads==0);
  decode_source=200;message_kind=23;deliver("native friendly participant surveillance");
  assert(!reports.at(200).ppli&&reports.at(200).affiliation==1&&"PPLI identity lost on surveillance update");
  // Ownship, unknown senders and unrecognized native message types stay absent.
  decode_source=100;message_kind=23;deliver("native TADIL-J own track");assert(!reports.contains(100));
  deliver("native TADIL-J missing sender",999);assert(world_position_reads==0);
  message_kind=99;auto before=reports.size();deliver("native TADIL-J non-track");assert(reports.size()==before);
  // Consume and free one real-layout native std::list node, including its
  // separately allocated UCRT string, without touching another terminal.
  api.queue=queue_of;peer_type[3]=77;
  auto head=static_cast<char*>(std::malloc(16));auto node=static_cast<char*>(std::calloc(1,176));
  std::memcpy(head,&node,8);std::memcpy(head+8,&node,8);std::memcpy(node,&head,8);std::memcpy(node+8,&head,8);
  unsigned sender=200;std::memcpy(node+16,&sender,4);node[133]=1;
  const std::string payload="F22IFDL1;700,21,10000,3000,2000,0,0,0,-1,0;";
  auto buffer=static_cast<char*>(std::malloc(payload.size()+1));std::memcpy(buffer,payload.c_str(),payload.size()+1);
  StringView text{};text.pointer=buffer;text.size=payload.size();text.capacity=payload.size();std::memcpy(node+136,&text,32);
  queue_fixture={head,1};drain();assert(queue_fixture.count==0&&reports.contains(700));
  void *next{};std::memcpy(&next,head,8);assert(next==head);std::free(head);
  constructed=false;owner=nullptr;reports.clear();
  std::puts("Native datalink: J3.2/J2.2 and native fighter extension decode, strict malformed-envelope rejection, owned strings/queue, peer filtering and no target-truth reads PASS");
}
