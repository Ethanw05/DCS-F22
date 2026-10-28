# DCS contact labels and simpler DEF/Stores workflow

User-selected simulation policy: take aircraft/emitter type from DCS instead of
simulating classification. Type labels do not identify friend or foe and do
not create a detection, target association, range or weapon authority.

The owned scene provider reads the borrowed MovingObject's model-type string.
The matched CockpitBase insertion path at RVA2fd6e0 copies that same text from
MovingObject+296 (LinkBase's object interface is at+256, its model name at+40).
This was inspected with the existing Hex-Rays session; no RWR contact cache,
mechanical radar or stock sensing function is invoked. The existing matched
module guards apply. Bounded64-character copied text validates the MSVC string
layout, size, pointer, terminator and character range; bad metadata becomes
unknown without affecting sensing. No scene pointer crosses the callback.

Only successfully detected reports carry this DCS metadata into the owned track
snapshot (`F22A_nn_TYPE_NAME`), radar tactical stream and DEF/SA label. MiG29,
F22 and FA18 display29,22 and18; ground RF emitters displaySAM. The native RWR
name dictionary includes F-22 aliases. Unsupported type labels retainU. All
indicator label paths use numeric handles and static glyphs, protecting the
native formatter from startup numeric handles passed to `%s`.

The old scope-side comparison of equal RF and radar numbers is removed. Scope
RF markings consume the actual geometry-correlated tactical result, its original
radar source and source-local RF age. Air tracks do not correlate to known
ground emitters. Own ECM publication is inside its coherent sequence bracket;
the native fixture now asserts that on every effect-field write.

DEF keeps rangeIN/OUT and ECM on its operational page. Setup contains the five
countermeasure program fields withSAVE,REVERT andRTN. Receiver power, filtering,
direct-bank assignment, self-test and duplicate status rows are removed from
this setup page; existing input bindings/underlying functions are preserved.

Stores usesPROFILE to select a program andEDIT to open numeric programming.
The edit page shows quantity, multiplier, interval/spacing and current input.
MFD field buttons select the existing UFC row; ENTER submits through the same
request/acknowledgement owner; CLEAR edits that same buffer; DONE closes it.
Target/station/PP actions are grouped onTARGET. Four displays retain independent
local subpages while the UFC remains the single numeric entry owner. The new
ICP command10994 means commit the selected Stores field and is inert elsewhere.

`tools/render_avionics_preview.py` renders the current Lua graphs, shipped
stroke font and textures using synthetic inputs. Outputs are under
`out/previews/current-avionics/`; these are previews, not DCS captures.

Verification:31/31 native and167/167 script checks, including the actual
MFD→UFC→Weapon field/ENTER/CLEAR path for four screens and guided/unguided stores;
native type text copying/publication, metadata expiry, and numeric-safe labels.
The modified MFD button dispatcher and provider query were split into bounded
helpers. Existing untouched complexity debt remains in MFD publish/update and
native bind_driver; this patch does not claim whole-project standard compliance.
Type/arrow placement and complete RF effectiveness still need a native flight.
