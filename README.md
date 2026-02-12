# Ralph — Iterative AI Implementation Agent for VS Code Copilot

Ralph is a three-stage AI agent pipeline for VS Code Copilot that takes a feature idea from requirements through to a fully implemented solution with quality gates.

## Pipeline

```
┌─────────┐     ┌──────────────────┐     ┌────────────────────┐
│   PRD   │ ──▶ │ Ralph Plan       │ ──▶ │ Ralph Loop         │
│  Agent  │     │ Mode             │     │ (implementation)   │
└─────────┘     └──────────────────┘     └────────────────────┘
 Generates       Decomposes PRD into      Iterates through tasks
 requirements    spec + plan + tasks      with Coder/Inspector QA
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
- **Coder subagent** — Implements one task at a time, runs preflight checks, commits
- **Task Inspector** — Verifies each completed task against acceptance criteria
- **Phase Inspector** — Validates entire phases at phase boundaries

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
│   │   ├── ralph-plan.agent.md
│   │   ├── prd.agent.md
│   │   └── ralph.agent.md
│   ├── copilot-instructions.md      # ← create this (always-on Copilot context)
│   ├── prompts/                     # Slash commands (/prd, /plan)
│   │   ├── plan.prompt.md
│   │   └── prd.prompt.md
│   └── skills/                      # On-demand skill instructions
│       ├── plan/
│       │   └── SKILL.md
│       └── prd/
│           └── SKILL.md
├── AGENTS.md                        # ← customize (preflight + agent-specific config)
└── ...
```

### 2. Configure project context

Ralph uses **two configuration files**. They serve different purposes and are loaded differently:

#### `.github/copilot-instructions.md` — Always-on project context

This is a [VS Code Copilot custom instructions file](https://code.visualstudio.com/docs/copilot/customization/custom-instructions). Copilot **automatically includes** its contents in every chat request — you don't need to reference it from agent files.

Put your **tech stack, coding standards, and project conventions** here:

```markdown
# Project Instructions

## Tech Stack
- Language: TypeScript / Node.js 20
- Framework: Next.js 14 (App Router)
- Database: PostgreSQL with Prisma ORM
- Testing: Vitest
- Package manager: pnpm

## Coding Standards
- Use functional components with hooks (no class components)
- Prefer named exports over default exports
- All functions must have JSDoc comments
- Error handling: use Result types, not try/catch

## Project Structure
- src/app/       — Next.js routes and pages
- src/lib/       — Shared utilities and business logic
- src/components/ — React components
- prisma/        — Database schema and migrations
```

This context benefits **all** Copilot interactions (completions, chat, agents, inline edits), not just Ralph.

#### `AGENTS.md` — Agent-specific configuration

This file is read **explicitly by the Ralph subagents** during execution (via `read_file`). It is NOT auto-loaded by Copilot.

Put your **preflight commands and agent-specific workflow notes** here:

```markdown
## Preflight
\```bash
pnpm run lint && pnpm run typecheck && pnpm run test
\```

## Notes for AI Agents
- Always run preflight before marking a task complete
- Commit after each completed task with a conventional commit message
```

#### Why two files?

| File | Loaded by | When | What goes here |
|------|-----------|------|----------------|
| `.github/copilot-instructions.md` | Copilot (automatic) | Every chat/completion request | Tech stack, coding standards, conventions |
| `AGENTS.md` | Agents (explicit read) | During Ralph loop execution | Preflight commands, agent workflow rules |

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

## Quality Assurance

Ralph includes a three-tier QA system:

| Tier | Agent | When | Scope |
|------|-------|------|-------|
| 1 | Coder | Before marking any task complete | Preflight: types, lint, tests, build |
| 2 | Task Inspector | After each task completion | Per-task: acceptance criteria, test coverage |
| 3 | Phase Inspector | After all tasks in a phase complete | Phase-level: integration, gaps, side effects |

When a task fails inspection, it's marked 🔴 Incomplete with structured feedback prepended to the task file. The coder picks it up as highest priority in the next iteration.

## Requirements

- VS Code with GitHub Copilot (agent mode)
- Custom agents support (VS Code 1.106+)
