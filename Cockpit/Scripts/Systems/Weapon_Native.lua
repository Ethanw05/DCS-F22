-- GPL-3.0-or-later. Shared DCS payload/sight implementation.
-- Inputs are routed explicitly by Weapon_System, including unconditional stops.
-- Never use on_launch as a release veto: that callback is only a notification.
make_default_activity(0.02)
need_to_be_closed=false
