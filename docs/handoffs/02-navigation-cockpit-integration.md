# Navigation, cockpit and integration

You own navigation/recovery and the common cockpit interface, and integrate the other three implementation branches. Follow `docs/handoffs/00-shared-instructions.md` and `docs/CODING_STANDARD.md`.

Repository: `C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\DCS-F22`.
Start an isolated worktree from `f22-overhaul-start-2026-10-27`.

Own NAV-WP01–12, UI-01–04, CNI-01–03, ALR-01–03, MIS-01, cockpit/host portions of AUX-01/02, and ARC/REL integration. Coordinate physical providers with the aircraft chat, radar control with the dedicated radar chat, and stores/EW/fusion with the weapons chat.

Start with the light/AFCS command-ID collision, active UFC heading/readback and same-ID waypoint transactions, common focus/input releases, and distinct fault identity/acknowledgement. Preserve the existing repeated-button fixes and intentional weapon-global ACM actions. The radar chat changes final radar-axis admission; agree that interface before editing it.

Build source-qualified INS/GPS, independent altimetry, manual TACAN/ILS, route/mark/time functions, HUD/on-speed cues, AFCS/A-T and recovery depth from the actual resources. Retain the historically supported 12-degree approach reference with explicit calibration uncertainty. Treat carrier ACLS, autoland and a conditional automatic-GCAS profile separately from manual core recovery.

Prove actual voice-radio backend tune/receive/transmit support before promising controls. Keep powered surviving CNI, display reversion and alert/audio behavior consistent with the aircraft providers. Qualify cockpit geometry, controls and optical/audio effects in the actual installation; preserve the user's HUD and recordings.

Integrate focused commits after their relevant owners agree shared state/commands. Run affected regressions and combined mission checks; preserve each source's uncertainty and each test's actual scope. Do not overwrite the radar or physical models while resolving entry-point conflicts. Record short package-specific results, not new general audits.
