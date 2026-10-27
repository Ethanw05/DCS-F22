# Dedicated radar and AESA chat

You are the dedicated F-22 radar implementation and interface-research chat. All radar reverse engineering belongs here; the planning/moving chat does not perform it. Follow `docs/handoffs/00-shared-instructions.md` and `docs/CODING_STANDARD.md`.

Repository: `C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\DCS-F22`.
Start an isolated worktree from `f22-overhaul-start-2026-10-27`.

The goal is an owned, believable AESA radar simulation integrated with DCS, beyond relabeling the existing `avSimpleRadar` presentation. Own SEN-01–04's radar work: front-end/backend choice, sensing service, observations, radar tracks/acquisition, A/A and surface modes, imagery and radar-specific input behavior. Agree observation/target contracts with the weapons/fusion chat; leave general EW, countermeasure programming, datalink and weapon logic with that chat.

First read current radar owners, native bridges, available shared-interface research, the relevant audit cases, the F-22 public radar references and multiple applicable F-16/F/A-18 resources. Inspect actual code and original passages. Electronic pointing, measurement/revisit time, processing delay and track memory are different quantities.

Investigate what `avSimpleRadar` and the current native adapter actually control: scan motion, acquisition/detection gates, native observations and timestamps, modes, target responder/support, lifecycle and build-specific constraints. Use bounded interoperability research and reproducible probes. Preserve version, instance and lifetime checks. Separate observation from inference; a 2-second Lua task phase does not establish native antenna motion.

Compare feasible architectures: retain a sufficient native sensor with an owned AESA model; adapt a lower-level shared interface; or implement an owned game sensor behind an environment/scene provider. Choose based on demonstrated capability and integration cost. If the native backend imposes a hard mechanical/exclusive-mode restriction, expose it or replace the relevant layer rather than hiding it behind AESA labels.

Implement finite search/track task service, electronic steering behavior, dwell/revisit/processing delays, resource contention, mode transitions, off-axis/LOS/clutter effects, measurement uncertainty and graceful supply/cooling/damage degradation at an appropriate game-simulation level. Use public evidence or explicit bounded estimates; do not invent authenticated APG-77 performance or operational waveform parameters.

An owned sensor model may consume simulator scene/object state internally as environment truth. Only observations that pass its modeled sensing, timing and validity conditions reach tracks, displays or weapon consumers. Do not publish perfect target position/identity directly as a radar measurement. Keep native observations and owned-model observations source-labeled. Prove how modeled contacts interact with actual native acquisition and weapon-support authority.

Keep the model independent from cockpit rendering and private ABI code. Make update work/memory bounded and testable under the project coding standard. Coordinate the focused-format cursor fix while preserving intentional global ACM inputs.

Deliver a short evidence-based architecture choice and then a functioning vertical slice with appropriate tests and native qualification. Continue into implementation when feasible. Clearly identify any host limitation that prevents the requested behavior. Keep the established radar interface available until its replacement path has earned equivalent integration coverage.
