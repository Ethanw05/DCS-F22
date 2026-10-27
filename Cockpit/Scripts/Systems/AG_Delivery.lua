-- GPL-3.0-or-later. Delivery geometry from the selected native ballistic result.
local M = {}
local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) < 1e8
end
function M.release(impact, target, vn, ve, fall)
	for _, v in ipairs({ impact.n, impact.e, target.n, target.e, vn, ve, fall }) do
		if not finite(v) then
			return
		end
	end
	local speed = math.sqrt(vn * vn + ve * ve)
	if speed < 30 or fall < 1 then
		return
	end
	local dn, de = target.n - impact.n, target.e - impact.e
	local along = (dn * vn + de * ve) / speed
	local cross = (dn * ve - de * vn) / speed
	return {
		seconds = along / speed,
		along = along,
		cross = cross,
		ready = math.abs(cross) <= 40 and along >= -speed * 0.15 and along <= speed * 0.05,
	}
end
-- Conservative mod LAR for a coordinate-guided bomb. This is an explicitly
-- estimated correction ellipse around the native free-flight solution, not a
-- recovered F-22/JDAM mission computer or an assertion of the weapon's maximum.
function M.guided(own,impact,target,vn,vu,ve,fall)
 for _,v in ipairs({own.n,own.u,own.e,impact.n,impact.e,target.n,target.u,target.e,vn,vu,ve,fall})do if not finite(v)then return end end
 local speed=math.sqrt(vn*vn+ve*ve);local height=own.u-target.u
 if speed<1 then return end
 local rn,re=impact.n-own.n,impact.e-own.e
 local reach=math.sqrt(rn*rn+re*re)
 local tn,te=target.n-own.n,target.e-own.e
 local range=math.sqrt(tn*tn+te*te)
 local along=((target.n-impact.n)*vn+(target.e-impact.e)*ve)/speed
 local cross=((target.n-impact.n)*ve-(target.e-impact.e)*vn)/speed
 local correction=math.max(250,reach*.3)
 local maximum=math.min(24140,reach+correction) -- public USAF nominal 15-mile cap
 local minimum=math.max(500,reach-correction)
 local ellipse=(along/correction)^2+(cross/math.max(150,reach*.2))^2
 local reason
 if height<300 or height>13716 then reason=2
 elseif speed<100 or speed>360 or math.abs(vu)>speed*.7 then reason=3
 elseif tn*vn+te*ve<=0 then reason=4
 elseif range<minimum or range>maximum or ellipse>1 or fall<3 or fall>120 then reason=5 else reason=0 end
 return {ready=reason==0,reason=reason,minimum=minimum,maximum=maximum,range=range,along=along,cross=cross,seconds=along/speed,estimated=true}
end
local function intersection(points,height)
	local previous, delta
	for i, p in ipairs(points) do
		local ok, floor = pcall(height, p.n, p.e)
		if not ok or not finite(floor) then
			return
		end
		local d = p.u - floor
		if previous and delta > 0 and d <= 0 then
			local lo, hi = 0, 1
			for _ = 1, 14 do
				local f = (lo + hi) / 2
				local n, u, e =
					previous.n + (p.n - previous.n) * f,
					previous.u + (p.u - previous.u) * f,
					previous.e + (p.e - previous.e) * f
				local valid, z = pcall(height, n, e)
				if not valid or not finite(z) then
					return
				end
				if u > z then
					lo = f
				else
					hi = f
				end
			end
			local f = (lo + hi) / 2
			return {
				n = previous.n + (p.n - previous.n) * f,
				u = previous.u + (p.u - previous.u) * f,
				e = previous.e + (p.e - previous.e) * f,
				t = (previous.t or (i-2)*.05)+((p.t or (i-1)*.05)-(previous.t or (i-2)*.05))*f,
			}
		end
		previous = p
		delta = d
	end
end
function M.ground(points,height)
 -- Sample the terrain between trajectory vertices as well as at the vertices:
 -- endpoint-only crossing tests can skip a ridge entirely. Work stays bounded.
 local dense={};local queries=0
 for i,p in ipairs(points)do
  if not finite(p.n)or not finite(p.u)or not finite(p.e)then return end
  if i>1 then
   local previous=points[i-1]
   local spans=math.max(1,math.ceil(math.sqrt((p.n-previous.n)^2+(p.e-previous.e)^2)/50))
   if spans>256 or queries+spans>2048 then return end
   for j=1,spans-1 do local f=j/spans;dense[#dense+1]={n=previous.n+(p.n-previous.n)*f,u=previous.u+(p.u-previous.u)*f,e=previous.e+(p.e-previous.e)*f,t=(previous.t or (i-2)*.05)+((p.t or (i-1)*.05)-(previous.t or (i-2)*.05))*f}end
   queries=queries+spans
  end
  dense[#dense+1]={n=p.n,u=p.u,e=p.e,t=p.t or (i-1)*.05}
 end
 return intersection(dense,height)
end
return M
