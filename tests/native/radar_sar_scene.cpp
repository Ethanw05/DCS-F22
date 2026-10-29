// Independent scene registration/phase/provenance requirements, no DCS/GPU calls.
#include "../../EFM/source/SarSceneInput.h"
#include <iostream>
#include <limits>
namespace {
using namespace SarSceneInput;
unsigned checks{}, failures{};
std::array<Surface, maximum_batch> output;
void require(bool value, const char *label) {
    ++checks;
    if (!value) {
        ++failures;
        std::cout << "FAIL " << label << '\n';
    }
}
bool near(double a, double b) {
    return std::abs(a - b) < 1e-10;
}
Capture capture() {
    Capture c;
    c.epochs = {1, 2, 9, 3, 4};
    c.pass = c.depth_pass = c.radiance_pass = c.inverse_pass = c.visibility_pass = 7;
    c.width = 2;
    c.height = 2;
    c.geometry_time = 10;
    c.completed = c.registration_known = c.visibility_from_rf_origin = c.coverage_complete = true;
    c.radiometry = Radiometry::unblurred_linear_proxy;
    c.render_origin = {1000, 200, 2000};
    c.clip_to_local = {20, 0, 0, 0, 0, 4, 0, 0, 0, 0, 40, 0, 0, 0, 0, 1};
    return c;
}
Grid grid() {
    Grid g;
    g.origin = {1009.5, 201.5, 2009.5};
    g.voltage_scale = 3;
    return g;
}
Texel texel() {
    Texel t;
    t.x = 1;
    t.y = 0;
    t.depth = .25;
    t.linear_proxy = 4;
    t.area_m2 = 2;
    t.surface_known = t.surface_present = true;
    t.visibility = Visibility::visible;
    return t;
}
Batch run(const Capture &c, const Grid &g, const Texel &t, double time = 10.01) {
    return convert(c, g, std::span<const Texel>(&t, 1), output, time);
}
void geometry() {
    auto c = capture();
    auto g = grid();
    auto t = texel();
    Point world{};
    require(unproject(c, t, world) && world == Point{1010, 202, 2010},
            "pixel centres and row-vector clip inverse recover independent N/U/E point");
    auto b = run(c, g, t);
    require(b.available && b.count == 1 && b.environment_epoch == 9 && b.geometry_time == 10,
            "complete scene keeps original source epoch/time");
    require(output[0].position == Point{1010, 202, 2010} &&
                near(std::norm(output[0].amplitude), 72),
            "fixed world cell and declared voltage power use surface area exactly once");
    c.width = 4;
    t.x = 3;
    t.y = 1;
    require(unproject(c, t, world) && world == Point{1015, 198, 2010},
            "non-square texture normalization and top-left Y convention");
    c = capture();
    t = texel();
    c.clip_to_local[11] = 1;
    require(unproject(c, t, world) && near(world[0], 1008) && near(world[1], 201.6) &&
                near(world[2], 2008),
            "projective homogeneous W division is explicit");
    c = capture();
    c.clear_depth = 0;
    t = texel();
    t.depth = .75;
    require(run(c, g, t).available, "reverse-Z admits non-clear finite depth");
    t.depth = 0;
    require(!run(c, g, t).available, "reverse-Z clear value is not fabricated geometry");
    c = capture();
    t = texel();
    t.depth = 1;
    require(!run(c, g, t).available, "normal-Z clear value is not fabricated geometry");
}
void provenance() {
    auto c = capture();
    auto g = grid();
    const auto t = texel();
    for (auto *token : {&c.depth_pass, &c.radiance_pass, &c.inverse_pass, &c.visibility_pass}) {
        *token = 8;
        require(!run(c, g, t).available, "each mismatched pass tuple withdraws scene");
        *token = 7;
    }
    for (auto &epoch : c.epochs) {
        epoch = 0;
        require(!run(c, g, t).available,
                "unknown source/render/environment/nav/clock epoch withdraws");
        epoch = 1;
    }
    c = capture();
    c.completed = false;
    require(!run(c, g, t).available, "enqueued render pass is not completed scene acquisition");
    c = capture();
    c.registration_known = false;
    require(!run(c, g, t).available, "external indicator camera is not a proved internal inverse");
    c = capture();
    c.visibility_from_rf_origin = false;
    require(!run(c, g, t).available,
            "renderer clearance camera cannot impersonate RF phase-centre visibility");
    c = capture();
    c.coverage_complete = false;
    require(!run(c, g, t).available,
            "truncated footprint is unavailable rather than healthy blank");
    c = capture();
    c.radiometry = Radiometry::final_display;
    require(!run(c, g, t).available,
            "blurred/gained/display pixels cannot enter coherent scene proxy");
    c = capture();
    require(!run(c, g, t, 9.99).available && !run(c, g, t, 10.051).available,
            "future/expired geometry cannot be renewed by copy");
    c.geometry_time = 0;
    require(run(c, g, t, .05).available && !run(c, g, t, .050001).available,
            "zero source clock and exact scene lease boundary");
}
void absence_and_invalidity() {
    auto c = capture();
    auto g = grid();
    auto t = texel();
    t.surface_known = false;
    require(!run(c, g, t).available, "unknown terrain is unavailable");
    t = texel();
    t.surface_present = false;
    auto b = run(c, g, t);
    require(b.available && b.count == 0, "known blank is available zero return");
    t = texel();
    t.visibility = Visibility::blocked;
    b = run(c, g, t);
    require(b.available && b.count == 0, "known obstruction is zero illumination");
    t.visibility = Visibility::unknown;
    require(!run(c, g, t).available, "unknown LOS cannot become clear");
    t.visibility = static_cast<Visibility>(19);
    require(!run(c, g, t).available, "typed visibility domain rejects unknown numeric code");
    t = texel();
    t.depth = std::numeric_limits<double>::quiet_NaN();
    require(!run(c, g, t).available, "nonfinite depth withdraws");
    t = texel();
    t.linear_proxy = -1;
    require(!run(c, g, t).available, "negative radiance proxy withdraws");
    t = texel();
    t.area_m2 = 0;
    require(!run(c, g, t).available, "unmeasured surface footprint is unavailable");
    t = texel();
    t.linear_proxy = 1e12;
    t.area_m2 = 1e8;
    require(!run(c, g, t).available, "effective voltage capacity overflow withdraws");
    c = capture();
    t = texel();
    c.clip_to_local[0] = std::numeric_limits<double>::infinity();
    require(!run(c, g, t).available, "nonfinite inverse withdraws");
    c = capture();
    c.clip_to_local[0] = 0;
    require(!run(c, g, t).available, "singular finite inverse cannot invent a surface");
    c = capture();
    g.cell_m = 0;
    require(!run(c, g, t).available, "invalid phase grid withdraws");
}
void phase_and_coalescing() {
    auto c = capture();
    auto g = grid();
    auto t = texel();
    require(run(c, g, t).available, "reference phase sample");
    const auto first = output[0];
    c.width = c.height = 1;
    c.render_origin = {1010, 202, 2010};
    c.clip_to_local = {40, 0, 0, 0, 0, 8, 0, 0, 0, 0, 80, 0, 0, 0, 0, 1};
    c.pass = c.depth_pass = c.radiance_pass = c.inverse_pass = c.visibility_pass = 19;
    c.geometry_time = 10.01;
    t.x = t.y = 0;
    t.depth = 0;
    require(run(c, g, t, 10.02).available && output[0].position == first.position &&
                output[0].amplitude == first.amplitude,
            "world-cell amplitude/phase survives different camera pixels/pass/time");
    c.epochs[2] = 10;
    require(run(c, g, t, 10.02).available && output[0].amplitude != first.amplitude,
            "new environment epoch explicitly changes phase realization");
    Cell cell{};
    Point centre{};
    g = grid();
    g.origin = {0, 0, 0};
    require(world_cell(g, {-1.1, -.1, -2.9}, cell, centre) && cell == Cell{-2, -1, -3},
            "negative world coordinates use floor, not truncation");
    c = capture();
    c.height = 1;
    c.clip_to_local = {.1, 0, 0, 0, 0, .1, 0, 0, 0, 0, .1, 0, 0, 0, 0, 1};
    g.origin = {999.5, 199.5, 1999.5};
    std::array<Texel, 2> pair{texel(), texel()};
    pair[0].x = 0;
    pair[1].x = 1;
    pair[1].area_m2 = 3;
    auto b = convert(c, g, pair, output, 10.01);
    require(b.available && b.count == 1 && near(std::norm(output[0].amplitude), 180),
            "distinct raster footprints in same stable cell coalesce proxy power");
    pair[1].x = 0;
    require(!convert(c, g, pair, output, 10.01).available,
            "replayed raster pixel cannot repeat surface power");
}
void static_terrain_bridge() {
    auto g = grid();
    Surface point;
    const Point dem{1010, 202.12345, 2010};
    require(terrain_surface(dem, 1, 6, 9, g, point) && point.position == dem,
            "CPU DEM bridge keeps exact original altitude instead of invented voxel height");
    require(near(std::norm(point.amplitude), 54),
            "CPU DEM uses the same declared stable voltage mapping");
    const auto amplitude = point.amplitude;
    require(terrain_surface(dem, 1, 6, 9, g, point) && point.amplitude == amplitude,
            "unchanged static DEM geometry retains complex scattering phase");
    require(!terrain_surface(dem, 1, 6, 0, g, point),
            "unknown environment cannot supply terrain scatterers");
}
void capacities() {
    auto c = capture();
    c.width = 256;
    c.height = 1;
    auto g = grid();
    g.cell_m = .001;
    static std::array<Texel, 257> values;
    for (std::size_t i = 0; i < 256; ++i) {
        values[i] = texel();
        values[i].x = static_cast<std::uint32_t>(i);
        values[i].y = 0;
    }
    auto b = convert(c, g, std::span<const Texel>(values.data(), 256), output, 10.01);
    require(b.available && b.count == 256,
            "full core-compatible 256-scatterer batch stays bounded");
    require(!convert(c, g, values, output, 10.01).available,
            "over-capacity batch withdraws instead of truncating scene");
    require(!convert(c, g, std::span<const Texel>(values.data(), 2),
                     std::span<Surface>(output.data(), 1), 10.01)
                 .available,
            "insufficient output storage withdraws");
    values[1] = values[0];
    require(!convert(c, g, std::span<const Texel>(values.data(), 2), output, 10.01).available,
            "duplicate/reordered source pixels withdraw");
}
} // namespace
int main() {
    geometry();
    provenance();
    absence_and_invalidity();
    phase_and_coalescing();
    static_terrain_bridge();
    capacities();
    std::cout << "SAR scene checks=" << checks << " failures=" << failures << '\n';
    return failures ? 1 : 0;
}
