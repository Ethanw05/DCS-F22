# NAV-03: common COM1 / COM2 prototype handoff

2026-10-25, America/Denver. **Isolated, inactive, uninstalled and not native-flight qualified.** No user flight or installed runtime has been operated/changed by this prototype. Parent owns runtime scheduling: ground renderer, then warnings, then COM. Wait for explicit ownership handoff.

This is the authoritative COM handoff. It replaces exploratory COM paragraphs in OVERHAUL_NAV_HANDOFF.md. All accessor and PTT semantics below reflect the later checked export/assembly evidence.

## Package and inactive integration

Candidate: `C:/Users/Ethans Desktop 2.0/Documents/Codex/2026-10-24/o/work/comms-proof/candidate/`.

Patch: `C:/Users/Ethans Desktop 2.0/Documents/Codex/2026-10-24/o/work/comms-proof/integration.patch`.

The patch was generated against the four current shared files hashed below. `git apply --check --ignore-space-change` passed at that checkpoint. Recheck if those sources change; never overwrite/reset another lane's work. The patch is not applied.

The native CMake option F22_ENABLE_COM_PROOF defaults OFF. Proposed RAPTOR include/update/reset calls are enclosed in its compile guard. The separate device_init local F22_COM_PROOF_ENABLED defaults false. Default operation therefore calls no bridge and creates no unqualified factories. Both gates must be deliberately enabled only in an owned test package. Device definitions append29COM1_NATIVE,30COM2_NATIVE,31COM_INTERCOM,32COM_CONTROLLER; no existing ID shifts. Ground video requires no IDs and its indicator/controller14 is preserved.

Copy candidate EFM/source, Systems and tests files to matching source paths only when parent integrates. The patch adds scoped hooks, default-OFF option, adapter test and gated creators; it does not duplicate whole shared sources. Existing EFM source glob picks up NativeRadios.cpp. Fragment files are proposals, not runtime files. No ICP/MFD/input/comm.lua edit is included. Do not expose COM controls while the prototype is disabled.

Files: NativeRadios.{h,cpp}, RadioRequests.h, RadioPTTLease.h; COM_Radio_Config.lua, COM1_Native.lua, COM2_Native.lua, COM_Intercom.lua, COM_Controller.lua; wiring/CMake fragments; native adapter and Lua controller tests. Complete paths and hashes follow.

## Checked common factory and semantic evidence

CockpitBase contains cockpit::avDefaultLuaRadio -> DynamicBaseRadio. Candidate creator identifier is avDefaultLuaRadio using the common type-factory pattern. avLuaRadio is absent and is not guessed. Static initializer0x1800B2030 builds StandardFactory<avDefaultLuaRadio>, obtains type_info0x180557EE0, adds its identifier at0x1800B20CC, installs WorldFactory vtable0x180460638, registers it at0x1800B2136. Factory creation0x1802DF1B0 calls actual constructor0x1802DED60. avIntercomV2 has separate WorldFactory0x180463130. This proves compiled common availability, not successful construction in this cockpit.

DynamicBaseRadio Lua registration0x1802C6F40 provides tuned/commanded frequency, channel/range, modulation, on/off and volume methods. Common post_initialize0x1802C7330 connects actual receiver/dialog/audio machinery. TF-51D instead uses aircraft-specific P51Common::avVHF_SCR_522A_P51; it is not a dependency of this candidate. No paid aircraft code/audio/assets are copied.

Correct communicator accessor is the exact exported `?getCommunicator@avBaseRadio@cockpit@@QEAAAEAVavCommunicator@2@XZ`. Exported avMarkerReceiver::getRadioReceiver returns wRadioReceiver, despite a misleading shared-function alias in IDA, and is not used. All23 named CockpitBase symbols/data bindings plus the World model-clock export in the candidate exist in the audited binaries; work/comms-proof/check_host_exports.py checks the actual PE files.

Vanilla avIntercomV2 Lua selection is a stub: l_set_communicator0x1802E2D10 calls virtual+168, whose actual slot21 is empty0x1801E2420. make_setup_for_communicator calls virtual+152, resolving to unconditional true0x1801E2390. Neither result is treated as selected-radio readiness.

avIntercomV2::pushToTalk0x1802F50B0 forwards to0x1802E2FE0, which only opens the DCS command dialog on true; false does nothing. It is COMM MENU here, not microphone keying. Candidate uses genuine exported setCommunicator(pointer)/setAsCurrent before that menu action. A separate genuine VoIP proof path is now staged below; it defaults off and is not native-qualified.

isTransmitterOn indicates component enable/power: setOnOff0x1802E8440 enables both receiver and transmitter components. It does not prove an on-air carrier. Candidate exports TRANSMITTER_ON only. TX_READBACK_VALID and SELECTED_READBACK_VALID remain0; there is no TX lamp or verified selected-receiver indicator. DIRECT_PTT_AVAILABLE is0 by default, and becomes1 only for the separately opted-in, powered, mapped VoIP proof route. It is route eligibility, not transmit success.

## Native safety and validity contract

Exact CockpitBase PE timestamp0x6ac12468/image size0x59a000 is required. Unknown build fails closed before binding/use. All exact methods and expected exported vtables must resolve. Each update looks up the current context and owned IDs29/30/31, checks exact primary vtable and MSVC RTTI, then obtains the current communicator/transmitter. No old device pointer is retained.

Positive operation waits for an owned nonnull transmitter. Constructor Lua only sets GUI and native frequency ranges, with no premature receiver/transmitter calls. Quench also skips an uninitialized transmitter. Request lease is≤200ms with finite time, selected1/2, integer bounded menu sequence, on0/1, volume0..1 and valid frequency. MAIN_POWER gates actual logical on-state. Missing/stale/invalid requests clear own intercom and switch owned initialized receivers off. Missing/wrong types quench only still-owned matching objects. Exceptions latch failure/reason7 until reset; reset re-resolves ownership rather than using stale pointers.

Commanded frequency is compared before a new tune so a delayed native tuner is not restarted each update. Actual tuned frequency alone supplies the display. Missing/stale backend (>200ms) yields NO DATA. Native reason codes:1modules pending,2unsupported host,3missing symbol,4missing/wrong/uninitialized devices,5invalid/stale request,7native exception. NATIVE_READY means adapter availability, not successful radio contact.

## Bounded control contract and proposed ICP workflow

AM only,25kHz steps,118.000–151.975 or225.000–399.975MHz. Defaults305.000 and127.500MHz are mod settings, not recovered F-22 presets. Own preset slots1–20 store/recall validated targets; tuned readback remains independent. No FM,8.33kHz, crypto, hopping, guard or network feature is advertised.

Controller device32 commands:

| Command | Raw value/action |
| --- | --- |
|11200|Select edit radio1/2.|
|11201|Target frequency kHz, e.g.305000.|
|11202|Recall populated preset1–20.|
|11203|Selected logical on0/1.|
|11204|Selected volume0..1.|
|11205|Store validated target in preset1–20.|
|11206|Edge-triggered COMM MENU request.|
|11207|Held VoIP PTT intent; only accepted on a fresh press with the separately enabled proof route. Release is accepted even without power.|
|11208|Qualification-only VoIP opt-in0/1, defaults0. No cockpit/input assignment.|

ICP proposal only: COM1/COM2 opens its edit page. Rows: actual tuned readout/tune; preset recall/store; requested power plus actual on-state; volume; COMM MENU. Distinguish desired entry from actual data. Never label edit selection TX COM1/COM2 while SELECTED_READBACK_VALID=0. No physical assignments or shared ICP edits have been made.

Requests: F22_COM_REQUEST_TIME/VALID/SELECTED/PTT, F22_COM_MENU_SEQUENCE, F22_COM_PTT_SEQUENCE, F22_COM_VOIP_OPT_IN, per-radio F22_COM1/2_REQUEST_HZ/ON/VOLUME. Results: per-radio TUNED_HZ/ACTUAL_ON/TRANSMITTER_ON/READBACK_VALID; F22_COM_RESULT_TIME, NATIVE_READY/REASON; the route-eligibility and unavailable selection/TX-valid flags above. Diagnostic VOIP_ID and NATIVE_TRANSMITTING_FLAG per radio are not certified TX indications. Lua captions F22_COM1_TEXT/COM2_TEXT use native readback only; F22_COM_STATUS_TEXT and F22_COM_TX_CAPABILITY_TEXT identify missing backend/PTT limits. Parent must preserve freshness/validity gates.

## Completed isolated checks

Isolated project `o/work/comms-proof/CMakeLists.txt` built Release;1/1 native adapter CTest passes. It uses the actual candidate cpp with fake host/RTTI/parameter plumbing. Coverage: wrong host metadata, ownership, initialized-transmitter wait, commanded-versus-actual delayed tune, no repeated tuning restart, menu edge, component enable readback, stale/future/NaN/band/step/power/wrong-device/reset gates; the VoIP intent/release cases listed below. This is not a DCS ABI or flight qualification.

Actual staged Lua parses and controller tests pass independent presets/power, actual-only frequency captions, invalid requests, stale backend, menu edges, default-off VoIP, physical device32 press/release decoding, stale/power/selection/opt-in recovery without re-key, and no receiver calls in constructor Lua. Tests use portable repository-relative paths after copying. Logs: o/work/comms-proof/configure.log, build.log, lua-tests.log. No shared DLL build or runtime/process/input/installed-file operation was performed for this prototype.

## Required native acceptance after handoff

1. Wait for user closure and parent/ground runtime handoff; never stop their flight.
2. Enable both proof gates only in a reversible owned package. Inspect actual construction, exact RTTIs and native communicator/transmitter availability before positive actions.
3. Prove both actual tuned/on-state readbacks. Test receiver audio/independent volume against known compatible airfield/AI sender; wrong frequency, restore and radio independence.
4. Check each radio's COMM MENU and actual recipient/frequency behavior. Menu appearance alone is not transmit proof. Separately opt into VoIP proof with command11208 only after mapping/power readback succeeds. Verify actual microphone/audio transmission and release with a real recipient/capture; include simulator pause, active pause, focus loss and input release while paused. The model-time heartbeat alone does not establish real-time PTT release during full simulator pause. No normal PTT binding or TX indication may be enabled before these gates pass.
5. Qualify power/lease/controller loss, mission restart and receiver recreation; ensure no old connection/menu event persists.
6. Default-enable and expose cockpit controls only after this evidence; otherwise keep the candidate inactive without affecting working NAV/AP/radar.

## Exact candidate SHA256 checkpoint

| Candidate-relative file | SHA256 |
| --- | --- |
| `CMAKE_INTEGRATION.fragment.txt` | `16a349e68ac079f2d6b872b21669de1909dce468a5277e68c5a9d6962f158a50` |
| `Cockpit/Scripts/COM_DEVICE_WIRING.fragment.lua` | `d568fb787360685bd67907e51617440be7833b174aac004882f64204b0e52956` |
| `Cockpit/Scripts/Systems/COM1_Native.lua` | `b5ec3042dcea0e0a9d93c3dd9a73b7f649d7ec59557c617d4f4076e4069e0259` |
| `Cockpit/Scripts/Systems/COM2_Native.lua` | `9680519f3b235254cdfafb82665b867a0b981457996712fe9263c02d9391d686` |
| `Cockpit/Scripts/Systems/COM_Controller.lua` | `33cec2a17da8c7d76f726b4abcec3e297308dfba1ac9c528bccf2133b3275f5d` |
| `Cockpit/Scripts/Systems/COM_Intercom.lua` | `af5b4e7cd3e35e696f3d683b6d9a5081dd239f904e6bc2445950b94d3b14db4a` |
| `Cockpit/Scripts/Systems/COM_Radio_Config.lua` | `76e2c70ea9c749f00d716b39b74fe991a12e6a6b21af0b886af85b9c6c1fdf9e` |
| `EFM/source/NativeRadios.cpp` | `531c67ac7f1e1324817c75ffd04a18edffec64cab3af3fe0b9533aa1bffccd03` |
| `EFM/source/NativeRadios.h` | `0e681026c316bc538327f26a6b0278d5aef8eee5e42b367c931cf959b467a642` |
| `EFM/source/RadioPTTLease.h` | `134dde95844731fbb2076d92425990bc2975864f1ea207d444c44bd9fea37cd1` |
| `EFM/source/RadioRequests.h` | `ec6451fbde1f6d508d725701f7a0813623414cee88d33a67a3e6e8d8f1c26738` |
| `tests/test_com_controller.py` | `8d17f8fc18f00093ab82c0c3c4c56ef9adaae4b2ae362f76b308008e041a585d` |
| `tests/test_native_radios.cpp` | `6711224588d7c75d97eba1057d0218862831f3161f7c734a5bb95e91d76f1ed1` |

Integration patch SHA256: `9f8febbcae1a831930c4cbb9da9490e4184854ae11c296eb4e263e09b7610b55`.

## Shared-source baseline for the integration patch

These bytes identify the dry-run checkpoint, not a lock against other owners' changes.

| Repository-relative baseline | SHA256 |
| --- | --- |
| `EFM/source/RAPTOR.cpp` | `d2acccdf1db311ece8b569cae0935e320686be5c86d88a989a7f6ca2db3597df` |
| `EFM/CMakeLists.txt` | `df47be691e7747e08d544b57d5d9c6e9fb4134b230af66cc0a5c92cb3057d912` |
| `Cockpit/Scripts/devices.lua` | `697d4540c65821788f98b356377c0e25bf12487f75c2e30b74e7f498ad2f23d9` |
| `Cockpit/Scripts/device_init.lua` | `ea723cfedd4761603627dbed395d11c8566214c0aca63c8e24aedc44fba8b0de` |

## Construction diagnostics and native-dialog coexistence refinement

The isolated candidate now reports F22_COM_CONTEXT_FOUND, per-radio DEVICE_FOUND/TYPE_VALID/COMMUNICATOR_VALID/TRANSMITTER_VALID, and F22_COM_INTERCOM_FOUND/TYPE_VALID. It checks every owned slot before reporting failure, so a missing first radio does not hide later construction diagnostics. Controller32 preallocates these fields. They expose boolean constructor/ownership stages, not raw pointers or invented readiness.

Native communicator selection now occurs only after a real selected-radio request change, a COMM MENU event, or restoration after quench. The bridge no longer reasserts the selected receiver every update, allowing native DCS dialog selection to persist. Independent selected-receiver readback remains unavailable. Fake-host regression verifies exactly one initial selection, no repeated selection during steady/delayed tuning, one new selection for a menu event and one for a real radio change. Native and Lua isolated tests pass. No shared integration or runtime activation has occurred.


## Genuine VoIP path, guarded intent and receive audio

The local current Hornet keyboard/joystick files bind microphone PTT to the global `iCommandVoIPRadioPushToTalkEnableDisableVoice` commands, while the older aircraft-specific VoIP HOTAS bindings are commented out. This is behavioral reference only; no Hornet implementation is included.

The common C export `ed_cockpit_voip_start_stop_transmission(unsigned avDeviceId,bool)` at0x18021CE20 forwards to HumanRadiosKeeper::i_start_stop_nondynamic_radio_transmission0x1802D0D00. It maps the **owned avDevice ID**, not guessed first/second-radio ordering, with getRadioIdBy_avDevice_id0x1802CF9C0. The candidate uses owned IDs29/30 after factory, RTTI and transmitter checks. Optional `ed_cockpit_voip_enable_for_transmission`0x18021CC40 forwards to the permission path0x1802D0700. Missing optional VoIP exports leave the basic tune/menu bridge usable and PTT unavailable.

Start0x1802D0D40 checks the real holder communicator, mapped registry entry, permission and transmitter component, then uses the common VOIP message route. The wrapper returns true for a known device even if the underlying start fails. getCurrentTransmittingRadio0x1802CF020 retains the selected registry index after stop. getIsTransmitting0x1802CF760 reads the native transceiver flag, but that flag's actual semantics still need live qualification. None of those is promoted to on-air success or a TX lamp here.

Stop0x1802D0FB0 stops the **global** VOIP message and ignores the nominal index. Our lease therefore releases only after rechecking the same context, owned exact radio type, unchanged device-to-registry mapping and matching native current-radio index. It never calls global stop for another current channel or a remapped/recreated radio. Release is evaluated **before** changing native radio selection or power. Power-off, stale/invalid heartbeat, opt-out, radio change and reset drop our own intent. No automatic keying occurs on initial hold or restoration; a release and fresh accepted press are required. The lease records an attempted request, not successful transmission. Model-time freshness is200ms; full-pause/focus behavior is explicitly an open native gate.

The actual candidate C++ test covers ten start attempts, release/up deduplication, release-before-selection, held suppression, power/stale/opt-in recovery, foreign-channel protection, changed/missing/duplicate mapping, optional-API unavailability, missing transmitter, malformed PTT sequence and reset. A true wrapper return with a false native flag leaves TX_READBACK_VALID0. The Lua test exercises the real controller including power-off key-up consumption.

Receive-audio evidence is from the common libraries, not a copied aircraft intercom. DynamicBaseRadio::post_initialize0x1802C7330 ensures HEADPHONES exists, post-initializes its communicator and routes the native receiver output into the radio's own regulator. avReceiver::postInitialize_0x1802E7D50 creates native message sources on HEADPHONES and registers its incoming-message handler with the human communicator. DynamicBaseRadio::set_volume0x1802C7C10 sets that radio regulator's gain directly. The candidate already calls it only after native initialization, with the requested0..1 gain.

The newly opened read-only wRadio IDA database (MCP13344, work/comms-proof/ida/wRadio.i64) confirms Sounder::Element0x18008B730 initializes inherited/parent gain1, getResultGain0x180031240 multiplies that gain by local gain, and ParentElement::update_0x18008D040 propagates the product to sources. The **regulator local gain starts0**, so it still needs the explicit native volume call; it is not assumed audible by default. Sources play on their own HEADPHONES host. This explains a plausible complete common receive path without an extra Hornet graph, but only known-frequency receive/audio/volume trials can qualify it. No new sound asset or wRadio binding was added.

Factory identifier lookup is also checked: ccCockpitContext::create0x1801F4BB0 first prefixes `class cockpit::` to the creator identifier (fallback `class `), so the common registry's `class cockpit::avDefaultLuaRadio` corresponds to creator `avDefaultLuaRadio`. This is stronger than guessing a Lua alias, and still does not replace actual construction proof.


## Normal-input direction after native qualification

Keep11207/11208 as proof controls for now. The current local Hornet uses DCS global cockpit-radio VoIP commands, which gives us a stronger normal-binding direction than inventing a second real-time microphone input manager. Before using numbered global bindings, compare each radio's actual device-ID registration with the exported HumanRadiosKeeper::i_get_radio_idx_by_number_and_kind0x1802D0760 for the corresponding cockpit-radio ordinal/group. The function filters the registry by group and type, so ordinal0/1 must not be inferred solely from append-only device IDs29/30. No new binding is included in this candidate. Stock global PTT must still pass microphone, pause, focus, power and key-up trials in this cockpit; its presence in another aircraft's inputs is not proof of our radio ordering or readiness.

## Prepared offline reception fixture

`o/work/comms-proof/prepare_audio_case.py` builds `o/work/comms-proof/F22-Dogfight-Validation.miz` from the existing owned navigation validation mission. It preserves the original mission table byte-for-byte and adds only two original synthesized PCM tones and the manually loaded `F22COMProbe.lua` helper. No flight/trigger/weapon setup is changed. The ZIP integrity, mission/resources Lua and helper logic passed offline checks. No DCS run or installed-file operation occurred.

305.000MHz AM carries a610Hz single pulse;127.500MHz AM carries a930Hz double pulse. The helper starts neither on load. In the owned proof mission, load the packaged helper using the normal DCS script action (or the existing trusted owned-test mission evaluator), then call `F22_COM_PROOF.start('305')`, `start('127500')`, `start('both')` or `stop()`. The transmitter point is1000m north,200m up and1000m east of the proof ownship when started. It stays fixed thereafter; this is a controlled reception fixture, not aircraft state or sensor data. Requested1000W test power is a fixture setting.

The fixture follows the official DCS [mission radio transmission API](https://www.digitalcombatsimulator.com/en/support/faq/1257/): packaged audio, transmitter Vec3, modulation, loop, frequency in Hz and power in watts. The [DCS User Manual](https://www.digitalcombatsimulator.com/upload/iblock/ed6/87v22jwd1xh51i3rgki944xsf503istq/DCS_User_Manual_EN_2020.pdf) also documents the operating-range/frequency requirement for reception. The optional named stop/helper path remains part of live acceptance, not proven by the offline mocks.

Proposed native reception sequence after explicit runtime handoff:

1. Prove construction, fresh actual tuned/on readbacks and distinct registered IDs before emitting a fixture signal.
2. Start both carriers. With COM1 at305.000 and COM2 at127.500, record both tone signatures through the actual headset output.
3. Change only COM1 to306.000, confirm its signature disappears while COM2 stays; restore305.000 and confirm return. Repeat with COM2 at128.000/127.500.
4. Set one radio's volume to0, then restore; repeat on the other. Test independent logical power-off/restore as well. Actual volume/carrier isolation must be observed, not inferred from a parameter request.
5. Stop both transmitters and confirm the known signatures end. Then test actual AI/ATC menu/recipient behavior independently from these tone carriers.
6. Separately test real VoIP microphone PTT with a recipient/capture, key-up and normal/full/active-pause/focus/power/controller-loss conditions. The tone fixture does not establish microphone transmission success.

Reception fixture checkpoint SHA256: `e8205641ef9dab9bf8fc1a07ed114e22a3286704cd4e390e7ef75cdbb8be2920`, 17370 bytes.
