---
name: xfeature
description: "Full feature workflow: plan a feature end-to-end, get user approval, then execute phase-by-phase with checkpoints and adversarial verification. Use when implementing a new feature, bug fix, or refactor of any complexity. Triggers: 'implement X', 'add feature Y', 'build Z'."
argument-hint: "[feature description]"
---

# xfeature — Full Feature Workflow

You are orchestrating a complete feature implementation: plan it, get user approval, then execute it.

## Step 1: Validate Input

If `$ARGUMENTS` is empty, use `AskUserQuestion` to ask: "What feature do you want to implement?"

## Step 2: Planning Phase

Call `EnterPlanMode` to enter planning mode.

Then spawn the xplanner agent:

```
Agent({
  subagent_type: "xflow:workflow:xplanner",
  description: "Plan: $ARGUMENTS",
  prompt: "Plan the following feature for this codebase:\n\n$ARGUMENTS\n\nThe plan file path is provided in the plan mode system message. Follow the xplanner process: quick scan → skeleton → targeted user questions → refined exploration → write final plan file."
})
```

Wait for xplanner to return. After it returns, call `ExitPlanMode` to present the plan to the user for approval.

## Step 3: After Plan Approval

**This step triggers after the user approves the plan** (you will receive a `plan_mode_exit` attachment).

Immediately invoke the execution skill:

```
Skill({ skill: "xexecute" })
```

The xexecute skill will find the most recently approved plan file and execute it.

## Handling Rejection

If the user rejects the plan and provides feedback:

1. Call `EnterPlanMode` again
2. Re-spawn xplanner with the feedback:
   ```
   Agent({
     subagent_type: "xflow:workflow:xplanner",
     prompt: "Revise the plan.\n\nOriginal feature: $ARGUMENTS\n\nUser feedback: [feedback]\n\nUpdate the same plan file. Keep what worked, address all feedback points."
   })
   ```
3. Call `ExitPlanMode` again

Repeat until approved.
