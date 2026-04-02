# xflow Directive Protocol

Directives are XML tags embedded in plan files. They signal the xexecute orchestrator to perform
specific actions or pause for verification. They are processed in document order after each phase
is implemented.

## Syntax Rules

- Directives appear on their own line (not inline in prose)
- All attribute values must be quoted
- Directives inside fenced code blocks are NOT processed
- Unknown directive types are logged and skipped (forward-compatible)

## Directive Reference

### `<checkpoint>`

Pauses execution. Orchestrator runs acceptance criteria and asks user to confirm before continuing.

```xml
<checkpoint message="Verify migration runs clean before touching app code"/>
```

**Attributes:**
- `message` (required) — Human-readable description of what to verify

**When to use:**
- Before any destructive or irreversible operation
- After a phase that creates artifacts the next phase depends on
- Whenever manual testing is valuable before committing to the next phase

**Orchestrator behavior:**
1. Run acceptance criteria commands from the current phase
2. Use AskUserQuestion: "Checkpoint: [message] — proceed?"
3. Options: proceed / re-run this phase with changes / abort

---

### `<action type="commit">`

Commits the files changed in the current phase.

```xml
<action type="commit" message="feat: add user authentication middleware"/>
```

**Attributes:**
- `type` (required) — `"commit"`
- `message` (required) — Conventional commit message

**Orchestrator behavior:**
1. `git add` the files listed in the phase's `**Files:**` section
2. `git commit -m "[message]"`
3. On pre-commit hook failure: surface error, ask user how to resolve

---

### `<action type="push">`

Pushes the current branch to remote.

```xml
<action type="push"/>
```

**Orchestrator behavior:**
1. Check for upstream tracking branch
2. If exists: `git push`
3. If not: `git push -u origin HEAD`

---

### `<action type="pr">`

Creates a GitHub pull request.

```xml
<action type="pr" title="feat: add user authentication" body="Implements JWT-based auth middleware with role-based access control."/>
```

**Attributes:**
- `type` (required) — `"pr"`
- `title` (required) — PR title
- `body` (optional) — PR description

**Orchestrator behavior:**
1. `gh pr create --title "[title]" --body "[body or auto-generated from phase descriptions]"`
2. Output the PR URL

---

### `<action type="verify">`

Triggers adversarial verification via the xverifier agent.

```xml
<action type="verify"/>
<action type="verify" command="npm run test:integration"/>
```

**Attributes:**
- `type` (required) — `"verify"`
- `command` (optional) — specific command for the verifier to run; if absent, verifier uses plan's `## Verification` command

**Orchestrator behavior:**
1. Spawn xverifier agent with phase context
2. On `FAIL`: halt, surface verdict to user
3. On `PARTIAL`: log warnings, continue (user can override)

---

### `<discovery>`

Marks a blocking finding discovered during planning (usually added during execution by the xexecutor, not the planner).

```xml
<discovery reason="The users table uses soft deletes — auth middleware must filter deleted_at IS NULL" severity="medium"/>
```

**Attributes:**
- `reason` (required) — What was discovered and why it matters
- `severity` (required) — `"high"` halts all execution; `"medium"` continues with warning; `"low"` logs only

**Orchestrator behavior for `severity: high`:**
1. Create `[DISCOVERY]` task
2. Halt all subsequent phase execution
3. AskUserQuestion with three options: update plan / accept deviation / abort

---

## Directive Placement Guide

```markdown
### Phase 1: Schema

**Files:** ...
**Acceptance:** ...

<checkpoint message="Run migration manually and verify schema"/>   ← before risky next step

---

### Phase 2: API

**Files:** ...
**Acceptance:** ...

<action type="commit" message="feat: add schema"/>                 ← after phase complete
<action type="verify"/>                                            ← optional extra check

---

### Phase 3: Frontend (final)

**Files:** ...
**Acceptance:** ...

<checkpoint message="Manual smoke test in browser"/>
<action type="commit" message="feat: add UI"/>
<action type="push"/>
<action type="pr" title="feat: X" body="Implements X end-to-end"/>
```

## Auto-Checkpoint Triggers

Even without explicit `<checkpoint>` directives, xexecute will auto-pause when:
- Phase involved a database migration or schema change
- Phase deleted files
- xexecutor reported any discovery (even non-blocking)
- More files changed than listed in the phase (>2 extra)
