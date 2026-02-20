# Customizing Ralph for Your Company

A guide to adapting the Ralph agent pipeline so that every agent has the right internal context — your infrastructure patterns, libraries, conventions, and tooling — to implement features end-to-end without hand-holding.

---

## Overview

Ralph already has extension points designed for project-level customization (`AGENTS.md`, file-pattern instructions, and the agent markdown files themselves). Adapting it for a company means layering **organization-wide** context on top of these project-level hooks so the agents always know how to use your internal Terraform modules, email proxy, UI component library, backend frameworks, and so on.

The approach has three layers:

| Layer | Scope | Where it lives | Who maintains it |
|-------|-------|-----------------|------------------|
| **1. Company knowledge base** | Org-wide patterns, libraries, APIs | Shared instruction files + a dedicated internal docs repo | Platform / DevEx team |
| **2. Project configuration** | Per-repo tech stack, preflight, conventions | `AGENTS.md` + file-pattern instructions in each repo | Each project team |
| **3. Agent customization** | Modified agent prompts referencing internal context | `.github/agents/*.agent.md` in each repo (or a shared fork) | Platform / DevEx team |

---

## Layer 1: Company Knowledge Base

This is the foundation. Before touching any agent prompts, centralize the internal context the agents need to reference.

### 1a. Create an internal context repository

Create a dedicated repo (e.g., `your-org/engineering-context`) containing structured reference docs for every major internal system:

```
engineering-context/
├── infrastructure/
│   ├── terraform-modules.md        # Catalog of internal TF modules, usage examples
│   ├── cloud-patterns.md           # Approved cloud architecture patterns
│   └── deployment.md               # How to deploy (CI/CD pipelines, environments)
├── backend/
│   ├── backend-libs.md             # Internal backend libraries, API patterns
│   ├── email-proxy.md              # How to send emails via the internal proxy
│   ├── auth-patterns.md            # Authentication/authorization patterns
│   ├── database-conventions.md     # DB naming, migration patterns, approved ORMs
│   └── api-standards.md            # REST/gRPC conventions, error formats, versioning
├── frontend/
│   ├── ui-libs.md                  # Internal UI component library reference
│   ├── design-system.md            # Design tokens, spacing, typography rules
│   └── frontend-patterns.md        # State management, routing, data fetching
├── testing/
│   ├── testing-strategy.md         # Unit/integration/e2e testing expectations
│   └── test-utilities.md           # Shared test helpers, mocks, fixtures
├── conventions/
│   ├── coding-standards.md         # Language-specific style guides
│   ├── naming-conventions.md       # Service naming, repo naming, branch naming
│   ├── pr-conventions.md           # PR size, review process, merge strategy
│   └── security-requirements.md    # Security review gates, dependency policies
└── templates/
    ├── AGENTS.md.template           # Pre-filled AGENTS.md for new projects
    ├── prd-addendum.md              # Company-specific PRD sections
    └── file-instructions/           # Shared file-pattern instructions
        ├── terraform.instructions.md
        ├── react.instructions.md
        └── api.instructions.md
```

**Key principle:** Each file should be a concise, actionable reference — not a wiki dump. Write them as if you're giving a senior engineer (or AI agent) a briefing on "how we do X here." Include code examples, import paths, and usage patterns.

### 1b. Write docs optimized for AI consumption

Traditional wiki docs are often too verbose or vaguely structured for agents to use effectively. Optimize for AI by following these patterns:

**Do:**
- Start each doc with a one-sentence summary of what this system is and when to use it
- Include concrete code examples with full import paths
- Show the "happy path" usage pattern first, then edge cases
- List explicit do's and don'ts
- Keep each file under ~500 lines (split into multiple files if needed)

**Don't:**
- Write long narrative explanations — use bullet lists
- Include historical context ("we used to use X but switched to Y") — just describe the current state
- Assume the reader has context from other docs — each file should be self-contained

**Example — `email-proxy.md`:**

```markdown
# Email Proxy

Send transactional and notification emails through the internal email proxy service.
Do NOT use third-party email providers (SendGrid, Mailgun, etc.) directly.

## When to use
- Transactional emails (password reset, verification, receipts)
- System notifications (alerts, reports, digests)
- User-to-user messaging (if routed through the platform)

## Quick start

\```typescript
import { EmailClient } from '@yourco/email-proxy';

const email = new EmailClient({
  serviceId: 'my-service-name', // must match your service registration
});

await email.send({
  to: 'user@example.com',
  template: 'welcome-email',    // templates live in email-templates repo
  data: { userName: 'Alice' },
});
\```

## Rules
- Always use registered templates — do not send raw HTML
- Service must be registered in the email proxy config (see infra/email-proxy-config)
- Rate limit: 100 emails/sec per service
- For bulk sends (>1000 recipients), use the batch API

## API reference
- `EmailClient.send(options)` — send a single email
- `EmailClient.sendBatch(options[])` — send up to 10,000 emails
- `EmailClient.getStatus(messageId)` — check delivery status

## Common mistakes
- ❌ Using `nodemailer` or SMTP directly — always use `@yourco/email-proxy`
- ❌ Hardcoding email addresses — use the recipient lookup service
- ❌ Sending from a personal email — use service-registered sender addresses
```

### 1c. Install mechanism

The context repo needs a way to get into each project. Options:

| Approach | Pros | Cons |
|----------|------|------|
| **Git submodule** in `.github/context/` | Always up to date on pull, version-pinnable | Submodule complexity, extra clone step |
| **Install script** (extend `install.sh`) | Simple, scriptable in CI | Point-in-time snapshot, must re-run to update |
| **Symlinks / workspace reference** | Zero duplication | Only works locally, not in CI |
| **Copy into `.github/instructions/`** | VS Code auto-loads file-pattern instructions | Must keep in sync manually |

**Recommended:** Extend the existing `install.sh` to pull from your internal context repo alongside the agent files. This keeps the workflow familiar and ensures context is refreshed on each install.

---

## Layer 2: Project Configuration (`AGENTS.md`)

### 2a. Create a pre-filled `AGENTS.md` template

Instead of shipping the generic template with TODO markers, create an org-specific template pre-filled with your defaults:

```markdown
# Project Agent Configuration

## Preflight

\```bash
pnpm run lint && pnpm run typecheck && pnpm run test
\```

## Project Context

- **Language/Runtime**: TypeScript / Node.js 20
- **Framework**: <!-- fill in: Next.js 14, Express, etc. -->
- **Database**: PostgreSQL with internal ORM wrapper (`@yourco/db`)
- **Testing**: Vitest
- **Build tool**: Vite
- **Package manager**: pnpm

## Coding Standards

- Use functional components with hooks (no class components)
- Use `@yourco/ui` component library — do not import from MUI/Chakra/etc. directly
- Use `@yourco/email-proxy` for all email sending
- Use `@yourco/auth` for authentication — do not roll custom auth
- Infrastructure as code uses internal TF modules from `terraform-modules` repo
- Follow the API standards in `.github/context/backend/api-standards.md`

## Internal Libraries

| Library | Purpose | Docs |
|---------|---------|------|
| `@yourco/ui` | Component library | `.github/context/frontend/ui-libs.md` |
| `@yourco/email-proxy` | Email sending | `.github/context/backend/email-proxy.md` |
| `@yourco/auth` | Authentication | `.github/context/backend/auth-patterns.md` |
| `@yourco/db` | Database access | `.github/context/backend/database-conventions.md` |
| `@yourco/logging` | Structured logging | `.github/context/backend/backend-libs.md` |

## Terraform Modules

| Module | Purpose | Docs |
|--------|---------|------|
| `yourco/modules/api-service` | Standard API service infra | `.github/context/infrastructure/terraform-modules.md` |
| `yourco/modules/worker` | Background worker infra | `.github/context/infrastructure/terraform-modules.md` |
| `yourco/modules/database` | RDS/Aurora setup | `.github/context/infrastructure/terraform-modules.md` |

## Conventions

- **Commit format**: Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`)
- **Branch naming**: `feature/{feature-name-kebab-case}`, `fix/{issue-id}`
- **Test files**: Co-located with source (e.g., `foo.test.ts` next to `foo.ts`)
- **Code style**: Enforced by linter — do not override

## Notes for AI Agents

- Always run preflight before marking a task complete
- Always use internal libraries listed above — never use external alternatives
- Read the relevant `.github/context/` docs before implementing unfamiliar patterns
- When writing Terraform, use internal modules — never write raw AWS resources
- When sending emails, use the email proxy — never use SMTP or third-party providers
```

### 2b. Use file-pattern instructions for domain-specific rules

VS Code Copilot supports [file-pattern instruction files](https://code.visualstudio.com/docs/copilot/customization/custom-instructions) that activate only when working with matching files. Use these for domain-specific context:

```
.github/instructions/
├── terraform.instructions.md     # Activated for *.tf files
├── react.instructions.md         # Activated for *.tsx files
├── api-routes.instructions.md    # Activated for src/routes/**
├── migrations.instructions.md    # Activated for db/migrations/**
└── emails.instructions.md        # Activated for src/email/**
```

**Example — `terraform.instructions.md`:**

```markdown
---
applyTo: "**/*.tf"
---

## Terraform Conventions

- Always use internal TF modules from `github.com/yourco/terraform-modules`
- Never create raw AWS resources — wrap them in a module
- Module source format: `github.com/yourco/terraform-modules//modules/{name}?ref=v{version}`
- Tag all resources with: `team`, `service`, `environment`, `cost-center`
- Use workspaces for environment separation (dev/staging/prod)
- State backend is always S3 with DynamoDB locking (pre-configured in `_backend.tf`)

### Available modules

| Module | Purpose | Example |
|--------|---------|---------|
| `api-service` | ECS Fargate service with ALB | See `.github/context/infrastructure/terraform-modules.md` |
| `worker` | SQS + Lambda worker | See `.github/context/infrastructure/terraform-modules.md` |
| `database` | RDS PostgreSQL | See `.github/context/infrastructure/terraform-modules.md` |
| `cdn` | CloudFront distribution | See `.github/context/infrastructure/terraform-modules.md` |
```

---

## Layer 3: Agent Customization

### 3a. Fork and customize agent prompts

Clone the Ralph agent files and modify them to reference your internal context. The key changes are:

#### PRD Agent (`prd.agent.md`)

Add company-specific PRD sections and constraints:

```markdown
# In the PRD Structure section, add:

### 7b. Internal Dependencies
- Which internal services does this feature interact with?
- Which internal libraries should be used?
- Are there infrastructure requirements (new services, databases, queues)?

### 7c. Compliance & Security
- Does this feature handle PII? If so, reference the data classification guide.
- Does it need a security review gate?
- Are there regulatory requirements?
```

Also modify the clarifying questions to ask about internal systems:

```markdown
## Additional clarifying questions for internal projects:

5. Which internal services does this feature interact with?
   A. Email proxy (transactional emails)
   B. Auth service (user management)
   C. Notification service (push/in-app)
   D. None / standalone
   E. Other: [please specify]

6. Does this require new infrastructure?
   A. Yes — new service (API, worker, etc.)
   B. Yes — database changes only
   C. No — changes to existing service only
```

#### Plan Agent (`ralph-plan.agent.md`)

This is where the biggest impact is. Modify the plan agent to:

1. **Read internal context during codebase research:**

```markdown
## Codebase Research Checklist (modified)

- [ ] Read the full PRD
- [ ] Read `AGENTS.md`
- [ ] Read relevant `.github/context/` docs for systems mentioned in the PRD
- [ ] Identify which internal libraries to use (check the Internal Libraries table in AGENTS.md)
- [ ] If infrastructure changes are needed, read `.github/context/infrastructure/terraform-modules.md`
- [ ] If email sending is needed, read `.github/context/backend/email-proxy.md`
- [ ] Identify the tech stack
- [ ] Map the project directory structure
- [ ] Find existing code related to the feature
- [ ] Identify test patterns
```

2. **Add internal context to task files:**

```markdown
## Implementation Notes (enhanced)

In addition to standard implementation notes, include:
- Which internal libraries to import and how
- Which internal TF modules to use (with version refs)
- Links to relevant `.github/context/` docs
- Any internal API endpoints the task needs to call
- Internal service registration requirements
```

3. **Add infrastructure phase for features that need it:**

```markdown
### Phase Design Rules (additional)

7. **Infrastructure first**: If a feature requires new infrastructure (databases, 
   queues, services), include an infrastructure phase before the application code 
   phase. Use internal TF modules exclusively.
```

#### Ralph Loop / Coder Subagent (`ralph.agent.md`)

Modify the coder subagent instructions to:

1. **Always check internal context before implementing:**

```markdown
## Before implementing any task:

1. Read the task file for implementation notes
2. If the task references internal libraries, read the corresponding 
   `.github/context/` doc
3. Use internal libraries — never install external alternatives for 
   capabilities covered by internal libs
4. When writing infrastructure code, use internal TF modules only
```

2. **Add internal library verification to preflight:**

```markdown
## Additional preflight checks:

- No direct imports of banned external libraries (check against AGENTS.md)
- Internal TF modules used (no raw AWS/GCP/Azure resources)
- Email sent via proxy (no direct SMTP or third-party SDK)
```

### 3b. Distribute via a company fork

The cleanest distribution model:

1. **Fork `williamg97/ralph-copilot`** to `your-org/ralph-copilot`
2. Apply the agent customizations described above
3. Add your internal context repo as a submodule or integrate it into the install script
4. Update `install.sh` to point at your fork:

```bash
REPO="your-org/ralph-copilot"
```

5. Each project installs from your fork:

```bash
curl -fsSL https://raw.githubusercontent.com/your-org/ralph-copilot/main/install.sh | sh
```

6. Periodically sync upstream changes from `williamg97/ralph-copilot` into your fork

### 3c. Keep upstream compatibility

To make syncing easy:

- Keep all company-specific additions in clearly marked sections (e.g., `<!-- COMPANY CUSTOMIZATION START -->`)
- Don't remove upstream content — add to it
- Use the `AGENTS.md` template and `.github/context/` for project-specific context rather than hardcoding into agent prompts
- Only modify agent prompts for structural changes (new PRD sections, new research steps, new verification checks)

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1–2)

- [ ] Create the `engineering-context` repo with initial docs for your most-used internal systems
- [ ] Write the first batch of context docs (start with the 3–5 most commonly used internal libraries/services)
- [ ] Create a pre-filled `AGENTS.md` template with your org defaults
- [ ] Fork `ralph-copilot` to your org

### Phase 2: Agent Customization (Week 2–3)

- [ ] Modify the PRD agent to include company-specific sections and questions
- [ ] Modify the plan agent to read internal context docs and include internal library references in task files
- [ ] Modify the coder subagent instructions to check internal context before implementing
- [ ] Create file-pattern instructions for your most common file types (`.tf`, `.tsx`, API routes, etc.)
- [ ] Update `install.sh` to also pull from the internal context repo

### Phase 3: Pilot (Week 3–4)

- [ ] Install on 2–3 real projects with different tech stacks
- [ ] Run the full pipeline (PRD → Plan → Loop) on a real feature for each project
- [ ] Collect feedback: Did the agents use the right internal libraries? Did they follow infra patterns? Did they miss anything?
- [ ] Iterate on context docs based on gaps found

### Phase 4: Rollout (Week 4+)

- [ ] Write onboarding guide for teams adopting the customized agents
- [ ] Add the install step to your new-project scaffolding / cookiecutter template
- [ ] Set up a sync schedule with upstream `ralph-copilot` for new features
- [ ] Establish an owner for the `engineering-context` repo (DevEx / Platform team)
- [ ] Create a feedback loop: teams report when agents use wrong patterns → update context docs

---

## Maintenance

### Keeping context docs current

- Assign ownership of each context doc to the team that owns the underlying system
- Add a review reminder (quarterly) to check docs for staleness
- When an internal library ships a breaking change, update the context doc in the same PR
- Monitor agent output for recurring mistakes — each one indicates a gap in the context docs

### Syncing with upstream Ralph

- Watch `williamg97/ralph-copilot` for releases
- Create a sync PR periodically (monthly or on major releases)
- Resolve conflicts in clearly marked company customization sections
- Test the updated agents on a sample project before rolling out

---

## Summary

The core idea is simple: **the agents are only as good as the context they have**. Ralph already has the right architecture for customization — `AGENTS.md` for project config, file-pattern instructions for domain-specific rules, and modular agent prompts that can be extended. The work is primarily in creating high-quality, AI-optimized reference docs for your internal systems and wiring them into the agent pipeline so they're always consulted at the right moments.

```
Your internal context docs        →  Agents read these during planning & implementation
Pre-filled AGENTS.md template     →  Every project starts with the right defaults
Modified agent prompts             →  Agents know when to consult which context docs
File-pattern instructions          →  Domain-specific rules activated by file type
Company fork of ralph-copilot     →  Single distribution point, easy to update
```
