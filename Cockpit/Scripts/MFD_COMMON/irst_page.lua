-- GPL-3.0-or-later. Azimuth/elevation plot; never a fabricated range display.
return function(page)
    local D=dofile(LockOn_Options.script_path..'MFD_COMMON/lcd.lua')(page,'IRST_'..page)
    D.text('IRST',0,.66,nil,'blue',.005)
    local states={'OFF','NO POD','NO POWER','SENSOR N/A','SUPPLY DATA','SEARCH','TRACK'}
    for code=1,#states do D.text(states[code],0,.57,nil,'green',.0045,D.choice('F22_IRST_STATUS',code))end
    D.text('AZIMUTH / ELEVATION',0,-.55,nil,'blue',.0038)
    D.text('PASSIVE   RANGE ---',0,-.63,nil,'green',.004)
    D.box(0,0,1.2,.9,'green')
    D.line(-.6,-.27,.6,-.27,'green');D.line(0,-.45,0,.45,'green')
    for _,label in ipairs({{'L90',-.60},{'0',0},{'R90',.60}})do D.text(label[1],label[2],-.49,nil,'green',.0036)end
    D.text('+60',-.66,.45,nil,'green',.0036);D.text('0',-.66,-.27,nil,'green',.0036)
    D.text('-15',-.66,-.45,nil,'green',.0036)
    D.text('CONTACTS %.0f',-.36,.52,'F22_IRST_COUNT','green',.0036)
    D.text('SCAN +/-%.0f',.35,.52,'F22_IRST_WIDTH','green',.0036)
    D.text('CAPACITY',0,-.72,nil,'yellow',.0036,D.choice('F22_IRST_OVERFLOW',1))
    local ready=D.choice('F22_IRST_READY',1)
    for i=1,16 do
        local prefix=string.format('F22_IRST_%02d_',i)
        local e=CreateElement('ceSimple')
        e.element_params={prefix..'VALID',prefix..'X',prefix..'Y'}
        e.controllers={{'parameter_in_range',0,.9,1.1},
            {'move_left_right_using_parameter',1,D.scale},{'move_up_down_using_parameter',2,D.scale}}
        local parent=D.add(e,ready)
        local fresh=D.choice(prefix..'COAST',0,parent)
        local coast=D.choice(prefix..'COAST',1,parent)
        D.line(-.018,0,0,.018,'cyan',fresh);D.line(0,.018,.018,0,'cyan',fresh)
        D.line(.018,0,0,-.018,'cyan',fresh);D.line(0,-.018,-.018,0,'cyan',fresh)
        D.text('+',0,0,nil,'cyan',.0036,coast)
        D.text('%.0f',.035,.015,prefix..'ID','cyan',.0036,parent)
        D.box(0,0,.064,.064,'yellow',D.choice(prefix..'SELECTED',1,parent))
    end
    local selected=D.group('F22_IRST_SELECTED',.9,4294967295.1)
    D.text('IR %.0f',-.35,-.70,'F22_IRST_SELECTED','yellow',.0036,selected)
    D.text('AGE %.1f',.35,-.70,'F22_IRST_SELECTED_AGE','yellow',.0036,selected)
    D.text('RADAR OFF',0,.05,nil,'yellow',.004,D.choice('F22_IRST_RADAR_CUE_STATUS',2))
    D.text('RADAR BUSY',0,.05,nil,'yellow',.004,D.choice('F22_IRST_RADAR_CUE_STATUS',3))
    D.text('RADAR CUED',0,.05,nil,'yellow',.004,D.choice('F22_IRST_RADAR_CUE_STATUS',1))
end
