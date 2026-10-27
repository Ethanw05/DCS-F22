// Local clock fixture. Never installed in DCS or loaded by the production mod.
#include <cmath>
namespace {
double model_seconds = 0;
}
class __declspec(dllexport) wTime {
public:
    static double __cdecl GetModelTime();
};
double __cdecl wTime::GetModelTime() { return model_seconds; }
extern "C" __declspec(dllexport) void set_model_time(double seconds) {
    if (std::isfinite(seconds)) model_seconds = seconds;
}
