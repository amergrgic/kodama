#!/usr/bin/env python3
"""Kodama local telemetry — emit events, query stats, rotate logs.

All data stays local. Nothing is transmitted over the network.
Only agent names, timestamps, session IDs, and numeric counts are stored.
Never captures prompts, code, file contents, or paths.
"""
import json
import os
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

STATE_DIR = Path(os.environ.get("KIRO_DIR", Path.home() / ".kiro")) / "kodama"
TELEMETRY_DIR = STATE_DIR / "telemetry"
EVENTS_LOG = TELEMETRY_DIR / "events.jsonl"
SESSION_FILE = TELEMETRY_DIR / "current-session.json"

SESSION_TIMEOUT_S = 1800  # 30 minutes
MAX_LOG_SIZE = 1_048_576  # 1 MB
MAX_ROTATED_FILES = 4
MAX_AGE_DAYS = 90


def now_iso():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def load_session():
    if SESSION_FILE.exists():
        try:
            return json.loads(SESSION_FILE.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return None
    return None


def save_session(session):
    SESSION_FILE.write_text(
        json.dumps(session, separators=(",", ":")) + "\n", encoding="utf-8"
    )


def is_stale(session):
    last = session.get("last_activity", "")
    if not last:
        return True
    try:
        last_ts = datetime.fromisoformat(last).timestamp()
        return (time.time() - last_ts) > SESSION_TIMEOUT_S
    except (ValueError, OSError):
        return True


def append_event(event):
    TELEMETRY_DIR.mkdir(parents=True, exist_ok=True)
    with EVENTS_LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, separators=(",", ":")) + "\n")


def finalize_session(session, completed=False):
    started = session.get("started", "")
    last = session.get("last_activity", started)
    duration_s = 0
    try:
        t_start = datetime.fromisoformat(started).timestamp()
        t_end = datetime.fromisoformat(last).timestamp()
        duration_s = max(0, int(t_end - t_start))
    except (ValueError, OSError):
        pass
    append_event({
        "ts": now_iso(),
        "event": "session_end",
        "sid": session.get("sid", ""),
        "duration_s": duration_s,
        "completed": completed,
        "agents": session.get("spawns", []),
        "delegations": session.get("delegations", 0),
    })


def new_session(agent, ts_iso):
    sid = uuid.uuid4().hex[:8]
    session = {
        "sid": sid,
        "started": ts_iso,
        "last_activity": ts_iso,
        "spawns": [agent],
        "delegations": 0,
        "errors": 0,
    }
    save_session(session)
    return session


def check_completion():
    """Heuristic: if no handoff files remain, the previous session completed."""
    handoffs_dir = STATE_DIR.parent / "kodama" / "handoffs"
    if not handoffs_dir.exists():
        return True
    return not any(handoffs_dir.iterdir())


def rotate_if_needed():
    if not EVENTS_LOG.exists():
        return
    try:
        size = EVENTS_LOG.stat().st_size
    except OSError:
        return
    if size <= MAX_LOG_SIZE:
        return
    # Rotate: shift numbered files up
    for i in range(MAX_ROTATED_FILES, 0, -1):
        src = EVENTS_LOG.with_suffix(f".jsonl.{i - 1}") if i > 1 else EVENTS_LOG
        dst = EVENTS_LOG.with_suffix(f".jsonl.{i}")
        if i == MAX_ROTATED_FILES and dst.exists():
            dst.unlink()
        if src.exists():
            src.rename(dst)
    EVENTS_LOG.touch()
    # Age purge
    cutoff = time.time() - (MAX_AGE_DAYS * 86400)
    for rotated in TELEMETRY_DIR.glob("events.jsonl.*"):
        try:
            if rotated.stat().st_mtime < cutoff:
                rotated.unlink()
        except OSError:
            pass


def emit(event_type, agent, **extra):
    """Record a single event. Manages sessions automatically."""
    TELEMETRY_DIR.mkdir(parents=True, exist_ok=True)
    ts = now_iso()

    session = load_session()
    if session is None or is_stale(session):
        if session:
            finalize_session(session, completed=check_completion())
        session = new_session(agent, ts)
        append_event({"ts": ts, "event": "session_start", "sid": session["sid"], "agent": agent})

    # Update session
    session["last_activity"] = ts
    if agent not in session["spawns"]:
        session["spawns"].append(agent)
    if event_type == "delegation":
        session["delegations"] = session.get("delegations", 0) + 1
    if event_type == "error":
        session["errors"] = session.get("errors", 0) + 1
    save_session(session)

    # Write event
    event = {"ts": ts, "event": event_type, "sid": session["sid"], "agent": agent}
    event.update(extra)
    append_event(event)
    rotate_if_needed()


def read_events(period_days=30):
    """Read events from all log files within the given period."""
    cutoff = time.time() - (period_days * 86400)
    events = []
    log_files = [EVENTS_LOG] + sorted(TELEMETRY_DIR.glob("events.jsonl.*"))
    for log_file in log_files:
        if not log_file.exists():
            continue
        try:
            for line in log_file.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                    ts_str = ev.get("ts", "")
                    ts_epoch = datetime.fromisoformat(ts_str).timestamp() if ts_str else 0
                    if ts_epoch >= cutoff:
                        events.append(ev)
                except (json.JSONDecodeError, ValueError):
                    continue
        except OSError:
            continue
    return events


def query(period_days=30):
    """Aggregate stats from event log files."""
    events = read_events(period_days)
    if not events:
        return None

    sessions = {}
    agent_spawns = {}
    total_errors = 0

    for ev in events:
        sid = ev.get("sid", "")
        event_type = ev.get("event", "")
        agent = ev.get("agent", "")

        if event_type == "session_start":
            sessions[sid] = {
                "started": ev.get("ts", ""),
                "ended": None,
                "completed": None,
                "duration_s": 0,
                "agents": [],
                "delegations": 0,
            }
        elif event_type == "session_end":
            if sid in sessions:
                sessions[sid]["ended"] = ev.get("ts", "")
                sessions[sid]["completed"] = ev.get("completed", False)
                sessions[sid]["duration_s"] = ev.get("duration_s", 0)
                sessions[sid]["agents"] = ev.get("agents", [])
                sessions[sid]["delegations"] = ev.get("delegations", 0)
        elif event_type == "agent_spawn":
            agent_spawns[agent] = agent_spawns.get(agent, 0) + 1
            if sid in sessions:
                if agent not in sessions[sid]["agents"]:
                    sessions[sid]["agents"].append(agent)
        elif event_type == "error":
            total_errors += 1

    # Compute aggregates
    total_sessions = len(sessions)
    completed = sum(1 for s in sessions.values() if s.get("completed") is True)
    abandoned = sum(1 for s in sessions.values() if s.get("completed") is False)
    durations = [s["duration_s"] for s in sessions.values() if s.get("duration_s", 0) > 0]
    avg_duration = int(sum(durations) / len(durations)) if durations else 0
    total_delegations = sum(s.get("delegations", 0) for s in sessions.values())
    avg_delegations = round(total_delegations / total_sessions, 1) if total_sessions else 0

    return {
        "period_days": period_days,
        "sessions": {
            "total": total_sessions,
            "completed": completed,
            "abandoned": abandoned,
            "in_progress": total_sessions - completed - abandoned,
            "avg_duration_s": avg_duration,
        },
        "agents": agent_spawns,
        "delegations": {
            "total": total_delegations,
            "avg_per_session": avg_delegations,
        },
        "errors": total_errors,
    }


def format_duration(seconds):
    if seconds < 60:
        return f"{seconds}s"
    minutes = seconds // 60
    secs = seconds % 60
    if minutes < 60:
        return f"{minutes}m {secs:02d}s" if secs else f"{minutes}m"
    hours = minutes // 60
    mins = minutes % 60
    return f"{hours}h {mins:02d}m"


def format_bar(count, max_count, width=20):
    if max_count == 0:
        return "░" * width
    filled = int((count / max_count) * width)
    return "█" * filled + "░" * (width - filled)


def print_report(stats):
    """Print a human-readable stats report."""
    if stats is None:
        print("  No telemetry data recorded yet.")
        print("  Enable with: kodama stats --enable")
        return

    s = stats["sessions"]
    period = stats["period_days"]

    print(f"\n  \033[1m━━ Kodama Usage (last {period} days) ━━\033[0m\n")

    # Sessions
    print("  Sessions")
    print(f"    Total:        {s['total']}")
    if s["avg_duration_s"]:
        print(f"    Avg duration: {format_duration(s['avg_duration_s'])}")
    if s["completed"] or s["abandoned"]:
        comp_pct = int(s["completed"] / s["total"] * 100) if s["total"] else 0
        print(f"    Completed:    {s['completed']} ({comp_pct}%)")
        if s["abandoned"]:
            print(f"    Abandoned:    {s['abandoned']}")
    if s["in_progress"]:
        print(f"    In progress:  {s['in_progress']}")
    print()

    # Agent activity
    agents = stats["agents"]
    if agents:
        print("  Agent Activity")
        # Sort by spawn count descending, skip kodama (it's always 100%)
        sorted_agents = sorted(agents.items(), key=lambda x: x[1], reverse=True)
        max_spawns = sorted_agents[0][1] if sorted_agents else 1
        max_name_len = max(len(a) for a, _ in sorted_agents)
        for agent, count in sorted_agents:
            bar = format_bar(count, max_spawns)
            pct = int(count / s["total"] * 100) if s["total"] else 0
            name_padded = agent.ljust(max_name_len)
            print(f"    {name_padded}  {count:3d} spawns  │{bar}│ {pct:3d}%")
        print()

    # Delegations
    d = stats["delegations"]
    if d["total"]:
        print("  Delegations")
        print(f"    Total:        {d['total']}")
        print(f"    Avg/session:  {d['avg_per_session']}")
        print()

    # Errors
    if stats["errors"]:
        print("  Errors")
        print(f"    Total:        {stats['errors']}")
        print()

    # Footer
    data_size = "0 KB"
    if EVENTS_LOG.exists():
        total_bytes = EVENTS_LOG.stat().st_size
        for rotated in TELEMETRY_DIR.glob("events.jsonl.*"):
            total_bytes += rotated.stat().st_size
        data_size = f"{total_bytes // 1024} KB" if total_bytes >= 1024 else f"{total_bytes} B"
    print(f"  Data: {TELEMETRY_DIR}/events.jsonl ({data_size})")
    print()


def main():
    # Usage: kodama-telemetry.py <emit|query|rotate|finalize> [args...]
    # emit <event_type> <agent_name>
    # query [--period N] [--json]
    # rotate
    # finalize
    if len(sys.argv) < 2:
        print("usage: kodama-telemetry.py <emit|query|rotate|finalize> [args...]", file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    args = sys.argv[2:]

    if cmd == "emit":
        if not args:
            print("usage: kodama-telemetry.py emit <event_type> [agent_name]", file=sys.stderr)
            sys.exit(1)
        event_type = args[0]
        agent = args[1] if len(args) > 1 else "kodama"
        emit(event_type, agent)

    elif cmd == "query":
        period = 30
        as_json = False
        i = 0
        while i < len(args):
            if args[i] in ("--period", "-p") and i + 1 < len(args):
                period = int(args[i + 1])
                i += 2
            elif args[i] == "--json":
                as_json = True
                i += 1
            else:
                i += 1
        stats = query(period)
        if as_json:
            print(json.dumps(stats, indent=2))
        else:
            print_report(stats)

    elif cmd == "rotate":
        rotate_if_needed()

    elif cmd == "finalize":
        session = load_session()
        if session and is_stale(session):
            finalize_session(session, completed=check_completion())
            SESSION_FILE.unlink(missing_ok=True)

    else:
        print(f"unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
