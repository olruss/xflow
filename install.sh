#!/usr/bin/env bash
# xflow installer — bash shim, delegates to install.py (python3)
#
# Usage: same flags as install.py
#   ./install.sh              # Interactive
#   ./install.sh --claude     # Claude Code, user scope
#   ./install.sh --copilot    # GitHub Copilot CLI
#   ./install.sh --all        # Both
#   ./install.sh --uninstall  # Remove from all locations

set -euo pipefail

GITHUB_RAW="https://raw.githubusercontent.com/olruss/xflow/main/install.py"

# Detect local clone vs piped execution
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/install.py" ]]; then
    exec python3 "$SCRIPT_DIR/install.py" "$@"
else
    # Piped via curl/wget — fetch and run install.py
    exec python3 <(curl -fsSL "$GITHUB_RAW") "$@"
fi
