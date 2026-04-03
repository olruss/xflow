#!/usr/bin/env python3
"""xflow installer — cross-platform (stdlib only)

Usage:
  python3 install.py              # Interactive — prompts for target and scope
  python3 install.py --claude     # Claude Code, user scope
  python3 install.py --copilot    # GitHub Copilot CLI
  python3 install.py --all        # Both
  python3 install.py --uninstall  # Remove from all locations
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path

GITHUB_REPO = "olruss/xflow"

# Detect local clone (script is a real file on disk) vs piped execution
_argv0 = sys.argv[0] if sys.argv else ""
_argv0_path = Path(_argv0) if _argv0 not in ("", "-") else None
SCRIPT_DIR = _argv0_path.parent.resolve() if (_argv0_path and _argv0_path.is_file()) else None

# ANSI colours — disabled when stdout is not a terminal
_color = sys.stdout.isatty()
RED    = "\033[0;31m" if _color else ""
GREEN  = "\033[0;32m" if _color else ""
YELLOW = "\033[1;33m" if _color else ""
BLUE   = "\033[0;34m" if _color else ""
BOLD   = "\033[1m"    if _color else ""
NC     = "\033[0m"    if _color else ""


def log_info(msg):    print(f"  {BLUE}\u2192{NC} {msg}")
def log_success(msg): print(f"  {GREEN}\u2714{NC} {msg}")
def log_warn(msg):    print(f"  {YELLOW}!{NC} {msg}")
def log_error(msg):   print(f"  {RED}\u2718{NC} {msg}", file=sys.stderr)


# ── Interactive input ─────────────────────────────────────────────────────────

_tty_fh = None  # cached /dev/tty file handle


def _open_tty():
    """Open a TTY device for reading interactive input when stdin is a pipe."""
    global _tty_fh
    if _tty_fh is not None:
        return _tty_fh
    for dev in ("/dev/tty", "CON"):  # Unix / Windows
        try:
            _tty_fh = open(dev, "r")
            return _tty_fh
        except OSError:
            continue
    return None


def ask(prompt, default=""):
    """Print prompt, read a line. Reads from /dev/tty when stdin is piped; falls back to default in headless/CI."""
    sys.stdout.write(prompt)
    sys.stdout.flush()

    if sys.stdin.isatty():
        try:
            line = sys.stdin.readline()
        except (EOFError, OSError):
            line = ""
    else:
        tty = _open_tty()
        if tty:
            try:
                line = tty.readline()
            except OSError:
                print(default)
                return default
        else:
            print(default)
            return default

    ans = line.rstrip("\n").strip()
    return ans if ans else default


# ── Claude Code ───────────────────────────────────────────────────────────────

def install_claude(scope="user"):
    if not shutil.which("claude"):
        log_error("Claude Code CLI not found in PATH — install Claude Code first.")
        return False

    source = str(SCRIPT_DIR) if SCRIPT_DIR else GITHUB_REPO
    log_info(f"Source: {'local clone' if SCRIPT_DIR else f'GitHub ({GITHUB_REPO})'}")

    log_info("Registering marketplace...")
    result = subprocess.run(
        ["claude", "plugin", "marketplace", "list"],
        capture_output=True, text=True
    )
    already = any(
        line.startswith("xflow ") or line.strip() == "xflow"
        for line in result.stdout.splitlines()
    )
    if already:
        log_info("Marketplace already registered — skipping.")
    else:
        r = subprocess.run(["claude", "plugin", "marketplace", "add", source, "--scope", "user"])
        if r.returncode != 0:
            log_error("Failed to register marketplace.")
            return False
        log_success("Marketplace registered.")

    log_info(f"Installing plugin (scope: {scope})...")
    r = subprocess.run(["claude", "plugin", "install", "xflow@xflow", "--scope", scope])
    if r.returncode != 0:
        log_error("Installation failed.")
        return False
    log_success("Plugin installed.")
    return True


def uninstall_claude():
    if not shutil.which("claude"):
        log_error("Claude Code CLI not found in PATH.")
        return False
    log_info("Uninstalling from Claude Code...")
    r = subprocess.run(["claude", "plugin", "uninstall", "xflow@xflow"])
    if r.returncode != 0:
        log_warn("Plugin not found or already uninstalled.")
    else:
        log_success("Uninstalled.")
    return True


# ── GitHub Copilot CLI ────────────────────────────────────────────────────────

_COPILOT_SKILLS = {
    "xfeature": """\
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
""",
    "xplan": """\
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
""",
    "xexecute": """\
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
""",
}


def _find_copilot_home():
    env = os.environ.get("GITHUB_COPILOT_HOME")
    if env:
        return Path(env)
    candidates = [
        Path.home() / ".config" / "github-copilot",
        Path.home() / "Library" / "Application Support" / "GitHub Copilot",
    ]
    appdata = os.environ.get("APPDATA")
    if appdata:
        candidates.append(Path(appdata) / "GitHub Copilot")
    for p in candidates:
        if p.is_dir():
            return p
    return None


def install_copilot():
    copilot_home = _find_copilot_home()
    if not copilot_home:
        log_error("GitHub Copilot config directory not found.")
        log_error("Set GITHUB_COPILOT_HOME to point to your Copilot config directory.")
        return False

    skills_dir = copilot_home / "skills"
    skills_dir.mkdir(parents=True, exist_ok=True)
    log_info(f"Installing skills to {skills_dir} ...")
    for name, content in _COPILOT_SKILLS.items():
        (skills_dir / f"{name}.md").write_text(content)
    log_success("Skills installed.")
    log_warn("Full multi-agent orchestration is available only in Claude Code.")
    return True


def uninstall_copilot():
    copilot_home = _find_copilot_home() or (Path.home() / ".config" / "github-copilot")
    removed = 0
    for name in _COPILOT_SKILLS:
        f = copilot_home / "skills" / f"{name}.md"
        if f.exists():
            f.unlink()
            log_success(f"Removed {f}")
            removed += 1
    if removed == 0:
        log_warn("No Copilot CLI skills found to remove.")
    return True


# ── Interactive flow ──────────────────────────────────────────────────────────

def run_interactive():
    print()
    print(f"  {BOLD}Which AI coding assistant are you installing xflow for?{NC}")
    print()
    print("    1) Claude Code           (full multi-agent: planner + executor + verifier)")
    print("    2) GitHub Copilot CLI    (simplified single-agent mode)")
    print("    3) Both")
    print()

    cli_choice = ask("  Choice [1]: ", "1")
    if cli_choice in ("1", ""):
        do_claude, do_copilot = True, False
    elif cli_choice == "2":
        do_claude, do_copilot = False, True
    elif cli_choice == "3":
        do_claude, do_copilot = True, True
    else:
        log_error(f"Invalid choice '{cli_choice}'")
        sys.exit(1)

    scope = "user"
    if do_claude:
        print()
        print(f"  {BOLD}Install xflow for:{NC}")
        print()
        print("    1) All projects — user-wide  [recommended]")
        print("    2) This project only")
        print()
        scope_choice = ask("  Choice [1]: ", "1")
        scope = "project" if scope_choice == "2" else "user"

    print()
    print(f"  {BOLD}Summary{NC}")
    if do_claude:
        print(f"    \u2022 Claude Code  (scope: {scope})")
    if do_copilot:
        print("    \u2022 GitHub Copilot CLI")
    print()

    confirm = ask("  Install now? [Y/n]: ", "y")
    if confirm.lower().startswith("n"):
        print("  Aborted.")
        sys.exit(0)

    print()

    if do_claude:
        print(f"  {BOLD}Claude Code{NC}")
        install_claude(scope)
        print()
        print("  Commands available after restarting Claude Code:")
        print("    /xfeature <description>   — Plan + execute a feature")
        print("    /xplan <description>      — Plan only")
        print("    /xexecute [plan-path]     — Execute an approved plan")
        print()

    if do_copilot:
        print(f"  {BOLD}GitHub Copilot CLI{NC}")
        install_copilot()
        print()

    log_success("Installation complete.")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print()
    print(f"  {BOLD}xflow{NC} installer")
    print("  \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500")

    args = sys.argv[1:]
    # strip leading '-' (python3 - --flag pattern)
    args = [a for a in args if a != "-"]
    flag = args[0] if args else ""

    if flag == "--claude":
        print()
        print(f"  {BOLD}Claude Code{NC}")
        install_claude("user")
        print()
        print("  Commands (restart Claude Code to activate):")
        print("    /xfeature  /xplan  /xexecute")
        print()
        log_success("Done.")

    elif flag == "--copilot":
        print()
        print(f"  {BOLD}GitHub Copilot CLI{NC}")
        install_copilot()
        print()
        log_success("Done.")

    elif flag == "--all":
        print()
        print(f"  {BOLD}Claude Code{NC}")
        install_claude("user")
        print()
        print(f"  {BOLD}GitHub Copilot CLI{NC}")
        install_copilot()
        print()
        log_success("Done.")

    elif flag == "--uninstall":
        print()
        uninstall_claude()
        uninstall_copilot()
        print()
        log_success("Uninstall complete.")

    elif flag in ("--help", "-h"):
        script_name = Path(sys.argv[0]).name if sys.argv[0] not in ("", "-") else "install.py"
        print()
        print(f"  Usage: python3 {script_name} [option]")
        print()
        print("    (none)       Interactive — prompts for target and scope")
        print("    --claude     Claude Code, user scope")
        print("    --copilot    GitHub Copilot CLI")
        print("    --all        Both")
        print("    --uninstall  Remove from all locations")
        print()

    elif not flag:
        run_interactive()

    else:
        log_error(f"Unknown argument: {flag}")
        print(f"  Run python3 install.py --help for usage.")
        sys.exit(1)


if __name__ == "__main__":
    main()
