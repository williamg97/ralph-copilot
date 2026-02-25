# Automating Context Doc Authoring and Maintenance

A guide to solving the two hardest problems with the `engineering-context` repo described in
[Customizing Ralph for Your Company](./customizing-for-your-company.md):

1. **Authoring** — writing the initial docs without doing it all by hand
2. **Staying current** — ensuring docs don't drift as internal libraries evolve

---

## Problem 1: Initial Authoring

The context docs are concise, AI-optimized references for internal systems (see the
`email-proxy.md` example in the customization guide). Writing them by hand for every internal
library is tedious, but you already have everything you need: the source code, the existing
README, and an AI assistant.

**This is a one-time bootstrapping task — just use AI.**

Point Claude, Copilot, or your preferred assistant at the relevant source files and ask it to
generate the doc in the right format:

> "Read `src/libs/email-proxy/index.ts` and any related README. Write a concise, AI-optimized
> context doc for this library. Structure it as: one-sentence summary, when to use it, quick
> start with a real code example, rules/constraints, API reference, and common mistakes. Keep it
> under 500 lines."

Repeat once per internal system. One afternoon of prompting bootstraps the full
`engineering-context` repo. The format matters more than completeness — a short, well-structured
doc beats a verbose one every time.

---

## Problem 2: Staying Current

This is the harder problem. Docs drift the moment someone changes an internal library without
updating the corresponding context doc. The solution has two parts: **detecting staleness** and
**drafting the update**.

### The three options

#### Option A — Swimm (freemium)

[Swimm](https://swimm.io) creates documentation that is explicitly coupled to specific lines of
source code. When the referenced code changes, Swimm marks the doc as stale and can fail CI.

**How it works:**
- You embed "snippet tokens" in your docs that reference specific lines or functions in source
- Swimm tracks these references; when the source lines move or change, the doc is flagged
- A GitHub Action (`swimmio/swimm-verify`) runs on every PR and blocks merge if docs are stale

**Setup:**
```yaml
# .github/workflows/swimm.yml
name: Verify Swimm docs
on: [pull_request]
jobs:
  swimm-verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: swimmio/swimm-verify@v1
```

**Upside:** Zero false negatives — if referenced code changed, the signal fires reliably.

**Downside:** Swimm still requires a human to write the updated doc. It detects staleness but
doesn't draft the fix.

---

#### Option B — GitHub Actions + AI re-generation

A path-filtered GitHub Action watches for changes to library source files. When triggered, it
calls the Claude API with the updated source code and generates a draft PR with the updated
context doc. A human reviews and merges.

**How it works:**
1. PR modifies `src/libs/email-proxy/**`
2. Action detects the change via path filter
3. Action reads the updated source + current context doc
4. Action calls Claude API: "Here is the updated source and the current doc. Rewrite the doc to
   reflect the changes. Preserve structure and keep it under 500 lines."
5. Action opens a draft PR against the engineering-context repo with the generated update

**Workflow skeleton:**

```yaml
# .github/workflows/update-context-docs.yml
name: Update context docs on library change
on:
  push:
    branches: [main]
    paths:
      - 'src/libs/email-proxy/**'
      - 'src/libs/auth/**'
      - 'src/libs/ui/**'
      # Add a path entry for each internal library

jobs:
  update-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Detect which library changed
        id: detect
        run: |
          # Map changed paths to their corresponding context doc
          if git diff --name-only HEAD~1 | grep -q 'src/libs/email-proxy'; then
            echo "lib=email-proxy" >> $GITHUB_OUTPUT
            echo "doc=backend/email-proxy.md" >> $GITHUB_OUTPUT
            echo "src=src/libs/email-proxy" >> $GITHUB_OUTPUT
          fi
          # Extend with additional libraries as needed

      - name: Generate updated doc
        if: steps.detect.outputs.lib != ''
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          SOURCE=$(find ${{ steps.detect.outputs.src }} -name "*.ts" | xargs cat)
          CURRENT_DOC=$(cat engineering-context/${{ steps.detect.outputs.doc }} 2>/dev/null || echo "")

          curl -s https://api.anthropic.com/v1/messages \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d "{
              \"model\": \"claude-haiku-4-5-20251001\",
              \"max_tokens\": 4096,
              \"messages\": [{
                \"role\": \"user\",
                \"content\": \"Here is updated source code for our internal ${{ steps.detect.outputs.lib }} library:\n\n$SOURCE\n\nHere is the current context doc:\n\n$CURRENT_DOC\n\nRewrite the context doc to reflect any changes in the source. Preserve the structure (summary, when to use, quick start, rules, API reference, common mistakes). Keep it under 500 lines. Output only the markdown, no preamble.\"
              }]
            }" | jq -r '.content[0].text' > updated-doc.md

      - name: Open PR with updated doc
        if: steps.detect.outputs.lib != ''
        uses: peter-evans/create-pull-request@v6
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: "docs: auto-update ${{ steps.detect.outputs.lib }} context doc"
          title: "docs: update ${{ steps.detect.outputs.lib }} context doc (auto-generated)"
          body: |
            Context doc auto-updated because `${{ steps.detect.outputs.src }}` changed.

            **Review checklist:**
            - [ ] Examples still match real usage
            - [ ] Rules/constraints are complete
            - [ ] Common mistakes section is accurate
          branch: "auto-docs/${{ steps.detect.outputs.lib }}-update"
          add-paths: "engineering-context/${{ steps.detect.outputs.doc }}"
```

**Upside:** Fully automatic authoring — humans only review diffs, not write from scratch.

**Downside:** AI-generated updates occasionally need correction. Requires an Anthropic API key
in CI secrets.

---

#### Option C — Process gate (no external tooling)

A CI check fails any PR that modifies library source without also updating the corresponding
context doc. No AI, no external services — just a path-coupling script.

```bash
#!/usr/bin/env bash
# scripts/check-context-docs-updated.sh
# Fail if library source changed but context doc was not touched.

CHANGED=$(git diff --name-only origin/main...HEAD)

check_pair() {
  local src_pattern="$1"
  local doc_path="$2"
  local lib_name="$3"

  if echo "$CHANGED" | grep -q "$src_pattern"; then
    if ! echo "$CHANGED" | grep -q "$doc_path"; then
      echo "❌ $lib_name source changed but $doc_path was not updated."
      echo "   Update the context doc in the same PR as the library change."
      exit 1
    fi
  fi
}

check_pair "src/libs/email-proxy" "engineering-context/backend/email-proxy.md" "email-proxy"
check_pair "src/libs/auth"        "engineering-context/backend/auth-patterns.md" "auth"
check_pair "src/libs/ui"          "engineering-context/frontend/ui-libs.md"      "UI library"
check_pair "terraform/modules"    "engineering-context/infrastructure/terraform-modules.md" "Terraform modules"

echo "✅ Context docs are up to date."
```

```yaml
# .github/workflows/context-docs-gate.yml
name: Context doc gate
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: bash scripts/check-context-docs-updated.sh
```

**Upside:** Zero dependencies, dead simple, very reliable.

**Downside:** Forces a human to write the update — it detects the problem but does not help solve
it.

---

### Recommendation: combine A + B

Use **Swimm for detection** and **GitHub Actions + AI for drafting**:

1. Swimm embeds code references in context docs and fires on staleness → gives you the "this is
   broken" signal in every PR
2. The AI re-generation Action runs on merges to main → opens a ready-to-review PR with a
   drafted update

The result: code changes → CI flags the stale doc AND opens a PR with an AI-drafted update →
human reviews the diff → merges. The human role shrinks from "author" to "reviewer."

For teams that want to start simpler, **Option C alone** is the fastest path to preventing drift —
it requires no external accounts and enforces the discipline of updating docs in the same PR as
the code change.

---

## Ownership model

Regardless of tooling, assign explicit ownership:

| Context doc | Owner | Review trigger |
|-------------|-------|----------------|
| `backend/email-proxy.md` | Platform team | Any change to `src/libs/email-proxy/` |
| `backend/auth-patterns.md` | Auth team | Any change to `src/libs/auth/` |
| `frontend/ui-libs.md` | Design systems team | Any change to `src/libs/ui/` |
| `infrastructure/terraform-modules.md` | Infra team | Any change to `terraform/modules/` |

Add these as `CODEOWNERS` entries in the `engineering-context` repo so the right team is
auto-requested as reviewer on every auto-generated PR.

```
# engineering-context/CODEOWNERS
/backend/email-proxy.md          @your-org/platform-team
/backend/auth-patterns.md        @your-org/auth-team
/frontend/ui-libs.md             @your-org/design-systems
/infrastructure/                 @your-org/infra-team
```
