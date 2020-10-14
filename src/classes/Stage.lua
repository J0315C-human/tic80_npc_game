
--------- Stage class -----
function Map(parent, mapOffset)
	local s = {
		parent = parent,
		mapXOffset = 0,
		mapYOffset = 0,
	}
	if mapOffset then
		s.mapXOffset = mapOffset.x
		s.mapYOffset = mapOffset.y
	end
	function s.draw()
		local mapXRem = s.parent.loc.x % 8
		local mapYRem = s.parent.loc.y % 8
		local mapX = (s.parent.loc.x - mapXRem) / 8 + s.mapXOffset
		local mapY = (s.parent.loc.y - mapYRem) / 8 + s.mapYOffset

		map(mapX, mapY, 31, 18, -mapXRem, -mapYRem)
	end

	return s
end