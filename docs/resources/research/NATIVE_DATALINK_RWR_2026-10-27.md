# Native datalink and proximity evidence — 27 October 2026

The user's `Desktop/DCS MODDING` databases and reference Lua were inspected.
Follow-up RWR and radio analysis used the installed IDA Pro MCP plugin directly,
through its read-only metadata, decompile and disassembly methods. Local copies
of the databases were opened; original databases and DCS binaries were preserved.

## Confirmed RWR issue

CockpitBase SHA-256:
`163d55167503da8dd0ea9eb459e17206fc3dc8d6b4805b5b13bbe58341beb794`.

- `avRWR::getSignalStreigth`, `0x1802FBA50`, derives normalized strength/proximity
  as `1 - distance / effective detection range`, inside the accepted envelope.
  The effective denominator depends on source/mode and receiver coefficient.
- `avSimpleRWR::update_export`, `0x180328E70`, calls `0x180329050` for valid
  native emitters. That helper binds `RWR_CONTACT_nn_POWER`.
- Assembly at `0x18032926D` loads emitter float `+4`; `0x180329272` selects the
  POWER handle at export record `+0x28`; `0x180329279` publishes the value.
- The F-22 read TIME, AZIMUTH, ELEVATION, SIGNAL and PRIORITY, but omitted POWER
  from both the raw receiver observations and its common tactical picture.
  Defensive overview consequently placed all RF-only tracks at radius 0.84.
- The correction transports the existing native POWER value unchanged and maps
  `1 - POWER` into relative display radius, with a small inner glyph clearance.
  This is not a new RF detector or an absolute range estimator.

The shared ALR-69 display callback `ccAN_ALR69V::ThreatPos` at `0x1803C7B80`
also confirms that stock threat placement is a dedicated native display path,
distinct from the bearing exporter. Its grouping and declutter behavior is not
claimed as an exact match to our display mapping.

## Confirmed native datalink contracts

wRadio SHA-256:
`07831989c80a3510d1281664558b2137894d6fb2db371bec4485b7bc7ac9823a`.

- `wDatalinkCommunicator` constructor: `0x18002ADD0`, size 0x340 in the Hornet
  creation path. Receive queue at `+0x2F0`; native queue bounds itself to 100.
- `receive_msg`: `0x18002BED0`; queue nodes are 0xB0 bytes with a 0x10-byte
  list header and a 0xA0-byte message. Text flag is message `+117`, and native
  string view is message `+120` (32 bytes).
- `get_msgs_gueue`: `0x18002BB00`. Only the adapter's own queue is drained.
  wRadio's malloc/free imports resolve to the UCRT heap ABI used by our /MD build.
- `wNetDatalinkCommunicator` is a network-forwarding implementation. It is not
  interchangeable with the player receiver. The first runtime experiment showed
  zero accepted messages; the standard communicator received real AWACS PPLI.
- `wTransiverOwner` constructor `0x180024900`; size 0x2B8. Native `setDevices`
  `0x1800433C0` takes receiver noise/sensitivity first and transmitter power second.
- Hornet MIDS RT creation `0x1805D8800` uses native datalink type 2 and comm flags
  0x400. Its initialize path `0x1805D8600` configures 1,092,500,000 Hz,
  3,000,000 Hz bandwidth, modulation 0 and disabled frequency selectivity.
- Native TADIL-J parser `0x18007EE50`; J2.2 unpacker `0x18007FE30` and J3.2
  unpacker `0x180080170`. Parsed message kinds are 16 and 23 respectively.
  Both carry runtime source ID at decoded `+40`. Geographic position, heading
  and speed are decoded from the message. Hornet `0x1805B61C0` confirms the
  coordinate conversion and feet/knots conversion.
- Native settings loader `0x180064040` selects SADL storage for type 1 and
  Link 16 storage for type 2. Legacy EPLRS is a different registration concern.

Inspected profiles: CockpitBase timestamp `0x6AC12468`, image size `0x59A000`;
wRadio `0x6AAE1F77` / `0x144000`; WorldGeneral `0x6AC122F4` / `0x125B000`;
edCore `0x6AAE1D76` / `0xAAD000`.

## Limits

These are DCS implementation contracts, not classified F-22 performance data.
Peer IFDL is an independently defined mod exchange over shared DCS transport.
J3.2 combat identity remains conservative until its enumeration is qualified.
Controlled flights establish native F-22 fighter donations and AWACS surveillance
receipt with radar off. Viper/Hornet PPLI reception is established; their radar
donations and two-client exchange require separate qualification.

## Fighter-track and MAWS follow-up

- wRadio `packFighterToFighterAirTrack`, `0x180080EA0`, uses free-text kind 91
  with extension 0. `extract_FighterToFighterAirTrack`, `0x180080AE0`, decodes the
  eleven-number body emitted by `0x1800807A0`. The adapter validates the complete
  numeric envelope before invoking the extractor, whose API has no failure
  return. Native temporary strings use the qualified UCRT ownership convention.
- CockpitBase `avMLWS::update_existing_contacts`, `0x180336B90`, confirms threats
  by angular-rate thresholds and observation hits. This can accept a departing
  friendly missile on nearly constant bearing.
- `get_spike_world`, `0x180335D00`, supplies native relative world polar
  observations including range. The added approach classifier consumes only
  already confirmed native optical contacts. It does not enumerate world
  missiles or consume shot events/coalition truth as sensor observations.
- The former 12-second datalink lease collided with normal PPLI cadence. PPLI
  now retains 26 seconds; target SA memory retains 75 seconds across observed
  common-AI report intervals. Prediction/coast transitions at 13 seconds and
  source observation times remain unchanged. Display range clipping produces
  direction cues instead of withdrawing offboard tracks.
