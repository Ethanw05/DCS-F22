# C-FLT-001 numerical-helper retirement

The exact `actuator` and `smooth_lerp` definitions in Utility.h were removed.
The current EFM source/include closure, cockpit scripts, tools and tests contain
no callers. The built DLL exports 40 named host callbacks and neither helper;
the source registration/CMake closure adds no alternate export or dynamic lookup.
`actuator_timed`, `slew_rate_limit`, the physical owner, all host callbacks and
saved command identities remain intact. No numerical schedule or coefficient
was changed.

The original Utility.h hash was
`7b667024c1a394aa831ec176fa7cff795067b7146a6ee0bab21ef881e4fe92b0`.
The external MSVC Release DLL builds after removal. The new actual-DLL flight
case passes 32 atmospheric-failure cases and 54 lifecycle comparisons; the
actual Lua HUD owner passes its three cases. Fixture code passes /W4 /WX
/analyze. DLL legacy warning-code counts do not increase. Native source hashes
were unchanged across the final build. The source bin DLL was not overwritten.

The 160-value healthy comparison is between the independently built current
integration and flight DLLs, with zero delta. The integration output advanced
after the original pre-fix reproduction, so this is current source consistency,
not a historical baseline comparison or aircraft calibration evidence.

The software validity/reset changes are integrated by Chat 2 in `a21145f`.
This separate cleanup touches only Chat 1's noncontended Utility.h and this note;
it does not reopen the released RAPTOR/HUD lease. Native wind/TAS consumer
migration and installation/DCS/VR/MP qualification remain open.
