# F-22 project instructions

- Read `docs/CODING_STANDARD.md` before changing project-owned Lua or C++. Apply it to new and modified code; migrate existing violations in focused changes.
- Use `docs/overhaul/README.md` as the implementation plan and `docs/audit/README.md` for reference behavior and uncertainty. Read the relevant source passages rather than relying only on audit summaries.
- Keep documented F-22 behavior, adopted aircraft analogues and estimated parameters distinguishable. A unit test does not authenticate an aircraft parameter.
- Work in a separate branch/worktree when other implementation chats are active. Preserve existing user changes, bindings, HUD styling and recorded audio.
- Coordinate shared-file changes through `docs/handoffs/README.md`. Implement complete behavior chains with explicit physical/data ownership and focused commits.
- Preserve original source references and evidence. Update the relevant work item after a change; keep documentation concise and useful to implementation.
