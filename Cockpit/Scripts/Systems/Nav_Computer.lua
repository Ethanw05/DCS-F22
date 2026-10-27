-- GPL-3.0-or-later. Own mission-route guidance; all bearings are true/world.
-- AUTO is a fly-over capture/passed-waypoint policy, not turn anticipation.
local M={ranges={5,10,20,40,80,160,320},slots=32,radius=.56}
local pi=math.pi
function M.finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.atan2(y,x)
    if x>0 then return math.atan(y/x) end
    if x<0 then return math.atan(y/x)+(y>=0 and pi or -pi) end
    if y>0 then return pi/2 elseif y<0 then return -pi/2 end
    return 0
end
function M.wrap(v) return (v+pi)%(2*pi)-pi end
local function point(p,id,height)
    if type(p)~='table' or not M.finite(p.x) or not M.finite(p.y) then return end
    local alt=M.finite(p.alt) and p.alt or nil
    local reference=p.alt_type=='RADIO' and 'AGL' or 'MSL'
    local msl=alt
    if reference=='AGL' then
        local terrain=height and height(p.x,p.y)
        msl=M.finite(terrain) and alt and alt+terrain or nil
    end
    local name=type(p.name)=='string' and p.name:upper():gsub('[^A-Z0-9 /%-]','') or ''
    if name=='' then name=string.format('WAYPOINT %02d',id) end
    return {x=p.x,y=p.y,alt=alt,msl=msl,reference=reference,id=id,name=name:sub(1,16)}
end
function M.new(raw,height)
    local self={route={},selected=1,range_index=4,automatic=false,direct_origin=nil,arrived=false,sequence_count=0}
    if type(raw)=='table' then
        raw=raw.points or raw.route or raw
        if type(raw)=='table' then
            for i,p in ipairs(raw) do
                if i>256 then break end
                local w=point(p,i,height)
                if i==1 then self.origin=w
                elseif w then self.route[#self.route+1]=w end
            end
        end
    end
    function self:step(n)
        self.selected=math.max(1,math.min(#self.route,self.selected+n))
        self.direct_origin=nil;self.arrived=false;self.designation=nil
    end
    function self:direct(own)
        if own and M.finite(own.x) and M.finite(own.y) then
            self.direct_origin={x=own.x,y=own.y};self.arrived=false
        end
    end
    function self:select_id(id)
        for i,w in ipairs(self.route)do if w.id==id then self.selected=i;self.direct_origin=nil;self.arrived=false;self.designation=nil;return true end end
        return false
    end
    function self:edit(id,n,e,alt)
        if not M.finite(id)or id%1~=0 or not M.finite(n)or not M.finite(e)or not M.finite(alt)or alt< -500 or alt>20000 then return false end
        local index
        for i,w in ipairs(self.route)do if w.id==id then index=i;break end end
        local next_id=(self.route[#self.route]or self.origin or {id=1}).id+1
        if not index and(id~=next_id or #self.route>=255)then return false end
        index=index or #self.route+1
        self.undo={index=index,waypoint=self.route[index],selected=self.selected}
        self.route[index]={id=id,x=n,y=e,alt=alt,msl=alt,reference='MSL',name='USER '..string.format('%02d',id)}
        self.selected=index;self.direct_origin=nil;self.arrived=false;self.designation=nil
        return true
    end
    function self:undo_edit()
        if not self.undo then return false end
        local u=self.undo
        if u.waypoint then self.route[u.index]=u.waypoint else table.remove(self.route,u.index)end
        self.selected=math.min(u.selected,math.max(1,#self.route));self.direct_origin=nil;self.arrived=false;self.undo=nil
        return true
    end
    function self:scale(n) self.range_index=math.max(1,math.min(#M.ranges,self.range_index+n)) end
    return self
end
-- Clip even a leg with both endpoints outside but crossing the circular map.
function M.clip(x1,y1,x2,y2)
    local dx,dy=x2-x1,y2-y1;local a=dx*dx+dy*dy
    if a<1e-16 then return end
    local b=2*(x1*dx+y1*dy);local c=x1*x1+y1*y1-M.radius*M.radius
    local d=b*b-4*a*c
    if d<0 then return end
    local low=math.max(0,(-b-math.sqrt(d))/(2*a));local high=math.min(1,(-b+math.sqrt(d))/(2*a))
    if high<=low then return end
    return {x1=x1+low*dx,y1=y1+low*dy,x2=x1+high*dx,y2=y1+high*dy}
end
local function geometry(self,own)
    local w=self.route[self.selected]
    if not w then return end
    local dn,de=w.x-own.x,w.y-own.y;local distance=math.sqrt(dn*dn+de*de)
    local bearing=M.atan2(de,dn)%(2*pi)
    local origin=self.direct_origin or self.route[self.selected-1] or self.origin
    local s=self.solution_buffer or {}
    self.solution_buffer=s
    s.waypoint,s.distance,s.bearing=w,distance,bearing
    s.relative,s.count,s.selected=M.wrap(bearing-own.heading),#self.route,self.selected
    s.course,s.cross,s.along,s.length=nil,nil,nil,nil
    s.sequence_from,s.sequence_reason=nil,nil
    s.ttg,s.arrived,s.direct,s.designated,s.designation_alt=nil,nil,nil,nil,nil
    if origin then
        local ln,le=w.x-origin.x,w.y-origin.y;local length=math.sqrt(ln*ln+le*le)
        if length>1 then
            local on,oe=own.x-origin.x,own.y-origin.y
            s.course=M.atan2(le,ln)%(2*pi);s.cross=(ln*oe-le*on)/length;s.along=(ln*on+le*oe)/length;s.length=length
        end
    end
    return s
end
function M.solution(self,own)
    if not own or not M.finite(own.x) or not M.finite(own.y) or not M.finite(own.alt)
        or not M.finite(own.heading) then return end
    local s=geometry(self,own)
    if not s then return end
    local distance=s.distance
    local captured=distance<=.3*1852 or (s.along and s.along>=s.length
        and math.abs(s.cross)<=.75*1852 and distance<=1.5*1852)
    if not self.designation and M.finite(own.gs) and own.gs>15 and captured then
        if self.automatic and self.selected<#self.route then
            local previous=s.waypoint.id
            self.selected=self.selected+1;self.direct_origin=nil;self.arrived=false
            self.sequence_count=self.sequence_count+1
            -- Recompute once, without recursive sequencing or a second passage.
            s=geometry(self,own)
            if not s then return end
            s.sequence_from=previous
            s.sequence_reason=distance<=.3*1852 and 'CAPTURE' or 'PASSED'
        elseif self.direct_origin or self.selected==#self.route then self.arrived=true end
    end
    distance=s.distance
    s.arrived=self.arrived;s.direct=self.direct_origin~=nil
    if M.finite(own.gs) and own.gs>2.572222 then s.ttg=distance/own.gs end
    local scale=M.radius/(M.ranges[self.range_index]*1852)
    local sh,ch=math.sin(own.heading),math.cos(own.heading)
    local function map(p)
        local n,e=p.x-own.x,p.y-own.y
        return (e*ch-n*sh)*scale,(n*ch+e*sh)*scale
    end
    s.points={};s.legs={}
    local first=math.max(1,math.min(self.selected-8,#self.route-M.slots+1))
    for i=first,math.min(#self.route,first+M.slots-1) do
        local p=self.route[i];local x,y=map(p)
        s.points[#s.points+1]={x=x,y=y,id=p.id,active=i==self.selected,visible=x*x+y*y<=(M.radius-.02)^2}
        local previous=self.route[i-1] or self.origin
        if i==self.selected and self.direct_origin then previous=self.direct_origin end
        if previous then
            local px,py=map(previous);local leg=M.clip(px,py,x,y)
            if leg then leg.active=i==self.selected;s.legs[#s.legs+1]=leg end
        end
    end
    return s
end
return M
