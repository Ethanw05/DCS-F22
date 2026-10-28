# I-NAV-001 altitude consumer admission

Chat 2 owns the sole Altitude_System producer and shared read-only
Altitude_Snapshot admission. Schema 1 protects selection, three distinct source
values/flags/observation times, World clock kind 2, current physical generation
and publication time under an odd/even sequence. Source units are feet. BARO and
STANDBY retain the native -3000..32000 metre domain; radar retains 0..20000 metres.
The 0.2-second maximum age and 0.01-second future tolerance are explicit software
transport policies inherited from native altimeter admission, not F-22 sensor
specifications. Copy/publication never renews observation time.

Every consumer also requires the current valid physical generation and its own
World/model clock. Schema/clock/generation/torn/rollback failures withdraw the
snapshot. A clock rollback requires a new physical generation; old generations
cannot return. Per-source failures withdraw that source alone. RDR selection
falls back to fresh BARO with BARO FB feedback; STBY never silently switches.

Consumer migration: HUD altitude/pressure context, Avionics BARO side readout,
common/UFD indicator validity, pilot warnings, UFC altitude rows, and native
AFCS radar-height admission. The native branch additionally needs checked reads;
old field flags alone never establish freshness. Keep physical atmosphere and
ADC validity separate from independent healthy standby pressure.

Status: producer and all listed consumers migrated. Independent tests execute
the actual producer, HUD, side readout, UFC, warnings and native reader across
normal, stopped/torn/invalid, rollback, generation and recovery cases. The
current source build passes; installed DCS, optics, audio and aircraft sensor
calibration remain separate P-NAV-001 qualification limits. HUD appearance and
recorded audio are preserved.
