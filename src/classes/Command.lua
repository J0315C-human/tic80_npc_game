
--------- Command "class" ----
function Command(cmdStr)
	local parts = split(cmdStr, " ")

	local s = {
		tic = parts[1],
		name = parts[2],
		cmd = parts[3],
		params = {}
	}
	for i = 4, #parts do
		s.params[#s.params + 1] = parts[i]
	end

	return s
end