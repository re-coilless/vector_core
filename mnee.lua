_BINDINGS[ "vector_core" ] = {
	left = {
		order_id = "aa",
		name = "Move Left",
		desc = "Translates character to the left.",
		keys = {[ "a" ] = 1 },
	},
	right = {
		order_id = "ab",
		name = "Move Right",
		desc = "Translates character to the right.",
		keys = {[ "d" ] = 1 },
	},
	up = {
		order_id = "ac",
		name = "Move Up",
		desc = "Translates character to upwards.",
		keys = {[ "w" ] = 1 },
	},
	down = {
		order_id = "ad",
		name = "Move Down",
		desc = "Translates character downwards.",
		keys = {[ "s" ] = 1 },
	},
	
	run = {
		order_id = "ba",
		allow_special = true,
		name = "Run",
		desc = "Makes the character move faster.",
		keys = {[ "left_shift" ] = 1 },
	},
	jump = {
		order_id = "bb",
		name = "Jump",
		desc = "Quickly elevates the character.",
		keys = {[ "space" ] = 1 },
	},
	fly = {
		order_id = "bc",
		name = "Ascend",
		desc = "Allows the character to soar.",
		keys = {[ "space" ] = 1 },
		keys_alt = {[ "w" ] = 1 },
	},

	
	interact = {
		order_id = "ca",
		name = "Use",
		desc = "Interacts with the world.",
		keys = {[ "e" ] = 1 },
	},
	throw = {
		order_id = "cb",
		name = "Throw",
		desc = "Dispenses of the item in hand.",
		keys = {[ "t" ] = 1 },
	},
	kick = {
		order_id = "cc",
		name = "Kick",
		desc = "Performs a short-ranged attack that affects world and enemies.",
		keys = {[ "f" ] = 1 },
	},

	fire = {
		order_id = "da",
		name = "Shoot Primary",
		desc = "Activates currently held item.",
		keys = {[ "mouse_left" ] = 1 },
	},
	fire_alt = {
		order_id = "db",
		name = "Shoot Secondary",
		desc = "Activates additional abilities of the currently held item.",
		keys = {[ "mouse_right" ] = 1 },
	},
	next_item = {
		order_id = "dc",
		name = "Equip Next",
		desc = "Switches to the following slot.",
		keys = {[ "mouse_wheel_up" ] = 1 },
	},
	last_item = {
		order_id = "dd",
		name = "Equip Previous",
		desc = "Switches to the preceding slot.",
		keys = {[ "mouse_wheel_down" ] = 1 },
	},
}