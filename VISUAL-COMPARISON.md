# Visual Comparison: V3 vs V2 vs Main

## Branch Evolution Timeline

```
main (05c556d)
│
├─ Initial Ralph pattern
├─ 3 agent files (prd, ralph-plan, ralph)
├─ 2 skill files
└─ Inline subagent instructions
    │
    ├──> feature/v2 (8a11931)
    │    │
    │    ├─ Extract instructions to 4 files
    │    ├─ Add Journey Verifier agent
    │    ├─ Add web/fetch to PRD
    │    ├─ Add branch logic
    │    └─ "user-facing" terminology
    │        │
    │        └──> feature/v3 (1e92cb9)
    │             │
    │             ├─ Refactor "user-facing" → "consumer-facing"
    │             ├─ Add copilot-instructions.md template
    │             ├─ Enhance Journey Verifier reachability checks
    │             ├─ Improve README documentation
    │             └─ Refine ralph.agent.md orchestration
```

---

## File Count Comparison

```
main:     ████████ (8 files)
v2:       ████████████ (12 files) +50%
v3:       █████████████ (13 files) +62%
```

**Breakdown:**

| Category | main | v2 | v3 |
|----------|------|----|----|
| Agent definitions | 3 | 3 | 3 |
| Instruction files | 0 | 4 | 4 |
| Skill files | 2 | 2 | 2 |
| Prompt files | 2 | 2 | 2 |
| Config files | 1 | 1 | 2 |
| **Total** | **8** | **12** | **13** |

---

## Agent Size Comparison

### ralph.agent.md (Core Orchestrator)

```
main:   ████████████████████████ (22,033 bytes)
v2:     ███████████████████ (19,551 bytes) -11%
v3:     ██████████████████████ (21,656 bytes) -2%
```

**Observation**: Despite extracting instructions, v3 is only 2% smaller than main!

### Total Documentation Size

```
main:   ████████████████████████ (22KB)
v2:     ████████████████████████████ (27KB est.) +23%
v3:     ███████████████████████████████ (30KB est.) +36%
```

**Includes**: ralph.agent.md + all instruction files

---

## Feature Comparison Matrix

| Feature | main | v2 | v3 |
|---------|:----:|:--:|:--:|
| **Core Orchestration** | ✅ | ✅ | ✅ |
| PRD Generation | ✅ | ✅ | ✅ |
| Plan Decomposition | ✅ | ✅ | ✅ |
| Ralph Loop | ✅ | ✅ | ✅ |
| Coder Subagent | ✅ | ✅ | ✅ |
| Task Inspector | ✅ | ✅ | ✅ |
| Phase Inspector | ✅ | ✅ | ✅ |
| **Journey Verifier** | ❌ | ❓ | ❓ |
| Web Fetch (PRD) | ❌ | ✅ | ✅ |
| External Instructions | ❌ | ✅ | ✅ |
| Two-File Config | ❌ | ❌ | ✅ |
| Enhanced Reachability | ❌ | ❌ | ✅ |
| "Consumer-facing" Term | ❌ | ❌ | ✅ |

**Legend:**
- ✅ Implemented and working
- ❓ Code exists but integration unclear
- ❌ Not present

---

## Complexity Score

**Metric**: Files × Avg Lines + Cross-references

```
main:   ████████ (8 files, ~2.7KB avg, 0 refs)  = Complexity: 22
v2:     ████████████████ (12 files, ~2.2KB avg, 4 refs) = Complexity: 30
v3:     ██████████████████ (13 files, ~2.3KB avg, 5 refs) = Complexity: 35
```

**Interpretation**: V3 is ~59% more complex than main in terms of file management.

---

## Quality Assurance Coverage

### main (3-Tier)

```
┌──────────────┐
│    Coder     │ ← Tier 1: Preflight
└──────────────┘
        ↓
┌──────────────┐
│Task Inspector│ ← Tier 2: Per-task QA
└──────────────┘
        ↓
┌──────────────┐
│Phase Inspec. │ ← Tier 3: Phase-level QA
└──────────────┘
```

### v2/v3 (4-Tier IF integrated)

```
┌──────────────┐
│    Coder     │ ← Tier 1: Preflight
└──────────────┘
        ↓
┌──────────────┐
│Task Inspector│ ← Tier 2: Per-task QA
└──────────────┘
        ↓
┌──────────────┐
│Phase Inspec. │ ← Tier 3: Phase-level QA
└──────────────┘
        ↓
┌──────────────┐
│   Journey    │ ← Tier 4: End-to-end validation
│  Verifier    │    (⚠️ NOT INTEGRATED YET)
└──────────────┘
```

---

## Critical Issue Impact

### Issue #1: Journey Verifier Not Integrated

```
Expected Flow:
  Coder → Task Insp. → Phase Insp. → Journey Ver. → Done
                                           ↑
                                     (validates E2E)

Actual Flow:
  Coder → Task Insp. → Phase Insp. ──┐
                                      ├─→ Done
  Journey Verifier (orphaned) ───────┘
                ↑
          (never called)
```

**Wasted Effort**: 314 lines of instruction code with no caller

---

## Terminology Evolution

| Term | main | v2 | v3 |
|------|------|----|----|
| "user-facing" | Some usage | Some usage | Refactored |
| "consumer-facing" | ❌ | ❌ | ✅ |

**v3 Improvement**: More inclusive term covering:
- Web UIs (user-facing)
- APIs (consumer = developers)
- Libraries (consumer = other code)
- CLIs (consumer = operators)
- SDKs (consumer = integrators)

---

## Documentation Quality

### README.md Improvements (v3)

```
main README:
├─ Basic pipeline description
├─ Setup instructions
└─ File structure

v3 README:
├─ Enhanced pipeline description
├─ Detailed setup instructions
├─ File structure
├─ ✨ Two-file config pattern explained
├─ ✨ When each file is loaded (Copilot vs explicit)
├─ ✨ File-pattern instructions guidance
└─ ✨ Clear distinction: copilot-instructions.md vs AGENTS.md
```

**Improvement**: +37 lines of clarifying documentation

---

## Recommendation Scorecard

| Criterion | main | v2 | v3 | Best |
|-----------|:----:|:--:|:--:|:----:|
| **Simplicity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | main |
| **Documentation** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | **v3** |
| **QA Coverage** | ⭐⭐⭐ | ⭐⭐⭐⭐* | ⭐⭐⭐⭐* | **v3** |
| **Terminology** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | **v3** |
| **Maintainability** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | v2/v3 |
| **Integration** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | **main** |
| **Testing** | ⭐ | ⭐ | ⭐ | None |

\* If Journey Verifier were actually integrated

---

## Decision Tree

```
Do you need end-to-end journey validation?
│
├─ YES → Choose v3 BUT:
│        1. Integrate Journey Verifier
│        2. Fix documentation mismatch
│        3. Add error handling
│        4. Accept increased complexity
│
└─ NO → Consider:
         ├─ Want better docs/terminology? → v3 (after fixes)
         ├─ Want maximum simplicity? → main
         └─ Want modular instructions? → v2
```

---

## Risk Heatmap

| Risk | Probability | Impact | Total |
|------|:-----------:|:------:|:-----:|
| Journey Verifier never works | 🔴 HIGH | 🔴 HIGH | 🔴 CRITICAL |
| Docs confuse users | 🔴 HIGH | 🟡 MED | 🔴 HIGH |
| File I/O errors | 🟡 MED | 🔴 HIGH | 🟡 MED-HIGH |
| Terminology drift | 🟡 MED | 🟢 LOW | 🟢 LOW |
| Complexity hurts maintenance | 🟡 MED | 🟡 MED | 🟡 MEDIUM |

---

## Quick Reference

### Use main if:
- ✅ You want the simplest, proven implementation
- ✅ You don't need end-to-end journey validation
- ✅ You prefer all-in-one files over modular split
- ✅ You need something that works NOW without fixes

### Use v2 if:
- ✅ You want modular instruction files
- ✅ You need web/fetch in PRD agent
- ⚠️ You can accept unclear Journey Verifier integration

### Use v3 if:
- ✅ You want the best documentation
- ✅ You need "consumer-facing" terminology (APIs, SDKs, etc.)
- ✅ You want enhanced reachability checks
- ✅ You value the two-file config pattern
- ⚠️ **BUT**: You MUST fix Journey Verifier integration first

---

## Action Items by Priority

### P0 (Before Production)
- [ ] Integrate Journey Verifier OR remove it
- [ ] Update README to match actual tier count (3 or 4)

### P1 (Soon)
- [ ] Add error handling for file reads
- [ ] Audit terminology consistency
- [ ] Create validation test suite

### P2 (Nice to Have)
- [ ] Customize copilot-instructions.md
- [ ] Document size trade-offs
- [ ] Rename branches for clarity

### P3 (Future)
- [ ] Build integration tests
- [ ] Add example PRDs with outputs
- [ ] Performance profiling

---

## Summary in 3 Bullets

1. **V3 has the best documentation and terminology** but introduces a critical bug: Journey Verifier exists but isn't called.

2. **Main is simpler and works** but lacks modern features like web fetch, modular instructions, and consumer-facing terminology.

3. **Recommendation**: Fix v3's Journey Verifier integration, then use it. If you need something NOW, use main.

---

**Visual created**: 2026-02-13  
**For**: Comparison of ralph-copilot branches  
**See also**: EXEC-SUMMARY.md, ANALYSIS.md, FINDINGS-DETAILED.md
