---
name: plan-decomposition
description: "Decompose a Product Requirements Document into technical specification, implementation plan, and phased task files. Use when breaking down a PRD, planning implementation phases, or creating task files for execution. Triggers on: decompose prd, plan implementation, break down feature, create tasks from prd, plan mode."
---

# Plan Decomposition Skill

Take a PRD and produce the structured artifacts needed for iterative implementation: a technical specification, a phased implementation plan, and individual task files.

---

## The Job

1. Receive a PRD (from file or handoff)
2. Research the existing codebase for context
3. Generate `01.specification.md` — technical spec
4. Generate `02.plan.md` — phased implementation plan
5. Generate `03-tasks-phase{N}-{NN}.md` — one file per task
6. Generate `PROGRESS.md` — progress tracker
7. Present summary for human review

**Important:** Do NOT implement any code. Only produce planning artifacts.

---

## Codebase Research Checklist

Before generating any artifacts, gather this context:

- [ ] Read the full PRD
- [ ] Read `AGENTS.md` or `CONSTITUTION.md` if present (for project conventions and preflight commands)
- [ ] Identify the tech stack (languages, frameworks, build tools)
- [ ] Map the project directory structure
- [ ] Find existing code related to the feature
- [ ] Identify test patterns (framework, file naming, coverage approach)
- [ ] Identify existing components/utilities that can be reused
- [ ] Note any CI/CD or build constraints

---

## Specification Template (`01.specification.md`)

```markdown
# Specification: {Feature Name}

## Overview
Brief technical summary of what will be built.

## Source PRD
`tasks/{feature-name}/prd.md`

## Technical Context
- Relevant architecture description
- Existing code/components to modify or reuse
- Technical constraints or dependencies

## Detailed Requirements

### SR-001: {Title}
**From**: US-001, FR-1
**Description**: What must be implemented, technically.
**Acceptance Criteria**:
- [ ] Testable criterion
**Files to Modify/Create**:
- `path/to/file` — changes needed
**Dependencies**: None | SR-XXX
**Complexity**: Low | Medium | High

## API Changes
(if applicable — new/modified endpoints, request/response schemas)

## Data Model Changes
(if applicable — new tables, columns, migrations)

## Non-Goals
(carried forward from PRD)
```

### Specification Guidelines

- Each SR should map to one or more PRD user stories (US-*) or functional requirements (FR-*)
- Group related requirements — one SR can cover multiple FRs if they're tightly coupled
- Be specific about files to modify — the coder shouldn't have to search
- Complexity ratings: **Low** = straightforward, known pattern; **Medium** = requires some design decisions; **High** = significant new code or complex logic
- Always include non-goals to prevent scope creep

---

## Plan Template (`02.plan.md`)

```markdown
# Implementation Plan: {Feature Name}

**Branch**: `feature/{feature-name-kebab-case}`

## Architecture Overview
How this feature fits into the existing system.

## Phase Breakdown

### Phase 1: {Name} (e.g., "Data Layer")
**Goal**: What this phase delivers.
**Tasks**:
1. Task 01 — {title} (SR-001) [Low]
2. Task 02 — {title} (SR-002) [Medium]
**Phase Exit Criteria**:
- [ ] Criterion for phase completion

### Phase 2: {Name} (e.g., "Core Logic")
**Goal**: ...
**Tasks**:
3. Task 03 — {title} (SR-003) [Medium]
**Phase Exit Criteria**:
- [ ] Criterion

## Dependency Graph
Which tasks depend on which others.

## Risks & Considerations
Known unknowns and deferred decisions.
```

**Branch naming:** Derive the branch name from the feature name in kebab-case, prefixed with `feature/`. Example: "User Notification System" → `feature/user-notification-system`. This must match in both `02.plan.md` and `PROGRESS.md`.

### Phase Design Rules

1. **Vertical slices over horizontal layers**: Each phase MUST deliver a vertical slice — data + logic + user-facing wiring. A phase that only adds backend plumbing without any user-visible change is strongly discouraged. If backend-only work is necessary, it must be followed within the same phase by a task that exposes it to the user (route, menu item, UI component). Avoid the anti-pattern of "Foundation → Core logic → Integration → UI/polish" where all user-facing wiring is deferred to the last phase.
2. **Size**: 2-5 tasks per phase. If >5, split the phase.
3. **Increment**: Each phase MUST produce a user-facing, testable, demonstrable increment — not just passing unit tests, but something a user can navigate to and interact with.
4. **Exit criteria**: Should be verifiable AND include reachability ("user can navigate to feature X from the main menu", not just "tests pass").
5. **Total scope**: 4-12 tasks for a typical feature. 12-20 for large features. If >20, the PRD scope is too large — suggest splitting.
6. **Wiring task**: Any phase that introduces user-facing features MUST include a final task that wires features into the application's navigation, routing, or entry points. This task ensures nothing is built but unreachable.

---

## Task File Template (`03-tasks-phase{N}-{NN}.md`)

Filename pattern: `03-tasks-phase1-01.md`, `03-tasks-phase1-02.md`, `03-tasks-phase2-03.md`

Task numbers are globally unique and sequential across phases.

```markdown
# Task {NN}: {Title}

**Phase**: {N} — {Phase Name}
**Specification Refs**: SR-001, SR-002
**Complexity**: Low | Medium | High
**Dependencies**: Task 01 | None

## Description

Clear description of what to implement. A senior engineer unfamiliar with the
spec should be able to understand the scope from this section alone.

## Acceptance Criteria

- [ ] Specific, verifiable criterion
- [ ] Another criterion
- [ ] Unit tests added covering new functionality
- [ ] Typecheck / lint passes
- [ ] Preflight checks pass

## Files to Create or Modify

- `path/to/file.ext` — what to change and why
- `path/to/test.ext` — test file to create or update

## Implementation Notes

Practical guidance: patterns to follow, existing code to reference, edge cases
to handle, gotchas, or relevant documentation links.
```

### Task Design Rules

1. **One session**: Each task should be completable by one coder agent call (15-60 min of focused work)
2. **Verifiable**: Every acceptance criterion must be testable — no "works correctly"
3. **Self-contained context**: Include enough detail that the coder doesn't need to read the full spec to start
4. **Always require tests**: Include "Unit tests added" and "Preflight passes" as criteria
5. **File-explicit**: List exact files to create/modify — this dramatically improves coder accuracy
6. **UI tasks**: Always include "Verify visually in browser" as a criterion for front-end changes
7. **No orphans**: Every task must trace back to at least one specification requirement (SR-*)
8. **Wiring required**: Any task that adds user-facing features MUST include an acceptance criterion: "Feature is reachable by a user through the application's existing navigation/routing" — not just "component renders in isolation" or "unit tests pass". If the task adds a page, verify the route is registered AND a navigation link exists.

---

## Progress File Template (`PROGRESS.md`)

Use the Ralph-compatible format:

```markdown
# Progress Tracker: {Feature Name}

**Epic**: {identifier}
**Branch**: `feature/{feature-name-kebab-case}`
**Started**: {YYYY-MM-DD}
**Last Updated**: {YYYY-MM-DD}
**HITL Mode**: false
**Current Phase**: Phase 1

---

## Task Progress by Phase

### Phase 1: {Phase Name}

| Task | Title | Status | Inspector Notes |
|------|-------|--------|-----------------|
| 01 | {title} | ⬜ Not Started | |
| 02 | {title} | ⬜ Not Started | |

**Phase Status**: ⬜ Not Started

---

## Status Legend

- ⬜ Not Started
- 🔄 In Progress
- ✅ Completed (verified by Task Inspector)
- 🔴 Incomplete (Inspector or Phase Reviewer identified gaps/issues)
- ⏸️ Skipped

---

## Completion Summary

- **Total Tasks**: {N}
- **Completed**: 0
- **Incomplete**: 0
- **In Progress**: 0
- **Remaining**: {N}

---

## Phase Validation (HITL & Audit Trail)

| Phase | Completed | Phase Inspector Report | Validated By | Validation Date | Status |
|-------|-----------|------------------------|--------------|-----------------|--------|
| Phase 1 | ⬜ | (pending) | (pending) | (pending) | Not Started |

---

## Change Log

| Date | Task | Action | Agent | Details |
|------|------|--------|-------|---------|
| {YYYY-MM-DD} | - | Progress file created | Ralph Plan Mode | Initial setup |
```

---

## Traceability Matrix

Every artifact should trace back to the PRD:

```
PRD User Story (US-001) → Spec Requirement (SR-001) → Plan Task (Task 01) → Task File (03-tasks-phase1-01.md) → PROGRESS.md row
```

Before finalizing, verify:
- [ ] Every US from the PRD has at least one SR
- [ ] Every SR maps to at least one task
- [ ] Every task has a task file with clear acceptance criteria
- [ ] PROGRESS.md includes all tasks
- [ ] Phase ordering respects dependencies

---

## Checklist

Before presenting the plan to the user:

- [ ] Codebase research was done (not just reading the PRD)
- [ ] Specification maps all PRD requirements
- [ ] Plan has well-sized phases (2-5 tasks each)
- [ ] Each phase delivers a vertical slice with user-facing output (not just backend plumbing)
- [ ] Every phase with user-facing features includes a wiring/integration task ensuring features are navigable
- [ ] Task files are specific enough for a coder to implement
- [ ] Acceptance criteria are verifiable, not vague
- [ ] User-facing tasks include reachability criteria ("feature accessible from main navigation")
- [ ] Every task lists specific files to modify
- [ ] Dependencies between tasks are documented
- [ ] PROGRESS.md is populated and correctly formatted
- [ ] Total task count is reasonable (4-20)
- [ ] Summary is ready for human review
