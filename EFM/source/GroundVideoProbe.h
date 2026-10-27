// GPL-3.0-or-later. Opt-in raw GPU statistics; never changes engine textures.
#pragma once
#include <Windows.h>
#include <d3d11.h>
#include <d3d10.h>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <functional>
#include <string>
#include <sstream>
#include <mutex>
#include <array>
namespace GroundVideoProbe {
inline std::atomic<int> status{}, width{}, height{}, format{}, samples{}, nonzero{}, render_thread{};
inline std::atomic<int> selected_target{},observed_target{};
inline constexpr const char *targets[]={"mfd8","RadarOrtho","RadarOrthoDepth","RadarTemp0","RadarTemp1","RadarTemp2","RadarShadowmap"};
inline std::atomic<double> minimum{}, maximum{}, mean{}, variance{};
inline std::array<std::atomic<int>,3> channel_nonzero{};
inline std::array<std::atomic<double>,3> channel_mean{},channel_max{};
inline std::atomic<double> observed_time{};
inline std::atomic<std::uint64_t> observations{}, changes{}, hash{};
inline std::mutex resources_mutex;
inline std::string resources;
// Compact numeric capture for registration/continuity analysis, opt-in only.
// Values are green/first-channel radiance in 1/128 steps, row-major 64x64.
struct Frame {double time{},north{},east{},heading{},range{};};
inline std::string grid;
inline bool version(HMODULE module, DWORD stamp, DWORD size) {
  if (!module) return false;
  auto b=reinterpret_cast<const unsigned char *>(module);
  auto dos=reinterpret_cast<const IMAGE_DOS_HEADER *>(b);
  if (dos->e_magic!=IMAGE_DOS_SIGNATURE || dos->e_lfanew<0) return false;
  auto pe=reinterpret_cast<const IMAGE_NT_HEADERS64 *>(b+dos->e_lfanew);
  return pe->Signature==IMAGE_NT_SIGNATURE && pe->FileHeader.TimeDateStamp==stamp && pe->OptionalHeader.SizeOfImage==size;
}
inline bool read(std::uintptr_t p, void *out, std::size_t size) {
  MEMORY_BASIC_INFORMATION m{};
  if (!p || !VirtualQuery(reinterpret_cast<void *>(p),&m,sizeof(m)) || m.State!=MEM_COMMIT || m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) return false;
  const auto start=reinterpret_cast<std::uintptr_t>(m.BaseAddress);
  if (p<start || size>m.RegionSize || p-start>m.RegionSize-size) return false;
  std::memcpy(out,reinterpret_cast<void *>(p),size);return true;
}
template<class T> inline bool read(std::uintptr_t p,T &out) {return read(p,&out,sizeof(out));}
inline double half(std::uint16_t h) {
  const int sign=h&0x8000?-1:1, exponent=(h>>10)&31, fraction=h&1023;
  if (exponent==31) return 0;
  return sign*std::ldexp(exponent?1.+fraction/1024.:fraction/1024.,exponent?exponent-15:-14);
}
inline double unsigned_float(unsigned value,unsigned mantissa) {
  const unsigned exponent=value>>mantissa,fraction=value&((1u<<mantissa)-1);
  if(exponent==31)return 0;
  return std::ldexp(exponent?1.+fraction/double(1u<<mantissa):fraction/double(1u<<mantissa),exponent?int(exponent)-15:-14);
}
struct State {
  ID3D11Texture2D *staging{};
  double last=-1;
  int target{};
  double stamp{};
  Frame frame{};
  ~State(){if(staging)staging->Release();}
};
inline thread_local State state;
// Called only from the owned indicator's render collection callback. Context
// work is allowed on the engine's actual render thread, or under its existing
// D3D multithread lock. It never enables protection or changes render state.
inline void sample(Frame frame) {
  const double now=frame.time;
  if (now<state.last)state.last=-1;
  if (now-state.last<1) return;state.last=now;
  auto backend=GetModuleHandleW(L"dx11backend.dll"),renderer=GetModuleHandleW(L"Renderer.dll");
  if (!version(backend,0x6aae1d9d,0x199000) || !version(renderer,0x6aae1d95,0x1f000)) {status=2;return;}
  auto global=GetProcAddress(renderer,"?pRenderApi@RenderAPI@@3PEAUIRenderAPI@1@EA");
  std::uintptr_t object{},table{};
  if (!read(reinterpret_cast<std::uintptr_t>(global),object) || !read(object,table)) {status=3;return;}
  if (table!=reinterpret_cast<std::uintptr_t>(GetProcAddress(backend,"??_7DX11Renderer@RenderAPI@@6B@"))) {status=4;return;}
  using GetTarget=void *(__fastcall *)(void *,std::uintptr_t *,const char *);
  using GetDevice=ID3D11Device *(__fastcall *)(void *);
  using GetContext=ID3D11DeviceContext *(__fastcall *)(void *);
  auto target=reinterpret_cast<GetTarget>(GetProcAddress(backend,"?getRenderTargetInternal@DX11Renderer@RenderAPI@@AEAA?AV?$Ptr@UITexture@RenderAPI@@UDeleter@12@@ed@@PEBD@Z"));
  auto device=reinterpret_cast<GetDevice>(GetProcAddress(backend,"?getDevice@DX11Renderer@RenderAPI@@QEAAPEAUID3D11Device@@XZ"));
  auto context=reinterpret_cast<GetContext>(GetProcAddress(backend,"?getDeviceContext@DX11Renderer@RenderAPI@@QEAAPEAUID3D11DeviceContext@@XZ"));
  if (!target || !device || !context) {status=2;return;}
  auto dev=device(reinterpret_cast<void *>(object));auto ctx=context(reinterpret_cast<void *>(object));
  if (!dev || !ctx) {status=7;return;}
  using InRenderThread=bool(__cdecl *)();
  auto in_render=reinterpret_cast<InRenderThread>(GetProcAddress(GetModuleHandleW(L"EDCore.dll"),"?inRenderThread@RenderingThread@ed@@YA_NXZ"));
  const bool native_render_thread=in_render && in_render();render_thread=native_render_thread?1:0;
  ID3D10Multithread *lock{};
  ctx->QueryInterface(__uuidof(ID3D10Multithread),reinterpret_cast<void **>(&lock));
  const bool protected_context=lock && lock->GetMultithreadProtected();
  if (!protected_context && !native_render_thread) {if(lock)lock->Release();status=14;return;}
  if(protected_context)lock->Enter();
  struct Unlock {ID3D10Multithread *p;bool entered;~Unlock(){if(p){if(entered)p->Leave();p->Release();}}} unlock{lock,protected_context};
  {
    std::lock_guard<std::mutex> hold(resources_mutex);
    if(resources.empty()) {
      using List=const char *(__fastcall *)(void *);using Free=void(__fastcall *)(void *,const char *);
      auto list=reinterpret_cast<List>(GetProcAddress(backend,"?getResourcesList@DX11Renderer@RenderAPI@@UEAAPEBDXZ"));
      auto free=reinterpret_cast<Free>(GetProcAddress(backend,"?freeStringMem@DX11Renderer@RenderAPI@@UEAAXPEBD@Z"));
      if(list && free)if(auto text=list(reinterpret_cast<void *>(object))) {
        std::istringstream input(text);std::string line;
        while(std::getline(input,line))if(line.find("adar")!=std::string::npos || line.find("mfd")!=std::string::npos || line.find("rtho")!=std::string::npos) {
          if(resources.size()+line.size()>16000)break;resources+=line+'\n';
        }
        free(reinterpret_cast<void *>(object),text);
        if(resources.empty())resources="No radar/MFD/ortho names in backend resource inventory";
      }
    }
  }
  if (state.staging) {
    D3D11_MAPPED_SUBRESOURCE mapped{};
    auto hr=ctx->Map(state.staging,0,D3D11_MAP_READ,D3D11_MAP_FLAG_DO_NOT_WAIT,&mapped);
    if (hr==DXGI_ERROR_WAS_STILL_DRAWING) {status=10;return;}
    if (SUCCEEDED(hr)) {
      D3D11_TEXTURE2D_DESC d{};state.staging->GetDesc(&d);
      const bool rgba=d.Format==DXGI_FORMAT_R8G8B8A8_UNORM || d.Format==DXGI_FORMAT_R8G8B8A8_UNORM_SRGB || d.Format==DXGI_FORMAT_B8G8R8A8_UNORM || d.Format==DXGI_FORMAT_B8G8R8A8_UNORM_SRGB;
      const bool fp16=d.Format==DXGI_FORMAT_R16G16B16A16_FLOAT;
      const bool packed=d.Format==DXGI_FORMAT_R11G11B10_FLOAT;
      const bool rg16=d.Format==DXGI_FORMAT_R16G16_FLOAT;
      const bool rg32=d.Format==DXGI_FORMAT_R32G32_FLOAT;
      const bool r32=d.Format==DXGI_FORMAT_R32_FLOAT || d.Format==DXGI_FORMAT_R32_TYPELESS || d.Format==DXGI_FORMAT_D32_FLOAT;
      double lo=1e30,hi=-1e30,sum=0,squares=0;int count=0,nz=0;std::uint64_t signature=1469598103934665603ULL;
      double sums[3]{},highs[3]{};int nzs[3]{};
      std::string pixels;pixels.reserve(8192);const char*hex="0123456789abcdef";
      const unsigned stride=fp16||rg32?8:4;
      if(rgba || fp16 || packed || rg16 || rg32 || r32)for(unsigned y=0;y<d.Height;y+=std::max(1u,d.Height/64))for(unsigned x=0;x<d.Width;x+=std::max(1u,d.Width/64)) {
        auto p=static_cast<const unsigned char *>(mapped.pData)+y*mapped.RowPitch+x*stride;
        double channels[3]{};
        if(r32||rg32){float c[2]{};std::memcpy(c,p,stride);channels[0]=c[0];if(rg32)channels[1]=c[1];}
        else if(rg16){std::uint16_t c[2];std::memcpy(c,p,4);channels[0]=half(c[0]);channels[1]=half(c[1]);}
        else if(packed){std::uint32_t c{};std::memcpy(&c,p,4);channels[0]=unsigned_float(c&2047,6);channels[1]=unsigned_float((c>>11)&2047,6);channels[2]=unsigned_float(c>>22,5);}
        else if(rgba){for(unsigned j=0;j<3;++j)channels[j]=p[j]/255.;}
        else {std::uint16_t c[4];std::memcpy(c,p,8);for(unsigned j=0;j<3;++j)channels[j]=half(c[j]);}
        const double value=std::max({channels[0],channels[1],channels[2]});
        const unsigned q=static_cast<unsigned>(std::clamp((state.target==0?channels[1]:channels[0])*128.,0.,255.));
        pixels+=hex[q>>4];pixels+=hex[q&15];
        for(unsigned j=0;j<3;++j){sums[j]+=channels[j];highs[j]=std::max(highs[j],channels[j]);if(channels[j]>1e-6)++nzs[j];}
        lo=std::min(lo,value);hi=std::max(hi,value);sum+=value;squares+=value*value;++count;if(value>1e-6)++nz;
        for(unsigned j=0;j<stride;++j){signature^=p[j];signature*=1099511628211ULL;}
      }
      ctx->Unmap(state.staging,0);
      if(count){observed_target=state.target;minimum=lo;maximum=hi;mean=sum/count;variance=std::max(0.,squares/count-(sum/count)*(sum/count));samples=count;nonzero=nz;if(observations.load() && hash.load()!=signature)++changes;hash=signature;++observations;status=12;}
      if(count){observed_time=state.stamp;for(unsigned j=0;j<3;++j){channel_nonzero[j]=nzs[j];channel_mean[j]=sums[j]/count;channel_max[j]=highs[j];}}
      else status=8;
      if(count==4096){std::ostringstream row;row.precision(16);row<<state.frame.time<<' '<<state.target<<' '<<state.frame.north<<' '<<state.frame.east<<' '<<state.frame.heading<<' '<<state.frame.range<<' '<<pixels;
        std::lock_guard<std::mutex>hold(resources_mutex);grid=row.str();}
    }else status=11;
    state.staging->Release();state.staging=nullptr;
  }
  const int index=std::clamp(selected_target.load(),0,6);
  std::uintptr_t texture{};target(reinterpret_cast<void *>(object),&texture,targets[index]);
  if(!texture){status=5;return;}
  // ed::Ptr owns one intrusive reference at+8; getRenderTargetInternal's
  // verified implementation increments it. Balance it after reading metadata.
  struct TextureRef {std::uintptr_t p;~TextureRef(){auto n=reinterpret_cast<volatile LONG *>(p+8);if(InterlockedDecrement(n)==0){std::uintptr_t v{},f{};if(read(p,v)&&read(v+120,f))reinterpret_cast<void(__fastcall *)(void *)>(f)(reinterpret_cast<void *>(p));}}} reference{texture};
  std::uintptr_t resource{};
  if(!read(texture+136,resource) || !resource){status=6;return;}
  auto source=reinterpret_cast<ID3D11Resource *>(resource);
  ID3D11Texture2D *tex{};
  if(FAILED(source->QueryInterface(__uuidof(ID3D11Texture2D),reinterpret_cast<void **>(&tex))) || !tex){status=6;return;}
  D3D11_TEXTURE2D_DESC d{};tex->GetDesc(&d);width=d.Width;height=d.Height;format=d.Format;
  if(d.SampleDesc.Count!=1 || !d.Width || !d.Height || d.Width>4096 || d.Height>4096){tex->Release();status=8;return;}
  d.Usage=D3D11_USAGE_STAGING;d.BindFlags=0;d.CPUAccessFlags=D3D11_CPU_ACCESS_READ;d.MiscFlags=0;
  if(FAILED(dev->CreateTexture2D(&d,nullptr,&state.staging))){tex->Release();status=9;return;}
  ctx->CopyResource(state.staging,tex);tex->Release();
  state.target=index;
  state.stamp=now;
  state.frame=frame;
  if(status.load()!=12)status=10;
}
inline std::atomic<bool> pending{};
inline std::atomic<double> queued_time{-1};
inline void request(Frame frame) {
  const double now=frame.time;
  const double last=queued_time.load();
  if(now>=last && now-last<1)return;
  if(pending.exchange(true))return;
  using Call=void(__cdecl *)(const std::function<void()> &,const char *);
  auto call=reinterpret_cast<Call>(GetProcAddress(GetModuleHandleW(L"EDCore.dll"),"?callFunction@RenderingThread@ed@@YAXAEBV?$function@$$A6AXXZ@std@@PEBD@Z"));
  if(!call){pending=false;status=15;return;}
  // The asynchronous host queue retains callable code. This opt-in diagnostic
  // pins its own DLL for the process so mission/device teardown cannot unload
  // that code while a queued observation is outstanding. No engine is patched.
  static HMODULE lifetime{};
  if(!lifetime && !GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_PIN,
      reinterpret_cast<LPCWSTR>(&request),&lifetime)){pending=false;status=16;return;}
  queued_time=now;
  const std::function<void()> job=[frame]{sample(frame);pending=false;};
  call(job,"F22 raw ground-radar statistics");
}
}
