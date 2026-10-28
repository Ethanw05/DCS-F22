// Offline host shim around an unmodified revision of NativeGunSight.cpp.
// Only DCS bindings and shell flight integration are substituted.
#include "NativeGunSight.cpp"
#include <cstring>
namespace {
using GunIntercept::V;
std::map<std::string, double> parameters;
EDPARAM parameter_api;
alignas(16) std::array<std::byte,32> weapon_storage{};
alignas(16) std::array<std::byte,184> shell_storage{};
void* human_vtable[41]{};
void** human_object=human_vtable;
void* aircraft_vtable[52]{};
void** aircraft_object=aircraft_vtable;
void* cockpit_context[3]{};
double model_time=0;

void* parameter(const char* name) { return &parameters[name]; }
void set_parameter(void* handle,double value) { *static_cast<double*>(handle)=value; }
bool read_parameter(const void* handle,double& value,bool) {
    value=*static_cast<const double*>(handle);return true;
}
double clock_time() { return model_time; }
void* context() { return cockpit_context; }
void* device(void*,unsigned id) { return id==15 ? weapon_storage.data() : nullptr; }
const void* shell(void*) { return shell_storage.data(); }
void* construct(void* memory,const void*) { return memory; }
void destroy(void*) {}
void* aircraft(void*) { return &aircraft_object; }
void pose(void*,float* matrix,unsigned char,unsigned,unsigned) {
    for(unsigned i=0;i<16;++i) matrix[i]=0;
    const double heading=parameters["BENCH_HEADING"];
    matrix[0]=static_cast<float>(std::cos(heading));
    matrix[2]=static_cast<float>(std::sin(heading));
    matrix[5]=matrix[15]=1;
    matrix[8]=-matrix[2];matrix[10]=matrix[0];
    matrix[12]=static_cast<float>(parameters["BENCH_N"]+std::cos(heading));
    matrix[13]=static_cast<float>(parameters["BENCH_U"]+.5);
    matrix[14]=static_cast<float>(parameters["BENCH_E"]+std::sin(heading));
}
V acceleration(V velocity,V wind) {
    const V relative=velocity-wind;
    return relative*(-.00012*relative.norm())+V{0,-9.8,0};
}
V projectile(V velocity,V wind,double time,double maximum_step) {
    V position{};
    // Offline-only: at most 2001 substeps for the solver's four-second limit.
    for(unsigned step=0;step<2001 && time>1e-12;++step) {
        const double dt=std::min(maximum_step,time);
        const V a=acceleration(velocity,wind);
        const V v2=velocity+a*(dt*.5),b=acceleration(v2,wind);
        const V v3=velocity+b*(dt*.5),c=acceleration(v3,wind);
        const V v4=velocity+c*dt,d=acceleration(v4,wind);
        position=position+(velocity+v2*2+v3*2+v4)*(dt/6);
        velocity=velocity+(a+b*2+c*2+d)*(dt/6);
        time-=dt;
    }
    return position;
}
int flight(void*,double altitude,double time,const V* velocity,NativeGunSight::Wind* wind,V* out,double) {
    NativeGunSight::WindVector sampled{};
    using Query=NativeGunSight::WindVector*(*)(NativeGunSight::Wind*,NativeGunSight::WindVector*,const float*);
    float height=static_cast<float>(altitude);
    reinterpret_cast<Query>(wind->table[1])(wind,&sampled,&height);
    *out=projectile(*velocity,{sampled.x,sampled.y,sampled.z},time,.01);
    out->y+=altitude;
    return 1;
}
}
#if defined(F22_BENCH_NATIVE_MOTION)
// The production adapter is unmodified; this replaces its DCS object API only.
namespace NativeAesaRadar {
bool gun_motion(unsigned track, std::uint64_t generation, GunMotion& out) noexcept {
    if (track != 42 || generation != 1) return false;
    const char* axes[] = {"N", "U", "E"};
    for (unsigned axis = 0; axis < 3; ++axis) {
        out.position[axis] = parameters[std::string("BENCH_TARGET_") + axes[axis]];
        out.velocity[axis] = parameters[std::string("BENCH_V") + axes[axis]];
        out.acceleration[axis] = parameters[std::string("BENCH_A") + axes[axis]];
    }
    out.time = model_time; out.generation = generation;
    return true;
}
}
#endif
extern "C" __declspec(dllexport) void benchmark_reset() {
    using namespace NativeGunSight;
    reset();parameters.clear();model_time=0;
    parameter_api.ed_param_api.pfn_ed_cockpit_get_parameter_handle=parameter;
    parameter_api.ed_param_api.pfn_ed_cockpit_update_parameter_with_number=set_parameter;
    parameter_api.ed_param_api.pfn_ed_cockpit_parameter_value_to_number=read_parameter;
    api.ready=true;api.context=context;api.device=device;api.shell=shell;
    api.ctor=construct;api.dtor=destroy;api.time=flight;api.clock=clock_time;
    api.vtable=reinterpret_cast<void*>(0x12345);
    std::memcpy(weapon_storage.data(),&api.vtable,sizeof(void*));
    void* pointer=cockpit_context;
    std::memcpy(weapon_storage.data()+24,&pointer,sizeof(void*));
    cockpit_context[2]=&human_object;
    human_vtable[40]=reinterpret_cast<void*>(&aircraft);
    aircraft_vtable[51]=reinterpret_cast<void*>(&pose);
    const double speed=1030;
    std::memcpy(shell_storage.data()+176,&speed,sizeof(speed));
}
extern "C" __declspec(dllexport) void benchmark_set(const char* name,double value) {
    parameters[name]=value;
}
extern "C" __declspec(dllexport) double benchmark_get(const char* name) {
    return parameters[name];
}
extern "C" __declspec(dllexport) void benchmark_update(double time) {
    model_time=time;NativeGunSight::update(parameter_api);
}
extern "C" __declspec(dllexport) void benchmark_projectile(const double* velocity,
    const double* wind,double time,double* output) {
    const V result=projectile({velocity[0],velocity[1],velocity[2]},
        {wind[0],wind[1],wind[2]},time,.002);
    output[0]=result.x;output[1]=result.y;output[2]=result.z;
}

// Evaluate the actual target-motion kernel for sampled player-flight forecasts.
extern "C" __declspec(dllexport) void benchmark_predict(const double* position,
    const double* velocity,const double* acceleration,double time,double* output) {
    const GunTargetMotion::Model model({position[0],position[1],position[2]},
        {velocity[0],velocity[1],velocity[2]},{acceleration[0],acceleration[1],acceleration[2]});
    const V result=model.at(time);
    output[0]=result.x;output[1]=result.y;output[2]=result.z;
}
