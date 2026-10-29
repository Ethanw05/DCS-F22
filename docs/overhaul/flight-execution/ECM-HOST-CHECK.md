# ECM host check — 28 October 2026

The current evidence supports a functioning common DCS ECM control path on
DCS 2.9.31.29434. It does **not** establish how much that ECM delays a particular
SAM's detection, tracking or launch. No update-related ECM control failure was
found. No production strength, signature or native offset was changed for this
check.

## IDA MCP comparison

The existing IDA sessions were queried through their plugin's local `/mcp`
JSON-RPC endpoint. The sessions identify the previous and current CockpitBase
images by SHA-256. Current WorldGeneral analysis uses the restored analysis
snapshot already qualified in `../radar-execution/host-update/AIR-SEAM-PROOF.json`;
its hash differs from the installed packed DLL. It was not loaded into DCS.
`ecm-host-check.json` records inputs, addresses, comparison hashes and captures.
Raw disassembly and pseudocode remain in the external analysis directory.

| CockpitBase function | Previous RVA | Current RVA | Result |
| --- | --- | --- | --- |
| ECM getter | `0x27a1c0` | `0x362200` | Same normalized pseudocode |
| ECM setter | `0x27aab0` | `0x362af0` | Same normalized pseudocode |
| Simple radar ECM lock-block check | `0x3406e0` | `0x42ef70` | Same normalized pseudocode |

Normalization removes IDA address comments, image/import address literals,
generated function addresses and whitespace. It preserves member offsets and
non-address numeric constants. This establishes agreement for these routines,
with the inspected calls and member roles below; it is not a whole-DLL equivalence
claim or a substitute for executing a receiver against a jammer.

The setter accepts a Lua **boolean**, resolves the aircraft's ECM object through
virtual slot 57, and calls its enable method at slot 2. It returns no Lua value.
`EW_System.lua` supplies the required boolean and accepts a successful call with a
nil result. It polls the native getter and retries mismatches. The getter reads
the aircraft's native flag 8, rather than a local cockpit switch variable.

Current WorldGeneral confirms the common ECM object's owner at byte offset 8,
strength at 16 and the active/strength vtable entries used by our guarded native
reader. The constructor initializes strength to 1.0, with type-dependent branches
using 0.79, 1.0 or 1.92. These are internal simulator coefficients: this check
does not identify the F-22 instance's actual value or convert them to RF watts.

Enable starts a pending timer. After 1.05 seconds, its activity sets flag 8 and
submits an enabled ECM record, including strength, to the world radar processor
through slot 5. Disable resets flag 8 and submits a disabled record. The processor
inserts the supplied record under the unit ID and includes registered ECM records
in its work input. This traces a native submission path beyond the cockpit flag.
It does not show an actual SAM accepting a particular target/receiver result.

The simple radar receiver separately checks active ECM, obtains its strength and
applies receiver/geometry conditions. Its code provides evidence of modeled
jamming and burn-through behavior for that receiver. Its constants cannot be
used as a Tor/Osa detection or burn-through range.

## Actual flight observations

The earlier log snapshot had 678 service rows with ECM requested, host enabled,
native ECM valid/active and fresh indication, with driver-ready and reason zero.
One observed activation took approximately 1.224 model seconds, consistent with
the native 1.05-second delay plus sampling cadence.

A newer live-log snapshot, captured at 02:42:26 UTC on 29 October, contains 2,283
service rows across five segments. Of these, 1,014 show requested/enabled ECM and
fresh native active indication with no control failure or adapter error. The
last such row is at 02:39:47.554 UTC, model time 117.708 seconds. These are repeated
status observations, not independent effectiveness trials.

In the fourth segment, the native sequence and sample time subsequently stop at
sequence 45254/time 117.5 while Lua model time advances. Fifty-nine rows reject
the stale indication and display enabled state 2. The control remains requested
and host-active. The freshness guard does not disable ECM. The reason sampling
stopped is unqualified; these rows cannot prove continued transmission or a
jammer shutdown.

The telemetry names containing `TRANSMITTING` describe the adapter's validated
common ECM object/active state. The adapter checks that strength is finite and
within bounds, but does not publish its value and permits zero. Consequently,
those names do not authenticate nonzero RF output, a victim's tracking loss or
SAM suppression. Neither captured log contains the prepared `F22_RCS_SAM|`
observer records or an embedded loaded-binary identity token.

The installed F22.dll changed between the earlier flight and this check, and
again during parallel integration. The receipt distinguishes historical file
identity, current installed identity and observed runtime status. An on-disk
hash alone does not authenticate the DLL loaded in a flight.

## Remaining effectiveness gate

Use the prepared matched F-22/Hornet qualification missions at the same altitude,
geometry, speed, stores and threat settings, with separate ECM-off and ECM-on
passes. Record per-threat detection, tracking and launches, source age and the
loaded package identity. Repeat with the multiplayer server controlling the AI.
The existing close-pass account and an active JAM indication cannot replace
those observations. Dynamic ownship RCS remains a separate open host-effect and
multiplayer qualification requirement.
