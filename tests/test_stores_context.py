"""Visible Stores controls and actual actions agree with aircraft master mode."""
from cockpit_fixture import runtime

lua=runtime()
lua.execute(r'''
dofile(SCRIPT_ROOT..'Systems/MFD_System.lua');post_initialize()
local function put(k,v)get_param_handle(k):set(v)end
local function get(k)return get_param_handle(k):get()end
local function key(b)SetCommand(10060+b,devices.MFD_SYSTEM+.375);SetCommand(10060+b,devices.MFD_SYSTEM+.25);update()end
put('MAIN_POWER',1);put('MFD_OPACITY',1);put('HUD_MODE',2);put('HUD_AG_SUBMODE',2)
update();key(13);key(3)
assert(get('LMFD_BAY_PAGE')==1 and get('F22_SMS_AA_CONTEXT')==1 and get('F22_SMS_PROGRAM_PAGE')==0)
assert(get('F22_MFD_LMFD_KEY_18')=='STEP'and get('F22_MFD_LMFD_KEY_10')=='DOORS')
actions={};key(18)
local steps=0;for _,a in ipairs(actions)do if a[1]==10804 and a[2]==1 then steps=steps+1 end end
assert(steps==1,'A/A STEP did not reach selection exactly once')
for _,b in ipairs({1,2,3,4,5,6,7,8,9,11,12,14,15,16,17})do
 assert(get('F22_MFD_LMFD_KEY_'..b)=='','hidden A/G legend appeared in A/A')
 actions={};key(b)
 for _,a in ipairs(actions)do assert(a[1]==10742,'blank A/A key executed a strike action')end
end
put('HUD_MODE',7);put('F22_SMS_LABEL',2);update()
assert(get('F22_SMS_AA_CONTEXT')==0 and get('F22_MFD_LMFD_KEY_7')=='PROFILE'
 and get('F22_MFD_LMFD_KEY_8')=='EDIT')
actions={};key(8);assert(actions[2][1]==10989 and actions[2][2]==1 and actions[3][2]==0)
assert(get('F22_LMFD_VIEW')==1 and get('F22_MFD_LMFD_KEY_14')=='QTY')
key(12);assert(get('F22_LMFD_VIEW')==0)
put('HUD_MODE',1);update();assert(get('F22_MFD_LMFD_KEY_7')=='PROFILE','NAV lost strike preparation')
put('HUD_AG_SUBMODE',1);update()
assert(get('F22_MFD_LMFD_KEY_7')==''and get('F22_MFD_LMFD_KEY_8')=='','GUN retained bomb programming')
dofile(SCRIPT_ROOT..'MFD_COMMON/stores_page.lua')('LMFD_BAY_PAGE','F22_TEST_STORES','F22_SMS_UI_PAGE_LMFD')
dofile(SCRIPT_ROOT..'MFD_COMMON/bezel.lua')('LMFD')
local names={};for _,e in ipairs(elements)do assert(not names[e.name]);names[e.name]=true end
for _,e in ipairs(elements)do assert(not e.parent_element or names[e.parent_element],'native parent unresolved')end
''')
print('Actual Stores owner: A/A STEP, blank strike controls, NAV/A/G preparation, GUN inhibition and complete native graph PASS')
