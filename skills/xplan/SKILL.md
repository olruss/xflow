---
name: xplan
description: "Plan a feature using interview-loop planning: explore codebase, ask targeted questions, write a structured phase-based plan with execution directives. Use when you want planning without immediate execution. The plan can be executed later with /xexecute."
argument-hint: "[feature description]"
---

# xplan — Feature Planning

You are orchestrating the planning phase of a feature implementation.

## Step 1: Enter Plan Mode

Call `EnterPlanMode` to enter planning mode. This signals to the user that you are in a planning session.

## Step 2: Spawn the Planner

Spawn the xplanner agent to explore the codebase and write the implementation plan:

```
Agent({
  subagent_type: "xflow:workflow:xplanner",
  description: "Plan: $ARGUMENTS",
  prompt: "Plan the following feature for this codebase:\n\n$ARGUMENTS\n\nThe plan file path is available in the plan mode system message. Follow the xplanner process: quick scan, skeleton, user questions, refinement, write plan."
})
```

Wait for the xplanner agent to return.

## Step 3: Review and Exit

After the xplanner returns, call `ExitPlanMode` to present the plan to the user for review and approval.

If the user rejects the plan and provides feedback, re-spawn the xplanner with the original description plus the feedback:

```
Agent({
  subagent_type: "xflow:workflow:xplanner",
  prompt: "Revise the feature plan.\n\nOriginal request: $ARGUMENTS\n\nUser feedback on previous plan: [feedback]\n\nKeep what worked, address the feedback. The same plan file path applies."
})
```

Then call `ExitPlanMode` again.

## After Approval

After the plan is approved, tell the user:

> "Plan approved. Run `/xexecute` to execute it, or edit the plan file at `~/.claude/plans/<slug>.md` before executing."

If `$ARGUMENTS` is empty, use `AskUserQuestion` to ask: "What feature do you want to plan?"
