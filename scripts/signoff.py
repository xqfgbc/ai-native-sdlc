#!/usr/bin/env python3
"""scripts/signoff.py — local web tool for human sign-off of knowledge proposals.

Runs on 127.0.0.1 only, uses the Python standard library, and executes the same
scripts a human would run:
  - promote: bash scripts/promote-proposal.sh . <id> <owner> <advisory|deterministic>
  - sync:    bash scripts/sync-cognition.sh . <service-repo>

The tool never signs anything by itself: a person enters their name/e-mail and
clicks sign. A per-run CSRF token protects the POST endpoints.

Usage: python3 scripts/signoff.py [--port 8765]
"""
import argparse
import json
import os
import secrets
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOKEN = secrets.token_urlsafe(24)
LOCK = threading.Lock()


def rel(path):
    return os.path.relpath(path, ROOT)


def read_json(path, fallback):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return fallback


def proposals():
    directory = os.path.join(ROOT, "knowledge", "proposals")
    items = []
    if os.path.isdir(directory):
        for name in sorted(os.listdir(directory)):
            if name.endswith(".json"):
                data = read_json(os.path.join(directory, name), None)
                if isinstance(data, dict):
                    items.append(data)
    return items


def pack():
    data = read_json(os.path.join(ROOT, "knowledge", "pack.json"), {})
    metadata = data.get("metadata", {})
    return {"version": metadata.get("version", "?"), "items": data.get("items", [])}


def services():
    registry = read_json(os.path.join(ROOT, "loop", "04-build", "services.json"), {})
    result = []
    for entry in registry.get("services", []):
        repo = entry.get("repo", "")
        local = None
        if repo and os.path.isdir(repo):
            local = repo
        elif "/" in repo:
            candidate = os.path.join(os.path.dirname(ROOT), repo.split("/")[-1])
            if os.path.isdir(candidate):
                local = candidate
        result.append({"name": entry.get("name"), "repo": repo, "localPath": local,
                       "exists": bool(local)})
    return result


def run(args, dry_run):
    command = " ".join(args)
    if dry_run:
        return {"ok": True, "dryRun": True, "command": command, "output": "(dry run)"}
    try:
        finished = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        return {"ok": False, "command": command, "output": "timed out after 120s"}
    output = (finished.stdout or "") + (finished.stderr or "")
    return {"ok": finished.returncode == 0, "command": command, "output": output.strip()}


def promote(payload):
    proposal_id = str(payload.get("id", "")).strip()
    owner = str(payload.get("owner", "")).strip()
    enforcement = str(payload.get("enforcement", "")).strip()
    dry_run = bool(payload.get("dryRun"))
    valid_ids = {item.get("id") for item in proposals()}
    if proposal_id not in valid_ids:
        return 400, {"ok": False, "output": "unknown proposal id"}
    if not owner:
        return 400, {"ok": False, "output": "owner (name or e-mail) is required"}
    if enforcement not in ("advisory", "deterministic"):
        return 400, {"ok": False, "output": "enforcement must be advisory or deterministic"}
    args = ["bash", "scripts/promote-proposal.sh", ".", proposal_id, owner, enforcement]
    return 200, run(args, dry_run)


def sync(payload):
    name = str(payload.get("service", "")).strip()
    dry_run = bool(payload.get("dryRun"))
    targets = [s for s in services() if s["name"] == name]
    if not targets:
        return 400, {"ok": False, "output": "unknown service"}
    target = targets[0]
    if not target["exists"]:
        return 400, {"ok": False, "output": "service repo is not available locally: " + str(target["repo"])}
    args = ["bash", "scripts/sync-cognition.sh", ".", target["localPath"]]
    return 200, run(args, dry_run)


PAGE = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Knowledge sign-off</title>
<style>
:root{--bg:#f6f7f9;--card:#fff;--ink:#1c2430;--muted:#6b7785;--line:#e3e7ee;--accent:#2f5bd3;--warn:#b45309;--ok:#0f7b4f;--bad:#b42318}
@media (prefers-color-scheme: dark){:root{--bg:#121821;--card:#1a2230;--ink:#e8edf5;--muted:#9aa7b8;--line:#2a3444;--accent:#7aa2ff;--warn:#f0b35d;--ok:#5fd3a1;--bad:#ff8b7d}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
main{max-width:980px;margin:0 auto;padding:28px 18px 64px}
h1{font-size:24px;margin:0 0 4px}h2{font-size:16px;margin:0 0 12px}
.sub{color:var(--muted);margin:0 0 24px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:18px;margin-bottom:16px}
.row{display:flex;gap:16px;flex-wrap:wrap;align-items:flex-end}
label{display:block;font-size:13px;color:var(--muted);margin-bottom:4px}
input,select{font:inherit;color:inherit;background:transparent;border:1px solid var(--line);border-radius:8px;padding:8px 10px;min-width:220px}
button{font:inherit;border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:8px;padding:8px 14px;cursor:pointer}
button.primary{background:var(--accent);border-color:var(--accent);color:#fff}
button:disabled{opacity:.5;cursor:not-allowed}
.chip{display:inline-block;font-size:12px;border:1px solid var(--line);border-radius:999px;padding:2px 8px;color:var(--muted);margin-right:6px}
.chip.warn{color:var(--warn);border-color:var(--warn)}
.chip.ok{color:var(--ok);border-color:var(--ok)}
pre{background:var(--bg);border:1px solid var(--line);border-radius:8px;padding:12px;overflow:auto;white-space:pre-wrap;margin:12px 0 0;font-size:12.5px}
.muted{color:var(--muted)} .mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
.grid{display:grid;gap:16px;grid-template-columns:repeat(auto-fit,minmax(280px,1fr))}
#log{min-height:70px}
</style></head><body><main>
<h1>知识签核</h1>
<p class="sub">人工门禁：由人填写 owner 并签核；AI 不能代签。页面只监听 127.0.0.1。</p>
<section class="card"><h2>现状</h2><div id="state" class="muted">加载中…</div></section>
<section id="list"></section>
<section class="card"><h2>下发认知包</h2><div id="services" class="muted">加载中…</div><div id="log"></div></section>
</main>
<script>
const TOKEN = "__TOKEN__";
const call = async (method, path, body) => {
  const res = await fetch(path, {method, headers: {"Content-Type": "application/json", "X-Signoff-Token": TOKEN}, body: body ? JSON.stringify(body) : undefined});
  return res.json();
};
const esc = (value) => String(value ?? "").replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","\\"":"&quot;"}[c]));
const log = (data) => {
  document.getElementById("log").innerHTML = "<pre>" + esc((data.command || "") + "\\n" + (data.output || "")) + "</pre>";
};
async function load() {
  const state = await call("GET", "/api/state");
  document.getElementById("state").innerHTML =
    `项目 <b>${esc(state.project)}</b> · pack <span class="mono">v${esc(state.pack.version)}</span> · active ${state.pack.items.length} 条 · 待签核 ${state.proposals.length} 条`;
  const list = document.getElementById("list");
  if (!state.proposals.length) {
    list.innerHTML = '<section class="card"><h2>待签核</h2><p class="muted">没有待签核的 proposal。</p></section>';
  } else {
    list.innerHTML = state.proposals.map(p => `
      <section class="card">
        <h2>${esc(p.title)}</h2>
        <div><span class="chip">${esc(p.type)}</span><span class="chip">${esc(p.id)}</span>
          <span class="chip ${p.repeat ? "warn" : ""}">repeat ${p.repeatCount ?? 1}${p.repeat ? " · 建议提升" : ""}</span></div>
        <p>${esc(p.statement || "")}</p>
        <p class="muted mono">provenance: ${esc((p.provenance || []).join(", "))}</p>
        <div class="row">
          <div><label>owner（你的名字或邮箱）</label><input id="owner-${esc(p.id)}" placeholder="例如 zhangsan@example.com" oninput="updateCmd('${esc(p.id)}')"></div>
          <div><label>enforcement</label><select id="enf-${esc(p.id)}" onchange="updateCmd('${esc(p.id)}')">
            <option value="deterministic">deterministic（需落成 hook/lint/CI）</option>
            <option value="advisory">advisory（建议性）</option></select></div>
          <button class="primary" onclick="promote('${esc(p.id)}')">签核</button>
        </div>
        <pre class="mono" id="cmd-${esc(p.id)}"></pre>
      </section>`).join("");
  }
  const services = document.getElementById("services");
  services.innerHTML = state.services.map(s => `
    <div class="row" style="margin:8px 0">
      <div><b>${esc(s.name)}</b> <span class="muted mono">${esc(s.repo)}</span>
        ${s.exists ? '<span class="chip ok">本地可用</span>' : '<span class="chip warn">本地不可用</span>'}</div>
      <button ${s.exists ? "" : "disabled"} onclick="sync('${esc(s.name)}')">下发</button>
    </div>`).join("") || '<p class="muted">services.json 里没有服务。</p>';
}
function commandFor(id) {
  const owner = document.getElementById("owner-" + id).value.trim() || "<你的名字或邮箱>";
  const enforcement = document.getElementById("enf-" + id).value;
  return "bash scripts/promote-proposal.sh . " + id + " " + owner + " " + enforcement;
}
function updateCmd(id) {
  const el = document.getElementById("cmd-" + id);
  if (el) el.textContent = commandFor(id);
}
async function promote(id) {
  const owner = document.getElementById("owner-" + id).value.trim();
  const enforcement = document.getElementById("enf-" + id).value;
  if (!owner) { alert("请填写 owner：签核必须由人完成"); return; }
  const command = commandFor(id);
  if (!confirm("将执行：\n" + command + "\n\n确认签核？")) return;
  const data = await call("POST", "/api/promote", {id, owner, enforcement});
  log(data); load();
}
async function sync(name) {
  if (!confirm("把 pack 下发到 " + name + "？服务仓的 service.json 会被钉版本。")) return;
  const data = await call("POST", "/api/sync", {service: name});
  log(data); load();
}
load();
</script></body></html>
"""


class Handler(BaseHTTPRequestHandler):
    server_version = "Signoff/1.0"

    def log_message(self, fmt, *args):
        sys.stderr.write("signoff: " + (fmt % args) + "\n")

    def send_json(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            body = PAGE.replace("__TOKEN__", TOKEN).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path == "/api/state":
            project = os.path.basename(ROOT)
            project = project[:-len("-control-plane")] if project.endswith("-control-plane") else project
            with LOCK:
                self.send_json(200, {"project": project, "pack": pack(), "proposals": proposals(),
                                     "services": services()})
            return
        self.send_json(404, {"ok": False, "output": "not found"})

    def do_POST(self):
        if self.headers.get("X-Signoff-Token") != TOKEN:
            self.send_json(403, {"ok": False, "output": "missing or invalid sign-off token"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, json.JSONDecodeError):
            self.send_json(400, {"ok": False, "output": "invalid JSON body"})
            return
        with LOCK:
            if self.path == "/api/promote":
                status, data = promote(payload)
            elif self.path == "/api/sync":
                status, data = sync(payload)
            else:
                status, data = 404, {"ok": False, "output": "not found"}
        self.send_json(status, data)


def main():
    parser = argparse.ArgumentParser(description="Local knowledge sign-off web tool")
    parser.add_argument("--port", type=int, default=int(os.environ.get("SIGNOFF_PORT", "8765")))
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print("signoff: http://127.0.0.1:%d  (Ctrl+C to stop)" % args.port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
