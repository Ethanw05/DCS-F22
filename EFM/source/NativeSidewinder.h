// GPL-3.0-or-later. Adapter to the installed simulator's shared seeker API.
#pragma once
class EDPARAM;
namespace NativeSidewinder {
void update(EDPARAM& parameters, double dt);
void start_feedback();
void reset(EDPARAM* parameters = nullptr);
}
