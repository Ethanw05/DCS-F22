# F-22 project instructions

- Read `docs/CODING_STANDARD.md` before changing project-owned Lua or C++. Apply it to new and modified code; migrate existing violations in focused changes.
- Use `docs/overhaul/README.md` as the implementation plan and `docs/audit/README.md` for reference behavior and uncertainty. Read the relevant source passages rather than relying only on audit summaries.
- Keep documented F-22 behavior, adopted aircraft analogues and estimated parameters distinguishable. A unit test does not authenticate an aircraft parameter.
- The user requires this work to continue directly in the primary DCS-F22 checkout on main. Do not create another isolated working copy unless the user explicitly requests it. Preserve existing user changes, bindings, HUD styling and recorded audio.
- When the user requests deletion, remove the specified item without creating or retaining a backup.
- Implement complete behavior chains with explicit physical/data ownership and focused commits; preserve changes already made by other owners.
- Preserve original source references and evidence. Update the relevant work item after a change; keep documentation concise and useful to implementation.
- Current user priority is airborne systems and handling. Complete validated fixes with installation into the normal DCS mod, using one coordinated installer, backups and verification; preserve other chats' updates and saved bindings. Do not leave completed fixes source-only.
- The user requires completed changes to be committed and integrated into the main checkout on `main`; do not leave main behind. Preserve any unrelated working changes and integrate safely.
- The user has explicitly stopped chat-to-chat messaging for individual features. Only communicate when absolutely nessisary as it dramatically slows work down.