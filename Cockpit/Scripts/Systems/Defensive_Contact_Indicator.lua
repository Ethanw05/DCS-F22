-- GPL-3.0-or-later. One small class marker; no alert/selection brackets or stems.
return function(api,parent,name,parameter,color)
    local shapes={
        [2]={{-.025,-.018,0,.028},{0,.028,.025,-.018},{.025,-.018,-.025,-.018}},
        [3]={{-.022,-.022,-.022,.022},{-.022,.022,.022,.022},{.022,.022,.022,-.022},{.022,-.022,-.022,-.022}},
        [4]={{-.028,.018,.028,.018},{.028,.018,.018,-.018},{.018,-.018,-.018,-.018},{-.018,-.018,-.028,.018}},
        [5]={{-.022,.025,0,-.025},{0,-.025,.022,.025}},
    }
    for kind=1,5 do
        local at=name..'_'..kind
        at=api.group(at,{parameter},{{'parameter_in_range',0,kind-.1,kind+.1}},parent)or at
        if kind==1 then api.circle(0,0,.018,color,at,1.2)
        else
            for _,s in ipairs(shapes[kind])do api.line(s[1],s[2],s[3],s[4],color,at,1.2)end
        end
    end
end
