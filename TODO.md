# Backlog

Deferred improvements for future implementation.

## Planned

- **Archiving completed features** — When the Ralph loop exits successfully, move the completed feature folder to `tasks/_archive/{feature-name}/`. Add stale-feature detection to ralph-plan (scan `tasks/` for completed PROGRESS.md files before creating a new feature). Modeled after [snarktank/ralph's archive logic](https://github.com/snarktank/ralph).

- ~~**Light mode**~~ ✅ — Implemented. Skips Phase Inspector + Journey Verifier for ≤ 3 tasks. Auto-detected at `PROGRESS.md` creation, overridable via `**Light Mode**: true/false`.

- **Browser verification skill** — Add concrete tooling for automated browser checks on UI stories. Currently acceptance criteria say "Verify visually in browser" but there's no skill or MCP integration to actually do it. snarktank/ralph uses a `dev-browser` skill for this.
