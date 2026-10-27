-- GPL-3.0-or-later. Reference the simulator's existing Mk-83 weapon, not a new model.
-- Optional conventional-bomb training store; not an operational F-22 loadout claim.
declare_loadout({
	category = CAT_BOMBS,
	CLSID = "{F22-MK83-TRAINING}",
	attribute = { wsType_Weapon, wsType_Bomb, wsType_Bomb_A, Mk_83 },
	Count = 1,
	Cx_pil = 0.00035,
	Weight = 447,
	Picture = "mk83.png",
	displayName = _("Mk-83 - CCIP/AUTO training (non-standard F-22 load)"),
	Elements = { { ShapeName = "MK-83" } },
})
