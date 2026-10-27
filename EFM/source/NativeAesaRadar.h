// GPL-3.0-or-later. Version-checked scene provider; independent of avSimpleRadar sensing.
#pragma once
class EDPARAM;
namespace NativeAesaRadar {
void update(EDPARAM& parameters) noexcept;
void attach(void* owned_radar) noexcept;
void reset() noexcept;
void damage(int cell, double integrity) noexcept;
void repair() noexcept;
void sample(void* owned_radar) noexcept;
}
