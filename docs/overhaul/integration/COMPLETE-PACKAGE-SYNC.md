# Complete runtime package synchronization

The user's JDAM investigation exposed a mixed installation: the DLL already
required schema-1 coherent delivery targets, while the installed weapon owner
still published individual legacy coordinate fields. The native reader rejected
that handoff even when the HUD displayed a release cue. Other current avionics
changes were also absent from the normal mod.

The complete package now comes from a full external native build and the current
runtime source inventory. `tools/install_mod.py` plans every declared runtime
directory, root registration/configuration file and payload preset. It requires
the DLL's embedded source/cache identity to match the entire current native
source. Applying the saved plan rejects changed source/build/installed inputs,
requires DCS to be closed, copies the coherent package and verifies every hash.
Source archives, development files, fixtures and documentation are not deployed.

Existing recorded audio overrides, saved pilot controls and installed hooks are
protected. Installed-only user files are retained. Default controls and HUD
styling were compared semantically before synchronization; newline-only changes
do not alter them. The concurrently authored NAV/ground designation cue repair
is captured by its exact runtime hashes without staging its owner's work.

The JDAM regression runs the actual Lua mark/store/weapon publishers and feeds
their resulting parameter values directly into the production C++
`GroundTargetPacket::Reader`. A valid assigned coordinate is accepted unchanged;
the former missing header and an in-progress commit are rejected. It does not
substitute a healthy target or bypass the native handoff. This is a software
interface check, not a real bomb-release/impact test.

Older target/fusion tests applied historical review patches in memory. They now
execute the integrated source directly while retaining their behavioral checks.
The existing MAP test follows the documented pilot fix that hides mover symbols
in MAP and shows them in GMT. Radar test targets include explicit fail-fast IRST
ports and the integrated interleaving fixture. Its source scheduler and the
current request-only IFF/IRST consumers are included after their owner checks.
The PMFD explicitly displays an unavailable IFF request instead of an achieved
interrogation. No new qualified IFF reply capability is claimed.

Verification includes the full rebuilt native suite, current Lua-owner suite,
compilation of all package Lua, baseline-relative lint, unchanged public DLL
exports/import dependencies and hashes of 14 reviewed DCS libraries. A separate
post-installation run loads the actual installed Lua dependency graph, including
the JDAM cross-language case. No simulator is launched, controlled or terminated.
Legacy compiler/lint diagnostics remain recorded rather than being called clean.

`COMPLETE-PACKAGE-INSTALLATION.json` records exact identities, checks, protections
and the final runtime comparison. This synchronizes implemented production work;
it does not close every remaining fidelity/audit package or establish actual
DCS flight, optics, weapon-impact or multiplayer performance.
