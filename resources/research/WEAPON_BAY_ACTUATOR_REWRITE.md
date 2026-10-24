# F-22 weapon bay and gun animation: one-owner actuator review

## Public primary evidence

- [USAF F/A-22 gun-door flight test photograph](https://www.af.mil/News/Photos.aspx?igphoto=2000030462): identifies the M61A2 gun's hydraulic door and test at high speed. This supports a separate gun-door state, **not** a numeric operational deployment time.
- [USAF Air Combat Command: F-22 launchers & weapon bays, 2009](https://www.acc.af.mil/News/Photos/igphoto/2000516374/): documented LAU-142 AIM-120 vertical ejector associated with the main bay.
- [USAF Air Combat Command: F-22 Sidewinder rail, 2009](https://www.acc.af.mil/News/Photos/igphoto/2000516347/): documents LAU-141 AIM-9 rail and side bay.
- [USAF F-22 aircraft fact sheet](https://www.af.mil/About-Us/Fact-Sheets/Display/Article/104506/f-22-raptor/): published A/A and A/G weapon types and counts; no timing, interlock or weapon-handoff equations.

## Code findings corrected

- A single 0.02 s weapon-device tick formerly executed up to four *independent* branches per bay, each writing the same animation arguments and adding 0.05.
- A second-detent gun trigger could instantly add 1.0 to an already partially opened door.
- Numeric `getNoseLandingGearDown()==1` was treated as WOW, making gear extension in flight erroneously equate to ground contact.
- Pickle fire originally dispatched before the weapon bay had even opened.
- An explicit `native_pickle_active` flag separates pending pilot request, bay animation and actual native dispatch. Power loss/master-arm/WOW or releasing pickle results in **PickleOFF**. The mod **cannot** establish FC3 native release authority merely by dispatching a command.

## New semantics

All bay arguments 600 (main), 601 (left), 602 (right) are updated once and clamped [0,1] by a `dt` normalized actuator with independent open targets. Station select=1 left, 2 center, 3 right, 4 all; ground override and ground crew left bay retained as separate requests. Requested opening rates: 2.5 normalized/s for aerial bays, 0.11 for ground override, 0.25 for ground crew, 4.5 for gun door. **All are previous-mod cadence extrapolations, not confirmed F-22 actuator speeds.**

- Pending pickle triggers native only after chosen bay is ≥98% open. Selected all requires all three open. Gun mode never triggers pickle.
- Closing occurs on request removal when main power is present; power loss conservatively freezes the visual actuator as its hydraulic availability isn't independently simulated.
- Gun-door motor uses first/second detent intent; gun firing remains interlocked on gun-mode, full door, main power, ground contact and master arm.
- DCS native stores and ejector-rail timing **not implemented**.

## Follow-up tests

Test in actual DCS: keypad/ICPs/HOTAS modes, selected bays 1/2/3/4, partial openings, short vs held pickle, gear down in flight, WOW while taxiing, standby battery power, hydraulic failure, unlimited ammo, rearm. Compare observed door travel against public video and ensure no wrong-station mismatch with FC3 selection. Only the Lua parser can be validated in CI without DCS runtime.
