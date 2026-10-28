# Additional ownship RCS request

The existing registration is a constant0.0001m². No production source connects
achieved bay configuration to the radar return queried by AI SAMs. This is a
confirmed source gap; the reported no-engagement sortie is not yet reproduced.

The public EFM headers expose no runtime ownship-RCS setter. Installed native
getter exports were found, but their owning implementations are packed and not
file-backed. There is no qualified mutable-object/allocator/lifetime/replication
contract yet. The current blocker is an actual ownship response backend, not the
arithmetic for varying a signature. Receiver-side RCS models do not repair it.

The dedicated external20SAMmission uses nativeExcellent Tor/Osa/Tunguska groups
with RED alarm and WEAPON_FREE. Passive mission observations log RADAR-only
detection, current radar target and actual shots independently. The optional
export hook records achieved bay/gear/refuel arguments and ownship pose/jamming.
Neither observer controls the aircraft or AI, changes invisibility, forces locks,
or installs itself. They stop on clock reset and cap work/history explicitly.

Build with .venv Python and tools/build_signature_trial.py --output pointing to
an external F22-RCS-SAM-Qualification.miz. Use matched repeated closed/open bay,
external-store and aspect passes with recorded altitude/ECM/LOS and identical
threat setup. Confirm actual AI radar response before claiming dynamicRCS. The
20SAMtest is ready; install/runtime remain the integrator's exclusive slot.

[DCS radar Phase2 white paper,pp1–4](https://www.digitalcombatsimulator.com/upload/medialibrary/17e/m8odtgndhjszgek60f7xps2zh6lf6go5/DCS_Radar_White_Paper_Radar_Phase_2.pdf)
explains probabilistic receiver detection, not a mod-facing ownship signature
setter. It supplies no F22 aspect/bay coefficients. Any later numeric profile
must be labeled a gameplay estimate, not classified aircraft data.

The user identified the installed EW-Gauntlet and passes belowabout5000ft. The
installed mission has38 active groups, RED alarm/WEAPON_FREE and no invisible or
immortal player setting. gauntlet-baseline.json pins its actualZIP and setup.
An instrumented external copy preserves every enemy group, playerroute/altitude,
payload/nativeIDs and forcedoptions, recording radar/visual/optic/IR separately.

Full Lua descriptor evaluation also reveals that WorldID, shapeindex and
attribute[4] refer to the previous F_22A global during construction. They are nil
on a freshload or a staleLuaTABLE on reload. The local official F16C declaration
uses WSTYPE_PLACEHOLDER for allthree. The exact3fieldpatch and independent fresh/
reload regression were applied by Chat2 under flight-registration-descriptor and both regressions now pass. This repairs the
submitted type schema; native database normalization and the actual consequence
for AI target perception still require host observation. It is not proof that
this alone explains the reported sortie, nor a dynamicRCS implementation.

The user has made dynamic RCS the priority and requires multiplayer. They have
only the public repository's EDM. A pinned external reader successfully parses
the complete v10 aircraft file, including separate bay animations. New
[offline geometry and PEC estimate tools](../../../../tools/rcs/README.md) use
per-vertex parent selectors and generate eight bay configurations without
changing the original asset. Seven independent mathematical/geometry tests pass.
Candidate pose bounds differ from the root declaration and still need comparison
with DCS; PEC estimates omit aircraft materials and cavity/multiple reflection.
Neither this extraction nor a successful bake closes the native ownship response
or multiplayer gate. See offline-bake.json for the measured run and limits.
