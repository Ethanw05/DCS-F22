-- GPL-3.0-or-later. Display clustering only; never associates sensor tracks.
local M = { separation = math.rad(10), maximum = 8 }
function M.group(candidates)
	local clusters = {}
	for _, c in ipairs(candidates) do
		local same
		for _, cluster in ipairs(clusters) do
			local a = cluster.representative
			local distance = math.abs(math.atan2(math.sin(c.angle - a.angle), math.cos(c.angle - a.angle)))
			if
				distance < M.separation
				and c.optical == a.optical
				and c.irst == a.irst
				and c.irst_contributor == a.irst_contributor
				and c.affiliation == a.affiliation
				and c.coast == a.coast
			then
				same = cluster
				break
			end
		end
		if same then
			same.count = same.count + 1
		else
			clusters[#clusters + 1] = { representative = c, count = 1 }
		end
	end
	local represented = 0
	for i = 1, math.min(M.maximum, #clusters) do
		represented = represented + clusters[i].count
	end
	return clusters, math.max(0, #candidates - represented)
end
return M
