# Air radar compatibility proposal for DCS2.9.31.29434

The reviewed combined patch is now applied to the primary checkout on `main`.
[PRIMARY-RESULTS.json](PRIMARY-RESULTS.json) records165 actual-adapter checks,
4550 publication checks and185 packet checks passing with `/W4 /WX /analyze`.
[BUILD-RESULTS.json](BUILD-RESULTS.json) records a stable full DLL build with a
matching embedded source/cache identity. The DLL has not been installed and no
post-update scan or lock is claimed. The analysis/candidate records below retain
their original pre-application hashes and limits.

The current four-module identities differ from the previous qualified bundle.
The installed old Api rejects them with reason2 before it resolves exports or binds a
driver. The observed flight's zero driver-ready/tracks agrees with that refusal;
this is not evidence for changing detection/lock thresholds.

| Module | Current timestamp / image size | Current file SHA256 |
| --- | --- | --- |
| CockpitBase | 6adbad09 / 68e000 | fb0a09be70627c7790dea1527cedfee43082bb8b112484d5c85be1d99d33de95 |
| edObjects | 6ad87426 / 46000 | 53921811f0b0ec487a7615dba8262dad622a94908c84d64528fa3fd62ea5102f |
| World | 6acb804e / 14000 | 80f5bb2f83db6c5023727ff5097ca98a4069ddc767a1881638fc81353b310793 |
| WorldGeneral | 6adbace0 / 127b000 | 83d36b10205234da58b4a98dd06f75a84d6f3e13826d0a123e482eb53a7b8265 |

`AIR-SEAM-PROOF.json` records exact assembly and RTTI evidence, the17 required
export names, peer evidence hashes and current/old input identities. Current
WorldGeneral is packed on disk. The parent-owned offline emulator's reconstructed
snapshot SHA2ecc3945e15e371bb20e9a52000652aac8d28e74f036865382361891f070556b
supplies backed code; this owner did not load/execute a DCS DLL or capture a live
process. The current ECM factory/constructor establishes table1ef6a8 and unchanged
owner+8/strength+16 prefix. Its active80c70 and strength80c60 bodies establish the
new offsets directly. Export names or timestamps alone were not used to infer
them. Scene6/Registered7, own-aircraft40,24-byte GetPoint return buffer, Vec3f
velocity, type/dead/position, optional type text+296, terrain15, manager20/24,
update6 and respondercontext+256 have bounded current-code evidence.

Current edObjects query methods20/24 consume and destroy a64-byte by-value
`std::function`, clearing its holder+38hex before return. Their return is an
integer traversal result. The previous const-reference/void declarations had the
same indirect machine argument shape and physically worked with mutable locals,
but did not describe ownership correctly. The focused proposal uses by-value
callbacks, explicit moves and deliberately ignores the existing traversal result.
No callback values or sensing/visibility policy are changed. Native callback
`QueryObjectBehavior` is32bits; the adapter retains its existing0/1 representation.

The root applied **only the reviewed combined** `NATIVE-AESA-CURRENT.patch`, not it plus its
component patches. It adds checked PE64 metadata, selects either complete exact
old/current four-module bundle, rejects every mixed/unknown bundle and uses that
bundle's verified ECM offsets. `NATIVE-AESA-PROFILE.patch` and
`NATIVE-AESA-QUERY-ABI.patch` and `NATIVE-AESA-FINAL-RELEASE.patch` are separately reviewable components. None was
applied during the delegated candidate review. The pre-application baseline was
SHA18df690166a301b3c0ace7039c593821a2389404c9a19cd0196e33ea7a28196d;
the combined candidate preserves every line from `struct Request` through the
control/publication/responder/gun/bridge/reset implementation except its declared
exact FinalRelease wrapper and slot0 hook rename.

`API-RESULTS.json` records source-stable14-file closure and MSVC `/W4 /WX /analyze`
verification. Unchanged actual source produces149 checks with23 expected
current-host failures; that baseline is diagnostic, not acceptance. The exact
external combined candidate passes165 checks, including actual Api malformed
headers/export/ECM guards and actual Provider search/segment dispatch through
owned inert managers. Separate tracked callbacks verify move transfer and one
destruction; static assertions bind the actual source aliases to by-value
signatures. No DCS export is invoked. The integrator must include
`tests/native/radar_api_profile.cmake` and explicitly enable its reviewed-source
gate after paired source application; an unregistered test is not counted passed.

One separate old issue is corrected in the proposal: driver slot0 is
`FinalRelease(void)`, while the previous wrapper used a deleting-destructor-shaped signature. Both
old/current tables have the same organization; actual deleting destructor is
slot1. The focused wrapper now has exact void(void*) type, captures original0,
resets, then forwards once. An inert fixture verifies exact signature and
reset-before-forward order. Native slot1 and ownership scheduling are unchanged;
concurrent teardown/lifetime remain host qualification.

The same activated Api also makes simulator-assisted gun motion reachable.
Current Nx/Ny/Nz exports are explicitly float returns and occupy slots73/74/75.
ModelInstance RTTI confirms MovingObject+48 and slot3 forwarding through slot14
to the same float matrix. Current RegisterManager2/Registered7 resolver is checked.
These are current static interface proofs, not radar-measured motion or aircraft
calibration.

This evidence supports reviewing the compatibility repair. It does not establish
actual host callback serialization, borrowed-object destruction, live scene/LOS
effects, aircraft calibration, installation or loaded identity. Root/integrator
owns applying the narrow region, rebuilding the matched full package and later
flight verification. SAR remains frozen.
