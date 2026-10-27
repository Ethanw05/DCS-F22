-- GPL-3.0-or-later. Shared selected release capabilities, not a fleet fit claim.
-- Brower (2001), sections 32.3/32.4 establishes the historical CNI families.
-- Optional modern additions need a qualified complete backend before selection.
local selected = {
    gins = true, gps = true, tacan = true, ils = true, radar = true,
    manual_recovery = true, advisory_terrain = true,
    targeting_pod = false, hmd = false, irds = false, carrier_acls = false,
    autoland = false, automatic_gcas = false, additional_weapons = false,
    clear_voice_backend = false, diagnostic_weapon_truth = false,
}
local M = {
    id = 'public_f22_manual_recovery',
    revision = 1,
    afcs_analogue = 'DCS F/A-18C pilot relief; mod controller estimates',
    approach_reference_degrees = 12,
    approach_calibration = 'historical reference; production schedule and band limits unqualified',
}
function M.supports(capability)
    return selected[capability] == true
end
return M
