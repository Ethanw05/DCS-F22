// GPL-3.0-or-later. Own cockpit source for the shared DCS radar image renderer.
#pragma once
class EDPARAM;
namespace AesaRadar { struct Pose; }
namespace NativeGroundVideo {
// Value copy from the owned scene sampler; null explicitly withdraws motion.
void set_aircraft(const AesaRadar::Pose*, double stamp) noexcept;
void update(EDPARAM &);
void reset();
}
