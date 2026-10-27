# Regression contracts

`run_all.py` executes every `test_*.py` and the Lua syntax check. CTest separately
checks C++ models and actual DLL callbacks. Fixtures do not establish DCS flight
or native rendering qualification.

The shared display/UFC redesign superseded three legacy tests removed during
the 27 October regression repair:

| Retired test | Replacement coverage / changed contract |
| --- | --- |
| test_human_factors_workflow.py | test_common_ufc_workflow.py, test_entry_transactions.py and test_ufc_mouse_stores.py cover drafts, errors, exact acknowledgements, cancel and CLR/UNDO. The former generic OP5 ENTER, AP wheel pages and row-local draft echo were intentionally replaced by same-option commits and one scratchpad. |
| test_icp_flight_pages.py | test_common_ufc_workflow.py, test_entry_transactions.py and test_autopilot.cpp cover actual UFC ALT/AP isolation, numeric requests, explicit modes and independent AFCS controls. The removed test expected the retired five-page ICP flight owner. |
| test_pmfd_local_pages.py | test_common_mfd_workflow.py, test_mfd_mouse_menus.py and test_mfd_physical_layout.py cover every format on all four displays, local subpages, saved mouse descriptors, release ownership and power. The removed SYS submenu no longer exists. |

Numerical model, transaction, launch/release and physical-boundary tests are
retained. Updated graph tests call format constructors, respect display name
prefixes and exercise current physical keys. Page snapshots are refreshed only
with review of the changed formats and their behavioral/visibility checks.
