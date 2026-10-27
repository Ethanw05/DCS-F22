#pragma once

#include "VehicleSystems.h"
#include "VehicleLedger.h"
#include <array>

namespace RaptorVehicle {
// Three feed roles plus five transfer roles follow the historical 2006
// functional description. EVERY split, location, rate and threshold below is
// an explicit simulation estimate. Only the aggregate 8,200 kg is a rounded
// public F-22 anchor. This is not a recovered production fuel schematic.
struct FuelCell {
    double capacity_kg;
    std::array<double, 3> position_m;
    double quantity_kg = 0.0;
};

struct FuelSystem {
    static constexpr double capacity_kg = 8200.0;
    static constexpr double unusable_feed_kg = 25.0 / 3.0;
    static constexpr double low_feed_kg = 100.0;
    static constexpr double transfer_rate_kg_s = 40.0;
    // 0 common/APU feed, 1 left feed, 2 right feed, 3..7 transfer.
    std::array<FuelCell, 8> cells = {{
        {1000.0, {1.0, 0.0, 0.0}},
        {1500.0, {-1.0, 0.0, -0.75}},
        {1500.0, {-1.0, 0.0, 0.75}},
        {900.0, {0.0, 0.0, -4.0}},
        {900.0, {0.0, 0.0, 4.0}},
        {900.0, {0.0, 0.0, 0.0}},
        {750.0, {2.0, 0.0, 0.0}},
        {750.0, {-2.0, 0.0, 0.0}}
    }};
    double boost = 0.0;
    double pressurization = 0.0;

    void set_internal(double quantity_kg) {
        const double fraction = unit(quantity_kg / capacity_kg);
        for (auto& cell : cells) cell.quantity_kg = cell.capacity_kg * fraction;
    }
    double internal_kg() const {
        double total = 0.0;
        for (const auto& cell : cells) total += cell.quantity_kg;
        return total;
    }
    void update_supply(double hydraulic, bool bleed, bool electric, double dt) {
        boost = lag(boost, unit(hydraulic), 0.5, dt);
        pressurization = lag(pressurization, bleed && electric ? 1.0 : 0.0, 2.0, dt);
    }
    bool feed_available(bool left, bool isolated) const {
        const auto& cell = cells[left ? 1 : 2];
        return !isolated && cell.quantity_kg > unusable_feed_kg && boost > 0.05;
    }
    double accept_internal(double requested_kg, MassLedger& ledger) {
        double accepted = 0.0;
        for (auto& cell : cells) {
            const double addition = std::min(requested_kg - accepted,
                std::max(0.0, cell.capacity_kg - cell.quantity_kg));
            const auto& pos = cell.position_m;
            if (ledger.add(-addition, pos[0], pos[1], pos[2])) {
                cell.quantity_kg += addition;
                accepted += addition;
            }
        }
        return accepted;
    }
    double feed_demand(std::size_t index) const {
        return index < 3 ? std::max(0.0, cells[index].capacity_kg - cells[index].quantity_kg) : 0.0;
    }
    double transfer_external(double available_kg, const std::array<double, 3>& source,
                             double maximum_kg, MassLedger& ledger) {
        double moved = 0.0;
        const double limit_kg = std::min(available_kg, maximum_kg);
        // Equal normalized fill deficit avoids exhausting the first station or
        // overfilling one feed. Iteration and transaction capacity are fixed.
        const double demand = feed_demand(0) + feed_demand(1) + feed_demand(2);
        if (demand <= 0.0) return 0.0;
        const double fraction = std::min(1.0, limit_kg / demand);
        for (std::size_t index = 0; index < 3; ++index) {
            auto& cell = cells[index];
            const double transfer = feed_demand(index) * fraction;
            if (ledger.transfer(transfer, source, cell.position_m)) {
                cell.quantity_kg += transfer;
                moved += transfer;
            }
        }
        return moved;
    }
    void transfer_internal(double maximum_kg, MassLedger& ledger) {
        double stored = 0.0;
        for (std::size_t index = 3; index < cells.size(); ++index) stored += cells[index].quantity_kg;
        if (stored <= 0.0) return;
        const double total_limit = std::min(stored, maximum_kg);
        for (std::size_t index = 3; index < cells.size(); ++index) {
            auto& cell = cells[index];
            const double amount = total_limit * cell.quantity_kg / stored;
            const double moved = transfer_external(cell.quantity_kg, cell.position_m, amount, ledger);
            cell.quantity_kg -= moved;
        }
    }
    double burn(std::size_t feed, double requested_kg, bool unlimited, MassLedger& ledger) {
        if (feed >= 3 || !std::isfinite(requested_kg) || requested_kg <= 0.0) return 0.0;
        auto& cell = cells[feed];
        const double delivered = std::min(requested_kg,
            std::max(0.0, cell.quantity_kg - unusable_feed_kg));
        if (unlimited) return cell.quantity_kg > unusable_feed_kg ? requested_kg : 0.0;
        const auto& pos = cell.position_m;
        if (!ledger.add(delivered, pos[0], pos[1], pos[2])) return 0.0;
        cell.quantity_kg -= delivered;
        return delivered;
    }
};
} // namespace RaptorVehicle
