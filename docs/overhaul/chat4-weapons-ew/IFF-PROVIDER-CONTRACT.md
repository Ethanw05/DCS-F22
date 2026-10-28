# I-WPN-007 current-host provider decision, schema 1

Chat4 owns `Systems/IFF_Provider.lua`. The provider decision is **unavailable / HOST_UNQUALIFIED**. `provider_ready=true` means that this explicit no-go decision is available to the radar consumer; `available=false` means there is no qualified interrogation/reply capability. No package or IFF capability is passed by that decision.

Matched-host evidence is in `iff-host-inspection.json`: CockpitBase exports candidate IffTransceiver functions, but an owned instance, exact ABI, source/request correlation, observation clock and allocator/callback lifetime have not been qualified. Export presence neither proves a usable backend nor proves one impossible. No simulator or native module was loaded for this inspection.

## Provider interface

`new()` creates one fixed output table. `sample()` overwrites and returns that borrowed table; consumers copy any values they retain. `request(request)` always returns `false, 'HOST_UNQUALIFIED'`. It does not dispatch, queue, accept consent or create a pending request. `reset()` republishes the same unavailable snapshot. Work and storage are constant; there is no callback, native pointer, history or teardown dependency.

| Field | Value and meaning |
| --- | --- |
| schema | 1 |
| provider_ready | true; explicit decision complete |
| available | false; no reply capability |
| status | HOST_UNQUALIFIED |
| identity | -1, unknown |
| identity_known | false |
| identity_time, received_time | nil; no observation or receipt exists |
| clock_kind, source_epoch | 0; no active qualified source |
| source_id, request_id | 0; no accepted request or correlated source |

Power, clock, target type, coalition, scripted reply, simulated own responder and delayed cached values cannot promote this provider. No-reply remains unknown, including hostile0. A future native implementation requires a new reviewed contract with independent identity source time, clock mapping, source epoch, request identity, rejection/timeout and teardown; no flag enables it.

## Consumer handoff and gates

Chat3 P-RAD-007 owns routing and pilot indications. It must consume `available`, preserve saved AUTO/LOS/manual input intent, publish unavailable feedback and keep achieved IFF ON/status off. Existing `Radar_IFF.lua` request-policy state alone currently makes ON true and is not an achieved backend. Its migration and common MFD/HUD changes remain with Chat3/Chat2. This decision has no dependency on that later migration.

The simulated own responder remains explicitly simulated with HOST_READY0 and cannot supply this provider. Independent friendly protection/conflict evidence from other qualified sources must survive the no-go. D-P-WPN-001 still gates any achieved IFF/donor identity expansion; this standalone feasibility decision does not close that transport package or P-WPN-004.

Independent tests exercise the actual provider module, attempted scripted/scene identity, missing/rewound/nonfinite clocks, generation/reset, recreation, stale borrowed output and zero dispatch. They qualify software no-go behavior only. No old identity/fusion test is retired by this new-provider slice; those tests remain assigned pending complete independent remakes.
