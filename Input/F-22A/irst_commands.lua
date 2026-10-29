-- GPL-3.0-or-later. Appended without default combos or changed saved actions.
return function(profile,environment)
    local labels={'Power Toggle','Scan Width Cycle','Scan Elevation Up','Scan Elevation Down',
        'Scan Azimuth Left','Scan Azimuth Right','Scan Recenter','Next Contact',
        'Track Selected Toggle','Drop Selected','Cue Radar to Selected'}
    for index=1,#labels do
        local command=11299+index
        profile.keyCommands[#profile.keyCommands+1]={down=command,up=command,value_down=1,value_up=0,
            cockpit_device_id=30,name=environment._('IRST - '..labels[index]),category=environment._('F-22 IRST')}
    end
end
