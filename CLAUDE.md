# xflow Plugin

Cross-agentic planning and execution workflow for Claude Code.

## Entry Points

| Command | Description |
|---------|-------------|
| `/xfeature <description>` | Plan + execute end-to-end (main workflow) |
| `/xplan <description>` | Plan only — writes plan file, presents for approval |
| `/xexecute [plan-path]` | Execute an approved plan (uses latest if path omitted) |

## Plan File Format

Plans live at `~/.claude/plans/<slug>.md`. Structure:

```
# Plan: Feature Title

## Context
Why this change is needed. Chosen approach.

### Phase 1: Title
**Files:** path/to/file.ts — what changes
**Acceptance:** [ ] runnable criterion

<checkpoint message="Verify X before proceeding"/>

### Phase 2: Title
...
<action type="commit" message="feat: description"/>

## Verification
\`\`\`bash
exact test command
\`\`\`
```

## Directive Quick Reference

| Directive | Effect |
|-----------|--------|
| `<checkpoint message="..."/>` | Pause and ask user to confirm before proceeding |
| `<action type="commit" message="..."/>` | Run git commit with files from current phase |
| `<action type="push"/>` | Push current branch to remote |
| `<action type="pr" title="..." body="..."/>` | Create GitHub PR via gh |
| `<action type="verify" [command="..."]/>` | Spawn adversarial verifier (xverifier agent) |
| `<discovery reason="..." severity="high\|medium\|low"/>` | Report unexpected finding; high severity halts execution |

Full directive protocol: `xflow/skills/xfeature/references/directives.md`

## Agents

| Agent | Role |
|-------|------|
| `xflow:workflow:xplanner` | Interview-loop planner: explore → question → write plan |
| `xflow:workflow:xexecutor` | Phase executor: read → implement → verify → report |
| `xflow:workflow:xverifier` | Adversarial verifier: independent check → PASS/FAIL/PARTIAL |

## Execution Flow

```
/xfeature description
     │
     ├─ EnterPlanMode
     ├─ xplanner agent (explore + question + write plan file)
     ├─ ExitPlanMode (user reviews plan)
     │
     └─ /xexecute (after approval)
           │
           ├─ For each phase:
           │    ├── TaskCreate (pending) → in_progress
           │    ├── xexecutor agent (implement phase)
           │    ├── Handle discoveries (halt if severity: high)
           │    ├── Process directives: checkpoint / commit / push / pr / verify
           │    └── TaskUpdate → completed
           │
           └─ xverifier (final end-to-end adversarial check)
```

## Current Limitations

- Phases execute **sequentially**. The task DAG (blockedBy/blocks) is in place for future parallel execution.
- xexecutor does not create commits — the orchestrator does after reviewing the executor's report.
- Discovery handling requires user interaction; unattended execution stops at severity: high findings.
- Copilot CLI support is simplified (no multi-agent orchestration).
