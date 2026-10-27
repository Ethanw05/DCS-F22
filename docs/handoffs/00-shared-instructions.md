# Shared instructions for each implementation chat

The actual repository is `C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\DCS-F22`.
The audit deliverables are in `C:\Users\Ethans Desktop 2.0\Desktop\DCS MODDING\F22-Audit`.

Before changing code, read:

- `AGENTS.md` and `docs/CODING_STANDARD.md`.
- `docs/overhaul/README.md` and the packages assigned to your chat in `docs/overhaul/BACKLOG.json`.
- Relevant findings in `docs/audit/README.md`, `AUTHENTICITY_COMPARISONS.json` and the cited original resources. Consult multiple applicable sources for each changed system, including F-22 evidence and F-16/F/A-18 analogues where needed.

Use a separate branch/worktree starting at `f22-overhaul-start-2026-10-27`. Reuse a suitable existing worktree; never reset or discard somebody else's changes. Keep the primary checkout for integration. All source edits, tests and build commands must use your actual worktree directory explicitly.

Implement documented F-22 behavior first. Where detail is unavailable, adopt a coherent named analogue or a labeled estimate. Preserve source dates and configuration limits. Passing tests does not turn an estimated parameter into documented behavior.

Follow the NASA/JPL-inspired coding standard for all new and modified Lua/C++. Keep loops and callback work bounded, state ownership explicit, failures checked and native lifetimes controlled. Establish useful lint/compiler/static-analysis checks against the real toolchain. Record legacy exceptions and checks unavailable on the machine; avoid a mass formatting rewrite.

Implement one complete behavior at a time: inputs and physical/provider state, adapter, validity/authority, indications, pilot workflow, failure and recovery. Preserve correct existing behavior, saved bindings, preferred HUD styling and recorded audio. Inspect actual host behavior before adding a duplicate simulation of something the host already supplies.

For shared files, agree the interface and make a focused integration patch. `RAPTOR.cpp` has physical, guidance and sensor entry points; `NativeSidewinder.cpp` has radar and payload/seeker portions. Ownership of one portion does not authorize replacing the other portions. The navigation/cockpit chat integrates shared changes and requests the relevant owner's review.

Run appropriate owner tests and affected integration checks. Native readiness, preview images and mocked tests prove different things; qualify actual DCS effects when required. Coordinate a runtime session before using the same DCS instance as another chat. Do not overwrite the installed mod or terminate the user's running simulator as a side effect of a test.

Commit focused changes on your branch. Give the integration chat the commit IDs, affected interfaces, results and outstanding limits. Keep implementation notes short and attached to the relevant package; do not create another general audit or reports about agent activity. Continue through implementation and verification rather than stopping at an inventory of possibilities.
