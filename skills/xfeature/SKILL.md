---
name: xfeature
description: "Full feature workflow: plan a feature end-to-end, get user approval, then execute phase-by-phase with checkpoints and adversarial verification. Use when implementing a new feature, bug fix, or refactor of any complexity. Triggers: 'implement X', 'add feature Y', 'build Z'."
argument-hint: "[feature description]"
---

# xfeature — Full Feature Workflow

You are running in the main conversation context. Implement the feature in `$ARGUMENTS` end-to-end:
plan it in the main context (so `AskUserQuestion` is available throughout), get user approval,
then execute phase by phase. Do NOT call `EnterPlanMode` — planning happens here.

---

## Phase 1: Planning

### 1a. Quick Exploration (parallel)

Before asking anything, explore the project in parallel:

- Read `CLAUDE.md` or `README.md` — tech stack, conventions, test command
- Scan directory structure — entry points, modules, test locations
- Search for files most likely touched by the requested change (Grep for relevant keywords)

Use `Agent(subagent_type: "Explore")` for deep parallel searches when the scope is unclear.

### 1b. Ask Targeted Questions

Use `AskUserQuestion` with 3–5 focused questions. Ask only what the code doesn't answer.

**Good questions:**
- "I found two auth patterns — `src/middleware/jwt.ts` and `src/auth/verify.ts`. Which should the new endpoint follow?"
- "Will this be a breaking API change, or must it stay backward-compatible?"
- "There are no existing tests for this module. Should I create them, or skip for now?"

**Never ask:** "What files do I need to change?" or "Can you explain more?"

### 1c. Follow-Up Exploration

Based on the user's answers, do any targeted follow-up reads or searches.

### 1d. Write the Plan File

Generate a kebab-case slug from the feature name (e.g., "add JWT auth" → `add-jwt-auth`).
Write the plan to: `~/.claude/plans/<slug>.md`

Use this structure **exactly**:

```markdown
# Plan: [Feature Title]

## Context

[1–3 sentences: why this change is needed]

**Approach:** [One sentence: implementation strategy and why]

---

### Phase 1: [Title]

**Files:**
- `exact/path/to/file.ts` — [what changes and why]

**Acceptance:**
- [ ] [exact shell command or observable state]

---

### Phase 2: [Title]

**Files:**
- `exact/path.ts` — [what changes]

**Acceptance:**
- [ ] [criterion]

<action type="commit" message="feat: add X"/>

---

## Verification

```bash
[exact end-to-end verification command]
```
Expected: [what success looks like]
```

**Plan rules:**
- Every file path must be the exact real path (from your exploration — do not guess)
- Every acceptance criterion must be a runnable shell command or clearly observable state
- Phases touch 1–5 files each; target 30–60 lines total
- Add `<checkpoint message="..."/>` before irreversible operations
- Add `<action type="commit" message="..."/>` at natural commit points
- Database/schema changes always get their own phase

### 1e. Present for Approval

Show the full plan and ask for approval:

> Here's the implementation plan for **[feature name]**:
>
> ---
> [full plan content]
> ---
>
> Approve to start execution, or share feedback to revise.

Use `AskUserQuestion` with **Approve** and a feedback option.

On feedback: revise the plan file, re-show it. Repeat until approved.

---

## Phase 2: Execution

Once the user approves, immediately invoke the execution skill:

```
Skill({ skill: "xexecute" })
```

The xexecute skill will find the most recently written plan file and execute it phase by phase.

---

If `$ARGUMENTS` is empty: use `AskUserQuestion` to ask "What feature do you want to implement?"
