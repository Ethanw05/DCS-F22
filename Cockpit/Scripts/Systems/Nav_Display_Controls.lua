-- GPL-3.0-or-later. One physical-bezel contract for NAV labels and actions.
local command=dofile(LockOn_Options.script_path..'Systems/Nav_Commands.lua')
local controls={
 [1]={label='SEQ1',device='NAV_SYSTEM',command=command.sequence_display,selected_parameter='F22_NAV_SEQUENCE_VISIBLE'},
 [13]={label='MENU',page=0},
 [16]={label='HDG',device='ICP_SYSTEM',command=11033},
 [11]={label='DATA',view=1},
 [5]={label='MARK/TIME',view=4},
 [6]={label='WYPT',device='FLIGHT_GUIDANCE',command=10943,selected_parameter='F22_NAV_SOURCE',selected_value=0},
 [7]={label='TCN',device='FLIGHT_GUIDANCE',command=10944,selected_parameter='F22_NAV_SOURCE',selected_value=1},
 [8]={label='ILS',device='FLIGHT_GUIDANCE',command=10945,selected_parameter='F22_NAV_SOURCE',selected_value=2},
 [9]={label='WPDSG',device='NAV_SYSTEM',command=command.designate},
 [10]={label='UNDESG',device='NAV_SYSTEM',command=command.undesignate,condition='F22_NAV_DESIGNATED'},
 [17]={label='D-TO',device='NAV_SYSTEM',command=command.direct},
 [18]={parameter='F22_NAV_AUTO_TEXT',device='NAV_SYSTEM',command=command.auto,condition='F22_NAV_ROUTE_SELECTED'},
 [15]={label='RNG-',device='NAV_SYSTEM',command=command.range_in},
 [14]={label='RNG+',device='NAV_SYSTEM',command=command.range_out},
 [19]={label='PREV',device='NAV_SYSTEM',command=command.previous},
 [20]={label='NEXT',device='NAV_SYSTEM',command=command.next},
}
local pages={[0]={}}
for button,row in pairs(controls)do pages[0][button]=row end
for view=1,3 do
 pages[view]={
  [13]={label='MENU',page=0},[2]={label='WYPT',view=1},[3]={label='TCN',view=2},[4]={label='ILS',view=3},
  [12]={label='RTN',view=0},[6]={label='UFC',device='ICP_SYSTEM',command=11029+view},
 }
 if view==1 then
  pages[view][19]=controls[19];pages[view][20]=controls[20]
 end
 if view==2 then pages[view][7]={label='MODE',device='FLIGHT_GUIDANCE',command=10936}end
 if view==1 or view==2 then pages[view][8]={label='OBS',device='FLIGHT_GUIDANCE',command=10948,selected_parameter='F22_NAV_OBS'}end
end
pages[4]={
 [13]={label='MENU',page=0},[12]={label='RTN',view=0},
 [6]={label='UFC',device='ICP_SYSTEM',command=11034},
 [7]={label='MARK OWN',device='NAV_SYSTEM',command=command.mark_capture},
 [8]={label='MARK TGT',device='NAV_SYSTEM',command=command.mark_target},
 [9]={label='M-TO',device='NAV_SYSTEM',command=command.mark_direct},
 [19]={label='PREV',device='NAV_SYSTEM',command=command.mark_previous},
 [20]={label='NEXT',device='NAV_SYSTEM',command=command.mark_next},
}
local top={-.565,-.2825,0,.2825,.565}
local side={.42,.14,-.14,-.42,-.70}
for _,page in pairs(pages)do for button,row in pairs(page)do
 if button<=5 then row.x,row.y=top[button],.92
 elseif button<=10 then row.x,row.y=.86,side[button-5]
 elseif button<=15 then row.x,row.y=top[16-button],-.92
 else row.x,row.y=-.88,side[21-button]end
end end
function controls.for_page(view)return pages[view]or pages[0]end
return controls
