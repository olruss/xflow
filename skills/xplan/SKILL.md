---
name: xplan
description: "Plan a feature with interview-loop exploration: explore codebase, ask targeted questions, write a structured phase-based plan with execution directives. Use when you want planning without immediate execution. Execute later with /xexecute."
argument-hint: "[feature description]"
---

# xplan — Feature Planning

You are running in the main conversation context. Plan the feature in `$ARGUMENTS` using the
interview-loop process below. Do NOT call `EnterPlanMode` — the entire planning workflow runs
here, in the main context, so you can use `AskUserQuestion` throughout.

---

## Step 1: Quick Exploration (parallel)

Before asking anything, explore the project in parallel:

- Read `CLAUDE.md` or `README.md` — tech stack, conventions, test command
- Scan directory structure — entry points, modules, test locations
- Search for files most likely touched by the requested change (Grep for relevant keywords)

Use `Agent(subagent_type: "Explore")` for deep parallel codebase searches when the scope is unclear.

---

## Step 2: Ask Targeted Questions

Use `AskUserQuestion` with 3–5 focused questions. Ask only what you cannot determine from the code.

**Good questions:**
- "I found two auth middleware patterns — `src/middleware/jwt.ts` and `src/auth/verify.ts`. Which should the new endpoint follow?"
- "Will this be a breaking API change, or must it stay backward-compatible?"
- "There are no existing tests for this module. Should I create them, or skip for now?"

**Never ask:**
- "Can you explain what you want?" (too vague)
- "What files do I need to change?" (you figure this out)

---

## Step 3: Follow-Up Exploration

Based on the user's answers, do any targeted follow-up reads or searches.

---

## Step 4: Write the Plan File

Generate a kebab-case slug from the feature name (e.g., "add JWT auth" → `add-jwt-auth`).
Write the plan to: `~/.claude/plans/<slug>.md`

Use this structure **exactly**:

```markdown
# Plan: [Feature Title]

## Context

[1–3 sentences: why this change is needed, what problem it solves]

**Approach:** [One sentence: implementation strategy and why]

---

### Phase 1: [Title]

**Files:**
- `exact/path/to/file.ts` — [what changes and why]

**Acceptance:**
- [ ] [exact shell command or observable state — no prose]

<!-- optional directives below acceptance criteria -->

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
- Every acceptance criterion must be a runnable shell command or a clearly observable state
- Phases touch 1–5 files each; split larger changes into smaller phases
- Target 30–60 lines total. Every line should be a decision, a path, or a command
- Add `<checkpoint message="..."/>` before irreversible operations (migrations, destructive changes)
- Add `<action type="commit" message="..."/>` at natural commit points
- Database/schema changes always get their own phase

**Directive reference:**
```xml
<checkpoint message="Verify migration before touching app code"/>
<action type="commit" message="feat: add X"/>
<action type="push"/>
<action type="pr" title="feat: X" body="Description"/>
<action type="verify"/>
<discovery reason="Found Y that invalidates Phase 3" severity="high"/>
```

---

## Step 5: Present for Approval

After writing the plan file, show the user the full plan and ask for approval:

> Here's the implementation plan for **[feature name]**:
>
> ---
> [full plan content]
> ---
>
> Approve this plan, or share feedback to revise it.

Use `AskUserQuestion` with two options: **Approve** and a free-text option for feedback.

---

## Step 6: Revise if Needed

If the user provides feedback: update the plan file, re-show the revised plan (Step 5).
Repeat until approved.

---

## Step 7: Confirm

After approval, tell the user:

> Plan approved and saved to `~/.claude/plans/<slug>.md`.
> Run `/xexecute` to execute it phase by phase, or edit the plan file before executing.

---

If `$ARGUMENTS` is empty: use `AskUserQuestion` to ask "What feature do you want to plan?"
