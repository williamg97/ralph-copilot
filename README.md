# Forge — Iterative AI Implementation Agent for VS Code Copilot

> **🚧 Work in Progress** — Agent instructions, QA tiers, and loop behavior may change between versions.

> **⚠️ Token Usage:** A full pipeline run consumes roughly **4–6x** the tokens of single-agent implementations. Use a strong model (Claude Opus 4.6 etc) for **PRD, and Plan** agents where reasoning quality matters. Use a cheaper model for the **Forge loop agent** where most tokens are spent, since the orchestration and inspection tasks are more about structured execution than deep reasoning.

This project was originally inspired by the [Ralph pattern](https://ghuntley.com/ralph/) and [snarktank/ralph](https://github.com/snarktank/ralph), but has diverged significantly — adding multi-agent orchestration with strict role separation, a four-tier QA pipeline, phased execution with enforced boundaries, structured planning, and native VS Code integration. It has since been rebranded as **Forge** to reflect the divergence. See the [comparison tables](#comparison-with-other-implementations) below for a detailed breakdown.

Forge is a multi-stage AI agent pipeline for VS Code Copilot that takes a feature idea from requirements through to a fully implemented solution with quality gates.

## Pipeline

```
┌─────────┐     ┌──────────────────┐     ┌─────────────────────────────────┐     ┌─────────────────┐
│   PRD   │ ──▶ │ Forge Plan       │ ──▶ │ Forge Loop                      │ ──▶ │ Forge Archive   │
│  Agent  │     │ Mode             │     │ (orchestration + implementation) │     │ (optional)      │
└─────────┘     └──────────────────┘     └─────────────────────────────────┘     └─────────────────┘
 Generates       Decomposes PRD into      Iterates through tasks with             Moves completed
 requirements    spec + plan + tasks      Coder / Inspector / Journey QA          feature to _archive/
```

### Stage 1: PRD Agent (`prd`)
Generates a Product Requirements Document from a feature description. Detects the project state (greenfield vs existing codebase) to ask better clarifying questions, then produces a structured PRD with user stories, functional requirements, and acceptance criteria. Automatically scales interview depth based on feature complexity — simple features get 3-5 quick questions, complex multi-system features get 8-12 questions across two rounds.

### Stage 2: Forge Plan Mode (`forge-plan`)
Detects whether `.github/copilot-instructions.md` is configured — if not, auto-detects the tech stack from manifest files and offers to populate it. Warns if completed features in `tasks/` haven't been archived yet. Then takes a PRD and decomposes it into:
- **`00-context.md`** — Shared project context for all coder subagents (conventions, architecture, utilities, testing patterns)
- **`01.specification.md`** — Technical specification with detailed requirements
- **`02.plan.md`** — Phased implementation plan with dependency ordering
- **`03-tasks-*.md`** — Individual task files with acceptance criteria
- **`PROGRESS.md`** — Progress tracker for the Forge loop (with seeded learnings and iteration tracking)

### Stage 3: Forge Loop (`forge-loop`)
Iteratively implements each task using subagents:
- **Coder subagent** — Autonomously selects and implements one task at a time, runs preflight checks, verifies feature wiring, records learnings, and commits
- **Task Inspector** — Verifies each completed task against acceptance criteria and reachability
- **Phase Inspector** — Validates entire phases at phase boundaries including cross-task integration and reachability audits
- **Journey Verifier** — Final gate that traces every user story from the PRD to a reachable entry point before the loop exits

The orchestrator never writes application code — it only dispatches subagents and tracks progress via `PROGRESS.md`.

Supports two modes:
- **Auto** — Runs through all tasks autonomously
- **HITL (Human-in-the-Loop)** — Pauses at phase boundaries for human validation

### Stage 4: Forge Archive (`forge-archive`) — optional
Moves a completed feature folder from `tasks/{feature}/` to `tasks/_archive/{feature}/`. Validates that all tasks are ✅ before archiving (warns if incomplete). Available via the **Archive Feature** handoff at loop exit or the `/forge-archive` slash command at any time.

## Setup

### 1. Install

Copy the `.github/` folder into your project's root:

```
your-project/
├── .github/
│   ├── agents/                      # Custom agents (auto-detected by Copilot)
│   │   ├── forge-prd.agent.md
│   │   ├── forge-archive.agent.md
│   │   ├── forge-plan.agent.md
│   │   ├── forge.agent.md
│   │   └── instructions/            # Extracted subagent instruction files
│   │       ├── coder.md
│   │       ├── task-inspector.md
│   │       ├── phase-inspector.md
│   │       ├── journey-verifier.md
│   │       └── chrome-devtools-skill.md  # Browser verification skill reference
│   ├── copilot-instructions.md      # ← customize this (project config + preflight)
│   └── prompts/                     # Slash commands (/forge-prd, /forge-plan, /forge-archive)
│       ├── forge-prd.prompt.md
│       ├── forge-plan.prompt.md
│       └── forge-archive.prompt.md
└── ...
```

### 2. Configure project context

Forge uses a single **`.github/copilot-instructions.md`** file for all configuration — tech stack, coding standards, preflight commands, conventions, and agent workflow notes.

`.github/copilot-instructions.md` is **natively auto-loaded** by VS Code Copilot ([docs](https://code.visualstudio.com/docs/copilot/customization/custom-instructions#_use-a-githubcopilot-instructionsmd-file)), so its contents are included in every chat request with no extra setup.

**If your project already has a `.github/copilot-instructions.md`**, Forge will use it as-is — it won't overwrite your existing configuration. The plan agent will check for any missing Forge-specific sections (`## Preflight`, `## Notes for AI Agents`) and silently append them if needed, leaving your existing content untouched.

The plan agent handles three scenarios automatically:

- **Existing project with configured file** — Uses your file, patches in any missing Forge sections, and proceeds to planning.
- **Existing project without configuration (brownfield)** — Detects your tech stack from manifest files (`package.json`, `Cargo.toml`, `pyproject.toml`, etc.) and offers to populate the file before planning. The PRD agent also adapts its questions based on detected project state.
- **New project with no source code (greenfield)** — Asks you about language, framework, and project type, then populates the file. Ensures Phase 1 of the generated plan includes project scaffolding and build tooling setup.

You can also configure it manually at any time — open `.github/copilot-instructions.md` and replace the `TODO` markers with your project's values:

```markdown
## Preflight
\```bash
pnpm run lint && pnpm run typecheck && pnpm run test
\```

## Project Context
- **Language/Runtime**: TypeScript / Node.js 20
- **Framework**: Next.js 14 (App Router)
- **Database**: PostgreSQL with Prisma ORM
- **Testing**: Vitest
- **Build tool**: Vite
- **Package manager**: pnpm

## Coding Standards
- Use functional components with hooks (no class components)
- Prefer named exports over default exports

## Conventions
- **Commit format**: Conventional Commits (`feat:`, `fix:`, `chore:`)
- **Branch naming**: `feature/{name}`, `fix/{issue-id}`
- **Test files**: Co-located (`foo.test.ts` next to `foo.ts`)

## Directory Structure
src/           # Application source code
tests/         # Test files (if not co-located)

## Notes for AI Agents
- Always run preflight before marking a task complete
- Commit after each completed task with a conventional commit message
```

You can also create **file-pattern instructions** (e.g., `react.instructions.md` for React conventions) that Copilot applies only when working with matching files. See [VS Code custom instructions docs](https://code.visualstudio.com/docs/copilot/customization/custom-instructions) for details.

### 3. Use in VS Code

Open the Chat view (`Ctrl+Alt+I`) and select an agent from the dropdown:

| Agent | What it does |
|-------|-------------|
| **forge-prd** | Generate a PRD from a feature description |
| **forge-plan** | Decompose a PRD into spec/plan/tasks |
| **forge-loop** | Execute the implementation loop |
| **forge-archive** | Archive a completed feature folder to `tasks/_archive/` |

Or use prompt commands:
- `/forge-prd` — Quick PRD generation
- `/forge-plan` — Quick plan decomposition
- `/forge-archive` — Archive a completed feature folder

### Typical Workflow

1. Select the **forge-prd** agent → describe your feature → answer clarifying questions → PRD is saved
2. Click **"Decompose into Plan"** handoff → plan agent configures `.github/copilot-instructions.md` if needed, then generates spec + plan + tasks
3. Click **"Start Forge Loop (Auto)"** or **"Start Forge Loop (HITL)"** handoff → Forge implements everything with QA gates

## File Structure (generated per feature)

```
tasks/
├── my-feature/
│   ├── prd.md                       # Product Requirements Document
│   ├── 00-context.md                # Shared project context for coders
│   ├── 01.specification.md          # Technical specification
│   ├── 02.plan.md                   # Implementation plan
│   ├── 03-tasks-phase1-01.md        # Task files (one per task)
│   ├── 03-tasks-phase1-02.md
│   ├── 03-tasks-phase2-03.md
│   ├── 03-tasks-phase2-04.md
│   ├── PROGRESS.md                  # Progress tracker
│   └── PAUSE.md                     # (optional) Halts the loop
└── _archive/                        # Archived completed features
    └── old-feature/
        └── ...
```

## Controlling the Loop

- **Pause**: Create a `PAUSE.md` file in the feature folder to halt Forge mid-loop. Remove it to resume.
- **HITL mode**: Use the "Start Forge Loop (HITL)" handoff from the plan agent, or the "Human-in-the-Loop Forge Loop" self-handoff to get phase validation pauses.
- **Edit mid-flight**: Pause the loop, edit task files or PROGRESS.md, then remove PAUSE.md to resume.
- **Feature branches**: Forge commits on whichever branch you are on. Check out your feature branch before starting the loop.

## Safety & Error Handling

- **Circuit breaker**: If a task fails inspection 3 consecutive times, Forge automatically creates `PAUSE.md` and halts the loop for human intervention.
- **Subagent failure**: If a subagent call fails (rate limit, tool unavailable, crash), Forge retries once. If it fails again, it creates `PAUSE.md` and pauses.
- **Commit amend for rework**: When the coder reworks a 🔴 Incomplete task, it uses `git commit --amend` to update the previous commit rather than creating a new one.

## Quality Assurance

Forge includes a four-tier QA system:

| Tier | Agent | When | Scope |
|------|-------|------|-------|
| 1 | Coder | Before marking any task complete | Preflight checks + wiring verification for consumer-facing features |
| 2 | Task Inspector | After each task completion | Acceptance criteria, test coverage, reachability audit |
| 3 | Phase Inspector | After all tasks in a phase complete | Cross-task integration, phase-level reachability, gaps, side effects |
| 4 | Journey Verifier | After all phases complete | Traces every PRD user story to a reachable entry point |

When a task fails inspection, it's marked 🔴 Incomplete with structured feedback prepended to the task file. The coder picks it up as highest priority in the next iteration.

### Reachability Audits

A recurring theme across tiers 1–4 is **reachability verification** — ensuring features aren't just implemented but are actually accessible to consumers:

- **UI apps**: Routes registered, navigation links present, pages reachable from main entry point
- **APIs**: Endpoints mounted on the router and responding to requests
- **CLI tools**: Commands registered and appearing in help output
- **Libraries**: Modules exported from the public API

This prevents the common AI-agent failure mode where every unit test passes but users can't actually reach the new features.

### Knowledge Transfer

The plan agent seeds initial learnings from its codebase research into the `## Learnings` section of `PROGRESS.md`, and generates a `00-context.md` file containing project conventions, architecture decisions, testing patterns, and existing utilities. Every coder subagent reads `00-context.md` before starting any task, and the orchestrator passes the accumulated `## Learnings` to every coder dispatch. After completing each task, the Coder subagent records any new reusable patterns or gotchas it discovered, so knowledge compounds across the implementation loop — similar to the "Codebase Patterns" approach in [snarktank/ralph](https://github.com/snarktank/ralph).

## Requirements

- VS Code with GitHub Copilot (agent mode)
- Custom agents support (VS Code 1.106+)
- **Optional**: `chrome-devtools` MCP server for runtime browser verification in the Journey Verifier (UI/Frontend projects only). Without it, the Journey Verifier falls back to static-only reachability analysis. See [Chrome DevTools MCP Setup](#chrome-devtools-mcp-setup-optional).

## Key Enhancements

1. **Multi-agent architecture** — Separating orchestration, coding, and inspection into distinct subagents prevents the common failure mode where a single agent marks its own work as complete without proper verification.

2. **Phased execution with enforced boundaries** — Instead of a flat story list, work is organized into phases with exit criteria. Phase Inspector validates cross-task integration at each boundary before proceeding, catching issues that per-task checks miss.

3. **Four-tier QA pipeline** — Adds Task Inspector (per-task review), Phase Inspector (per-phase integration review), and Journey Verifier (final end-to-end reachability audit) on top of the standard preflight checks. Tiers 2–3 are static code analysis (reading source files to trace routes, exports, and registrations). Tier 4 (Journey Verifier) combines static reachability analysis with **runtime browser verification** via the `chrome-devtools` MCP server for UI/Frontend projects — navigating pages, checking for console errors, verifying DOM structure, and capturing screenshots. This addresses the common AI-agent failure mode of building features that pass unit tests but aren’t wired into the application or fail at runtime.

4. **Structured planning stage** — The plan agent produces a technical specification, phased implementation plan, and individual task files with file-level guidance. snarktank/ralph converts PRDs to a flat JSON story list with dependency-aware priority ordering. ralph-wiggum has no planning stage by design — it delegates task structure entirely to the user's prompt, trading planning overhead for simplicity.

5. **Human-in-the-loop mode** — Built-in HITL support with validation pauses at phase boundaries, useful for work requiring stakeholder review or compliance gates.

6. **Project-type-aware reachability audits** — Verification checks adapt to the project type (UI navigation, API endpoint mounting, CLI command registration, library public exports) across all QA tiers.

7. **Auto-detection of project configuration** — Reads manifest files to detect the tech stack and pre-populate `.github/copilot-instructions.md`, reducing manual setup compared to snarktank/ralph's manual configuration.

8. **Pause/resume mechanism** — `PAUSE.md` allows safely editing task files or the progress tracker mid-flight without racing the loop, more granular than killing a bash process.

9. **Circuit breaker with structured feedback** — After 3 consecutive inspection failures, the loop auto-pauses with specific feedback rather than silently consuming iterations. Inspector feedback is prepended to task files so the coder sees exactly what failed.

10. **Native VS Code integration** — Runs entirely within VS Code Copilot's agent mode with handoffs between agents, rather than requiring a terminal, external bash scripts, or Claude Code plugins.

11. **Shared coder context (`00-context.md`)** — The plan agent generates a shared context file containing project conventions, architecture decisions, testing patterns, and existing utilities. Every coder subagent reads this before starting any task, ensuring consistent behavior without duplicating context across individual task files.

12. **Adaptive interview depth** — The PRD agent automatically scales its questioning based on feature complexity. Simple features get 3-5 quick questions; complex multi-system features trigger 8-12 questions across two rounds to surface ambiguities, edge cases, and integration concerns before planning begins.

13. **Iteration tracking** — `PROGRESS.md` tracks the number of coder attempts per task via an `Iterations` column. Combined with the circuit breaker, this gives visibility into which tasks are churning and where the agent is spending tokens.

14. **Knowledge accumulation** — The plan agent seeds initial learnings from codebase research into `PROGRESS.md`. The orchestrator passes these learnings (plus runtime discoveries from previous coders) to every subsequent coder dispatch, so knowledge compounds across the implementation loop rather than being lost between subagent calls.

## Comparison with Other Implementations

This project was originally inspired by the Ralph pattern ([Geoffrey Huntley](https://ghuntley.com/ralph/)) but has diverged significantly — adding multi-agent orchestration, phased execution with enforced boundaries, a four-tier QA pipeline, structured planning, and feature archiving. The core loop-until-done idea remains, but the architecture and quality model are substantially different. Below is a comparison with [snarktank/ralph](https://github.com/snarktank/ralph) (the original open-source implementation for Amp / Claude Code) and [anthropics/ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) (the official Claude Code plugin).

### Architecture

| | snarktank/ralph | anthropics/ralph-wiggum | Forge (this project) |
|---|---|---|---|
| **Target** | Amp CLI / Claude Code (+ Claude Code marketplace plugin) | Claude Code (plugin) | VS Code Copilot (agent mode) |
| **Loop mechanism** | External bash script (`ralph.sh`) spawning fresh instances per iteration | Stop hook intercepting session exit; prompt replayed automatically | In-process orchestration via Copilot subagents |
| **Context model** | Fresh context per iteration — memory via git + `progress.txt` + `prd.json`; Amp supports auto-handoff when context fills up | Persistent session — files and git survive between iterations; prompt never changes | Persistent session — shared context within Copilot chat |
| **Task format** | `prd.json` (JSON with `passes: true/false` per story) | Free-form prompt text (user-structured) | Structured markdown files (`03-tasks-*.md`) grouped by phase |
| **Stop condition** | `<promise>COMPLETE</promise>` in output | `--completion-promise` flag with exact string match | All tasks ✅ in `PROGRESS.md` + Journey Verifier PASS |
| **Agent count** | 1 (single agent does everything) | 1 (single agent loop) | 4 pipeline agents (PRD, Plan, Loop, Archive) + 4 specialized subagents within the loop |

### Planning & Decomposition

| | snarktank/ralph | anthropics/ralph-wiggum | Forge |
|---|---|---|---|
| **PRD generation** | Skill-based PRD → saves to `tasks/prd-{feature}.md` | None (user provides the prompt) | Dedicated PRD agent with clarifying questions and project-state detection |
| **Plan decomposition** | Skill converts PRD to dependency-ordered JSON user stories (priority field guides execution order) | None — by design, the user structures work in their prompt; phases can be described but aren't enforced | Dedicated plan agent producing specification + phased plan + individual task files + progress tracker |
| **Task granularity** | Flat list of user stories ordered by priority | Single prompt covering all work | Hierarchical: phases → tasks → acceptance criteria, with dependency tracking and file-level guidance |
| **Tech stack detection** | Manual `AGENTS.md` / `CLAUDE.md` setup | None | Auto-detects from manifest files (`package.json`, `Cargo.toml`, etc.) and offers to populate `.github/copilot-instructions.md` |

### Quality Assurance

| | snarktank/ralph | anthropics/ralph-wiggum | Forge |
|---|---|---|---|
| **QA tiers** | 1 (coding agent runs quality checks) | 1 (self-correction via tests/linters) | 4 (Coder preflight → Task Inspector → Phase Inspector → Journey Verifier) |
| **Dedicated inspector** | No — same agent implements and verifies | No — same agent self-corrects | Yes — separate Task Inspector and Phase Inspector subagents review each task and phase independently |
| **Reachability audits** | Runtime browser verification via `dev-browser` skill (UI only) | Not built in | Static code analysis verifying features are wired into entry points (routes for UI, endpoint registration for APIs, command registration for CLIs, public exports for libraries) + **runtime browser verification** via `chrome-devtools` MCP for UI/Frontend projects (navigates pages, checks console errors, verifies DOM, captures screenshots). Falls back to static-only if MCP is unavailable |
| **Circuit breaker** | Max iterations on the bash loop (default: 10) | `--max-iterations` flag (default: unlimited) | Auto-pause (`PAUSE.md`) after 3 consecutive inspection failures on the same task |
| **Browser verification** | `dev-browser` skill for runtime visual UI checks (loads pages, interacts with UI, takes screenshots) | Not built in | Runtime browser verification via `chrome-devtools` MCP server — navigates routes, checks for JS console errors, verifies DOM structure via accessibility snapshots, and captures screenshots. Requires MCP server configuration; gracefully degrades to static-only reachability analysis if unavailable |

### Orchestration & Control

| | snarktank/ralph | anthropics/ralph-wiggum | Forge |
|---|---|---|---|
| **Human-in-the-loop** | Not built in | Not built in | Built-in HITL mode — pauses at phase boundaries for human validation |
| **Pause mechanism** | Kill the bash script | `/cancel-ralph` command | Create `PAUSE.md` to halt mid-loop; remove to resume |
| **Phase enforcement** | No enforced phases — flat story list ordered by `priority` field (dependency ordering is guided by the PRD skill but not structurally enforced) | No phases (can be described in prompt but aren't enforced) | Enforced — all tasks in a phase must complete before the next phase begins |
| **Role separation** | Single agent writes code and manages state | Single agent does everything | Strict — orchestrator never writes code; Coder subagent never chooses which task to skip; inspectors never implement fixes |
| **Task selection** | Agent picks highest-priority `passes: false` story | Agent decides what to work on | Coder subagent autonomously selects (orchestrator forbidden from recommending) |
| **Commit strategy** | One commit per story | Up to the agent | `git commit --amend` for rework iterations; conventional commits for new tasks |
| **Knowledge transfer** | `progress.txt` Codebase Patterns section + per-directory `AGENTS.md` updates | File changes persist in session | `00-context.md` shared context file (plan-seeded) + `## Learnings` section in `PROGRESS.md` passed to subsequent coder iterations |
| **Archiving** | Automatic — archives to `archive/YYYY-MM-DD-feature/` when branch changes | Not built in | Manual via `/forge-archive` command or **Archive Feature** handoff; stale-feature warnings in plan agent |

### Trade-offs

- **Token usage** — The multi-agent approach with 4 QA tiers consumes roughly 4–6x more tokens per feature than snarktank/ralph and ~20x more than ralph-wiggum. Each task requires at minimum 2 subagent calls (coder + task inspector), with additional phase inspector calls at boundaries and a journey verifier call at the end. Subagent instruction files are re-read from disk every iteration, further increasing per-iteration cost.
- **No fresh context** — snarktank/ralph's fresh-instance-per-iteration model avoids context window exhaustion on large projects. Amp's auto-handoff feature (`autoHandoff` at 90% context) further mitigates this. Forge runs within a single Copilot session, which can hit context limits on long runs.
- **Runtime browser verification requires MCP setup** — Forge’s Journey Verifier can perform runtime browser checks (navigating pages, inspecting console errors, verifying DOM structure) via the `chrome-devtools` MCP server, but this requires the MCP server to be configured and running. Without it, the Journey Verifier falls back to static-only reachability analysis. snarktank/ralph’s `dev-browser` skill works out of the box for Amp/Claude Code users. See the [Chrome DevTools MCP Setup](#chrome-devtools-mcp-setup-optional) section for configuration instructions.
- **Manual archiving** — snarktank/ralph auto-archives to `archive/YYYY-MM-DD-feature/` whenever the branch changes. Forge requires the user to explicitly run `/forge-archive` or use the **Archive Feature** handoff — but the plan agent warns about stale completed features to prompt archiving.
- **Platform lock-in** — snarktank/ralph works with Amp and Claude Code (including marketplace plugin support); ralph-wiggum works with Claude Code. Forge requires VS Code with GitHub Copilot agent mode.

## Chrome DevTools MCP Setup (Optional)

The Journey Verifier can perform **runtime browser verification** for UI/Frontend projects using the `chrome-devtools` MCP server. This is optional — without it, the Journey Verifier falls back to static-only reachability analysis.

### What it enables

When configured, the Journey Verifier will:
- Navigate to each route identified during static analysis in a real browser
- Check for JavaScript console errors (runtime crashes, failed imports, missing data)
- Verify DOM structure via accessibility snapshots (expected elements present)
- Capture screenshots as verification artifacts
- Inspect network requests for failed API calls

This closes the gap with snarktank/ralph's `dev-browser` skill — catching runtime errors that static code analysis cannot detect.

### Configuration

Add the `chrome-devtools` MCP server to your VS Code settings (`.vscode/settings.json` or User Settings):

```json
{
  "mcp": {
    "servers": {
      "chrome-devtools": {
        "command": "npx",
        "args": ["-y", "@anthropic-ai/chrome-devtools-mcp@latest"]
      }
    }
  }
}
```

Alternatively, add it to a `.vscode/mcp.json` file in your project:

```json
{
  "servers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/chrome-devtools-mcp@latest"]
    }
  }
}
```

### Requirements

- **Node.js** must be installed (for `npx`)
- **Google Chrome** or **Chromium** must be installed on the system
- The MCP server launches a headless Chrome instance automatically

### Verification

After configuring, you can verify the MCP server is working by:
1. Opening the VS Code Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`)
2. Running **"MCP: List Servers"** — `chrome-devtools` should appear and show as running
3. The Journey Verifier will automatically detect and use it when dispatched

If the MCP server is not configured or not running, the Journey Verifier will log a note in its report and proceed with static-only verification — no action needed.

## Acknowledgements

- Based on [snarktank/ralph](https://github.com/snarktank/ralph/tree/main) — the original Ralph agent pipeline
- Plugin reference: [anthropics/ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) — Claude Code's official Ralph plugin
- Original concept by [Geoffrey Huntley](https://ghuntley.com/ralph/)
- Inspired by gist from [@gsemet](https://gist.github.com/gsemet)