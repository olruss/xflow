# Plan: [Feature Title]

## Context

[1–3 sentences: why this change is needed, what problem it solves, what the intended outcome is]

**Approach:** [One sentence: the chosen implementation strategy and why it was chosen]

---

### Phase 1: [Title — e.g., "Data model"]

**Files:**
- `path/to/file.ts` — [what changes and why]
- `path/to/other.ts` — [what changes]

**Acceptance:**
- [ ] [Exact shell command or observable state that verifies this phase is done]
- [ ] [Another criterion]

<!-- Add directives here. Examples:
<checkpoint message="Verify migration runs cleanly before touching app code"/>
<action type="commit" message="feat: add [description]"/>
-->

---

### Phase 2: [Title — e.g., "Business logic"]

**Files:**
- `path/to/service.ts` — [what changes]

**Acceptance:**
- [ ] [Criterion]

<action type="commit" message="feat: [description]"/>

---

### Phase N: [Final phase — e.g., "UI / integration"]

**Files:**
- `path/to/component.tsx` — [what changes]

**Acceptance:**
- [ ] [End-to-end test or manual verification step]

<checkpoint message="Manual smoke test: [what to test]"/>
<action type="commit" message="feat: [description]"/>
<action type="pr" title="feat: [PR title]" body="[Brief PR description]"/>

---

## Verification

```bash
[Exact command(s) to verify the full feature works end-to-end]
```

Expected: [What success looks like — specific output, state, or behavior]

---
<!-- Plan writing rules (remove this section when done):
- Every file path must be the exact real path (from codebase exploration, not guessed)
- Every acceptance criterion must be a runnable command or clearly observable state
- Phases should touch 1–5 files each; split larger changes into more phases
- Target 30–60 lines total. Every line = a decision, a path, or a command
- Database/schema changes always get their own phase
- Add <checkpoint> before irreversible or risky operations
- Add <action type="commit"> at natural commit points
-->
