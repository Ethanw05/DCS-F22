-- GPL-3.0-or-later. Bounded public terrain-API geometry provider, not RF credit.
-- Static DEM geometry, current provider lease, object/LOS status remain separate.
local M = {maximum_cells=256, maximum_per_step=8, lease_seconds=.05}
-- Relative power-density estimates for public terrain surface categories.
-- These are game radiometry choices, not measured material/RCS coefficients.
local reflectivity = {land=1, sea=.05, river=.08, lake=.05}
local epochs = {'source_epoch','environment_epoch','navigation_epoch','clock_epoch','grid_epoch'}
local fields = {'north','east','column_n','column_e','row_n','row_e'}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<3e7 end
local function integer(v,low,high) return finite(v) and v>=low and v<=high and v%1==0 end
local function geometry(request)
    for _,name in ipairs(fields) do if not finite(request[name]) then return end end
    local area=math.abs(request.column_n*request.row_e-request.column_e*request.row_n)
    if area<1e-6 or area>1e8 then return end
    for _,p in ipairs({{0,0},{request.columns,0},{0,request.rows},{request.columns,request.rows}}) do
        local n=request.north+p[1]*request.column_n+p[2]*request.row_n
        local e=request.east+p[1]*request.column_e+p[2]*request.row_e
        if not finite(n) or not finite(e) then return end
    end
    return area
end
local function checked_request(request)
    if type(request)~='table' or request.schema~=1 then return end
    if not integer(request.columns,1,16) or not integer(request.rows,1,16) then return end
    for _,name in ipairs(epochs) do if not integer(request[name],1,16777215) then return end end
    local area=geometry(request)
    if not area then return end
    local copy={schema=1,columns=request.columns,rows=request.rows,area=area}
    for _,name in ipairs(epochs) do copy[name]=request[name] end
    for _,name in ipairs(fields) do copy[name]=request[name] end
    return copy
end
local function methods(terrain)
    return type(terrain)=='table' and type(terrain.GetHeight)=='function'
        and type(terrain.GetSurfaceType)=='function'
end
local function observation(terrain,n,e)
    local ok,height=pcall(terrain.GetHeight,n,e)
    if not ok or not finite(height) then return nil,nil,nil,'height_unavailable' end
    local typed,surface=pcall(terrain.GetSurfaceType,n,e)
    if not typed or type(surface)~='string' then return nil,nil,nil,'surface_unavailable' end
    local proxy=reflectivity[surface]
    if not proxy then return nil,nil,nil,'surface_unknown' end
    return height,surface,proxy
end
function M.new(terrain)
    local self={terrain=terrain,points={},frame_result={},serial=0,count=0,reason='not_requested'}
    for i=1,M.maximum_cells do self.points[i]={} end
    return setmetatable(self,{__index=M})
end
function M:fail(reason)
    self.provider_available=false
    self.active=false
    self.reason=reason
end
function M:begin(request,now)
    self.serial=self.serial+1
    self.count=0
    self.geometry_available=false
    self.provider_available=false
    self.request=checked_request(request)
    if not self.request or not finite(now) or now<0 then self:fail('request_invalid');return false end
    if not methods(self.terrain) then self:fail('provider_unavailable');return false end
    self.active=true
    self.first_geometry_time=nil
    self.last_geometry_time=nil
    self.lease_time=nil
    self.previous_time=now
    self.reason='collecting_geometry'
    return true
end
function M:clock(now)
    if not finite(now) or now<0 or now<(self.previous_time or now) then
        self:fail('clock_reset');return false
    end
    self.previous_time=now
    return true
end
function M:sample_cell(index,now)
    local r=self.request
    local column=(index-1)%r.columns+.5
    local row=math.floor((index-1)/r.columns)+.5
    local n=r.north+column*r.column_n+row*r.row_n
    local e=r.east+column*r.column_e+row*r.row_e
    local height,surface,proxy,reason=observation(self.terrain,n,e)
    if height==nil then self:fail(reason);return false end
    local point=self.points[index]
    point.north,point.altitude,point.east=n,height,e
    point.surface,point.proxy_power_density,point.area_m2=surface,proxy,r.area
    point.geometry_time=now
    self.first_geometry_time=self.first_geometry_time or now
    self.last_geometry_time=now
    self.lease_time=now
    self.provider_available=true
    return true
end
function M:step(now,budget)
    if not self.active or not self:clock(now) then return false end
    if not integer(budget,1,M.maximum_per_step) then self:fail('budget_invalid');return false end
    if not methods(self.terrain) then self:fail('provider_unavailable');return false end
    local total=self.request.rows*self.request.columns
    for _=1,budget do
        if self.count>=total then break end
        if not self:sample_cell(self.count+1,now) then return false end
        self.count=self.count+1
    end
    if self.count==total then
        self.geometry_available=true
        self.reason='static_terrain_ready'
        self.active=false
    end
    return self.geometry_available
end
function M:probe(now,source_epoch,environment_epoch)
    if not self.geometry_available or not self:clock(now) then return false end
    if source_epoch~=self.request.source_epoch or environment_epoch~=self.request.environment_epoch then
        self:fail('epoch_changed');return false
    end
    if not methods(self.terrain) then self:fail('provider_unavailable');return false end
    local anchor=self.points[1]
    local height,surface,_,reason=observation(self.terrain,anchor.north,anchor.east)
    if height==nil then self:fail(reason);return false end
    if math.abs(height-anchor.altitude)>.001 or surface~=anchor.surface then
        self:fail('geometry_changed');return false
    end
    self.lease_time=now
    self.provider_available=true
    self.reason='static_terrain_ready'
    return true
end
function M:frame(now)
    local current=self.provider_available and finite(now) and self.lease_time
        and now>=self.lease_time and now-self.lease_time<=M.lease_seconds
    local frame=self.frame_result
    frame.schema,frame.serial,frame.kind=1,self.serial,'static_terrain'
    frame.request=self.request
    frame.geometry_available=self.geometry_available==true
    frame.provider_available=current==true
    frame.geometry_first_time,frame.geometry_last_time=self.first_geometry_time,self.last_geometry_time
    frame.provider_lease_time=self.lease_time
    frame.points,frame.count=self.points,self.count
    frame.reason=self.reason
    if frame.geometry_available and not frame.provider_available then frame.reason='provider_stale' end
    frame.objects_known,frame.visibility_known,frame.scene_available=false,false,false
    return frame
end
return M
