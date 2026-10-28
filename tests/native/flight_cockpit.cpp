// Independent host ABI port from ccParametersAPI.h. No physical model lives here.
#include <array>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>

namespace {
struct Parameter {
    std::array<char, 128> name{};
    double number = 0.0; // The host creates storage, not a healthy observation.
    bool convertible = true;
};
std::array<Parameter, 4096> parameters;
std::size_t used = 0;
Parameter* find(const char* name) {
    if (!name || std::strlen(name) >= parameters[0].name.size()) return nullptr;
    for (std::size_t i = 0; i < used; ++i) {
        if (std::strcmp(parameters[i].name.data(), name) == 0) return &parameters[i];
    }
    return nullptr;
}
Parameter* acquire(const char* name) {
    if (auto* existing = find(name)) return existing;
    if (!name || std::strlen(name) >= parameters[0].name.size() || used == parameters.size())
        return nullptr;
    auto& result = parameters[used++];
    std::memcpy(result.name.data(), name, std::strlen(name) + 1);
    return &result;
}
}

extern "C" {
__declspec(dllexport) void* ed_cockpit_get_parameter_handle(const char* name) {
    return acquire(name);
}
__declspec(dllexport) void ed_cockpit_update_parameter_with_number(void* handle, double value) {
    if (!handle) return;
    auto& parameter = *static_cast<Parameter*>(handle);
    parameter.number = value;
    parameter.convertible = true;
}
__declspec(dllexport) void ed_cockpit_update_parameter_with_string(void* handle, const char* text) {
    if (!handle || !text) return;
    auto& parameter = *static_cast<Parameter*>(handle);
    char* end = nullptr;
    parameter.number = std::strtod(text, &end);
    parameter.convertible = end != text && *end == '\0';
}
__declspec(dllexport) bool ed_cockpit_parameter_value_to_number(
    const void* handle, double& value, bool) {
    if (!handle) return false;
    const auto& parameter = *static_cast<const Parameter*>(handle);
    value = parameter.number; // Failed conversion is allowed to modify the buffer.
    return parameter.convertible;
}
__declspec(dllexport) bool ed_cockpit_parameter_value_to_string(
    const void* handle, char* buffer, unsigned capacity) {
    if (!handle || !buffer || capacity == 0) return false;
    const auto& parameter = *static_cast<const Parameter*>(handle);
    const int count = std::snprintf(buffer, capacity, "%.17g", parameter.number);
    return parameter.convertible && count >= 0 && static_cast<unsigned>(count) < capacity;
}
__declspec(dllexport) int ed_cockpit_compare_parameters(void* first, void* second) {
    if (!first || !second) return 0;
    const double a = static_cast<Parameter*>(first)->number;
    const double b = static_cast<Parameter*>(second)->number;
    return a == b ? 0 : (a < b ? -1 : 1);
}
__declspec(dllexport) void flight_set_number(const char* name, double value) {
    ed_cockpit_update_parameter_with_number(acquire(name), value);
}
__declspec(dllexport) double flight_get_number(const char* name) {
    const auto* parameter = find(name);
    return parameter && parameter->convertible ? parameter->number :
        std::numeric_limits<double>::quiet_NaN();
}
__declspec(dllexport) void flight_set_conversion(const char* name, bool success) {
    if (auto* parameter = acquire(name)) parameter->convertible = success;
}
__declspec(dllexport) void flight_clear() {
    // Keep acquired addresses stable: actual native owners cache host handles.
    for (std::size_t i = 0; i < used; ++i) {
        parameters[i].number = 0.0;
        parameters[i].convertible = true;
    }
}
}
