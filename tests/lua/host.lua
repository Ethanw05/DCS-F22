-- SPDX-License-Identifier: GPL-3.0-or-later
-- Isolated host substitute for state/contract tests. Does not emulate DCS rendering.
local Host = {}
function Host.New(root)
    local h = {parameters={}, draws={}, commands={}, messages={}, elements={}, sensor={}, time=0,listeners={}}
    local env = {}; setmetatable(env,{__index=_G}); env._G=env
    env.LockOn_Options={script_path=root.."/Cockpit/Scripts/",common_script_path="__common__/",init_conditions={birth_place="GROUND_HOT"}}
    env.GetSelf=function() return {listen_command=function(_,c) h.listeners[c]=true end,listen_event=function()end,performClickableAction=function(_,c,v) if env.SetCommand then env.SetCommand(c,v) end end} end
    env.get_base_data=function() return setmetatable({}, {__index=function(_,k) return function() local v=h.sensor[k]; if type(v)=="table" then return unpack(v) end; return v or 0 end end}) end
    env.get_param_handle=function(name)
        return {get=function() return h.parameters[name] or 0 end,set=function(_,value) h.parameters[name]=value end}
    end
    env.get_cockpit_draw_argument_value=function(i) return h.draws[i] or 0 end
    env.get_aircraft_draw_argument_value=env.get_cockpit_draw_argument_value
    env.set_aircraft_draw_argument_value=function(i,v) h.draws[i]=v end
    env.set_cockpit_draw_argument_value=env.set_aircraft_draw_argument_value
    env.dispatch_action=function(_,c,v) h.commands[#h.commands+1]={command=c,value=v or 1} end
    env.print_message_to_user=function(v) h.messages[#h.messages+1]=v end
    env.make_default_activity=function(dt) h.dt=dt end
    env.get_absolute_model_time=function() return h.time end
    env.CreateElement=function(kind) return {class=kind} end
    env.MakeMaterial=function() return "material" end
    env.MakeFont=function() return "font" end
    env.SetScale=function()end
    env.MILLYRADIANS=1;env.h_clip_relations={COMPARE=1,REWRITE_LEVEL=2,INCREASE_IF_LEVEL=3}
    env.FOV=2
    env.render_purpose={GENERAL=1,HUD_ONLY_VIEW=2};env.indicator_types={COMMON=1,COLLIMATOR=2}
    env.Add=function(e) assert(e.name,"element name"); h.elements[#h.elements+1]=e end
    env.mount_vfs_texture_archives=function()end
    env.dofile=function(path)
        if path:find("__common__/",1,true) then return end
        local chunk,err=loadfile(path);assert(chunk,err);setfenv(chunk,env);return chunk()
    end
    h.env=env
    function h:load(path) return env.dofile(root.."/"..path) end
    function h:step(seconds) for _=1,math.floor(seconds/self.dt+.5) do self.time=self.time+self.dt;env.update() end end
    function h:command(c,v) env.SetCommand(c,v or 1) end
    return h
end
return Host
