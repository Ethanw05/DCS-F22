The normal installation matches all 583 current runtime assets and the native DLL/build identity. Fresh checks against actual installed Lua pass 74 package and 75 navigation/HUD cases; all 14 reviewed DCS libraries still match. Actual flight behavior remains unqualified.

The abandoned registered radar checkout was removed through Git (573 files, 2,886,849,897 bytes; its 24 audio files also exist identically in main). Main is the only remaining registered checkout. No backup was created.

Cleanup is **partial**: automatic approval review rejected both the bulk removal and an explicitly named single-receipt deletion with only `blocked by policy`. All 33 obsolete installed receipts and four obsolete active diagnostic hooks remain. The installed README refresh was also not applied. Eleven other old work/research directories are inventoried, not deleted; their original evidence must be distinguished from duplicate code/build artifacts.

[RESULTS.json](RESULTS.json) records exact pending file paths and hashes, remaining directory counts, checks and preserved assets. Current SAR work, saved controls, recorded audio, HUD styling, passive trim recording and other owners' pending source changes are preserved.
