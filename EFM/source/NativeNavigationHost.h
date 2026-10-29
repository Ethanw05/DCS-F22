// Private navigation ABI facts inspected from DCS2.9.31.29434 x64.
// See docs/overhaul/navigation-execution/host-update/README.md for provenance.
#pragma once
#include <cstddef>
#include <cstdint>
#include <Windows.h>

namespace RaptorNavigationHost {
static_assert(sizeof(void*) == 8, "Navigation private ABI requires Windows x64");
inline constexpr std::uint32_t timestamp = 0x6adbad09;
inline constexpr std::uint32_t image_size = 0x68e000;
inline constexpr std::size_t malloc_iat_rva = 0x538478;
inline constexpr std::size_t free_iat_rva = 0x538468;
inline constexpr std::size_t tacan_bytes = 2856;
inline constexpr std::size_t ils_bytes = 3352;
inline constexpr std::size_t electrical_probe_bytes = 5800;
inline constexpr std::size_t context_offset = 24;
inline constexpr std::size_t tacan_receiver_offset = 2064;
inline constexpr std::size_t ils_receiver_offset = 2048;

inline bool headers(const IMAGE_NT_HEADERS64& pe) noexcept {
    return pe.Signature == IMAGE_NT_SIGNATURE
        && pe.FileHeader.Machine == IMAGE_FILE_MACHINE_AMD64
        && pe.OptionalHeader.Magic == IMAGE_NT_OPTIONAL_HDR64_MAGIC
        && pe.FileHeader.TimeDateStamp == timestamp
        && pe.OptionalHeader.SizeOfImage == image_size;
}
inline bool header_offset(LONG offset) noexcept {
    return offset >= static_cast<LONG>(sizeof(IMAGE_DOS_HEADER))
        && static_cast<std::size_t>(offset) <= image_size-sizeof(IMAGE_NT_HEADERS64);
}
} // namespace RaptorNavigationHost
