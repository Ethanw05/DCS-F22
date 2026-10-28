"""DCS type metadata passes detected reports to numeric-safe DEF/SA labels."""
from test_display_startup import runtime
lua=runtime()
lua.execute(r'''
local labels=dofile(SCRIPT_ROOT..'Systems/RWR_Computer.lua')
for name,wanted in pairs({['MiG-29S']='29',['FA-18C_hornet']='18',['F-22A']='22',['F-15C']='15'})do
 assert(labels.label(name,1)==wanted)
end
assert(labels.label('Buk 9S18M1',2)=='SAM' and labels.label_code('SAM')==106)
assert(labels.label('unrecognized',1)=='U')
-- Native metadata is copied by the actual radar metadata owner, not an ID
-- lookup in a receiver cache. Geometry and type identification are separate.
local meta=dofile(SCRIPT_ROOT..'Systems/Radar_Track_Metadata.lua')
local values={TEST_TYPE_NAME='MiG-29S'}
local function get(k)return values[k] or 0 end
local function put(k,v)values[k]=v end
local observation,track={},{}
meta.read(get,'TEST_',observation);meta.copy(track,observation);meta.publish(put,'NEXT_',track)
assert(values.NEXT_TYPE_NAME=='MiG-29S')
local Tracks=dofile(SCRIPT_ROOT..'Systems/Tactical_Tracks.lua')
local Overview=dofile(SCRIPT_ROOT..'Systems/Defensive_Overview.lua')
local store=Tracks.new()
store:update(10,{radar={sequence=1,time=10,contacts={{source=9,age=0,az=.1,el=0,range=10000,
 label=labels.label(values.NEXT_TYPE_NAME,1)}}}},true)
assert(#store.contacts==1 and store.contacts[1].label=='29' and store.contacts[1].affiliation==-1)
values.F22_DEF_DISPLAY_RANGE_NM=40
local sensors={getHeading=function()return 0 end,getPitch=function()return 0 end,getRoll=function()return 0 end}
Overview.new(get,put,sensors):update(10,store.contacts,true,false)
assert(values.F22_DEF_OV_01_LABEL_CODE==29 and values.F22_DEF_OV_01_AFFILIATION==-1)
local metadata=dofile(SCRIPT_ROOT..'Systems/Radar_Contact_Metadata.lua')
values.F22_TACTICAL_TIME=10;values.F22_TACTICAL_SEQUENCE=1
for k,v in pairs({VALID=1,RADAR_SOURCE=9,LABEL_CODE=29,RF_SIGNAL=2,RF_AGE=0})do values['F22_TACTICAL_01_'..k]=v end
local correlated=metadata.read(get,10)
assert(correlated[9].signal==2 and metadata.label(track,correlated[9])==29)
assert(not metadata.read(get,10.3)[9],'stale fusion renewed RF presentation')
local graph={};local api={group=function(name,params,controls,parent)
 graph[name]={params=params,controls=controls,parent=parent}end,
 text=function(text,x,y,param)assert(not param or text=='%.0f','type label used an unsafe native string formatter')end}
dofile(SCRIPT_ROOT..'Systems/Contact_Label_Indicator.lua')(api,'TEST_',0,0,'root','type','white',.003)
assert(graph.type_SYMBOL_7.params[1]=='TEST_LABEL_CODE')
''')
print('DCS contact types: MiG29/FA18/F22/SAM, detected-radar metadata, unknown affiliation and safe native labels PASS')
