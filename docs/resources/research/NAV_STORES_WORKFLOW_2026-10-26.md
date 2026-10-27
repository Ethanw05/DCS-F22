# NAV and stores workflow — 26 October 2026

Direct user requirements: use the installed Hornet Lua as the workflow
reference; retain the researched F-22 display presentation; edit quantity and
interval on the UFC after pressing UFC on the MFD; remove invented explanatory
landing screens; make a display's STORES selection open stores on that display.
The user's existing HUD is excluded from this update.

## References actually inspected

Installed under `D:/DCS/Mods/aircraft/FA-18C/Cockpit/Scripts/`:

| File | Workflow evidence used |
| --- | --- |
| `Multipurpose_Display_Group/Common/indicator/Pages/MPD/HSI/HSI_MAIN.lua` | Steering format, DATA access, WYPT selection, sequence controls and WPDSG |
| `.../HSI/HSI_DATA_WYPT.lua` | Separate waypoint inspection; selected point, coordinates/elevation, UFC and HSI return |
| `.../HSI/HSI_DATA_TCN.lua` | Separate TACAN inspection and UFC access |
| `.../MPD/STORES.lua` | Selected-store context, persistent program readback, contextual MODE options, PROG, STEP and UFC |
| `UFC/indicator/UFC_main_page.lua` | Scratchpad and option-select display separation |
| `Computers/SMS/SMS.lua` and `UFC/device/UFC.lua` | These visible files primarily initialize native devices; they do not expose the complete Hornet C++ state machine |
| `Multipurpose_Display_Group/HUD_AVQ32/indicator/Pages/HUD_NAV.lua` and `HUD_common.lua` | Read-only check of NAV steering indications; no F-22 HUD change follows from this inspection |

The local official Hornet guide was also read, with relevant pages rendered
and visually inspected. Pages 126–127 describe HSI/DATA/WYPT/UFC editing;
139 describes the DATA sublevel; 304–306 describe stores programs, UFC quantity,
multiples, interval, and explicit ENTER commits. Public manual listing:
https://www.digitalcombatsimulator.com/en/downloads/documentation/dcs-hornet_early_access_guide_en/

F-22 layout evidence remains the historical display roles in Brower §32.3.7
and the existing museum-photo-derived front-view bay artwork:

- https://www.helitavia.com/avionics/TheAvionicsHandbook_Cap_32.pdf
- USAF photograph 080116-F-1234P-002:
  https://www.nationalmuseum.af.mil/Upcoming/Photos/igphoto/2000412735/

The public evidence does not establish every operational F-22 NAV/program
subpage or these exact bezel assignments. The existing F-22 aperture, atlas,
colors and bay graphic are preserved. The adapted page flow, DATA/UFC labels
and program table are identified as mod choices, not recovered F-22 software.
No Hornet Lua implementation, graphics, font or paid-aircraft backend is shipped.

Public DoD MIL-STD-1472F provides the human-factors basis for the cleanup:
visible entry feedback (§5.14.2.1.2), explicit completion (§5.14.2.1.4),
essential content (§5.14.3.1.2), concise text (§5.14.3.2.3), and feedback in
the controlled element (§5.14.4.1.13). These general principles do not prove
an operational F-22 page layout. Source:
https://www.denix.osd.mil/soh/denix-files/sites/21/2016/03/02_MIL-STD-1472F-Human-Engineering.pdf

## Changes

NAV has a steering view and separate waypoint/TACAN/ILS DATA views. DATA UFC
opens the relevant existing keypad editor without selecting another master
mode. Waypoint fields require ENTER; changing fields abandons the draft and
changing the selected point closes its old editing context. Radio DATA reads
the radio's own bearing/range, independently of the selected steering source.
AP/IRS status strings and normal route-status prose were removed from the
steering page; route, bearing, distance, time, course and applicable warning
data remain.

Stores shows the retained program's QTY, MULT and INT with units. UFC opens
the single numeric editor; no MFD key directly edits QTY or INT. PROG selects
the retained profile; MODE exposes only supported alternatives. DATA retains
station-target actions. The non-adjustable FUZE submenu, explanatory prompts,
duplicate estimated-LAR detail, modeled thrust-percent readout and unrelated
ENG/FUEL/FCS shortcuts were removed from stores.

The reported left STORES failure was a routing error: Attack's STORES key
called the lower-display opener and left Attack visible. Stores now uses one
shared native format for all three small displays. Selection, MENU return and
UFC work on the requesting display, including when the lower display is NAV.
The lower display still defaults to stores. The weapon owner's numeric-entry
context uses the powered stores-format authority rather than requiring the
lower display specifically. Release/safety/acknowledgement predicates are not
changed by that context correction.

The text-filled DISPLAY MENU and INTEGRATED TACTICAL PICTURE landing formats
are replaced by short bezel page selectors. Small-display selections go
directly to actual pages without a category sublevel. PMFD TSD selects the
actual plot. Setup and diagnostic entries are removed from that operational
selector. NAV LYR and RF/IR layer shortcuts and the duplicate bottom TSD
entry are removed from this selector. It now has one NAV entry.

UFC drafts now appear directly in the selected normal-size option row for
stores, waypoint, radio, AP target and altitude-setting entry. Previously,
the selected field retained the saved value while draft digits were drawn
in a tiny footer, or a sixth row outside the five normal physical apertures.
Detached scratchpad/help drawings are removed. Leading zeros remain visible;
an empty selected stores field shows `----`; rejected inputs show a short
error at the active page. This display fix retains the existing entry and
commit owners. No HUD source or installed HUD file is changed.

## Verification

The complete shared suite passes 101/101 scripts at this checkpoint. Existing
tests retain safety, target, acknowledgement and cancellation assertions.
Obsolete UI expectations were migrated for the intentionally changed routing.
Only the three NAV snapshots changed; nine other guarded display snapshots
remain identical.

The new actual-owner NAV test covers WYPT/TCN/ILS DATA/UFC, no master-mode
change, explicit commits, invalid coordinate drafts, independent radio data,
point changes and power loss. Stores integration covers left-only UFC quantity,
500-foot impact spacing and a separately committed 250-ms time interval while
the lower display remains NAV. Shared page routing and native graph construction
are exercised by the existing actual-source tests.

The new UFC test drives actual weapon/ICP owners and native element bindings.
It checks draft QTY/INT feedback before ENTER, leading zeros, unchanged saved
values before commit, and NAV/radio/AP draft visibility. It also checks normal
row position, font size, active visibility controllers and parameter declaration
before native binding. Removed footer channels cannot remain drawn.

Nine source-driven previews were rendered and inspected using the actual native
element graphs, shipped font atlas and original bay DDS assets with synthetic
values. Three show UFC drafts in the actual row graph, without simulating the
cockpit model's optical masking. All 21 changed runtime Lua files compile under
the DCS Lua interpreter. Native optical fit, VR and a post-install
flight are not claimed. The manifest records the exact installed Lua hashes;
this update does not require a native DLL rebuild. Restart DCS to load it.
