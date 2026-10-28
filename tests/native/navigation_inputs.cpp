// R-INT-008: actual EFM entry/draw callbacks through independent native ports.
#include <Windows.h>
#include <array>
#include <bit>
#include <cmath>
#include <iostream>
#include <stdexcept>

namespace {
void require(bool value, const char* reason) {
    if (!value) throw std::runtime_error(reason);
}
struct Module {
    HMODULE value;
    explicit Module(const char* path) : value(LoadLibraryA(path)) {
        require(value != nullptr,"Cannot load the explicit external fixture module");
    }
    ~Module() { if (value) FreeLibrary(value); }
    Module(const Module&) = delete;
    Module& operator=(const Module&) = delete;
    template<class Function> Function symbol(const char* name) const {
        const auto address = GetProcAddress(value,name);
        require(address != nullptr,name);
        return std::bit_cast<Function>(address);
    }
};
using Put = void(*)(const char*,double);
using Get = double(*)(const char*);
using Conversion = void(*)(const char*,bool);
using Command = void(*)(int,float);
void request(Put put, double sequence, double target) {
    put("F22_ENTRY_GUIDANCE_ACTIVE",1);
    put("F22_ENTRY_GUIDANCE_COMMAND",11010);
    put("F22_ENTRY_GUIDANCE_VALUE",target);
    put("MAIN_POWER",1);
    put("F22_ENTRY_GUIDANCE_REQUEST",sequence);
}
void check(const Module& cockpit, const Module& world, const Module& aircraft) {
    const auto put = cockpit.symbol<Put>("flight_set_number");
    const auto get = cockpit.symbol<Get>("flight_get_number");
    const auto conversion = cockpit.symbol<Conversion>("flight_set_conversion");
    const auto command = aircraft.symbol<Command>("ed_fm_set_command");
    aircraft.symbol<void(*)()>("ed_fm_hot_start_in_air")();
    put("F22_ENTRY_GUIDANCE_ACK_REQUEST",0);
    request(put,1,0);
    command(11800,1);
    require(get("F22_ENTRY_GUIDANCE_ACK_REQUEST") == 1,"Valid zero request was not acknowledged");
    require(get("F22_ENTRY_GUIDANCE_RESULT") == 1,"Valid zero target was rejected");
    require(get("F22_ENTRY_GUIDANCE_ACK_VALUE") == 0,"Committed zero changed");
    constexpr std::array<const char*,6> names{{"F22_ENTRY_GUIDANCE_REQUEST",
        "F22_ENTRY_GUIDANCE_ACTIVE","F22_ENTRY_GUIDANCE_ACK_REQUEST",
        "F22_ENTRY_GUIDANCE_COMMAND","F22_ENTRY_GUIDANCE_VALUE","MAIN_POWER"}};
    for (const auto* name : names) {
        request(put,2,90);
        conversion(name,false);
        command(11800,2);
        conversion(name,true);
        require(get("F22_ENTRY_GUIDANCE_ACK_REQUEST") == 1,
            "Failed conversion admitted a target request or manufactured an ACK");
    }
    request(put,2,90);
    command(11800,2);
    require(get("F22_ENTRY_GUIDANCE_ACK_REQUEST") == 2,"Fresh request did not recover");
    require(std::abs(get("F22_ENTRY_GUIDANCE_ACK_VALUE")-90) < 1e-6,"Heading units changed");
    std::array<float,1000> draw{};
    const auto cockpit_draw = aircraft.symbol<void(*)(float*,std::size_t)>("ed_fm_set_fc3_cockpit_draw_args_v2");
    put("FORM_KNOB",.75);
    cockpit_draw(draw.data(),draw.size());
    require(draw[714] == .75f,"Valid switch request did not reach its existing draw argument");
    conversion("FORM_KNOB",false);
    cockpit_draw(draw.data(),draw.size());
    require(draw[714] == 0,"Failed conversion became a healthy draw request");
    conversion("FORM_KNOB",true);
    cockpit_draw(draw.data(),draw.size());
    require(draw[714] == .75f,"Fresh draw request did not recover");
    cockpit_draw(nullptr,0);
    aircraft.symbol<void(*)()>("ed_fm_release")();
    put("FORM_KNOB",.9);cockpit_draw(draw.data(),draw.size());
    require(draw[714]==0,"Released parameter context was still used by drawing");
    request(put,3,180);command(11800,3);
    require(get("F22_ENTRY_GUIDANCE_ACK_REQUEST")!=3,"Released owner accepted a late command");
    aircraft.symbol<void(*)()>("ed_fm_hot_start_in_air")();
    request(put,3,180);command(11800,3);
    require(get("F22_ENTRY_GUIDANCE_ACK_REQUEST")==3,"Explicit new startup did not reacquire context");
    const auto set_clock=world.symbol<void(*)(double)>("flight_set_model_time");
    const auto simulate=aircraft.symbol<void(*)(double)>("ed_fm_simulate");
    set_clock(200);simulate(.006);
    require(get("EFM_PHYSICAL_WORLD_STAMP")==200 && get("EFM_PHYSICAL_WORLD_CLOCK_KIND")==2,
            "Cockpit publication did not preserve the independent World clock");
    set_clock(NAN);simulate(.006);
    require(get("EFM_PHYSICAL_WORLD_STAMP")==-100,"Invalid World clock became a current sample");
    set_clock(201);simulate(.006);
    require(get("EFM_PHYSICAL_WORLD_STAMP")==201,"World clock publication did not recover");
    aircraft.symbol<void(*)()>("ed_fm_release")();
    require(get("EFM_PHYSICAL_WORLD_CLOCK_KIND")==0,"Release retained a qualified cockpit clock");
}
}
int main(int argc, char** argv) {
    try {
        require(argc == 4 || argc == 5,"Supply explicit cockpit/world/aircraft fixture DLL paths");
        if (argc == 5) {
            Module aircraft(argv[3]);
            // Missing host at construction and first startup is a controlled
            // unavailable state. A fresh explicit startup after load reacquires.
            aircraft.symbol<void(*)()>("ed_fm_hot_start_in_air")();
            std::array<float,1000> draw{};
            aircraft.symbol<void(*)(float*,std::size_t)>("ed_fm_set_fc3_cockpit_draw_args_v2")
                (draw.data(),draw.size());
            Module cockpit(argv[1]),world(argv[2]);
            check(cockpit,world,aircraft);
        } else {
            Module cockpit(argv[1]),world(argv[2]),aircraft(argv[3]);
            check(cockpit,world,aircraft);
        }
        std::cout << "Actual EFM entry/draw: zero, six independent failed reads and recovery pass\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
