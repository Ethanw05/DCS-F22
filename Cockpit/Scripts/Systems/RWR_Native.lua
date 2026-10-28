-- GPL-3.0-or-later. Shared DCS receiver, independent of the attack radar.
-- Config keys verified in CockpitBase avRWR/avSimpleRWR::initialize.
dofile(LockOn_Options.common_script_path..'AN_ALR_SymbolsBase.lua')
-- Extend DCS's name-based presentation metadata; no RF classification model.
symbols_strings=symbols_strings or {}
for _,name in ipairs({'F-22A','F-22','F22','F-22A_Raptor'})do symbols_strings[name]='22'end
MaxThreats=16
EmitterLiveTime=12
RWR_detection_coeff=1.0
power_bus_handle='F22_RWR_SUPPLY'
-- Generic four-aperture simulation coverage, not an ALR-94 antenna model.
eyes={}
for i,az in ipairs({45,135,-135,-45}) do
    eyes[i]={position={x=0,y=0,z=0},orientation={azimuth=math.rad(az),elevation=0},field_of_view=math.rad(120)}
end
need_to_be_closed=true
