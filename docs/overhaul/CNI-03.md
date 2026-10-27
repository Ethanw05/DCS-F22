# CNI-03 — surviving physical feeds

NativeNavigation preserves separate achieved left/right generator state when driving the native electrical bridge. MAIN_POWER no longer turns both generators on. The fixed borrowed-handle CniPower reader checks finite API results, physical valid/generation/stamp/clock-kind before and after, and permanently latches ownership. Stale, mixed or missing frames withdraw receiver consent.

Selected estimate: either surviving engine generator plus usable DC supports both low-load native TACAN/ILS receivers; an environment/thermal fault withdraws receiver consent without changing generator state. This is a logical consumer mapping, not recovered F-22 wiring or SEM-E allocation. Battery-only/GPU/APU AC conversion is unqualified and cannot enable these AC-dependent receivers. F22_CNI_SUPPLY_VALID/RECEIVER_FEED/THERMAL_INHIBIT expose the distinction. Voice remains unavailable pending lifecycle/tune/RX/TX proof; no secure waveform or cryptography is implemented.

The actual MSVC /W4 /WX /analyze fixture covers each generator independently, battery-only, cooling, stale/wrong-clock/mixed generations, failed API reads and restoration. Native bus/receiver electrical effects and surviving emergency navigation still need an observed DCS scenario. This is partial CNI-03, not complete emergency CNI qualification.
