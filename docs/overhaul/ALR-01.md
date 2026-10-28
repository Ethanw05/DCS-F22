# ALR-01/03 — equipment occurrence and attention

The fixed eight-condition catalogue retains FCS, separate left/right generator,
hydraulic and oil conditions, and canopy identity. Each record has validity,
active state, occurrence, onset, acknowledgement and latest clearance time.
Acknowledgement clears attention, not the condition. Another fault or a recurrence
has a new occurrence even when an acknowledged condition remains active. Invalid
source data is UNAVAILABLE, not repaired. Storage and update work are bounded to
eight records; history retains the latest occurrence per identity.

Equipment processing is independent of terrain/navigation validity. FCS speech
retains its declared ground inhibit; valid equipment cautions can remain on the
ground. The exact F-22 phase/inhibit matrix is unknown. The existing physical
conditions are read from achieved physical causes; their 100 psi oil /
1000 psi hydraulic thresholds are mod estimates, not authenticated F-22 limits.
The aircraft provider remains responsible for source, supply, isolation and
recovery. Individual indications remain independent of display brightness.

`F22_MASTER_ATTENTION` is the published attention owner. Avionics requires
`F22_FAULT_REGISTRY_READY` from startup; missing or withdrawn readiness cannot
substitute aggregate display flags or cockpit animation for registry attention.
Each `F22_FAULT_<id>_` record publishes VALID/ACTIVE/OCCURRENCE/ACK/ONSET/CLEARED.
Active/unknown/unacknowledged counts and selected fault/reference are separate.
The existing ACK also clears a latched AFCS loss without engaging a mode.

Basis: Brower (2001), §32.4 supports graceful degraded functions; ED Hornet guide
(24 March 2024) supplies the master-attention analogue. This catalogue, history,
ground policy and attention mapping are explicit mod choices. Actual Lua tests
exercise independent causes, ACK, recurrence, source invalidity, mission rewind
and navigation loss. Physical fault injection, complete F-22 limits/BIT and native
annunciator optics remain separate qualification gates.

Physical integration: the registry now reads coherent EFM generator, hydraulic, oil and FCS causes rather than MFD color handles. Existing 1000 psi hydraulic / 100 psi oil thresholds remain mod policies. Canopy requires its independent provider-valid flag; cockpit argument 251 alone is unqualified. Stale/mixed/wrong-clock frames withdraw validity without creating a healthy zero.

Power transitions preserve fault occurrence/history and held physical ACK latches. Audio/pending crossings stop on loss; repeated down events after restoration cannot acknowledge a newly attended condition. Mission initialization/time reversal clears the history. Actual owner tests exercise these transitions.

Current-contract cleanup removes the pre-owner display-color/loose-power condition adapter. Missing physical ownership leaves all eight source-valid flags false from startup; colors and old aggregate flags cannot manufacture fault authority. Warning input/control power and master-attention consumption now follow the current owners from startup as well. Actual warning/replay fixtures publish coherent physical samples and low oil pressure, including a new fault after a display-power outage while ACK remains held. Independent source history, completed recordings, expiring audio leases and actual generator redundancy are preserved.
