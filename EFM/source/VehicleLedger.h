#pragma once

#include <array>
#include <cmath>
#include <cstddef>

namespace RaptorVehicle {
struct MassTransaction {
    double kg = 0.0; // positive removes mass, negative adds mass (DCS ABI)
    double x_m = 0.0;
    double y_m = 0.0;
    double z_m = 0.0;
};

// Coalesce by fixed tank location. Capacity failure refuses the transaction;
// the caller must retain fuel rather than lose an unreported mass debit.
class MassLedger {
public:
    static constexpr std::size_t capacity = 64;
    bool add(double kg, double x_m, double y_m, double z_m) {
        if (!std::isfinite(kg) || !std::isfinite(x_m) ||
            !std::isfinite(y_m) || !std::isfinite(z_m)) return false;
        if (kg == 0.0) return true;
        for (std::size_t index = 0; index < size_; ++index) {
            auto& entry = entries_[index];
            if (entry.x_m == x_m && entry.y_m == y_m && entry.z_m == z_m) {
                const double combined = entry.kg + kg;
                if (!std::isfinite(combined)) return false;
                entry.kg = combined;
                if (combined == 0.0) entries_[index] = entries_[--size_];
                return true;
            }
        }
        if (size_ == capacity) {
            overflow = true;
            return false;
        }
        entries_[size_++] = {kg, x_m, y_m, z_m};
        return true;
    }
    bool pop(MassTransaction& result) {
        if (size_ == 0) return false;
        result = entries_[--size_];
        return true;
    }
    bool transfer(double kg, const std::array<double, 3>& from,
                  const std::array<double, 3>& to) {
        if (!std::isfinite(kg) || kg < 0.0) return false;
        // Fixed-size transactional copy: either both first moments commit or
        // the transfer is refused. No allocation, partial debit or retry loop.
        MassLedger candidate = *this;
        if (!candidate.add(kg, from[0], from[1], from[2]) ||
            !candidate.add(-kg, to[0], to[1], to[2])) {
            overflow = true;
            return false;
        }
        *this = candidate;
        return true;
    }
    void clear() {
        size_ = 0;
        overflow = false;
    }
    bool overflow = false;
private:
    std::array<MassTransaction, capacity> entries_{};
    std::size_t size_ = 0;
};

struct DamageNotice {
    int element = 0;
    double integrity = 1.0;
};

class DamageLedger {
public:
    bool add(int element, double integrity) {
        if (element < 0 || element >= 137 || !std::isfinite(integrity)) return false;
        const auto index = static_cast<std::size_t>(element);
        values_[index] = std::fmax(0.0, std::fmin(1.0, integrity));
        pending_[index] = true;
        return true;
    }
    bool pop(DamageNotice& result) {
        for (std::size_t index = 0; index < pending_.size(); ++index) {
            if (pending_[index]) {
                result = {static_cast<int>(index), values_[index]};
                pending_[index] = false;
                return true;
            }
        }
        return false;
    }
    void clear() { pending_.fill(false); }
private:
    std::array<double, 137> values_{};
    std::array<bool, 137> pending_{};
};
} // namespace RaptorVehicle
