
function clamp(val, min, max)
	if val < min then
		return min
	elseif val > max then
		return max
	else
		return val
	end
end

function isArray(table)
	if table[1] then
		return true
	else return false end
end

function asList(table)
	local all = {}
	for k, item in pairs(table) do
		all[#all + 1] = item
	end
	return all
end

function invokeBackToFront(
	objects, --objects with locations
	methodNm) -- method name
	function sortByY(a, b)
		return b.loc.y > a.loc.y
	end
	table.sort(objects, sortByY)

	for i = 1, #objects do
		local f = objects[i][methodNm]
		if f then
			f()
		end
	end
end

function getCenteredTextX(str)
	local w = string.len(str) * C.CHAR_WIDTH
	return 120 - w / 2
end

local function split(str, sep)
	local result = {}
	local regex = ("([^%s]+)"):format(sep)
	for each in str:gmatch(regex) do
		table.insert(result, each)
	end
	return result
end
