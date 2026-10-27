// GPL-3.0-or-later. Native unassociated noise returns; Lua verifies terrain
// height.
#pragma once
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
namespace NativeGroundReturns {
struct Return {
  double north{}, altitude{}, east{}, stamp{};
  float rcs{};
};
template <class T> T field(const std::byte *record, std::size_t offset) {
  T value{};
  std::memcpy(&value, record + offset, sizeof(T));
  return value;
}
inline bool decode(const std::byte *record, std::size_t size, double now,
                   Return &out) {
  if (!record || size < 144 || !std::isfinite(now) ||
      field<std::uint8_t>(record, 124) != 1 ||
      field<std::uint32_t>(record, 128) != 0)
    return false;
  Return r{field<double>(record, 0), field<double>(record, 8),
           field<double>(record, 16), field<double>(record, 112),
           field<float>(record, 72)};
  if (!std::isfinite(r.north) || !std::isfinite(r.altitude) ||
      !std::isfinite(r.east) || !std::isfinite(r.stamp) ||
      !std::isfinite(r.rcs) || r.rcs <= 0 || std::abs(r.north) > 1e8 ||
      std::abs(r.east) > 1e8 || std::abs(r.altitude) > 1e5 ||
      now - r.stamp < -.05 || now - r.stamp > 8)
    return false;
  out = r;
  return true;
}
} // namespace NativeGroundReturns
