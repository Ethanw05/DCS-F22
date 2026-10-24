# GBU-32 JDAM host-compatibility study — 24 October 2026

## Evidence examined

- [US Air Force F-22 fact sheet](https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104506/f-22-raptor/): up to two 1,000-lb GBU-32 internally in F-22 A/G configuration, plus two AIM-120 and two AIM-9.
- [pydcs DCS weapons database](https://github.com/pydcs/dcs/blob/master/dcs/weapons_data.py): **stock host identifier** `{GBU_32_V_2B}`, 467 kg, GBU-32(V)2/B JDAM; third-party extracted metadata, not a guarantee of the currently installed DCS module's availability or API release pathway.
- [Eagle Dynamics DCS weapon enum](https://www.digitalcombatsimulator.com/en/support/faq/1261/): distinct BOMB vs MISSILE weapon categories and guided-bomb vs A/A types.
- [Existing weapons audit](../../docs/audit/12-weapons.md) `WPN06` identifies the legacy category/warhead/control mismatch.

## Code finding

The bundled `Weapons/GBU_32.lua` claims `CAT_AIR_TO_AIR`, `wsType_Missile`, `wsType_AA_Missile`, and contains a missile `ModelData` with inert thrust, radar-targeting fields and an **explosive charge of 460 kg**, matching its gross mass `M = 460`. Those values make it misleading and physically indefensible as a 1,000-lb GPS-guided bomb.

The old CLSID `{GBU32_JDAM}` appears on stations 5 and 7 of `F-22A.lua` and twice in `UnitPayloads/F-22A.lua` (01 two-JDAM preset). Removing or silently changing it would break existing user payloads.

## Implemented as safe compatibility spike

Added **optional stock DCS `{GBU_32_V_2B}`** to both internal GBU stations using their existing permitted geometry and reciprocal exclusions. Kept custom legacy weapon and premade mission preset unchanged, while labeling its incorrect behavior in source comments. No invented GPS seeker, guidance gains, fuze tables, impact solution or warhead fill were introduced.

This does **not** establish actual F-15C/FC3 guided bomb support, or current DCS stock weapon loading on this module. Native carrier avionics, weapon target coordinates, SMS pairing, authentic bay clearance and mode selection are still an open feasibility gate. If the host weapon does not work in DCS, remove the optional stock loadout from a tested revision; don't fake a lock-on missile as a JDAM.

## DCS acceptance steps

1. Open the Mission Editor with F-22A player and add the stock GBU-32 to each internal station; confirm no Lua/DCS loadout errors or invisible shapes.
2. Fly actual A/G mode with stock and legacy GBU in separate missions. Observe whether native weapon stepping selects the loadout and which weapon object is emitted at pickle.
3. Set a ground target/markpoint and check whether any native interface genuinely transfers INS/GPS target data. The new cockpit MARK stores a *visual* location only.
4. Verify gravity-only vs guided bomb trajectory and correct impact/no false airborne homing. Do not treat `CCIP N/A` as a bug until a validated ballistic computer exists.
5. Confirm correct mass/drag changes, station jettison, aircraft weapon-door animation and multiplayer synchronization. Archive `dcs.log` and DCS build number.
