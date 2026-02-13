# Ralph — Iterative AI Implementation Agent for VS Code Copilot

> **⚠️ Warning:** Ralph orchestrates multiple AI agent stages that can consume a **significant amount of AI usage** (tokens/requests). A single pipeline run may involve many LLM calls across PRD generation, planning, and iterative implementation with quality-gate loops. Be mindful of your Copilot usage limits and costs before kicking off a full run & ensure you use the right model for the right agents.

Ralph is a three-stage AI agent pipeline for VS Code Copilot that takes a feature idea from requirements through to a fully implemented solution with quality gates.

## Pipeline

```
┌─────────┐     ┌──────────────────┐     ┌─────────────────────────────────┐
│   PRD   │ ──▶ │ Ralph Plan       │ ──▶ │ Ralph Loop                      │
│  Agent  │     │ Mode             │     │ (orchestration + implementation) │
└─────────┘     └──────────────────┘     └─────────────────────────────────┘
 Generates       Decomposes PRD into      Iterates through tasks with
 requirements    spec + plan + tasks      Coder / Inspector / Journey QA
```

### Stage 1: PRD Agent (`prd`)
Generates a Product Requirements Document from a feature description. Asks clarifying questions, then produces a structured PRD with user stories, functional requirements, and acceptance criteria.

### Stage 2: Ralph Plan Mode (`ralph-plan`)
Takes a PRD and decomposes it into:
- **`01.specification.md`** — Technical specification with detailed requirements
- **`02.plan.md`** — Phased implementation plan with dependency ordering
- **`03-tasks-*.md`** — Individual task files with acceptance criteria
- **`PROGRESS.md`** — Progress tracker for the Ralph loop

### Stage 3: Ralph Loop (`ralph-loop`)
Iteratively implements each task using subagents:
- **Coder subagent** — Autonomously selects and implements one task at a time, runs preflight checks, verifies feature wiring, commits
- **Task Inspector** — Verifies each completed task against acceptance criteria and reachability
- **Phase Inspector** — Validates entire phases at phase boundaries including cross-task integration and reachability audits
- **Journey Verifier** — Final gate that traces every user story from the PRD to a reachable entry point before the loop exits

The orchestrator never writes application code — it only dispatches subagents and tracks progress via `PROGRESS.md`.

Supports two modes:
- **Auto** — Runs through all tasks autonomously
- **HITL (Human-in-the-Loop)** — Pauses at phase boundaries for human validation

## Setup

### 1. Copy into your project

Copy the `.github/` folder and `AGENTS.md` into your project's root:

```
your-project/
├── .github/
│   ├── agents/                      # Custom agents (auto-detected by Copilot)
│   │   ├── prd.agent.md
│   │   ├── ralph-plan.agent.md
│   │   ├── ralph.agent.md
│   │   └── instructions/            # Extracted subagent instruction files
│   │       ├── coder.md
│   │       ├── task-inspector.md
│   │       ├── phase-inspector.md
│   │       └── journey-verifier.md
│   ├── prompts/                     # Slash commands (/prd, /plan)
│   │   ├── plan.prompt.md
│   │   └── prd.prompt.md
│   └── skills/                      # On-demand skill instructions
│       ├── plan/
│       │   └── SKILL.md
│       └── prd/
│           └── SKILL.md
├── AGENTS.md                        # ← customize this (project config + preflight)
└── ...
```

### 2. Configure project context

Ralph uses a single **`AGENTS.md`** file in the project root for all configuration — tech stack, coding standards, preflight commands, conventions, and agent workflow notes.

`AGENTS.md` is **auto-loaded** by VS Code Copilot ([docs](https://code.visualstudio.com/docs/copilot/customization/custom-instructions#_use-an-agentsmd-file)), so its contents are included in every chat request.

Open `AGENTS.md` and fill in the `TODO` markers with your project's values:

```markdown
## Preflight
\```bash
pnpm run lint && pnpm run typecheck && pnpm run test
\```

## Project Context
- **Language/Runtime**: TypeScript / Node.js 20
- **Framework**: Next.js 14 (App Router)
- **Testing**: Vitest
- **Package manager**: pnpm

## Coding Standards
- Use functional components with hooks (no class components)
- Prefer named exports over default exports

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

Or use prompt commands:
- `/prd` — Quick PRD generation
- `/plan` — Quick plan decomposition

### Typical Workflow

1. Select the **prd** agent → describe your feature → answer clarifying questions → PRD is saved
2. Click **"Decompose into Plan"** handoff → plan agent generates spec + plan + tasks
3. Click **"Start Ralph Loop"** handoff → Ralph implements everything with QA gates

## File Structure (generated per feature)

```
tasks/
└── my-feature/
    ├── prd.md                       # Product Requirements Document
    ├── 01.specification.md          # Technical specification
    ├── 02.plan.md                   # Implementation plan
    ├── 03-tasks-phase1-01.md        # Task files (one per task)
    ├── 03-tasks-phase1-02.md
    ├── 03-tasks-phase2-03.md
    ├── 03-tasks-phase2-04.md
    ├── PROGRESS.md                  # Progress tracker
    └── PAUSE.md                     # (optional) Halts the loop
```

## Controlling the Loop

- **Pause**: Create a `PAUSE.md` file in the feature folder to halt Ralph mid-loop. Remove it to resume.
- **HITL mode**: Use the "Human-in-the-Loop Ralph Loop" handoff to get phase validation pauses.
- **Edit mid-flight**: Pause the loop, edit task files or PROGRESS.md, then remove PAUSE.md to resume.
- **Feature branches**: Ralph automatically creates and checks out a `feature/{name}` branch derived from the plan. The branch name is stored in `PROGRESS.md` and verified at the start of every iteration.

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

## Acknowledgements

- Based on [snarktank/ralph](https://github.com/snarktank/ralph/tree/main) — the original Ralph agent pipeline
- Initial gist by [@gsemet](https://github.com/gsemet)
