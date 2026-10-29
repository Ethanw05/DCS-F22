// GPL-3.0-or-later. Matched CockpitBase IR profiles; no aircraft dependency.
#pragma once
#include <cstddef>
#include <cstdint>
#include <span>

namespace NativeSidewinderHost {
struct Profile {
    std::uint32_t timestamp{};
    std::uint32_t image_size{};
    std::uint32_t object_lookup_rva{};
    std::uint64_t object_lookup_hash{};
    bool payload_qualified{};
};
inline constexpr std::size_t object_lookup_size = 49;
constexpr std::uint64_t digest(std::span<const std::byte> bytes) noexcept {
    if (bytes.size() != object_lookup_size) return 0;
    std::uint64_t hash = 14695981039346656037ULL;
    for (std::size_t index = 0; index < object_lookup_size; ++index) {
        hash ^= std::to_integer<unsigned char>(bytes[index]);
        hash *= 1099511628211ULL;
    }
    return hash;
}
inline constexpr Profile profiles[] = {
    {0x6ac12468, 0x59a000, 0x2165d0, 0x452660c42fa89b4aULL, true},
    {0x6adbad09, 0x68e000, 0x2fe650, 0xdbd7d715791c239fULL, true}
};
constexpr const Profile* select(std::uint32_t timestamp, std::uint32_t image_size) noexcept {
    for (const auto& profile : profiles) {
        if (profile.timestamp == timestamp && profile.image_size == image_size) return &profile;
    }
    return nullptr;
}
constexpr bool matches(const Profile& profile, std::span<const std::byte> code) noexcept {
    return code.size() == object_lookup_size && digest(code) == profile.object_lookup_hash;
}
} // namespace NativeSidewinderHost
