# Flight-driven sensor fusion upgrade

Both flights were read before source changes; see FUSION-FLIGHT-REVIEW.json. Raw RWR coalition identification was working shortly after detection in both. The logs did not record DL payloads or fusion rows, so the exact duplicate positions and AI report cadence cannot be reconstructed.

The common awareness picture now joins radar, RWR, datalink and IRST evidence into stable aircraft tracks. MAWS and missile-class RF can share a separate missile warning. No wingman is required for radar/RWR correlation. Radar local track IDs, donor-local IDs, cooperative PPLI and sensor epochs remain distinct namespaces. Only qualified cooperative PPLI has the reviewed cross-sensor world-ID rule.

Matching uses received/source-time geometry, reciprocal best-fit and ambiguity gates, per-reporter exclusivity, and pairwise contradiction checks across a merged group. Two nearby aircraft stay distinct when the evidence supports them; unresolved bearings remain unresolved. Multiple donors do not multiply source-mask bits. Established matches survive unchanged slow reports without renewing their clocks. New contradictory reports and resets retire the association.

Radar/TSD/DEF consumers share the joined identity and provenance. Successfully associated observations draw one aircraft symbol, including coasting radar cases. Fresh onboard observations prevent an unknown-time donor from dimming the whole DEF track. IRST-only bearings are visible without inventing a missile warning or range. Friend/hostile conflicts remain explicit. The picture never grants radar detection, STT, launch or missile-support authority.

Own F-22 peer transmissions are bounded to 5 Hz (previously 1 Hz), at most one packet per callback,33 rows / 16 KiB and no catch-up bursts. Native AI reports use bounded receipt-time motion estimates for 13 seconds while keeping their observation clock unknown; DCS controls actual AI transmission timing. PPLI and surveillance records have separate storage and original clocks, so surveillance cannot overwrite flight membership.

Tactical schema 2 uses an odd/even commit marker and epoch; radar metadata checks its own radar generation. MAWS publication now has the same coherent batch protection. Source leases remain independent. F22_FUSION logs every 2 seconds record received observations, fused IDs, affiliation, masks and native receipt/transmit ages for the next flight comparison.

Validation uses actual Lua owners and native transport code: close formations, multiple reporters, no-wingman radar/RWR, PPLI, IRST, separate MAWS, stale reports, contradictory updates, power/epoch resets, torn packets, display deduplication, and transport timing. Numeric gates and timings are explicit simulator estimates, not authenticated F-22 specifications. See the external sensor-fusion-20261029 build/check records and FUSION-COMPLEXITY.json for limits. Actual post-install flight validation remains pending.
