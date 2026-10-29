# Native host update: bounded integration proposal

The [inventory](ADAPTER-INVENTORY.json) covers all 12 `Native*.cpp` adapters, 14 capability rows, the optional renderer probe and existing common helpers. It pins source hashes and the installed DLL identities from Chat 4's comparison. Ten adapters consume private host contracts; `NativeGroundRadar` is a coordinator; `NativeAltimetry` uses public pressure input and a named clock export. The common seam remains a proposal. The separate air-radar update is committed on primary `main`; [PRIMARY-RESULTS.json](PRIMARY-RESULTS.json) and [BUILD-RESULTS.json](BUILD-RESULTS.json) supersede its captured inventory baseline. [INSTALLATION-OBSERVATION.json](INSTALLATION-OBSERVATION.json) confirms that a subsequently installed DLL matches current native source. Radar Lua installation and actual DCS effects remain open.

## Preserve capability boundaries

Use one small common PE identity reader and bounded status vocabulary, with **owner-specific immutable profile subsets**. Each owner keeps its typed binder, private fields/slots, native allocations and lifecycle. Primary `NativeAesaRadar.cpp` now uses `AesaHostProfile.h` for its four-image selector. This does not enable unreviewed profiles in the other adapters.

| Capability | Current guarded dependency subset | Additional named dependency |
| --- | --- | --- |
| Air radar | CockpitBase, edObjects, World, WorldGeneral | None |
| Surface sensor | Same four plus GraphicsVista | None |
| Ground video | CockpitBase, Visualizer, SceneRenderer, enlight, GraphicsVista | World clock |
| Optional texture diagnostic | dx11backend, Renderer | edCore rendering queue/thread |
| Datalink | CockpitBase, wRadio, WorldGeneral, edCore | World clock |
| Passive RWR coalition metadata | CockpitBase, WorldGeneral, World | None |
| Missile warning | CockpitBase | World clock |
| IR seeker | CockpitBase | World clock |
| Missile descriptor/DLZ | Weapons, separately from seeker | Its existing payload owner |
| AAM TOF | WeaponsBase, separately from seeker/DLZ | None |
| Gun sight | CockpitBase, Weapons | World clock |
| Bomb sight | CockpitBase | World clock |
| Navigation receivers | CockpitBase | Optional WorldGeneral declination/coordinates |
| Pressure altimetry | None | World clock and checked parameter exports |

These are captured source guards, not a claim that every existing guard is irreducible. Narrowing one requires owner evidence for the remaining typed contract. No capability waits for all 14 DLLs. Missing TOF, a render diagnostic or optional declination must not disable otherwise supported unrelated providers.

## Reduce repeated maintenance at specific seams

1. **Common identity observation and selection.** Chat 2 can extract a bounded PE64/AMD64 reader from the reviewed AESA candidate. Cache at most 16 normalized module observations per explicit initialization generation. Each descriptor selects its own exact required identities, then checks its exports and private invariants. Unknown or mixed required images fail closed; no nearest-version or mangled-name-only fallback for private layouts. Avoid per-frame PE/export scans.
2. **Record private assumptions once.** Give each private record an owner, profile ID, module subset, typed signature, offsets/slots/native extent, invariant checks, evidence path/hash/range, original-versus-derived designation and qualification limits. Start with actual repeated records: CockpitBase object resolver `0x2165d0` (Datalink/ContactIdentity/Sidewinder); allocator IAT pair `0x449470`/`0x449460` (Navigation/MWS); camera784 layout (GroundSensor/Video); scene conversion/query contracts (Air/Ground). Sharing a record does not share borrowed object lifetime.
3. **Prefer already evidenced accessors to replicated fields.** Air/Ground already use named `GetPoint`, `Type`, `Position`, `IsDead` and velocity accessors; current WorldGeneral field movement remains behind those accessors. Preserve that boundary. Existing AESA `read_gun_motion` shows an alternative lookup seam: exported `RegisterManager::instance`, virtual2 lookup, virtual7 conversion. It is a candidate for replacing the three private CockpitBase resolver references only after current-host ID, conversion and lifetime equivalence are proved; its current source presence alone is insufficient. Navigation/Weapons owners should similarly replace a raw field only when the matching host accessor and ABI are evidenced.
4. **Keep the parameter port.** `EDPARAM` already provides explicit initialization/invalidation, context epochs, bool reads, valid-zero preservation and guarded writes. Reuse [its contract](../../integration/NATIVE-PARAMETER-CONTRACT.md). Named export binding is widespread already; introducing another wrapper would not resolve private layout dependencies. SDK numeric/string setters return void: invocation status cannot acknowledge a simulator effect.

## Startup report and selection

Chat 2 owns a fixed report of at most 16 module rows and 24 capability rows (40 rows per generation). A capability row contains generation, capability ID, selected profile ID or none, state, first failed requirement ID, module-row index and context generation. States: `waiting_module`, `unsupported_profile`, `missing_export`, `layout_mismatch`, `binding_available`, `awaiting_context`, `context_ready`, `retired`.

Emit at explicit initialization and bounded actual state transitions, using fixed IDs/buffers; no per-frame logs or hot-path file I/O. Missing modules can be retried at declared initialization boundaries. Release must withdraw output, drain owned callbacks and retire pointers before rediscovery. A repeated address does not establish the same native owner. Binding/context readiness remains separate from a fresh observation, RF grant, weapon solution, video frame or IFF reply.

Runtime matching uses validated loaded PE identity plus selected private invariants. Keep original file SHA256 in the offline support manifest; do not compare a relocated loaded image or restored snapshot with that file hash. Any derived image needs its own hash, derivation and covered code ranges. A matching stamp/image size is a support selector, not proof of safety or runtime effect.

## Integration order and required evidence

Chat 3/root has the focused [AESA candidate](NATIVE-AESA-CURRENT.patch), selected profile table and [current evidence](AIR-SEAM-PROOF.json). The later [query ABI review](NATIVE-AESA-QUERY-ABI.patch) supersedes preliminary const-reference wording in that evidence: the native query owns/destroys a by-value 64-byte callback and returns a traversal result. The combined candidate includes that correction. Neither this inventory nor an export list grants runtime qualification. Surface query/frustum/ray/RCS and video indicator/camera/render fields require their distinct current-host proofs.

Weapons/EW owns seeker, missile, bomb/gun, MWS, datalink and passive identity contracts. Chat 2 owns navigation, common identity/report support, CMake and final shared integration. Chat 1 retains the public pressure producer. Radar-owned IFF work remains frozen for Weapons/EW; a compatibility report cannot supply IFF readiness. No blanket stamp update or unrelated owner edit is proposed.

The ground Query ownership repair is also committed (`20374a8`), with two warning-clean owner targets in [ground-query-abi-55224a2/RESULTS.json](ground-query-abi-55224a2/RESULTS.json). Its old host guards remain unchanged. The earlier static matrix retains its original hashes and pre-repair source diagnosis. [PACKAGING-GAPS.json](PACKAGING-GAPS.json) separately identifies the changed payload preset omitted by the existing package manifest; the final joint manifest must include it.

For each owner profile, test actual selectors/binders with known old/current subsets, unknown/mixed required images, optional absence, malformed PE, absent exports, wrong vtable/layout invariants, delayed module discovery, context reset/address reuse and paired native allocator/destructor families. Recheck exact source hashes before applying owner patches. Keep original-file, restored-code, synthetic host-test and actual DCS results separately identified; the last is still required for callback lifetime, scene queries, weapon effects and render/VR behavior.
