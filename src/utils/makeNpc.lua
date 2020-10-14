
function makeNpc(i, speechClr)
	
	i = i + 256
	local n =
		Npc(
		{
			idle = Anim({i}, 30, true),
			walk = Anim({2 + i, 1 + i}, 5, true),
			jump = Anim(
				{
					5 + i,
					4 + i,
					4 + i,
					3 + i,
					3 + i,
					5 + i
				},
				5
			),
			run = Anim({2 + i, 3 + i, 2 + i, 1 + i}, 3, true),
			wave = Anim({6 + i,7 + i, 6 + i, 7 + i, 6 + i, 7 + i}, 10),
			gesture = Anim({8 + i}, 100),
			point = Anim({9 + i}, 100),
		},
		{x = 1, y = 2},
		{x = C.NPC_START_X, y = C.NPC_START_Y}
	)
	if speechClr then
		n.speechClr = speechClr
	end
	return n
end
