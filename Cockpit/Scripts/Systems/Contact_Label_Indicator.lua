-- GPL-3.0-or-later. Numeric-safe shared labels from DCS type metadata.
return function(api,prefix,x,y,parent,name,color,size)
    local label=prefix..'LABEL_CODE'
    local at=api.group(name..'_NUMERIC',{label},{{'parameter_in_range',0,-.1,99.9}},parent)or name..'_NUMERIC'
    api.text('%.0f',x,y,label,color,at,size)
    local symbols=dofile(LockOn_Options.script_path..'Systems/RWR_Computer.lua').symbols
    for index,text in ipairs(symbols)do
        local key=name..'_SYMBOL_'..index
        at=api.group(key,{label},{{'parameter_in_range',0,98.9+index,99.1+index}},parent)or key
        api.text(text,x,y,nil,color,at,size)
    end
end
