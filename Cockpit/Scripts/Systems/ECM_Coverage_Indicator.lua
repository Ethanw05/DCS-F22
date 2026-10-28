-- GPL-3.0-or-later. Outward coverage arrow at a measured emitter bearing.
-- The common host ECM broadcasts; this is not a per-victim effectiveness cue.
return function(api,parent,name,scale,params,conditions)
    params[#params+1]='F22_ECM_TRANSMITTING_VALID'
    params[#params+1]='F22_ECM_TRANSMITTING'
    conditions[#conditions+1]={'parameter_in_range',#params-2,.9,1.1}
    conditions[#conditions+1]={'parameter_in_range',#params-1,.9,1.1}
    name=api.group(name,params,conditions,parent) or name
    api.line(0,-.15*scale,0,-.05*scale,'green',name,1.2)
    api.line(-.022*scale,-.08*scale,0,-.05*scale,'green',name,1.2)
    api.line(.022*scale,-.08*scale,0,-.05*scale,'green',name,1.2)
end
