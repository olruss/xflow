# xflow

Cross-agentic planning and execution plugin for [Claude Code](https://claude.ai/code).

Extends native plan mode with multi-agent orchestration, structured phase-based plans with inline directives, mid-execution checkpoints, and adversarial verification.

## What it does

```
/xfeature "add JWT authentication"
     │
     ├─ xplanner agent  →  you approve the plan
     │
     └─ /xexecute (phase by phase)
           ├── xexecutor agent per phase (implement → verify → report)
           ├── <checkpoint> directives → pause and ask you to verify
           ├── <action type="commit|push|pr"> → automatic git ops
           └── xverifier agent → adversarial PASS/FAIL/PARTIAL verdict
```

**Plan files** are human-readable markdown with optional inline XML directives you can add/edit before approving:

```markdown
### Phase 1: Database Schema
**Files:** `src/db/schema.ts`
**Acceptance:** [ ] npm run migrate succeeds

<checkpoint message="Verify migration before touching app code"/>

### Phase 2: API Layer
**Files:** `src/api/auth.ts`
**Acceptance:** [ ] npm test src/api passes

<action type="commit" message="feat: add auth API"/>
<action type="pr" title="feat: JWT authentication"/>
```

## Installation

### Option 1 — Claude Code plugin system

```bash
claude plugin marketplace add olruss/xflow
claude plugin install xflow@xflow
```

### Option 2 — One-liner (curl / wget)

```bash
# curl
curl -fsSL https://raw.githubusercontent.com/olruss/xflow/main/install.sh | bash -s -- --claude

# wget
wget -qO- https://raw.githubusercontent.com/olruss/xflow/main/install.sh | bash -s -- --claude
```

### Option 3 — Clone and install

```bash
git clone https://github.com/olruss/xflow.git ~/my/xflow
bash ~/my/xflow/install.sh --claude
```

Restart Claude Code after installation to activate the plugin.

### GitHub Copilot CLI

```bash
bash install.sh --copilot
```

Installs simplified single-agent versions of the skills (no multi-agent orchestration).

## Commands

| Command | Description |
|---------|-------------|
| `/xfeature <description>` | Plan + execute end-to-end (main workflow) |
| `/xplan <description>` | Plan only — writes plan file, presents for approval |
| `/xexecute [plan-path]` | Execute an approved plan (uses latest if path omitted) |

## Directive reference

| Directive | Effect |
|-----------|--------|
| `<checkpoint message="..."/>` | Pause and ask you to verify before continuing |
| `<action type="commit" message="..."/>` | Run `git commit` with the phase's files |
| `<action type="push"/>` | Push current branch |
| `<action type="pr" title="..." body="..."/>` | Create GitHub PR via `gh` |
| `<action type="verify"/>` | Spawn adversarial verifier (xverifier agent) |
| `<discovery reason="..." severity="high\|medium\|low"/>` | Report unexpected finding; `high` halts execution |

Full protocol: [`skills/xfeature/references/directives.md`](skills/xfeature/references/directives.md)

## Agents

| Agent | Role |
|-------|------|
| `xflow:workflow:xplanner` | Interview-loop planner: explore → question → write plan |
| `xflow:workflow:xexecutor` | Phase executor: read → implement → verify → report |
| `xflow:workflow:xverifier` | Adversarial verifier: independent check → PASS/FAIL/PARTIAL |

## Architecture notes

- Phases execute **sequentially**. The task DAG (`blocks`/`blockedBy`) is wired up from day one — parallel execution (multiple Docker/ralph-loop executors claiming tasks) is an upgrade path, not a rewrite.
- xexecutor never commits — the orchestrator does, after reviewing the report.
- `severity: high` discoveries halt all downstream phases until you resolve them.
