# Ralph — Iterative AI Implementation Agent for VS Code Copilot

> **🚧 Work in Progress** — Agent instructions, QA tiers, and loop behavior may change between versions.

> **⚠️ Token Usage:** A full pipeline run consumes roughly **4–6x** the tokens of single-agent Ralph implementations. Use a strong model (Claude Sonnet 4, GPT-4.1) for **PRD, Plan, and Coder** stages where reasoning quality matters. Use a cheaper model (GPT-4.1 mini, etc.) for the **orchestrator and inspectors**, which only read state and review code.

Ralph is a three-stage AI agent pipeline for VS Code Copilot that takes a feature idea from requirements through to a fully implemented solution with quality gates.

## Pipeline

```
┌─────────┐     ┌──────────────────┐     ┌─────────────────────────────────┐     ┌─────────────────┐
│   PRD   │ ──▶ │ Ralph Plan       │ ──▶ │ Ralph Loop                      │ ──▶ │ Ralph Archive   │
│  Agent  │     │ Mode             │     │ (orchestration + implementation) │     │ (optional)      │
└─────────┘     └──────────────────┘     └─────────────────────────────────┘     └─────────────────┘
 Generates       Decomposes PRD into      Iterates through tasks with             Moves completed
 requirements    spec + plan + tasks      Coder / Inspector / Journey QA          feature to _archive/
```

### Stage 1: PRD Agent (`prd`)
Generates a Product Requirements Document from a feature description. Detects the project state (greenfield vs existing codebase) to ask better clarifying questions, then produces a structured PRD with user stories, functional requirements, and acceptance criteria.

### Stage 2: Ralph Plan Mode (`ralph-plan`)
Detects whether `.github/copilot-instructions.md` is configured — if not, auto-detects the tech stack from manifest files and offers to populate it. Warns if completed features in `tasks/` haven't been archived yet. Then takes a PRD and decomposes it into:
- **`01.specification.md`** — Technical specification with detailed requirements
- **`02.plan.md`** — Phased implementation plan with dependency ordering
- **`03-tasks-*.md`** — Individual task files with acceptance criteria
- **`PROGRESS.md`** — Progress tracker for the Ralph loop

### Stage 3: Ralph Loop (`ralph-loop`)
Iteratively implements each task using subagents:
- **Coder subagent** — Autonomously selects and implements one task at a time, runs preflight checks, verifies feature wiring, records learnings, and commits
- **Task Inspector** — Verifies each completed task against acceptance criteria and reachability
- **Phase Inspector** — Validates entire phases at phase boundaries including cross-task integration and reachability audits
- **Journey Verifier** — Final gate that traces every user story from the PRD to a reachable entry point before the loop exits

The orchestrator never writes application code — it only dispatches subagents and tracks progress via `PROGRESS.md`.

Supports two modes:
- **Auto** — Runs through all tasks autonomously
- **HITL (Human-in-the-Loop)** — Pauses at phase boundaries for human validation

### Stage 4: Ralph Archive (`ralph-archive`) — optional
Moves a completed feature folder from `tasks/{feature}/` to `tasks/_archive/{feature}/`. Validates that all tasks are ✅ before archiving (warns if incomplete). Available via the **Archive Feature** handoff at loop exit or the `/ralph-archive` slash command at any time.

## Setup

### 1. Install

Copy the `.github/` folder into your project's root:

```
your-project/
├── .github/
│   ├── agents/                      # Custom agents (auto-detected by Copilot)
│   │   ├── prd.agent.md
│   │   ├── ralph-archive.agent.md
│   │   ├── ralph-plan.agent.md
│   │   ├── ralph.agent.md
│   │   └── instructions/            # Extracted subagent instruction files
│   │       ├── coder.md
│   │       ├── task-inspector.md
│   │       ├── phase-inspector.md
│   │       └── journey-verifier.md
│   ├── copilot-instructions.md      # ← customize this (project config + preflight)
│   └── prompts/                     # Slash commands (/prd, /plan, /ralph-archive)
│       ├── plan.prompt.md
│       ├── prd.prompt.md
│       └── ralph-archive.prompt.md
└── ...
```

### 2. Configure project context

Ralph uses a single **`.github/copilot-instructions.md`** file for all configuration — tech stack, coding standards, preflight commands, conventions, and agent workflow notes.

`.github/copilot-instructions.md` is **natively auto-loaded** by VS Code Copilot ([docs](https://code.visualstudio.com/docs/copilot/customization/custom-instructions#_use-a-githubcopilot-instructionsmd-file)), so its contents are included in every chat request with no extra setup.

You can configure it in two ways:

**Option A: Let the agents detect it.** If you leave `.github/copilot-instructions.md` unconfigured (with its `TODO` markers), the plan agent will auto-detect your tech stack from manifest files (`package.json`, `Cargo.toml`, etc.) and offer to populate it before planning. The PRD agent also adapts its questions based on detected project state.

**Option B: Fill it in manually.** Open `.github/copilot-instructions.md` and replace the `TODO` markers with your project's values:

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
| **prd** | Generate a PRD from a feature description |
| **ralph-plan** | Decompose a PRD into spec/plan/tasks |
| **ralph-loop** | Execute the implementation loop |
| **ralph-archive** | Archive a completed feature folder to `tasks/_archive/` |

Or use prompt commands:
- `/prd` — Quick PRD generation
- `/plan` — Quick plan decomposition
- `/ralph-archive` — Archive a completed feature folder

### Typical Workflow

1. Select the **prd** agent → describe your feature → answer clarifying questions → PRD is saved
2. Click **"Decompose into Plan"** handoff → plan agent configures `.github/copilot-instructions.md` if needed, then generates spec + plan + tasks
3. Click **"Start Ralph Loop (Auto)"** or **"Start Ralph Loop (HITL)"** handoff → Ralph implements everything with QA gates

## File Structure (generated per feature)

```
tasks/
├── my-feature/
│   ├── prd.md                       # Product Requirements Document
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

- **Pause**: Create a `PAUSE.md` file in the feature folder to halt Ralph mid-loop. Remove it to resume.
- **HITL mode**: Use the "Start Ralph Loop (HITL)" handoff from the plan agent, or the "Human-in-the-Loop Ralph Loop" self-handoff to get phase validation pauses.
- **Edit mid-flight**: Pause the loop, edit task files or PROGRESS.md, then remove PAUSE.md to resume.
- **Feature branches**: Ralph commits on whichever branch you are on. Check out your feature branch before starting the loop.

## Safety & Error Handling

- **Circuit breaker**: If a task fails inspection 3 consecutive times, Ralph automatically creates `PAUSE.md` and halts the loop for human intervention.
- **Subagent failure**: If a subagent call fails (rate limit, tool unavailable, crash), Ralph retries once. If it fails again, it creates `PAUSE.md` and pauses.
- **Commit amend for rework**: When the coder reworks a 🔴 Incomplete task, it uses `git commit --amend` to update the previous commit rather than creating a new one.

## Quality Assurance

Ralph includes a four-tier QA system:

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

After completing each task, the Coder subagent records any reusable patterns, gotchas, or conventions it discovered in the `## Learnings` section of `PROGRESS.md`. The orchestrator passes these learnings to subsequent coder iterations, so knowledge accumulates across the implementation loop — similar to the "Codebase Patterns" approach in [snarktank/ralph](https://github.com/snarktank/ralph).

## Requirements

- VS Code with GitHub Copilot (agent mode)
- Custom agents support (VS Code 1.106+)

## Comparison with Other Ralph Implementations

This project was originally inspired by the Ralph pattern ([Geoffrey Huntley](https://ghuntley.com/ralph/)) but has diverged significantly — adding multi-agent orchestration, phased execution with enforced boundaries, a four-tier QA pipeline, structured planning, and feature archiving. The core loop-until-done idea remains, but the architecture and quality model are substantially different. Below is a comparison with [snarktank/ralph](https://github.com/snarktank/ralph) (the original open-source implementation for Amp / Claude Code) and [anthropics/ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) (the official Claude Code plugin).

### Architecture

| | snarktank/ralph | anthropics/ralph-wiggum | ralph-copilot (this project) |
|---|---|---|---|
| **Target** | Amp CLI / Claude Code | Claude Code (plugin) | VS Code Copilot (agent mode) |
| **Loop mechanism** | External bash script (`ralph.sh`) spawning fresh instances | Stop hook intercepting session exit | In-process orchestration via Copilot subagents |
| **Context model** | Fresh context per iteration — memory via git + `progress.txt` | Persistent session — files and git survive between iterations | Persistent session — shared context within Copilot chat |
| **Task format** | `prd.json` (JSON with `passes: true/false` per story) | Free-form prompt text | Structured markdown files (`03-tasks-*.md`) grouped by phase |
| **Stop condition** | `<promise>COMPLETE</promise>` in output | `--completion-promise` flag with `<promise>` tag | All tasks ✅ in `PROGRESS.md` + Journey Verifier PASS |
| **Agent count** | 1 (single agent does everything) | 1 (single agent loop) | 5 (orchestrator + 4 specialized subagents) |

### Planning & Decomposition

| | snarktank/ralph | anthropics/ralph-wiggum | ralph-copilot |
|---|---|---|---|
| **PRD generation** | Skill-based PRD → saves markdown | None (user provides the prompt) | Dedicated PRD agent with clarifying questions and project-state detection |
| **Plan decomposition** | Skill converts PRD to dependency-ordered JSON user stories (priority field guides execution order) | None — by design, the user structures work in their prompt | Dedicated plan agent producing specification + phased plan + individual task files + progress tracker |
| **Task granularity** | Flat list of user stories ordered by priority | Single prompt covering all work | Hierarchical: phases → tasks → acceptance criteria, with dependency tracking and file-level guidance |
| **Tech stack detection** | Manual `AGENTS.md` / `CLAUDE.md` setup | None | Auto-detects from manifest files (`package.json`, `Cargo.toml`, etc.) and offers to populate `.github/copilot-instructions.md` |

### Quality Assurance

| | snarktank/ralph | anthropics/ralph-wiggum | ralph-copilot |
|---|---|---|---|
| **QA tiers** | 1 (coding agent runs quality checks) | 1 (self-correction via tests/linters) | 4 (Coder preflight → Task Inspector → Phase Inspector → Journey Verifier) |
| **Dedicated inspector** | No — same agent implements and verifies | No — same agent self-corrects | Yes — separate Task Inspector and Phase Inspector subagents review each task and phase independently |
| **Reachability audits** | Runtime browser verification via `dev-browser` skill (UI only) | Not built in | Static code analysis verifying features are wired into entry points (routes for UI, endpoint registration for APIs, command registration for CLIs, public exports for libraries) — does not start the application or verify at runtime |
| **Circuit breaker** | Max iterations on the bash loop | `--max-iterations` flag | Auto-pause (`PAUSE.md`) after 3 consecutive inspection failures on the same task |
| **Browser verification** | `dev-browser` skill for runtime visual UI checks (loads pages, interacts with UI, takes screenshots) | Not built in | Static reachability analysis only; runtime browser tooling is a [backlog item](TODO.md) |

### Orchestration & Control

| | snarktank/ralph | anthropics/ralph-wiggum | ralph-copilot |
|---|---|---|---|
| **Human-in-the-loop** | Not built in | Not built in | Built-in HITL mode — pauses at phase boundaries for human validation |
| **Pause mechanism** | Kill the bash script | `/cancel-ralph` command | Create `PAUSE.md` to halt mid-loop; remove to resume |
| **Phase enforcement** | No enforced phases — flat story list ordered by `priority` field (dependency ordering is guided by the PRD skill but not structurally enforced) | No phases (can be described in prompt but aren't enforced) | Enforced — all tasks in a phase must complete before the next phase begins |
| **Role separation** | Single agent writes code and manages state | Single agent does everything | Strict — orchestrator never writes code; Coder subagent never chooses which task to skip; inspectors never implement fixes |
| **Task selection** | Agent picks highest-priority `passes: false` story | Agent decides what to work on | Coder subagent autonomously selects (orchestrator forbidden from recommending) |
| **Commit strategy** | One commit per story | Up to the agent | `git commit --amend` for rework iterations; conventional commits for new tasks |
| **Knowledge transfer** | `progress.txt` Codebase Patterns section + per-directory `AGENTS.md` updates | File changes persist in session | `## Learnings` section in `PROGRESS.md` passed to subsequent coder iterations |
| **Archiving** | Automatic archive when branch changes | Not built in | Manual via `/archive` command or **Archive Feature** handoff; stale-feature warnings in plan agent |

### Key Enhancements in ralph-copilot

1. **Multi-agent architecture** — Separating orchestration, coding, and inspection into distinct subagents prevents the common failure mode where a single agent marks its own work as complete without proper verification.

2. **Phased execution with enforced boundaries** — Instead of a flat story list, work is organized into phases with exit criteria. Phase Inspector validates cross-task integration at each boundary before proceeding, catching issues that per-task checks miss.

3. **Four-tier QA pipeline** — Adds Task Inspector (per-task review), Phase Inspector (per-phase integration review), and Journey Verifier (final end-to-end reachability audit) on top of the standard preflight checks. Tiers 2–4 are static code analysis (reading source files to trace routes, exports, and registrations) rather than runtime verification. This addresses the common AI-agent failure mode of building features that pass unit tests but aren't wired into the application, though it cannot catch runtime errors that snarktank/ralph's `dev-browser` skill would.

4. **Structured planning stage** — The plan agent produces a technical specification, phased implementation plan, and individual task files with file-level guidance. snarktank/ralph converts PRDs to a flat JSON story list with dependency-aware priority ordering. ralph-wiggum has no planning stage by design — it delegates task structure entirely to the user's prompt, trading planning overhead for simplicity.

5. **Human-in-the-loop mode** — Built-in HITL support with validation pauses at phase boundaries, useful for work requiring stakeholder review or compliance gates.

6. **Project-type-aware reachability audits** — Verification checks adapt to the project type (UI navigation, API endpoint mounting, CLI command registration, library public exports) across all QA tiers.

7. **Auto-detection of project configuration** — Reads manifest files to detect the tech stack and pre-populate `.github/copilot-instructions.md`, reducing manual setup compared to snarktank/ralph's manual configuration.

8. **Pause/resume mechanism** — `PAUSE.md` allows safely editing task files or the progress tracker mid-flight without racing the loop, more granular than killing a bash process.

9. **Circuit breaker with structured feedback** — After 3 consecutive inspection failures, the loop auto-pauses with specific feedback rather than silently consuming iterations. Inspector feedback is prepended to task files so the coder sees exactly what failed.

10. **Native VS Code integration** — Runs entirely within VS Code Copilot's agent mode with handoffs between agents, rather than requiring a terminal, external bash scripts, or Claude Code plugins.

### Trade-offs

- **Token usage** — The multi-agent approach with 4 QA tiers consumes roughly 4–6x more tokens per feature than snarktank/ralph and ~20x more than ralph-wiggum. Each task requires at minimum 2 subagent calls (coder + task inspector), with additional phase inspector calls at boundaries and a journey verifier call at the end. Subagent instruction files are re-read from disk every iteration, further increasing per-iteration cost.
- **No fresh context** — snarktank/ralph's fresh-instance-per-iteration model avoids context window exhaustion on large projects. ralph-copilot runs within a single Copilot session, which can hit context limits on long runs.
- **No runtime browser verification** — snarktank/ralph includes a `dev-browser` skill that actually loads pages and interacts with UI at runtime. ralph-copilot's reachability audits are static code analysis only — they trace routes and exports by reading source files but never start the application. This means ralph-copilot can miss runtime errors, broken pages, or import cycles that snarktank/ralph would catch. Concrete browser tooling is a [backlog item](TODO.md).
- **No archiving** — snarktank/ralph auto-archives completed runs when the branch changes. ralph-copilot supports manual archiving via the `/ralph-archive` command or **Archive Feature** handoff — completed feature folders are moved to `tasks/_archive/`. The plan agent also warns when completed features haven't been archived yet.
- **Platform lock-in** — snarktank/ralph works with Amp and Claude Code; ralph-wiggum works with Claude Code. ralph-copilot requires VS Code with GitHub Copilot agent mode.

## Acknowledgements

- Based on [snarktank/ralph](https://github.com/snarktank/ralph/tree/main) — the original Ralph agent pipeline
- Plugin reference: [anthropics/ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) — Claude Code's official Ralph plugin
- Original concept by [Geoffrey Huntley](https://ghuntley.com/ralph/)