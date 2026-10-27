Archived owned-sensor regression, DCS 2.9.30.28738, 27 October 2026.

`aesa-position-run02.csv` retains the first 160 unique STT measurement timestamps
and noisy world positions from the defective pre-filter run. Coordinates share
a translation origin at its first target report; no mission target truth is
included. Ownship position at the measurement time is reconstructed from the
logged current position and ownship velocity across the short processing age.
This introduces a small constant-velocity reconstruction approximation.

Source log SHA-256:
`c5e45358652f9324f6768d2e50d818eeacce01aa7615d42a0c4972a7586616d9`.
Loaded F22.dll SHA-256:
`3B7D6A0BE49F9331FFFDF6E657440644064A9CCA560D4AA03DF2A5403DB2DEF4`.

The replay uses only the positions, reconstructed observer geometry and explicit
estimated errors (9 m range, 0.00036 rad angle). **Doppler was not recorded**;
it is disabled in this replay. The test measures velocity-step suppression and
covariance integrity, not truth accuracy. Separate synthetic measurement-domain
tests cover Doppler, maneuvers, ownship motion/rotation, missed revisits, outliers
and the absence of instantaneous transverse-velocity authority.
