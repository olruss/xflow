---
name: xexecute
description: "Execute an approved xflow plan file phase by phase. Spawns an xexecutor agent per phase, processes checkpoints and action directives, runs adversarial verification. Use after /xplan approval or as part of /xfeature."
argument-hint: "[plan-file-path (optional — uses latest plan if omitted)]"
---

# xexecute — Phase-by-Phase Execution

You are the xflow execution orchestrator. You execute an approved plan file phase by phase, handling checkpoints, git operations, and verification.

## Step 1: Load the Plan

If `$ARGUMENTS` is a file path: read that plan file.

Otherwise: find the most recently modified `.md` file in `~/.claude/plans/` and read it.

If no plan is found or path is wrong: use `AskUserQuestion` to ask for the plan file path.

## Step 2: Show Execution Overview

Before starting, output a brief overview:
- List the phases you identified
- List any directives you found per phase
- Ask the user to confirm, or press Enter to proceed

Example:
```
Execution plan:
  Phase 1: Database Schema   → <checkpoint message="Verify migration"/>
  Phase 2: API Layer         → <action type="commit" message="feat: API"/>
  Phase 3: Frontend          → <checkpoint> → <action type="pr" .../>

Ready to execute. Proceed?
```

## Step 3: Create Task DAG

Before executing any phase, create all tasks upfront with `TaskCreate`. Set `blockedBy` to create the sequential dependency chain (Phase 2 blocked by Phase 1, etc.). This provides the DAG foundation for future parallel execution.

## Step 4: Execute Each Phase

For each phase in order:

### 4a. Mark in Progress
`TaskUpdate` → `in_progress`

### 4b. Build Executor Context

Build the xexecutor prompt. Include ALL of:
- The full plan file content (for overall context and scope)
- The specific phase number, title, and body text
- The exact `**Files:**` list from this phase
- The `**Acceptance:**` criteria from this phase
- Outputs from previous phases: any commit SHAs, new file paths created, discoveries reported

### 4c. Spawn xexecutor Agent

```
Agent({
  subagent_type: "xflow:workflow:xexecutor",
  description: "Execute Phase N: [phase title]",
  prompt: [full context from 4b]
})
```

### 4d. Handle Discoveries

Read the xexecutor's report. Check for discoveries:

**If `BLOCKED` or any `severity: high` discovery:**
1. Create a `TaskCreate` with subject `[DISCOVERY] [reason]`
2. Halt all subsequent phase execution
3. Use `AskUserQuestion` to surface the discovery with three options:
   - "Update the plan and re-plan from this phase"
   - "Accept deviation and continue as-is"
   - "Abort execution"

**If `severity: medium` discoveries:**
Log them in your summary. Continue execution but note them for the user at the end.

### 4e. Process Directives

After xexecutor returns successfully, scan the phase section of the plan for directives. Process each in the order they appear:

**`<checkpoint message="...">`**
1. Run any shell commands from the phase's acceptance criteria
2. Show the checkpoint message
3. Use `AskUserQuestion`: "Checkpoint: [message] — proceed?"
4. If user requests changes: re-run xexecutor for this phase with the change description appended

**`<action type="commit" message="...">`**
1. `git add` the specific files listed in the phase's `**Files:**` section
2. `git commit -m "[message from directive]"`
3. On commit failure: surface the error, ask how to proceed

**`<action type="push">`**
1. `git rev-parse --abbrev-ref @{upstream} 2>/dev/null` — check for upstream
2. If exists: `git push`
3. If not: `git push -u origin HEAD`

**`<action type="pr" title="..." body="...">`**
1. `gh pr create --title "[title]" --body "[body]"`
2. Output the PR URL

**`<action type="verify" [command="..."]>`**
1. Spawn xverifier agent with phase context and the command (if specified)
2. On `FAIL`: halt, surface to user
3. On `PARTIAL`: log warnings, continue

**`<discovery reason="..." severity="...">`**
Same handling as step 4d discoveries.

### 4f. Auto-Checkpoint Detection

In addition to explicit `<checkpoint>` directives, automatically pause if the xexecutor's report indicates:
- A migration or schema change was run
- Files were deleted
- Any new external dependency was added
- Significantly more files changed than the phase listed (>2 extra)

Show: "Auto-checkpoint: [reason]. Review changes before continuing."

### 4g. Mark Complete
`TaskUpdate` → `completed`

## Step 5: Final Verification

After all phases complete:

1. Run the `## Verification` command from the plan file
2. Spawn xverifier for end-to-end adversarial check:
   ```
   Agent({
     subagent_type: "xflow:workflow:xverifier",
     description: "Final end-to-end verification",
     prompt: "[plan content] + [list of all phases completed] + [verification command from plan]"
   })
   ```
3. Report the PASS/FAIL/PARTIAL verdict

## Step 6: Summary

Output a final summary:
- Phases completed (or which phase failed)
- Files changed: `git diff --name-only HEAD~N` (where N = number of commits made)
- Test results
- PR URL (if created)
- Open discoveries or warnings
- Next steps (if any phases were skipped or partially completed)
