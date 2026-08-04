"""Kodama project memory — per-project context persistence for agents.

Memory is stored as Markdown files in <project-root>/.kiro/kodama/memory/.
Categories: facts, decisions, failures, conventions, architecture, sessions.
A generated context.md is loaded by agents as a resource at session start.
"""
import os
import re
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

CATEGORIES = ["facts", "decisions", "failures", "conventions", "architecture", "sessions"]
CONTEXT_FILE = "context.md"
CONTEXT_BUDGET = 4096

# --- Privacy filter -------------------------------------------------------

SECRET_PATTERNS = [
    re.compile(r'[A-Za-z0-9+/=]{40,}'),
    re.compile(r'password\s*=', re.IGNORECASE),
    re.compile(r'token\s*=', re.IGNORECASE),
    re.compile(r'Bearer\s+', re.IGNORECASE),
    re.compile(r'AKIA[A-Z0-9]'),
    re.compile(r'ghp_[A-Za-z0-9]'),
    re.compile(r'gho_[A-Za-z0-9]'),
    re.compile(r'sk-[A-Za-z0-9]'),
    re.compile(r'sk_live_'),
    re.compile(r'pk_live_'),
]

SENSITIVE_PATH_PARTS = ['.env', 'credentials', 'secrets', 'private_key', 'id_rsa']


def is_secret(text):
    for pattern in SECRET_PATTERNS:
        if pattern.search(text):
            return True
    lower = text.lower()
    for part in SENSITIVE_PATH_PARTS:
        if part in lower:
            return True
    return False


# --- Project root detection ------------------------------------------------

# Module-level override set by --project flag (per-invocation, no persistence)
_project_override = None


def detect_project_root():
    """Detect the project root directory.

    Strategy (first match wins):
    1. Module-level override from --project argument
    2. KODAMA_PROJECT_ROOT environment variable (set by kodama.sh wrapper)
    3. git rev-parse --show-toplevel
    4. Walk up from CWD looking for .kiro/ directory
    5. Fail closed — print error and exit (never write to a random directory)
    """
    # 1. Explicit --project override for this invocation
    if _project_override is not None:
        p = Path(_project_override).resolve()
        if p.is_dir():
            return p

    # 2. Environment variable (set by the wrapper at session start)
    env_root = os.environ.get("KODAMA_PROJECT_ROOT", "").strip()
    if env_root:
        p = Path(env_root)
        if p.is_dir():
            return p

    # 3. Git root
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            root = result.stdout.strip()
            if root:
                return Path(root)
    except (OSError, subprocess.TimeoutExpired):
        pass

    # 4. Walk up looking for .kiro/
    cwd = Path.cwd().resolve()
    current = cwd
    while True:
        if (current / ".kiro").is_dir():
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent

    # 5. Fall back to CWD (least surprising default)
    return cwd


def memory_dir(project_root=None):
    """Return the memory directory path for the given project root."""
    if project_root is None:
        project_root = detect_project_root()
    return project_root / ".kiro" / "kodama" / "memory"


# --- Helpers ---------------------------------------------------------------

BOLD = "\033[1m"
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
RESET = "\033[0m"


def category_path(mem_dir, category):
    return mem_dir / f"{category}.md"


def ensure_category_file(mem_dir, category):
    """Create the memory directory and category file if they don't exist."""
    mem_dir.mkdir(parents=True, exist_ok=True)
    path = category_path(mem_dir, category)
    if not path.exists():
        header = category.capitalize()
        path.write_text(f"# {header}\n\n", encoding="utf-8")
    return path


def read_category(mem_dir, category):
    """Read a category file, returning its content or None if missing."""
    path = category_path(mem_dir, category)
    if path.exists():
        return path.read_text(encoding="utf-8")
    return None


def count_entries(content):
    """Count lines starting with '- ' (memory entries)."""
    return sum(1 for line in content.splitlines() if line.startswith("- "))


def extract_entries(content):
    """Extract entry lines from a category file (lines starting with '- ')."""
    return [line for line in content.splitlines() if line.startswith("- ")]


def rebuild_file(header_line, entries):
    """Rebuild a category file from its header and a list of entry lines."""
    return header_line + "\n\n" + "\n".join(entries) + "\n"


def get_header(content):
    """Return the first line (# Header) of a category file."""
    lines = content.splitlines()
    for line in lines:
        if line.startswith("# "):
            return line
    return "# Memory"


# --- Subcommands -----------------------------------------------------------

def cmd_context():
    """Generate context.md from all memory files within budget."""
    root = detect_project_root()
    mem = memory_dir(root)
    context_path = mem / CONTEXT_FILE

    # Priority order for budget allocation
    priority_order = ["facts", "conventions", "failures", "decisions", "architecture", "sessions"]
    entry_limits = {
        "failures": 10,
        "decisions": 10,
        "sessions": 5,
    }

    # Read available content
    sections = {}
    for cat in priority_order:
        content = read_category(mem, cat)
        if content:
            sections[cat] = content

    if not sections:
        mem.mkdir(parents=True, exist_ok=True)
        context_path.write_text("# Project Memory\n\nNo project memory recorded yet.\n", encoding="utf-8")
        return

    # Build content respecting entry limits per category
    def build_section(cat, content):
        limit = entry_limits.get(cat)
        if limit is None:
            return content
        entries = extract_entries(content)
        if len(entries) <= limit:
            return content
        header = get_header(content)
        trimmed = entries[-limit:]
        return rebuild_file(header, trimmed)

    # Assemble within budget
    parts = []
    total = 0
    for cat in priority_order:
        if cat not in sections:
            continue
        section_text = build_section(cat, sections[cat])
        section_bytes = len(section_text.encode("utf-8"))
        if total + section_bytes <= CONTEXT_BUDGET:
            parts.append(section_text)
            total += section_bytes
        else:
            # Try to fit what we can from this section
            remaining = CONTEXT_BUDGET - total
            if remaining > 50:
                truncated = section_text.encode("utf-8")[:remaining].decode("utf-8", errors="ignore")
                # Cut at last newline for cleanliness
                last_nl = truncated.rfind("\n")
                if last_nl > 0:
                    truncated = truncated[:last_nl + 1]
                parts.append(truncated)
            break

    mem.mkdir(parents=True, exist_ok=True)
    context_path.write_text("\n".join(parts), encoding="utf-8")


def cmd_write(category, entry):
    """Append an entry to a category file after privacy checks."""
    if category not in CATEGORIES:
        print(f"  {YELLOW}⚠{RESET} Unknown category: {category}", file=sys.stderr)
        print(f"  Valid categories: {', '.join(CATEGORIES)}", file=sys.stderr)
        sys.exit(1)

    # Privacy filter
    if is_secret(entry):
        print(f"  {YELLOW}⚠{RESET} Rejected: entry contains sensitive content (token, secret, or credential pattern).")
        sys.exit(1)

    root = detect_project_root()
    mem = memory_dir(root)
    path = ensure_category_file(mem, category)

    today = date.today().isoformat()
    line = f"- {entry} <!-- updated: {today} -->\n"

    with path.open("a", encoding="utf-8") as f:
        f.write(line)

    print(f"  {GREEN}✓{RESET} Written to {category}.md")


def cmd_show(category=None):
    """Print current memory for the detected project."""
    root = detect_project_root()
    mem = memory_dir(root)

    if not mem.exists():
        print(f"  {CYAN}▸{RESET} No project memory recorded yet.")
        print(f"  {CYAN}▸{RESET} Project root: {root}")
        return

    cats = [category] if category else CATEGORIES

    found_any = False
    for cat in cats:
        content = read_category(mem, cat)
        if content:
            found_any = True
            print(f"\n  {BOLD}{cat.upper()}{RESET}")
            for line in content.splitlines():
                if line.startswith("# "):
                    continue
                if line.strip():
                    print(f"  {line}")
            print()

    if not found_any:
        if category:
            print(f"  {CYAN}▸{RESET} No entries in {category}.md")
        else:
            print(f"  {CYAN}▸{RESET} No project memory recorded yet.")


def cmd_reset():
    """Delete all memory files for the detected project."""
    root = detect_project_root()
    mem = memory_dir(root)

    if not mem.exists():
        print(f"  {CYAN}▸{RESET} No memory directory to reset.")
        return

    shutil.rmtree(mem)
    print(f"  {GREEN}✓{RESET} Project memory reset. All files removed from:")
    print(f"    {mem}")


def cmd_audit():
    """Scan memory files for potential secrets."""
    root = detect_project_root()
    mem = memory_dir(root)

    if not mem.exists():
        print(f"  {GREEN}✓{RESET} No memory files to audit.")
        return

    issues = []
    for cat in CATEGORIES:
        path = category_path(mem, cat)
        if not path.exists():
            continue
        lines = path.read_text(encoding="utf-8").splitlines()
        for line_num, line in enumerate(lines, 1):
            if is_secret(line):
                # Identify which pattern matched
                matched = "sensitive path pattern"
                for pattern in SECRET_PATTERNS:
                    if pattern.search(line):
                        matched = pattern.pattern
                        break
                issues.append((f"{cat}.md", line_num, matched))

    if not issues:
        print(f"  {GREEN}✓{RESET} All memory files are clean.")
        return

    print(f"\n  {BOLD}{YELLOW}⚠ Potential secrets found:{RESET}\n")
    for filename, line_num, pattern in issues:
        print(f"  {filename}:{line_num}  matched: {pattern}")
    print()
    sys.exit(1)


def cmd_compact():
    """Compact memory files by trimming old entries."""
    root = detect_project_root()
    mem = memory_dir(root)

    if not mem.exists():
        print(f"  {CYAN}▸{RESET} No memory files to compact.")
        return

    summary = []
    for cat in CATEGORIES:
        path = category_path(mem, cat)
        if not path.exists():
            continue

        content = path.read_text(encoding="utf-8")
        entries = extract_entries(content)
        header = get_header(content)

        max_entries = 20 if cat == "sessions" else 50
        file_size = path.stat().st_size

        if len(entries) > max_entries or file_size > 32768:
            kept = entries[-max_entries:]
            new_content = rebuild_file(header, kept)
            path.write_text(new_content, encoding="utf-8")
            removed = len(entries) - len(kept)
            summary.append(f"{cat}.md: removed {removed} entries (kept {len(kept)})")

    if summary:
        print(f"\n  {BOLD}Compacted:{RESET}")
        for line in summary:
            print(f"  {GREEN}✓{RESET} {line}")
        print()
    else:
        print(f"  {CYAN}▸{RESET} All files within limits. Nothing to compact.")


# --- Main dispatch ---------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print("usage: kodama-memory.py <context|write|show|reset|audit|compact> [options]", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    args = sys.argv[2:]

    # Global --project flag: override project root detection (per-invocation only)
    project_override = None
    filtered_args = []
    i = 0
    while i < len(args):
        if args[i] == "--project" and i + 1 < len(args):
            project_override = args[i + 1]
            i += 2
        else:
            filtered_args.append(args[i])
            i += 1
    args = filtered_args

    # Set the module-level override (no file writes, no global state)
    global _project_override
    if project_override:
        _project_override = project_override

    if cmd == "context":
        cmd_context()

    elif cmd == "write":
        category = None
        entry = None
        i = 0
        while i < len(args):
            if args[i] in ("--category", "-c") and i + 1 < len(args):
                category = args[i + 1]
                i += 2
            elif args[i] in ("--entry", "-e") and i + 1 < len(args):
                entry = args[i + 1]
                i += 2
            else:
                i += 1
        if not category or not entry:
            print("usage: kodama-memory.py write --category <cat> --entry \"<text>\"", file=sys.stderr)
            sys.exit(1)
        cmd_write(category, entry)

    elif cmd == "show":
        category = None
        i = 0
        while i < len(args):
            if args[i] in ("--category", "-c") and i + 1 < len(args):
                category = args[i + 1]
                i += 2
            else:
                i += 1
        cmd_show(category)

    elif cmd == "reset":
        cmd_reset()

    elif cmd == "audit":
        cmd_audit()

    elif cmd == "compact":
        cmd_compact()

    else:
        print(f"unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
