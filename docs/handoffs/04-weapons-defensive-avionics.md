# Weapons and defensive avionics

You own weapons, defensive avionics and integrated mission information. Follow `docs/handoffs/00-shared-instructions.md` and `docs/CODING_STANDARD.md`.

Repository: `C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\DCS-F22`.
Start an isolated worktree from `f22-overhaul-start-2026-10-27`.

Own SEN-05–15: IFF/transponder roles, fusion/datalink, passive warning/EW, countermeasure programs and MAN/SEMI/AUTO operation, stores/targets/release transactions, bay/IR readiness, engagement/support/gun behavior and selected optional optical/HMD/weapon equipment. SEN-01's shared equipment profile is coordinated across all chats. Radar model and radar-native reverse engineering belong to the dedicated radar chat.

Start with countermeasure editing versus actual normal/direct program selection, complete execution/cancellation/depletion feedback, and station/target/release/rearm correctness. Preserve actual inventory/native effects. Distinguish a requested release, a confirmed launch, jettison and ground service; a count decrease alone must not acknowledge the wrong action.

Read applicable F-22 public evidence and multiple selected Viper/Hornet references for each changed system. Keep source-specific age, uncertainty, identity and weapon-support authority intact through fusion. The radar chat supplies a qualified observation contract; received donor information is not automatically own-radar fire control.

Implement full chains and failure/recovery behavior. Coordinate physical bay/power/fuel/mass providers with the aircraft chat and common cockpit/audio controls with the navigation/integration chat. In `NativeSidewinder.cpp`, keep payload/seeker changes separate from the radar owner's hooks.

For selected optional targeting pods, IRDS/IRST, HMD and additional weapons, confirm equipment applicability and actual host support before advertising capability. Implement image/LOS, controls, designation, ranging/laser or cueing, target handoff and supported native effect as applicable; a pod model or reticle is insufficient. Use explicit optional profiles where F-22 fit is unestablished.

Deliver focused branch commits, relevant source/estimate decisions and actual normal/limit/failure/recovery results. Do not stop at page controls if the intended backend/physical effect is still missing.
