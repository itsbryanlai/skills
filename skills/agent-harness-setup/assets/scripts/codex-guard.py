#!/usr/bin/env python3
"""Adapt Codex hook input to the shared local guard. Never execute the input command."""
import json
from pathlib import Path
import re
import subprocess
import sys

def deny(reason):
    print("Blocked by agent-harness guard: " + reason, file=sys.stderr)
    sys.exit(2)

try:
    event = json.load(sys.stdin)
except (ValueError, TypeError):
    deny("invalid hook event")
name = event.get("tool_name", "")
args = event.get("tool_input", {})
if re.search(r"(?:merge_pull_request|merge_pr|set_auto_merge|enable_auto_merge|approve_pull_request)", name, re.I):
    deny("PR merge, approval and auto-merge require human review")
if re.search(r"(?:pull_request_review|review_pull_request)", name, re.I) and str(args.get("event", args.get("action", ""))).upper() == "APPROVE":
    deny("PR approval requires human review")
cmd = args.get("command", args.get("cmd", ""))
if not isinstance(cmd, str):
    deny("invalid shell command")
if name in ("Bash", "exec_command", "shell", "shell_command") and not cmd:
    deny("missing shell command")
event["tool_input"] = {"command": cmd}
event["cwd"] = args.get("workdir") or event.get("cwd") or str(Path.cwd())
guard = Path(__file__).with_name("guard.sh")
try:
    result = subprocess.run([str(guard)], input=json.dumps(event), text=True, capture_output=True)
except OSError as exc:
    deny("shared guard unavailable: " + str(exc))
if result.returncode:
    deny(result.stderr.strip() or "shared guard failed")
