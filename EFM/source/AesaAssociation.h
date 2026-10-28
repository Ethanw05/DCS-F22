// GPL-3.0-or-later. Bounded measurement-space mutual-neighbour association.
#pragma once
#include <array>
#include <cstddef>
#include <limits>
namespace AesaAssociation {
inline constexpr double gate = 36; // Game estimate, normalized innovation squared.
inline constexpr double separation = 9; // Game policy: coast uncertain assignments.
inline constexpr std::size_t none = 64;
struct Choice {
    std::size_t index = none;
    double best = std::numeric_limits<double>::infinity();
    double second = std::numeric_limits<double>::infinity();
    void offer(std::size_t candidate, double score) noexcept {
        if (score > gate) return;
        if (score < best) { second = best; best = score; index = candidate; }
        else if (score < second) second = score;
    }
    bool clear() const noexcept { return index != none && second-best >= separation; }
};
struct Assignment {
    std::array<Choice,8> reports{};
    std::array<Choice,64> tracks{};
    void offer(std::size_t report, std::size_t track, double score) noexcept {
        reports[report].offer(track,score);
        tracks[track].offer(report,score);
    }
    std::size_t selected(std::size_t report) const noexcept {
        const auto& row = reports[report];
        if (!row.clear()) return none;
        const auto& column = tracks[row.index];
        return column.clear() && column.index == report ? row.index : none;
    }
};
}
