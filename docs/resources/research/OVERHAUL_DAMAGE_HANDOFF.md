# F-22 damage-cell metadata correction candidate

## Result and exact artifact

A single collision-shell name in the external model fails the supported host's standard damage-cell/property coverage. A narrowly staged asset correction resolves that mismatch without changing model geometry, animation, materials, parent hierarchy, render names, damage arguments or aircraft numeric damage records.

- Staged asset: `D:\Codex-F22-Overhaul-2026-10-25\damage-cell-review\stage\Shapes\F-22A.EDM`.
- Original preserved asset: `originals/F-22A.EDM`.
- Reproducible guarded builder/verification: `stage_damage_shell_fix.py` and `inspect_edm_damage.py`.
- Exact hashes, field bytes/offset accounting and results: `damage-shell-fix-manifest.json`.
- Static host/aircraft property coverage: `collision-cell-property-coverage.json`.
- Verification output: `staging-checks.log`.

**No shared/live asset was overwritten. No DCS launch, replay, installation, stop or restart occurred.** This is a metadata correction candidate awaiting the owner's controlled native qualification window. Do not call it a runtime-qualified damage/repair fix yet.

## Evidence for the intended mapping

The user's preserved log reports `No property record for cell "FIN_L_BOTTOM_DAM"` at line947, followed by `Corrupt damage model` on all six aircraft loads. The aircraft definition selects the external `F-22A` shape; the installed and development external model files had identical SHA256 when preserved.

The typed EDM parser reads the original file completely, with no recovery/unknown-type warnings or trailing bytes:

| Category | Count |
| --- | ---: |
| Transform/animation nodes |214|
| Render nodes |89|
| Collision-shell/segment entries |110|
| Actual ShellNode entries within that list |70|
| Materials |28|
| Connectors |34|
| Light nodes |9|

Relevant typed records:

| Record | Name | Parent/condition |
| --- | --- | --- |
| Transform99 |FIN_L_BOTTOM|ArgVisibility243, range-1.72..1.0|
| Collision ShellNode34 |FIN_L_BOTTOM|Parent99|
| Transform213 |FIN_L_BOTTOM_DAM|ArgVisibility243, range1.0..1e300|
| RenderNode26 |FIN_L_BOTTOM_DAM|Parent213; damage argument243|
| Collision ShellNode109 |FIN_L_BOTTOM_DAM|Parent213; the sole unresolved collision name|

The undamaged and damaged left-fin presentations refer to the same existing physical damage argument243. The right damaged transform/render retain their separate `FIN_R_BOTTOM_DAM` names but do not have a correspondingly misnamed damaged collision shell. Do not rename every `_DAM` string: those render/visibility names describe distinct visual states and are preserved.

Primary local source evidence:

1. The supported installation's `D:/DCS/Scripts/Aircrafts/_Common/Damage.lua` maps `damage_cells["FIN_L_BOTTOM"]=43`; no `FIN_L_BOTTOM_DAM` alias exists.
2. The preserved as-found aircraft definition already has Damage[43], args={243}, critical damage2 and dependencies39/53. Its numerical record is retained unchanged.
3. Resolving **every one of110 original shell/segment names** through that host dictionary and requiring an existing active aircraft Damage[id] record produces exactly one failure: ShellNode109. After the staged correction all110 resolve to existing properties. Full evidence is recorded in the coverage JSON.
4. Existing model ShellNodes already repeat standard cell names for wings, gear, fuselage, engines and gun. Assigning the damaged left-fin collision geometry to the existing left-fin cell follows an existing asset pattern; no new numeric cell or global alias is introduced.

These facts strongly connect the unique typed name mismatch to the exact logged error. The internal native lookup path has **not** been decompiled here. IDA metadata was checked before considering addresses: the available database was CockpitBase.dll (SHA256163d55167503da8dd0ea9eb459e17206fc3dc8d6b4805b5b13bbe58341beb794), not the relevant world/damage implementation, so no WorldGeneral addresses were guessed or falsely attributed. Native startup qualification remains the causal acceptance gate.

## Exact binary change and preservation

The EDM is version10. Node instance names are serialized as little-endian length-prefixed uint_string values; the global type-name lookup table is separate. The parsed type and unique shell field are checked before any write.

| Field | Original | Staged |
| --- | --- | --- |
| Typed container/list index |SHELL_NODES /109|unchanged|
| Type |model::ShellNode|unchanged|
| Instance name |FIN_L_BOTTOM_DAM|FIN_L_BOTTOM|
| Name field offset |1,379,525|unchanged start offset|
| Name string byte length |16|12|
| Encoded length+name field |20bytes|16bytes|
| Total file length |28,609,462bytes|28,609,458bytes|
| Original SHA256 |5a3feaad9939c169be909f761428fe221008e54edaf0eb0f01a82b0c10265e9b|—|
| Staged SHA256 |—|1429462f21b3cfd79af144589980baa56b1f586f3bec09158b49a335c5f5d10e|

The prefix through offset1,379,524 is identical. The original suffix beginning1,379,545 is preserved byte for byte and begins at1,379,541 in the staged file. All subsequent bytes shift by-4; no array count, type lookup/index map, geometry buffer, material, hierarchy or opaque block is edited. The complete staged parse reaches the new EOF.

The verifier compares the entire parsed object graph, including dynamic material attributes and all geometry floats/indices, after normalizing the one permitted shell-name difference. Its deterministic serialization hash is identical. The byte-for-byte unchanged prefix/suffix check also covers fields the parser may not expose. Reversing that single length-prefixed replacement yields the exact preserved original bytes and SHA256; the reversed model also parses through EOF and matches the complete original typed model.

The original preserved asset matches the installed/development files captured during this investigation. The earlier221-file installed-as-found flight archive did not include large Shapes assets, so its original flight-time asset hash was not independently recorded. The report does not silently elevate a postflight asset hash into a preflight manifest guarantee.

## Native qualification to queue after current owners release DCS

The parent/runtime owner should preserve the current live asset and install only this staged external model in the controlled window, verifying the recorded staged SHA256. Other source/DLL changes should remain separately identified so the damage result is attributable.

1. Repeat the six-load condition: at least six controlled loads/restarts using the F-22A, verifying the missing-property and corrupt-damage messages are absent on **every** load. Preserve the full logs and module/asset hashes.
2. Test left-fin damage through argument243/state transition, with normal and damaged render states. Verify the damaged collision shell still belongs to existing cell43, actual damage reaches the EFM's intended index and no new right-fin mismatch appears.
3. Test right-fin damage through argument242/cell44 as a symmetric control, preserving distinct visual state names.
4. Test repair, mission restart and hot/cold reset. Damage/visibility/EFM integrity and warnings must recover consistently; absence of a startup message alone does not prove damage callbacks or repair behavior.
5. Check external geometry/materials, normal/damaged visibility and collision interactions at representative views/LODs. Static byte/typed invariance is strong, but host interpretation is still the runtime gate.

If the host still rejects a cell or behaves differently, preserve the candidate and logs, restore the exact original artifact and trace the native lookup. Do not add arbitrary Lua aliases, duplicate numeric damage entries or remove collision geometry to silence a message.

## Reproduction

Run `python stage_damage_shell_fix.py` in this directory. It refuses an unreviewed baseline or changed preserved primary source, writes only beneath this D: review folder, produces the staged asset and manifest, and performs all checks above. The reader sources are the already available local edm-reader-modern pure parser; their hashes are recorded. No Blender export, mesh regeneration, disassembly database mutation or simulation launch is involved.
