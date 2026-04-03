#!/usr/bin/env bash
# xflow plugin installer
#
# Usage:
#   ./install.sh              # Interactive (prompts for options)
#   ./install.sh --claude     # Claude Code, user scope (non-interactive)
#   ./install.sh --copilot    # GitHub Copilot CLI (non-interactive)
#   ./install.sh --all        # Both (non-interactive)
#   ./install.sh --uninstall  # Remove from all locations

set -euo pipefail

GITHUB_REPO="olruss/xflow"

# Local clone vs piped (wget/curl | bash): check if script file exists on disk
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "  ${BLUE}→${NC} $*"; }
log_success() { echo -e "  ${GREEN}✔${NC} $*"; }
log_warn()    { echo -e "  ${YELLOW}!${NC} $*"; }
log_error()   { echo -e "  ${RED}✘${NC} $*" >&2; }

# Read from /dev/tty when stdin is a pipe (wget/curl | bash pattern).
# Falls back to the default value silently when no terminal is available.
ask() {
    local __var="$1" __prompt="$2" __default="${3:-}"
    printf '%s' "$__prompt"
    local __ans
    if   [ -t 0 ];         then read -r __ans
    elif [ -e /dev/tty ];  then read -r __ans </dev/tty
    else __ans="$__default"; echo "$__default"
    fi
    printf -v "$__var" '%s' "${__ans:-$__default}"
}

# ── Claude Code ───────────────────────────────────────────────────────────────

install_claude() {
    local scope="${1:-user}"

    if ! command -v claude &>/dev/null; then
        log_error "Claude Code CLI not found in PATH — install Claude Code first."
        return 1
    fi

    local source
    if [[ -n "$SCRIPT_DIR" ]]; then
        source="$SCRIPT_DIR"
        log_info "Source: local clone"
    else
        source="$GITHUB_REPO"
        log_info "Source: GitHub ($GITHUB_REPO)"
    fi

    log_info "Registering marketplace..."
    if claude plugin marketplace list 2>/dev/null | grep -q "^xflow "; then
        log_info "Marketplace already registered — skipping."
    else
        claude plugin marketplace add "$source" --scope user 2>&1 \
            && log_success "Marketplace registered." \
            || { log_error "Failed to register marketplace."; return 1; }
    fi

    log_info "Installing plugin (scope: $scope)..."
    claude plugin install "xflow@xflow" --scope "$scope" 2>&1 \
        && log_success "Plugin installed." \
        || { log_error "Installation failed."; return 1; }
}

uninstall_claude() {
    if ! command -v claude &>/dev/null; then
        log_error "Claude Code CLI not found in PATH."
        return 1
    fi
    log_info "Uninstalling from Claude Code..."
    claude plugin uninstall "xflow@xflow" 2>&1 \
        && log_success "Uninstalled." \
        || log_warn "Plugin not found or already uninstalled."
}

# ── GitHub Copilot CLI ────────────────────────────────────────────────────────

install_copilot() {
    local copilot_home
    if   [[ -n "${GITHUB_COPILOT_HOME:-}" ]];                          then copilot_home="$GITHUB_COPILOT_HOME"
    elif [[ -d "$HOME/.config/github-copilot" ]];                      then copilot_home="$HOME/.config/github-copilot"
    elif [[ -d "$HOME/Library/Application Support/GitHub Copilot" ]];  then copilot_home="$HOME/Library/Application Support/GitHub Copilot"
    else
        log_error "GitHub Copilot config directory not found."
        log_error "Set GITHUB_COPILOT_HOME to point to your Copilot config directory."
        return 1
    fi

    local skills_dir="$copilot_home/skills"
    mkdir -p "$skills_dir"
    log_info "Installing skills to $skills_dir..."

    cat > "$skills_dir/xfeature.md" << 'EOF'
---
name: xfeature
description: "Plan and execute a feature end-to-end with structured phases and checkpoints (xflow — simplified Copilot CLI mode)"
---

# xfeature — Feature Implementation (Copilot CLI)

Note: Simplified single-agent mode. Full multi-agent orchestration requires Claude Code.

1. Read CLAUDE.md, README, and relevant source files
2. Ask the user 2–3 targeted clarifying questions
3. Write an implementation plan with numbered phases (files + acceptance criteria per phase)
4. Mark risky phases with ⚠️ Checkpoint — manual verify before continuing
5. Ask the user to approve the plan before making any changes
6. Execute each phase; pause at checkpoints for user confirmation
7. Run the test command and report results

Feature to implement: $ARGUMENTS
EOF

    cat > "$skills_dir/xplan.md" << 'EOF'
---
name: xplan
description: "Plan a feature with structured phases and checkpoints (xflow — simplified Copilot CLI mode)"
---

# xplan — Feature Planning (Copilot CLI)

1. Read CLAUDE.md, README, and relevant source files
2. Ask the user 2–4 targeted, specific questions
3. Write a plan with: Context section, numbered phases (files + acceptance criteria),
   inline directives ([CHECKPOINT: reason], [COMMIT: message], [PR: title]),
   and a Verification section with the exact test command
4. Present the plan and ask for approval
5. After approval: tell the user to say "execute the plan" to proceed

Feature to plan: $ARGUMENTS
EOF

    cat > "$skills_dir/xexecute.md" << 'EOF'
---
name: xexecute
description: "Execute an approved xflow plan phase by phase (xflow — simplified Copilot CLI mode)"
---

# xexecute — Execute Plan (Copilot CLI)

1. Read the plan file (path: $ARGUMENTS — ask if not provided)
2. List the phases and their directives
3. For each phase: implement changes, run acceptance criteria, pause at [CHECKPOINT]s
4. Run the final verification command
5. Report summary

Plan file: $ARGUMENTS
EOF

    log_success "Skills installed."
    log_warn "Full multi-agent orchestration is available only in Claude Code."
}

uninstall_copilot() {
    local copilot_home="${GITHUB_COPILOT_HOME:-$HOME/.config/github-copilot}"
    local removed=0
    for skill in xfeature xplan xexecute; do
        local f="$copilot_home/skills/$skill.md"
        if [[ -f "$f" ]]; then rm "$f"; log_success "Removed $f"; (( removed++ )) || true; fi
    done
    (( removed == 0 )) && log_warn "No Copilot CLI skills found to remove." || true
}

# ── Interactive flow ──────────────────────────────────────────────────────────

run_interactive() {
    echo ""

    # ── Step 1: which CLI? ──────────────────────────────────────────────────
    echo -e "  ${BOLD}Which AI coding assistant are you installing xflow for?${NC}"
    echo ""
    echo "    1) Claude Code           (full multi-agent: planner + executor + verifier)"
    echo "    2) GitHub Copilot CLI    (simplified single-agent mode)"
    echo "    3) Both"
    echo ""

    local cli_choice
    ask cli_choice "  Choice [1]: " "1"

    local do_claude=false do_copilot=false
    case "$cli_choice" in
        1|"") do_claude=true ;;
        2)    do_copilot=true ;;
        3)    do_claude=true; do_copilot=true ;;
        *)    log_error "Invalid choice '$cli_choice'"; exit 1 ;;
    esac

    # ── Step 2: Claude Code scope ───────────────────────────────────────────
    local scope="user"
    if $do_claude; then
        echo ""
        echo -e "  ${BOLD}Install xflow for:${NC}"
        echo ""
        echo "    1) All projects — user-wide  [recommended]"
        echo "    2) This project only"
        echo ""

        local scope_choice
        ask scope_choice "  Choice [1]: " "1"
        [[ "$scope_choice" == "2" ]] && scope="project" || scope="user"
    fi

    # ── Summary ─────────────────────────────────────────────────────────────
    echo ""
    echo -e "  ${BOLD}Summary${NC}"
    $do_claude  && echo "    • Claude Code  (scope: $scope)"
    $do_copilot && echo "    • GitHub Copilot CLI"
    echo ""

    local confirm
    ask confirm "  Install now? [Y/n]: " "y"
    [[ "$confirm" =~ ^[Nn] ]] && { echo "  Aborted."; exit 0; }

    echo ""

    # ── Install ──────────────────────────────────────────────────────────────
    if $do_claude; then
        echo -e "  ${BOLD}Claude Code${NC}"
        install_claude "$scope"
        echo ""
        echo -e "  Commands available after restarting Claude Code:"
        echo "    /xfeature <description>   — Plan + execute a feature"
        echo "    /xplan <description>      — Plan only"
        echo "    /xexecute [plan-path]     — Execute an approved plan"
        echo ""
    fi

    if $do_copilot; then
        echo -e "  ${BOLD}GitHub Copilot CLI${NC}"
        install_copilot
        echo ""
    fi

    log_success "Installation complete."
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo -e "  ${BOLD}xflow${NC} installer"
    echo "  ───────────────"

    case "${1:-}" in
        --claude)
            echo ""
            echo -e "  ${BOLD}Claude Code${NC}"
            install_claude "user"
            echo ""
            echo "  Commands (restart Claude Code to activate):"
            echo "    /xfeature  /xplan  /xexecute"
            echo ""
            log_success "Done." ;;
        --copilot)
            echo ""
            echo -e "  ${BOLD}GitHub Copilot CLI${NC}"
            install_copilot
            echo ""
            log_success "Done." ;;
        --all)
            echo ""
            echo -e "  ${BOLD}Claude Code${NC}"
            install_claude "user"
            echo ""
            echo -e "  ${BOLD}GitHub Copilot CLI${NC}"
            install_copilot
            echo ""
            log_success "Done." ;;
        --uninstall)
            echo ""
            uninstall_claude
            uninstall_copilot
            echo ""
            log_success "Uninstall complete." ;;
        --help|-h)
            echo ""
            echo "  Usage: $0 [option]"
            echo ""
            echo "    (none)       Interactive — prompts for target and scope"
            echo "    --claude     Claude Code, user scope"
            echo "    --copilot    GitHub Copilot CLI"
            echo "    --all        Both"
            echo "    --uninstall  Remove from all locations"
            echo ""
            exit 0 ;;
        "")
            run_interactive ;;
        *)
            log_error "Unknown argument: $1"
            echo "  Run $0 --help for usage."
            exit 1 ;;
    esac
}

main "$@"
