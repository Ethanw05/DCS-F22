# Flight-driven sensor fusion upgrade

Both flights were read before source changes; see FUSION-FLIGHT-REVIEW.json. Raw RWR coalition identification was working shortly after detection in both. The logs did not record DL payloads or fusion rows, so the exact duplicate positions and AI report cadence cannot be reconstructed.

The common awareness picture now joins radar, RWR, datalink and IRST evidence into stable aircraft tracks. MAWS and missile-class RF can share a separate missile warning. No wingman is required for radar/RWR correlation. Radar local track IDs, donor-local IDs, cooperative PPLI and sensor epochs remain distinct namespaces. Only qualified cooperative PPLI has the reviewed cross-sensor world-ID rule.

Matching uses received/source-time geometry, reciprocal best-fit and ambiguity gates, per-reporter exclusivity, and pairwise contradiction checks across a merged group. Two nearby aircraft stay distinct when the evidence supports them; unresolved bearings remain unresolved. Multiple donors do not multiply source-mask bits. Established matches survive unchanged slow reports without renewing their clocks. New contradictory reports and resets retire the association.

Radar/TSD/DEF consumers share the joined identity and provenance. Successfully associated observations draw one aircraft symbol, including coasting radar cases. Fresh onboard observations prevent an unknown-time donor from dimming the whole DEF track. IRST-only bearings are visible without inventing a missile warning or range. Friend/hostile conflicts remain explicit. The picture never grants radar detection, STT, launch or missile-support authority.

Own F-22 peer transmissions are bounded to 5 Hz (previously 1 Hz), at most one packet per callback,33 rows / 16 KiB and no catch-up bursts. Native AI reports use bounded receipt-time motion estimates for 13 seconds while keeping their observation clock unknown; DCS controls actual AI transmission timing. PPLI and surveillance records have separate storage and original clocks, so surveillance cannot overwrite flight membership.

Tactical schema 2 uses an odd/even commit marker and epoch; radar metadata checks its own radar generation. MAWS publication now has the same coherent batch protection. Source leases remain independent. F22_FUSION logs every 2 seconds record received observations, fused IDs, affiliation, masks and native receipt/transmit ages for the next flight comparison.

Validation uses actual Lua owners and native transport code: close formations, multiple reporters, no-wingman radar/RWR, PPLI, IRST, separate MAWS, stale reports, contradictory updates, power/epoch resets, torn packets, display deduplication, and transport timing. Numeric gates and timings are explicit simulator estimates, not authenticated F-22 specifications. See the external sensor-fusion-20261029 build/check records and FUSION-COMPLEXITY.json for limits. Actual post-install flight validation remains pending.

Installed source 1c81b19 into the normal F-22A mod with DCS closed: 588 runtime assets and the DLL hash-verified, 22 runtime files updated, 0 remaining mismatches. All 338 domain + 12 common cases and 30 native tests pass; 102 checks against 158 actual installed Lua dependencies pass. Canonical receipt: [COMPLETE-PACKAGE-INSTALLATION.json](../integration/COMPLETE-PACKAGE-INSTALLATION.json). No simulator operation or post-install flight was performed.


## Follow-up flight: stale entries and display clutter

The next flight is recorded in [FUSION-DECLUTTER-FLIGHT.json](FUSION-DECLUTTER-FLIGHT.json).
It supplied 53 accepted reports with zero reported rejections, roughly 12-second
PPLI/target intervals, and target entries retained as long as 73 seconds after
reports stopped. Unknown observation clocks incorrectly marked every native
report as coasting. Freshness now follows the actual source/receipt clock:
13 seconds to coast, 26 seconds to expire in the native receiver, Lua receiver
and fusion owner. Original observation-clock uncertainty remains explicit.

Removed the dotted radar bearing ring and its passive symbols, the SEARCH and
repeated AZ/HT/EL captions near ownship, and DEF R/DL tags. Rendering changes do
not remove their source data from fusion or missile/lock warnings. The source
changes and actual installed package are checked separately; another flight
remains the host confirmation of the new presentation.

Follow-up installed from source 58a4905: seven Lua assets plus the matched DLL updated,
all 588 runtime asset hashes verified with zero mismatches. 339 domain cases,
12 common cases, 30 native checks and 103 installed-package cases passed. No new
Lua or native diagnostic signatures. DCS remained closed during installation;
post-install flight confirmation remains pending.

## Radar acquisition after a donor report has gone stale

Previously, only an already established match survived the donor's 13-second
prediction limit. A radar acquisition after that point could leave two symbols.
The new delayed matcher compares the donor's estimated motion with current
radar position and velocity, requiring reciprocal best fit and three distinct
radar observations spanning at least 0.5 seconds. Reprocessing the same radar
observation does not advance confirmation. Unresolved close formations remain
separate; changed reports, sensor generations and lost candidates reset it.

This association-only estimate is limited to the donor's existing 26-second
retention. It never moves the displayed stale donor, extends its lifetime or
refreshes its timestamp. Once confirmed, radar supplies the fused direction and
range, the duplicate offboard symbol disappears, and DEF shows one aircraft.
Established associations survive radar-observed turns while the donor remains
unchanged. New contradictory donor reports must qualify again. Missing receipt
time cannot stand in for a known source observation clock.

The conservative simulator gates require radar age at most 1 second, valid
velocity, position sigma at most 100 m and velocity sigma at most 25 m/s. The
position gate is 250 m plus twice radar position sigma, with velocity difference
at most 50 m/s. These estimates are not authenticated aircraft specifications.
At most 64 confirmation candidates persist (128 records during frame rollover),
within the existing 176-observation pair and union work budgets. New helper
complexity is at most 10; changed module complexity is at most 13.

The last flight log remains SHA256
5d2c20a7bc8c425b04933c321b28cb4d2973f166798ebf18e6c2f313a3af5f4d;
no additional flight was available. Forty focused source cases and the same
forty cases using 75 actual installed Lua dependencies pass, with zero Lua lint
findings. Three fusion files were installed with DCS closed; the installed DLL,
controls, audio, HUD and concurrent radar button changes were preserved.
See [DELAYED-DONOR-INSTALLATION.json](DELAYED-DONOR-INSTALLATION.json).
Flight confirmation remains pending.
