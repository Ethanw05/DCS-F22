// Export shape used by NativeAltimetry; clock advancement belongs to the test.
namespace {
double seconds = 10000.0;
}
class __declspec(dllexport) wTime {
public:
    static double GetModelTime();
};
double wTime::GetModelTime() { return seconds; }
extern "C" __declspec(dllexport) void flight_set_model_time(double value) {
    seconds = value;
}
