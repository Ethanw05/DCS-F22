// GPL-3.0-or-later. Owned scene registration, no native ABI or graphics calls.
// Scalar radiance is a declared scene proxy, never a measured complex RF echo.
#pragma once
#include <array>
#include <cmath>
#include <complex>
#include <cstdint>
#include <span>
#include <utility>
namespace SarSceneInput {
using Point = std::array<double, 3>;   // World north/up/east metres.
using Matrix = std::array<double, 16>; // Row-major; row-vector clip * inverse.
using Cell = std::array<std::int64_t, 3>;
inline constexpr std::size_t maximum_batch = 256;
inline constexpr double maximum_scene_age = .05;
inline constexpr double pi = 3.14159265358979323846;
enum class Radiometry { unavailable, unblurred_linear_proxy, final_display };
enum class Visibility { unknown, blocked, visible };
struct Capture {
    std::uint32_t schema = 1;
    std::array<std::uint32_t, 5> epochs{}; // source/render/environment/nav/clock.
    std::uint64_t pass{}, depth_pass{}, radiance_pass{}, inverse_pass{}, visibility_pass{};
    std::uint32_t width{}, height{};
    double geometry_time{}, clear_depth = 1;
    Matrix clip_to_local{};
    Point render_origin{};
    bool completed{}, registration_known{}, visibility_from_rf_origin{}, coverage_complete{};
    Radiometry radiometry = Radiometry::unavailable;
};
struct Grid {
    Point origin{};
    double cell_m = 1, voltage_scale = 1;
    std::uint32_t phase_seed = 1;
};
struct Texel {
    std::uint32_t x{}, y{};
    double depth{}, linear_proxy{}, area_m2{};
    bool surface_known{}, surface_present{};
    Visibility visibility = Visibility::unknown;
};
struct Surface {
    Point position{};
    std::complex<double> amplitude{};
    Cell cell{};
    double voltage_power{};
};
struct Batch {
    bool available{};
    std::uint32_t environment_epoch{};
    double geometry_time{};
    std::size_t count{};
};
inline bool bounded(double value, double limit) noexcept {
    return std::isfinite(value) && std::abs(value) <= limit;
}
inline bool point_valid(const Point &point) noexcept {
    for (const double value : point)
        if (!bounded(value, 3e7))
            return false;
    return true;
}
inline bool identity_valid(const Capture &capture) noexcept {
    if (capture.schema != 1 || capture.pass == 0)
        return false;
    for (const auto epoch : capture.epochs)
        if (epoch == 0 || epoch > 16777215)
            return false;
    for (const auto token :
         {capture.depth_pass, capture.radiance_pass, capture.inverse_pass, capture.visibility_pass})
        if (token != capture.pass)
            return false;
    return true;
}
inline bool dimensions_valid(const Capture &capture) noexcept {
    return capture.width > 0 && capture.width <= 4096 && capture.height > 0 &&
           capture.height <= 4096;
}
inline std::size_t pivot_row(const Matrix &matrix, std::size_t column) noexcept {
    std::size_t result = column;
    for (std::size_t row = column + 1; row < 4; ++row)
        if (std::abs(matrix[row * 4 + column]) > std::abs(matrix[result * 4 + column]))
            result = row;
    return result;
}
inline bool nonsingular(Matrix matrix) noexcept {
    for (std::size_t column = 0; column < 4; ++column) {
        const auto pivot = pivot_row(matrix, column);
        if (std::abs(matrix[pivot * 4 + column]) < 1e-12)
            return false;
        for (std::size_t entry = 0; entry < 4; ++entry)
            std::swap(matrix[column * 4 + entry], matrix[pivot * 4 + entry]);
        for (std::size_t row = column + 1; row < 4; ++row) {
            const double ratio = matrix[row * 4 + column] / matrix[column * 4 + column];
            for (std::size_t entry = column + 1; entry < 4; ++entry)
                matrix[row * 4 + entry] -= ratio * matrix[column * 4 + entry];
        }
    }
    return true;
}
inline bool transform_valid(const Capture &capture) noexcept {
    if (!point_valid(capture.render_origin))
        return false;
    for (const double value : capture.clip_to_local)
        if (!bounded(value, 1e12))
            return false;
    return nonsingular(capture.clip_to_local) &&
           (capture.clear_depth == 0 || capture.clear_depth == 1);
}
inline bool capture_flags(const Capture &capture) noexcept {
    return capture.completed && capture.registration_known && capture.coverage_complete &&
           capture.visibility_from_rf_origin &&
           capture.radiometry == Radiometry::unblurred_linear_proxy;
}
inline bool scene_clock(const Capture &capture, double illumination_time) noexcept {
    return std::isfinite(illumination_time) && std::isfinite(capture.geometry_time) &&
           capture.geometry_time >= 0 && illumination_time >= capture.geometry_time &&
           illumination_time - capture.geometry_time <= maximum_scene_age;
}
inline bool capture_valid(const Capture &capture, double illumination_time) noexcept {
    return identity_valid(capture) && dimensions_valid(capture) && transform_valid(capture) &&
           capture_flags(capture) && scene_clock(capture, illumination_time);
}
inline bool grid_valid(const Grid &grid) noexcept {
    return point_valid(grid.origin) && std::isfinite(grid.cell_m) && grid.cell_m >= .001 &&
           grid.cell_m <= 1000 && std::isfinite(grid.voltage_scale) && grid.voltage_scale > 0 &&
           grid.voltage_scale <= 1e6 && grid.phase_seed != 0;
}
inline bool sample_depth_valid(const Capture &capture, const Texel &texel) noexcept {
    if (texel.x >= capture.width || texel.y >= capture.height || !std::isfinite(texel.depth))
        return false;
    if (texel.depth < 0 || texel.depth > 1 || texel.depth == capture.clear_depth)
        return false;
    return true;
}
inline bool unproject(const Capture &capture, const Texel &texel, Point &world) noexcept {
    world = {};
    if (!sample_depth_valid(capture, texel))
        return false;
    const std::array clip{2 * (texel.x + .5) / capture.width - 1,
                          1 - 2 * (texel.y + .5) / capture.height, texel.depth, 1.0};
    std::array<double, 4> local{};
    for (std::size_t column = 0; column < 4; ++column)
        for (std::size_t row = 0; row < 4; ++row)
            local[column] += clip[row] * capture.clip_to_local[row * 4 + column];
    if (!bounded(local[3], 1e12) || std::abs(local[3]) < 1e-12)
        return false;
    for (std::size_t axis = 0; axis < 3; ++axis)
        world[axis] = capture.render_origin[axis] + local[axis] / local[3];
    return point_valid(world);
}
inline bool world_cell(const Grid &grid, const Point &world, Cell &cell, Point &centre) noexcept {
    for (std::size_t axis = 0; axis < 3; ++axis) {
        const double coordinate = std::floor((world[axis] - grid.origin[axis]) / grid.cell_m);
        if (!bounded(coordinate, 1e11))
            return false;
        cell[axis] = static_cast<std::int64_t>(coordinate);
        centre[axis] = grid.origin[axis] + (coordinate + .5) * grid.cell_m;
    }
    return point_valid(centre);
}
inline std::uint64_t phase_hash(const Cell &cell, std::uint32_t environment,
                                std::uint32_t seed) noexcept {
    std::uint64_t hash = 1469598103934665603ULL;
    for (const auto value :
         {static_cast<std::uint64_t>(environment), static_cast<std::uint64_t>(seed),
          static_cast<std::uint64_t>(cell[0]), static_cast<std::uint64_t>(cell[1]),
          static_cast<std::uint64_t>(cell[2])}) {
        hash ^= value;
        hash *= 1099511628211ULL;
        hash ^= hash >> 32;
    }
    return hash;
}
inline std::complex<double> phased_voltage(const Cell &cell, std::uint32_t environment,
                                           const Grid &grid, double power) noexcept {
    // Phase has no dependence on camera pixels, pulse token, render pass or receipt time.
    const auto bits = phase_hash(cell, environment, grid.phase_seed) >> 11;
    const double phase = 2 * pi * (static_cast<double>(bits) / 9007199254740992.0);
    return std::polar(std::sqrt(power), phase);
}
inline bool power_valid(const Texel &texel, const Grid &grid, double &power) noexcept {
    if (!bounded(texel.linear_proxy, 1e12) || texel.linear_proxy < 0)
        return false;
    if (!bounded(texel.area_m2, 1e8) || texel.area_m2 <= 0)
        return false;
    power = texel.linear_proxy * texel.area_m2 * grid.voltage_scale * grid.voltage_scale;
    return std::isfinite(power) && power >= 0 && power <= 1e12;
}
inline bool make_surface(const Capture &capture, const Grid &grid, const Texel &texel,
                         Surface &result) noexcept {
    Point world{};
    if (!unproject(capture, texel, world))
        return false;
    if (!world_cell(grid, world, result.cell, result.position))
        return false;
    if (!power_valid(texel, grid, result.voltage_power))
        return false;
    result.amplitude = phased_voltage(result.cell, capture.epochs[2], grid, result.voltage_power);
    return true;
}
inline bool terrain_surface(const Point &world, double proxy_power_density, double area_m2,
                            std::uint32_t environment_epoch, const Grid &grid,
                            Surface &result) noexcept {
    if (!point_valid(world) || !grid_valid(grid) || environment_epoch == 0 ||
        environment_epoch > 16777215)
        return false;
    if (!world_cell(grid, world, result.cell, result.position))
        return false;
    result.position = world; // A fixed DEM grid already has stable exact sample coordinates.
    Texel material;
    material.linear_proxy = proxy_power_density;
    material.area_m2 = area_m2;
    if (!power_valid(material, grid, result.voltage_power))
        return false;
    result.amplitude = phased_voltage(result.cell, environment_epoch, grid, result.voltage_power);
    return true;
}
inline bool append(std::span<Surface> output, std::size_t &count, const Surface &surface,
                   const Capture &capture, const Grid &grid) noexcept {
    for (std::size_t index = 0; index < count; ++index) {
        if (output[index].cell != surface.cell)
            continue;
        const double power = output[index].voltage_power + surface.voltage_power;
        if (!std::isfinite(power) || power > 1e12)
            return false;
        output[index].voltage_power = power;
        output[index].amplitude = phased_voltage(surface.cell, capture.epochs[2], grid, power);
        return true;
    }
    if (count >= output.size())
        return false;
    output[count++] = surface;
    return true;
}
inline bool add_texel(const Capture &capture, const Grid &grid, const Texel &texel,
                      std::span<Surface> output, std::size_t &count) noexcept {
    if (!texel.surface_known)
        return false;
    if (!texel.surface_present)
        return true; // Known blank is distinct from unknown.
    if (texel.visibility == Visibility::unknown)
        return false;
    if (texel.visibility == Visibility::blocked)
        return true;
    if (texel.visibility != Visibility::visible)
        return false;
    Surface surface;
    return make_surface(capture, grid, texel, surface) &&
           append(output, count, surface, capture, grid);
}
inline bool ordered_pixel(const Capture &capture, const Texel &texel, std::uint64_t &previous,
                          bool first) noexcept {
    if (texel.x >= capture.width || texel.y >= capture.height)
        return false;
    const auto index = static_cast<std::uint64_t>(texel.y) * capture.width + texel.x;
    if (!first && index <= previous)
        return false;
    previous = index;
    return true;
}
inline Batch convert(const Capture &capture, const Grid &grid, std::span<const Texel> texels,
                     std::span<Surface> output, double illumination_time) noexcept {
    Batch result{};
    if (!capture_valid(capture, illumination_time) || !grid_valid(grid))
        return result;
    if (texels.size() > maximum_batch || output.size() < texels.size())
        return result;
    std::size_t count = 0;
    std::uint64_t previous = 0;
    bool first = true;
    for (const auto &texel : texels) {
        if (!ordered_pixel(capture, texel, previous, first))
            return result;
        first = false;
        if (!add_texel(capture, grid, texel, output, count))
            return result;
    }
    return {true, capture.epochs[2], capture.geometry_time, count};
}
} // namespace SarSceneInput
