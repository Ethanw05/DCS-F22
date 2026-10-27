# Flight model and aircraft systems

You own the flight model and physical aircraft systems of the F-22 mod. Follow `docs/handoffs/00-shared-instructions.md` and `docs/CODING_STANDARD.md`.

Repository: `C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\DCS-F22`.
Start an isolated worktree from `f22-overhaul-start-2026-10-27`.

Implement VEH-01–15: air data, fuel/mass/CG/inertia, engines, battery/generators/APU/SES, hydraulic sources and consumers, FCS and achieved surface/vector states, flight performance, gear/NWS/hook, brakes/heat, ECS/cooling/cabin, oxygen, canopy/escape and damage/repair. Supply the physical portions of AUX-01/02; the integration chat owns their cockpit/host adapters.

Start by preserving existing healthy behavior while establishing one physical owner and trustworthy outputs. Then correct concrete defects and missing dependencies in small changes. Read applicable F-22 manufacturer/development/utility sources and the selected Viper/Hornet procedures before choosing behavior or constants. Preserve historical versus production applicability.

Validate performance jointly across forces, mass, energy and fuel at declared conditions. Public thrust/capability anchors do not supply a complete engine or aerodynamic deck. Characterize host inertia, contact, store drag, braking and ground effect before adding duplicate contributions.

Agree input/output units, health, timing and failure interfaces with navigation, radar and weapons. Publish achieved configuration, supply availability and equipment faults; those chats consume the outputs. Keep AFCS mode logic with navigation and radar internals with the radar chat.

Deliver implemented, tested behaviors on a branch, with source-backed targets, estimated calibration values identified, and normal/limit/failure/recovery results. Preserve finite reserves and servicing distinctions; do not repair faults by clearing their indications.
