// GPL-3.0-or-later. Independent pod, using only shared DCS infrared services.
#pragma once
class EDPARAM;
namespace NativeIRST {
void initialize(EDPARAM& parameters) noexcept;
void update(EDPARAM& parameters) noexcept;
void sample() noexcept; // Existing cockpit device callback; never the FM thread.
void retire() noexcept;
}
