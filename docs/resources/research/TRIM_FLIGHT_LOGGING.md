# Trim flight recorder — 2026-10-27

Installed for the user's next flight. No trim gains, event increments, authority,
automatic-trim behavior, or flight-control calculations were changed.

The isolated instrumented native build publishes 39 `EFM_TRIM_*` parameters.
`tools/diagnostics/F22TrimTelemetry.lua` is installed as a Saved Games hook and
records F-22A player sessions at up to 20 samples per model second. No input
commands or cockpit parameters are written by this recorder. Pausing does not
generate duplicate samples. Each CSV is flushed every model second, closed on
mission stop, and limited to one hour per simulation session.

Output: `C:/Users/Ethans Desktop 2.0/Saved Games/DCS/Logs/F22-Trim/trim-*.csv`.
`dcs.log` also records `F22_TRIM` open/close messages. A missing instrumentation
DLL causes the hook to remain idle. Other aircraft are excluded.

## Requested pilot sequence

Use a safe altitude with autopilot off. Start with 15–20 seconds without touching
trim so automatic trim's baseline is visible. At roughly 200, 350, and 500 KIAS,
if practical, perform a small nose-up trim tap, leave trim released for about
five seconds, then a small nose-down tap and another release. Include a short
held input and a **Reset Trim** command if convenient. Some gentle roll-trim
inputs would provide a useful comparison. Fly normally afterward; do not force
the aircraft to maintain those speeds through an unsafe condition.

The pilot's own hat matters: the existing EFM applies discrete trim per received
command, rather than per elapsed second. Reception counters and FM timestamps
measure the resulting event rate. The logger does not directly read the USB
device. Multiple events in a sample interval are preserved as counter increments;
only the most recent command's individual timestamp/value is published.

## Fields and interpretation

The CSV includes IAS/TAS/Mach/altitude, AoA, bank/pitch, pitch/roll rate, load,
pitch input, manual pitch/roll/yaw trim, auto trim, takeoff trim, commanded and
achieved elevon positions, dynamic pressure, command counters, last command/value,
autopilot state, actuator availability, and export-frame corroborating sensors.

`AUTO_INHIBIT` is a bit mask matching the current existing code:

| Bit | Existing inhibit |
|---:|---|
| 1 | Autopilot active without override |
| 2 | On ground |
| 4 | Absolute bank greater than about 70 degrees |
| 8 | Manual pitch-trim latch set |
| 16 | AoA at least 9 degrees |
| 32 | IAS below 160 knots |

Publication occurs at the existing CockpitManager update point, before the
current simulation step's surface calculation. Diagnostic surface/control terms
therefore describe the completed preceding step; account for that one-step
latency in response analysis. Counters are reset with the flight-model state.

## Verification and limitations

The native vehicle callback test passed. A separate native DLL comparison applied
the same 700-frame disturbance/manual trim/reset sequence to the old and
instrumented builds: all 4,200 returned force/position components were identical.
Telemetry checks confirmed zero-valued command reception, counters, transfer
of automatic trim on first manual input, persistent manual latch, and reset.
The Lua callback test checked filtering, missing instrumentation, sampling,
pause behavior, transient export errors, restart, numeric row shape, and duration
limit. This is fixture verification; the user's next flight is the first native
DCS acceptance of this particular recorder. No new flight-test results are
claimed yet.

Build, backup DLLs, native test results and installed hashes:
`D:/Codex-F22-Overhaul-2026-10-25/trim-flight-20261027/`.
