#!/usr/bin/env bash
# xflow plugin installer
#
# Usage:
#   ./install.sh              # Interactive mode
#   ./install.sh --claude     # Claude Code only
#   ./install.sh --copilot    # GitHub Copilot CLI only
#   ./install.sh --all        # Both
#   ./install.sh --uninstall  # Remove from all locations

set -euo pipefail

# Detect piped execution (wget/curl | bash) — BASH_SOURCE[0] is empty or "-"
PIPED=false
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "-" ]]; then
    PIPED=true
    SCRIPT_DIR=""
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

PLUGIN_NAME="xflow"
GITHUB_REPO="olruss/xflow"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[xflow]${NC} $*"; }
log_success() { echo -e "${GREEN}[xflow]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[xflow]${NC} $*"; }
log_error()   { echo -e "${RED}[xflow]${NC} $*" >&2; }

# ── Claude Code ───────────────────────────────────────────────────────────────

install_claude() {
    log_info "Installing xflow for Claude Code..."

    if ! command -v claude &>/dev/null; then
        log_error "Claude Code CLI not found in PATH. Install Claude Code first."
        return 1
    fi

    # Determine marketplace source: GitHub (piped/remote) or local path
    local marketplace_source
    if $PIPED || [ -z "$SCRIPT_DIR" ]; then
        marketplace_source="$GITHUB_REPO"
        log_info "Installing from GitHub ($GITHUB_REPO)..."
    else
        marketplace_source="$SCRIPT_DIR"
        log_info "Installing from local path ($SCRIPT_DIR)..."
    fi

    # Step 1: Register marketplace (idempotent)
    log_info "Registering marketplace..."
    if claude plugin marketplace list 2>/dev/null | grep -q "^xflow "; then
        log_info "Marketplace 'xflow' already registered — skipping."
    else
        claude plugin marketplace add "$marketplace_source" --scope user 2>&1 \
            && log_success "Marketplace registered." \
            || { log_error "Failed to register marketplace."; return 1; }
    fi

    # Step 2: Install the plugin
    log_info "Installing plugin..."
    claude plugin install "xflow@xflow" --scope user 2>&1 \
        && log_success "Plugin installed." \
        || { log_error "Failed to install plugin."; return 1; }

    log_success "Claude Code installation complete."
    echo ""
    echo "  Commands available (restart Claude Code to activate):"
    echo "    /xfeature <description>   — Plan + execute a feature"
    echo "    /xplan <description>      — Plan only"
    echo "    /xexecute [plan-path]     — Execute an approved plan"
}

uninstall_claude() {
    if ! command -v claude &>/dev/null; then
        log_error "Claude Code CLI not found in PATH."
        return 1
    fi

    log_info "Uninstalling xflow from Claude Code..."
    if claude plugin uninstall "xflow@xflow" 2>&1; then
        log_success "Plugin uninstalled."
    else
        log_warn "Plugin not found or already uninstalled."
    fi
}

# ── GitHub Copilot CLI ────────────────────────────────────────────────────────

install_copilot() {
    log_info "Installing xflow for GitHub Copilot CLI..."

    local copilot_home
    if [ -n "${GITHUB_COPILOT_HOME:-}" ]; then
        copilot_home="$GITHUB_COPILOT_HOME"
    elif [ -d "$HOME/.config/github-copilot" ]; then
        copilot_home="$HOME/.config/github-copilot"
    elif [ -d "$HOME/Library/Application Support/GitHub Copilot" ]; then
        copilot_home="$HOME/Library/Application Support/GitHub Copilot"
    else
        log_error "GitHub Copilot config directory not found."
        log_error "Set GITHUB_COPILOT_HOME to your Copilot config directory."
        return 1
    fi

    local skills_dir="$copilot_home/skills"
    mkdir -p "$skills_dir"

    # Copilot CLI uses flat skill files — create thin wrappers
    cat > "$skills_dir/xfeature.md" << 'EOF'
---
name: xfeature
description: "Plan and execute a feature end-to-end with structured phases and checkpoints (xflow plugin — simplified mode for Copilot CLI)"
---

# xfeature — Feature Implementation (Copilot CLI)

Note: This is a simplified version. Full multi-agent orchestration requires Claude Code.

## What to do

1. Analyze the codebase to understand relevant context (read CLAUDE.md, README, related files)
2. Ask the user 2-3 targeted clarifying questions
3. Create an implementation plan with clearly numbered phases:
   - Each phase: list exact files to change and acceptance criteria
   - Mark risky phases (DB changes, deletions) with "⚠️ Checkpoint: verify before continuing"
4. Ask the user to approve the plan before making changes
5. Execute each phase in sequence
6. After each risky phase, pause and ask user to confirm before proceeding
7. Run the test command after all phases complete

The feature to implement: $ARGUMENTS
EOF

    cat > "$skills_dir/xplan.md" << 'EOF'
---
name: xplan
description: "Plan a feature with structured phases and checkpoints (xflow plugin — simplified mode)"
---

# xplan — Feature Planning (Copilot CLI)

Explore the codebase, ask clarifying questions, and write a structured implementation plan.

## Steps

1. Read CLAUDE.md, README, and relevant source files
2. Ask the user 2-4 targeted questions (not vague ones — be specific)
3. Write a plan with:
   - Context section (why the change is needed)
   - Numbered phases, each with: files to change, acceptance criteria
   - Directives where appropriate: [CHECKPOINT: reason], [COMMIT: message], [PR: title]
   - Verification section with exact test command
4. Present the plan and ask for approval
5. After approval: tell the user to say "execute the plan" to proceed

Feature to plan: $ARGUMENTS
EOF

    cat > "$skills_dir/xexecute.md" << 'EOF'
---
name: xexecute
description: "Execute an approved xflow plan phase by phase (simplified mode for Copilot CLI)"
---

# xexecute — Execute Plan (Copilot CLI)

Execute an approved plan file phase by phase with checkpoints.

## Steps

1. Read the plan file (path: $ARGUMENTS, or ask for it if not provided)
2. List the phases and their directives
3. For each phase in order:
   a. Implement the specified changes
   b. Run acceptance criteria commands
   c. If phase has [CHECKPOINT]: pause, show results, ask user to confirm
   d. If phase has [COMMIT]: run git commit with the listed files
4. Run final verification command
5. Report summary

Plan file path: $ARGUMENTS
EOF

    log_success "Copilot CLI skills installed to $skills_dir."
    log_warn "Note: Full multi-agent orchestration (separate planner/executor/verifier agents)"
    log_warn "      is available only in Claude Code. Copilot CLI uses single-agent mode."
}

uninstall_copilot() {
    local copilot_home="${GITHUB_COPILOT_HOME:-$HOME/.config/github-copilot}"
    for skill in xfeature xplan xexecute; do
        local f="$copilot_home/skills/$skill.md"
        if [ -f "$f" ]; then
            rm "$f"
            log_success "Removed $f"
        fi
    done
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo "  xflow plugin installer"
    echo "  ─────────────────────"
    echo ""

    local do_claude=false
    local do_copilot=false
    local do_uninstall=false

    case "${1:-}" in
        --claude)    do_claude=true ;;
        --copilot)   do_copilot=true ;;
        --all)       do_claude=true; do_copilot=true ;;
        --uninstall) do_uninstall=true; do_claude=true; do_copilot=true ;;
        --help|-h)
            echo "Usage: $0 [--claude | --copilot | --all | --uninstall | --help]"
            echo ""
            echo "  --claude     Install for Claude Code only"
            echo "  --copilot    Install for GitHub Copilot CLI only"
            echo "  --all        Install for both"
            echo "  --uninstall  Remove from all locations"
            echo "  (no args)    Interactive mode"
            exit 0 ;;
        "")
            # When piped (wget/curl | bash), default to --claude non-interactively
            if $PIPED; then
                log_info "No target specified — defaulting to --claude (piped mode)."
                do_claude=true
            else
                echo "Install for which environments?"
                echo "  1) Claude Code only"
                echo "  2) GitHub Copilot CLI only"
                echo "  3) Both"
                echo ""
                printf "Choose [1-3]: "
                read -r choice
                case "$choice" in
                    1) do_claude=true ;;
                    2) do_copilot=true ;;
                    3) do_claude=true; do_copilot=true ;;
                    *) log_error "Invalid choice"; exit 1 ;;
                esac
            fi ;;
        *)
            log_error "Unknown argument: $1"
            echo "Run $0 --help for usage."
            exit 1 ;;
    esac

    if $do_uninstall; then
        $do_claude  && uninstall_claude
        $do_copilot && uninstall_copilot
        log_success "Uninstall complete."
    else
        $do_claude  && install_claude  && echo ""
        $do_copilot && install_copilot && echo ""
        log_success "Installation complete."
    fi
}

main "$@"
