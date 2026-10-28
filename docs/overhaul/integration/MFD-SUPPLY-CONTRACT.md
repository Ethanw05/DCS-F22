# Single MFD presentation owner

MFD_Controller alone owns page, mask, format and blank flags for all four panels.
MFD_System passes two explicit booleans from the current physical snapshot:
main supply (MAIN_POWER==1), and limited APU display supply (MAIN_POWER==0,
BATTERY_POWER==1, finite APU_RPM_STATE>=2). The latter retains the existing
startup presentation policy; it does not authenticate an aircraft bus design.
Unqualified/missing/stale physical input makes both false.

With main supply, each panel presents its selected format. With limited supply,
the left panel presents ENG and the other three are blank. The selected formats
and views remain preferences; F22_<panel>_PRESENTED_FORMAT explicitly records the
achieved presentation (-1 means unavailable). Limited supply blanks bezel labels
and accepts no forwarded bezel action. Loss of main supply cancels held/forwarded
requests; return restores the stored selection without replay.

Avionics owns brightness and physical annunciation, and PMFD_System retains
saved input transport/preferences. Neither writes page/blank flags. No geometry,
font, HUD styling, audio or saved command ID is changed by this cutover.
