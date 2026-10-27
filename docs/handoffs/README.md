# Implementation chat prompts

Use the shared instructions with the prompt for each of these four chats:

| Chat | Prompt | Main scope |
| --- | --- | --- |
| Flight model and aircraft systems | [01](01-flight-and-aircraft.md) | VEH work; physical sources, forces and achieved state |
| Navigation, cockpit and integration | [02](02-navigation-cockpit-integration.md) | NAV, UI, CNI, ALR, MIS; shared integration |
| Radar and AESA | [03](03-radar-aesa.md) | SEN-01–04; radar model and native interface investigation |
| Weapons and defensive avionics | [04](04-weapons-defensive-avionics.md) | SEN-05–15; weapons, EW/CM, fusion, network and optional sensors |

Read [shared instructions](00-shared-instructions.md) and [coding standard](../CODING_STANDARD.md) first. Each chat works from the `f22-overhaul-start-2026-10-27` tag in its own branch/worktree. The navigation/cockpit chat integrates completed changes; the radar chat owns radar reverse engineering. This planning chat prepares handoffs and moves files.

Shared files need coordinated patches: `RAPTOR.cpp`, `NativeSidewinder.cpp`, `device_init.lua`, `F-22A.lua`, `Radar_System.lua` and `UFC_Controller.lua`. Change the relevant module in the owning branch; request integration of shared entry-point changes instead of overwriting another chat's work. Each feature's provider and consumer agree units, validity and reset behavior before integration.
