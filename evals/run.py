#!/usr/bin/env python3
"""Agent eval runner for the Spring Cloud AI-Native SDLC framework.

Runs each eval task non-interactively through the selected agent, then applies
the task's verify commands. Exits non-zero when the pass rate is below the
threshold so CI can gate configuration changes on the result.

Supported agents: claude (default), codex, opencode, dsh.

Usage:
  ANTHROPIC_API_KEY=... python3 evals/run.py --agent claude --threshold 0.8
  OPENAI_API_KEY=... python3 evals/run.py --agent codex --threshold 0.8
  python3 evals/run.py --agent opencode --threshold 0.8
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    print("PyYAML is required: pip install pyyaml", file=sys.stderr)
    sys.exit(2)


def parse_task(path: Path) -> dict | None:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return None
    parts = text.split("---", 2)
    if len(parts) < 2:
        return None
    meta = yaml.safe_load(parts[1])
    if not isinstance(meta, dict):
        return None
    meta["_file"] = path.name
    return meta


def build_command(agent: str, prompt: str, tools: list[str]) -> list[str]:
    """Build the headless command for the given agent."""
    if agent == "claude":
        cmd = ["claude", "-p", prompt]
        if tools:
            cmd += ["--allowedTools", ",".join(tools)]
        cmd += ["--output-format", "json"]
        return cmd
    if agent == "codex":
        cmd = ["codex", "exec", prompt, "--json", "--sandbox", "workspace-write"]
        return cmd
    if agent == "opencode":
        cmd = ["opencode", "run", prompt, "--format", "json", "--auto"]
        return cmd
    if agent == "dsh":
        return ["dsh", "headless", prompt]
    raise ValueError(f"unknown agent: {agent}")


def parse_output(agent: str, stdout: str) -> str:
    """Extract the agent's final text answer from its structured output."""
    if agent == "claude":
        try:
            payload = json.loads(stdout)
            return payload.get("result", "") if isinstance(payload, dict) else str(payload)
        except json.JSONDecodeError:
            return stdout
    if agent == "codex":
        # JSON Lines; the final message is the last `message` item.
        last = ""
        for line in stdout.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(obj, dict) and obj.get("type") in ("message", "turn.completed"):
                last = obj.get("message", last) if obj.get("type") == "message" else last
        return last or stdout
    if agent == "opencode":
        # NDJSON; take the last text part.
        parts = []
        for line in stdout.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(obj, dict):
                t = obj.get("text") or obj.get("content") or ""
                if t:
                    parts.append(t if isinstance(t, str) else json.dumps(t))
        return "\n".join(parts) or stdout
    return stdout


def run_agent(agent: str, task: dict) -> tuple[bool, str]:
    prompt = task.get("prompt", "").strip()
    if not prompt:
        return False, "empty prompt"
    cmd = build_command(agent, prompt, task.get("allowed_tools") or [])
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
    except FileNotFoundError:
        return False, f"{agent} CLI not found (install it, or choose a different --agent)"
    except subprocess.TimeoutExpired:
        return False, f"{agent} run timed out"
    if proc.returncode != 0:
        return False, f"{agent} exited {proc.returncode}: {proc.stderr[-400:]}"
    return True, parse_output(agent, proc.stdout)


def run_verify(verify: list[dict]) -> tuple[bool, str]:
    for step in verify or []:
        cmd = step.get("cmd", "")
        expect = step.get("expect", "")
        proc = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        output = (proc.stdout or "") + (proc.stderr or "")
        if proc.returncode != 0:
            return False, f"`{cmd}` exited {proc.returncode}"
        if expect and expect not in output:
            return False, f"`{cmd}` output missing expected: {expect!r}"
    return True, "verify ok"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--threshold", type=float, default=0.8)
    parser.add_argument("--tasks-dir", default=str(Path(__file__).parent / "tasks"))
    parser.add_argument("--agent", default=os.environ.get("AGENT", "claude"),
                        choices=["claude", "codex", "opencode", "dsh"])
    args = parser.parse_args()

    tasks_dir = Path(args.tasks_dir)
    tasks = []
    for path in sorted(tasks_dir.glob("*.md")):
        if path.name.upper() == "TEMPLATE.MD":
            continue
        task = parse_task(path)
        if task:
            tasks.append(task)
    if not tasks:
        print("No eval tasks found — add tasks under evals/tasks/.")
        return 2

    passed = 0
    for task in tasks:
        name = task.get("name", task["_file"])
        ok, detail = run_agent(args.agent, task)
        if not ok:
            print(f"FAIL {name}: {detail}")
            continue
        ok, detail = run_verify(task.get("verify") or [])
        if ok:
            passed += 1
            print(f"PASS {name}")
        else:
            print(f"FAIL {name}: {detail}")

    rate = passed / len(tasks)
    print(f"\n[{args.agent}] eval pass rate: {passed}/{len(tasks)} = {rate:.0%} (threshold {args.threshold:.0%})")
    return 0 if rate >= args.threshold else 1


if __name__ == "__main__":
    sys.exit(main())
