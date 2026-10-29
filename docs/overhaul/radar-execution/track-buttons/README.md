The A/A radar top row now contains SWAP at key3 and one TRACK caption spanning keys4/5, with a double-ended arrow underneath. Key4 selects the previous eligible radar track; key5 selects the next. Keys1/2 are blank. PRI, SEC, CLR2 and IFF are removed from this top row. A/G, ACM and donor subpage controls remain independent.

Previous-track command10653 is routed through the existing radar device, with optional keyboard/joystick bindings. Both directions wrap and share the retained sensor-return eligibility rule; stepping follows the chosen track without fabricating a lock. Empty lists clear selection/follow, held physical keys do not repeat, and page/power changes withdraw the paired caption. Existing automatic identity processing is unchanged.

Seven runtime files installed into the normal mod with DCS absent. All31 focused checks pass against73 actual installed Lua dependencies; Lua5.1 syntax and pinned Luacheck1.2.0 introduce zero new findings. Fifty-three protected entries and the installed DLL remain unchanged. No backups or simulator operation. Actual flight/render/VR behavior remains pending. See [RESULTS.json](RESULTS.json).

![Offline top-row preview](top-row-preview.png)

Follow-up: removed the bottom AESA caption and the unconnected static LDR / 30 S reference labels. Existing presentation checks pass; the updated page is installed with DLL, controls, audio and hooks preserved.
