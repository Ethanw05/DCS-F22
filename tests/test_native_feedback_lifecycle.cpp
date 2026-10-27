// Actual built DLL callback route; the fixture does not simulate acquisition.
#include <windows.h>
#include <iostream>
#include <stdexcept>
#define CHECK(x) do { if (!(x)) throw std::runtime_error(#x); } while (0)

template<typename T> T symbol(HMODULE module, const char* name) {
    const auto function = reinterpret_cast<T>(GetProcAddress(module, name));
    CHECK(function);
    return function;
}

int main(int argc, char** argv) {
    CHECK(argc == 3);
    const auto cockpit = LoadLibraryA(argv[1]);
    CHECK(cockpit);
    const auto handle = symbol<void*(*)(const char*)>(cockpit, "ed_cockpit_get_parameter_handle");
    const auto write = symbol<void(*)(void*, double)>(cockpit, "ed_cockpit_update_parameter_with_number");
    const auto read = symbol<bool(*)(const void*, double&, bool)>(cockpit, "ed_cockpit_parameter_value_to_number");
    const auto set = [&](const char* name, double value) { write(handle(name), value); };
    const auto get = [&](const char* name) {
        double value = 0;
        CHECK(read(handle(name), value, false));
        return value;
    };
    const auto fm = LoadLibraryA(argv[2]);
    CHECK(fm);
    const auto spawn = symbol<void(*)()>(fm, "ed_fm_hot_start");
    const auto release = symbol<void(*)()>(fm, "ed_fm_release");
    const auto command = symbol<void(*)(int, float)>(fm, "ed_fm_set_command");
    spawn();
    // Seed a previously valid frame. The release callback must use its live
    // parameter owner to invalidate it before the native resources are retired.
    set("F22_IR_SAMPLE_VALID", 1);
    release();
    CHECK(get("F22_IR_SAMPLE_VALID") == 0);
    set("F22_IR_SAMPLE_SEQUENCE", 77);
    set("F22_COMBAT_NATIVE_TICKS", 88);
    command(10850, .02f);
    CHECK(get("F22_IR_SAMPLE_VALID") == 0);
    CHECK(get("F22_IR_SAMPLE_SEQUENCE") == 77 && get("F22_COMBAT_NATIVE_TICKS") == 88);
    spawn();
    command(10850, .02f);
    CHECK(get("F22_IR_SAMPLE_OWNER") == 1 && get("F22_IR_SAMPLE_SCHEMA") == 1);
    CHECK(get("F22_IR_SAMPLE_SEQUENCE") == 1 && get("F22_COMBAT_NATIVE_TICKS") == 1);
    CHECK(get("F22_IR_SAMPLE_VALID") == 0); // Fixture has no native sensor API.
    release();
    CHECK(get("F22_IR_SAMPLE_VALID") == 0);
    std::cout << "Built DLL: live-API release invalidation, late callback rejection and explicit spawn recovery OK\n";
    FreeLibrary(fm);
    FreeLibrary(cockpit);
}
