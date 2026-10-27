-- GPL-3.0-or-later. Fixed-format keypad transaction, decimal degrees internally.
local M={}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
function M.new(id,lat,lon,alt,valid)
 local self={field=1,id=id,lat=lat,lon=lon,alt=alt,valid=valid,buffer='',error='',
  south=lat<0,west=lon<0,below_sea=alt<0}
 function self:digit(n)if #self.buffer<({3,7,8,6})[self.field]then self.buffer=self.buffer..n;self.error=''end end
 function self:accept()
  if self.buffer==''then return true end
  local v=tonumber(self.buffer)
  if not finite(v)or v%1~=0 or not self.buffer:match('^%d+$')then
   self.error='ENTER DIGITS';return false
  end
  if self.field==1 then if v<1 or v>256 then self.error='WYPT 001-256';return false end;self.id=v
  elseif self.field==4 then
   local altitude=self.below_sea and -v or v
   if altitude < -1640 or altitude > 65000 then self.error='ELEV -1640 TO65000';return false end
   self.alt=altitude
  else
   local digits=self.field==2 and 7 or 8
   if #self.buffer~=digits then self.error=self.field==2 and 'LAT DDMM.MMM' or 'LON DDDMM.MMM';return false end
   local deg=math.floor(v/100000);local minutes=(v%100000)/1000
   local max=self.field==2 and 90 or 180
   if minutes>=60 then self.error='MIN 00-59.999';return false end
   if deg>max or(deg==max and minutes~=0)then self.error=self.field==2 and 'LAT MAX 90 DEG'or'LON MAX 180 DEG';return false end
   local key=self.field==2 and 'lat' or 'lon';self[key]=((self.field==2 and self.south or self.field==3 and self.west)and -1 or 1)*(deg+minutes/60)
   self[self.field==2 and 'lat_entered' or 'lon_entered']=true
  end
  self.buffer='';self.error='';return true
 end
 function self:choose(field)self.field=field;self.buffer='';self.error=''end
 function self:hemisphere()
  local key=self.field==2 and 'lat'or(self.field==3 and 'lon')
  if key then local flag=self.field==2 and 'south'or'west';self[flag]=not self[flag];self[key]=math.abs(self[key])*(self[flag]and -1 or 1)end
 end
 function self:ready()return self:accept()and(self.valid or self.lat_entered and self.lon_entered)and finite(self.lat)and finite(self.lon)and finite(self.alt)end
 return self
end
function M.coord(v,lat,negative)
 local a=math.abs(v);local deg=math.floor(a);local minute=math.floor((a-deg)*60000+.5)/1000
 if minute>=60 then deg=deg+1;minute=0 end
 if negative==nil then negative=v<0 end
 return string.format(lat and '%s%02d %06.3f'or '%s%03d %06.3f',lat and(negative and 'S'or'N')or(negative and'W'or'E'),deg,minute)
end
function M.draft(buffer,lat,negative)
 local d=lat and 2 or 3;local full=buffer..string.rep('-',math.max(0,d+5-#buffer))
 return (lat and(negative and'S'or'N')or(negative and'W'or'E'))..full:sub(1,d)..' '..full:sub(d+1,d+2)..'.'..full:sub(d+3,d+5)
end
return M
