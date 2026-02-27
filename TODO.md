# Backlog

Deferred improvements for future implementation.

## Planned

- **Archiving completed features** — When the Ralph loop exits successfully, move the completed feature folder to `tasks/_archive/{feature-name}/`. Add stale-feature detection to ralph-plan (scan `tasks/` for completed PROGRESS.md files before creating a new feature). Modeled after [snarktank/ralph's archive logic](https://github.com/snarktank/ralph).

- **Light mode** — Skip Phase Inspector + Journey Verifier for small features (1–3 tasks) to reduce token usage. Add a flag (`**Light Mode**: true`) to PROGRESS.md that the orchestrator respects.

- **Browser verification skill** — Add concrete tooling for automated browser checks on UI stories. Currently acceptance criteria say "Verify visually in browser" but there's no skill or MCP integration to actually do it. snarktank/ralph uses a `dev-browser` skill for this.
