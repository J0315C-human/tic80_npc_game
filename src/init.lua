
local C = {
	--config
	DEF_ANIM_TICS = 5,
	BG_COL = 5,
	CLEAR_COL = 14,
	NPC_WALK_SPD = 0.5,
	NPC_RUN_SPD = 1.3,
	NPC_START_X = -30,
	NPC_START_Y = 0,
	STAGE_MOVE_SPD_SLOW = 0.3,
	STAGE_MOVE_SPD_MED = 1.5,
	STAGE_MOVE_SPD_FAST = 4,
	JUMP_SCALE = 0.3,
	TEXT_TOP = 8,
	T_LINE_MIN = 40,
	T_PER_LETTER = 3,
	CHAR_WIDTH = 6,
}

local G = {
	--global state
	t = 0,
	debug = "",
	--cur scene
	scene = nil
}
