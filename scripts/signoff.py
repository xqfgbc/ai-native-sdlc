#!/usr/bin/env python3
"""scripts/signoff.py — local web tool for human sign-off of knowledge proposals.

Runs on 127.0.0.1 only (Python standard library) and executes the same scripts a
human would run:
  - promote: bash scripts/promote-proposal.sh . <id> <owner> <advisory|deterministic>
  - debt:    bash scripts/debt.sh add ... (defer a proposal to the debt registry)
  - sync:    bash scripts/sync-cognition.sh . <local-repo>
             bash scripts/sync-cognition-remote.sh . <org/repo>   (no local clone)

The tool never signs by itself: a person enters their name/e-mail and clicks sign.
A per-run CSRF token protects the POST endpoints.

Usage: python3 scripts/signoff.py [--port 8765]
"""
import argparse
import datetime
import json
import os
import secrets
import shutil
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOKEN = secrets.token_urlsafe(24)
LOCK = threading.Lock()


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
                if isinstance(data, dict) and data.get("status") != "rejected":
                    items.append(data)
    return items


def rejected_proposals():
    directory = os.path.join(ROOT, "knowledge", "proposals")
    items = []
    if os.path.isdir(directory):
        for name in sorted(os.listdir(directory)):
            if name.endswith(".json"):
                data = read_json(os.path.join(directory, name), None)
                if isinstance(data, dict) and data.get("status") == "rejected":
                    items.append(data)
    return items


def reviews():
    directory = os.path.join(ROOT, "knowledge", "reviews")
    result = {}
    if os.path.isdir(directory):
        for name in sorted(os.listdir(directory)):
            if name.endswith(".json"):
                data = read_json(os.path.join(directory, name), None)
                if isinstance(data, dict) and data.get("proposalId"):
                    result[data["proposalId"]] = data
    return result


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
                       "exists": bool(local), "remote": "/" in repo})
    return result


def tooling():
    gh = bool(shutil.which("gh"))
    gh_auth = False
    if gh:
        try:
            gh_auth = subprocess.run(["gh", "auth", "status"], capture_output=True, timeout=5).returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            gh_auth = False
    token = bool(os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN"))
    return {"gh": gh, "ghAuth": gh_auth, "token": token}


def debt_items(days=7):
    try:
        finished = subprocess.run(
            ["bash", "scripts/debt.sh", "due", "--days", str(days), "--json"],
            cwd=ROOT, capture_output=True, text=True, timeout=20)
        return json.loads(finished.stdout or "[]")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return []


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


def record_decision(proposal_id, decision, owner, note=""):
    try:
        subprocess.run(
            ["bash", "scripts/review-proposals.sh", "record", proposal_id,
             "--decision", decision, "--owner", owner, "--note", note],
            cwd=ROOT, capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        pass


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
    result = run(args, dry_run)
    if result["ok"] and not dry_run:
        record_decision(proposal_id, "promote-" + enforcement, owner)
    return 200, result


def reject(payload):
    proposal_id = str(payload.get("id", "")).strip()
    owner = str(payload.get("owner", "")).strip()
    reason = str(payload.get("reason") or payload.get("note") or "").strip()
    dry_run = bool(payload.get("dryRun"))
    if proposal_id not in {item.get("id") for item in proposals()}:
        return 400, {"ok": False, "output": "unknown or already rejected proposal id"}
    if not owner:
        return 400, {"ok": False, "output": "owner (name or e-mail) is required"}
    args = ["bash", "scripts/review-proposals.sh", "reject", proposal_id, "--owner", owner]
    if reason:
        args += ["--reason", reason]
    result = run(args, dry_run)
    return 200, result


def retire(payload):
    item_id = str(payload.get("id", "")).strip()
    owner = str(payload.get("owner", "")).strip()
    reason = str(payload.get("reason") or "").strip()
    dry_run = bool(payload.get("dryRun"))
    if item_id not in {item.get("id") for item in pack().get("items", [])}:
        return 400, {"ok": False, "output": "unknown pack item id"}
    if not owner:
        return 400, {"ok": False, "output": "owner (name or e-mail) is required"}
    if not reason:
        return 400, {"ok": False, "output": "reason is required"}
    args = ["bash", "scripts/retire-cognition.sh", ".", item_id, owner, "--reason", reason]
    return 200, run(args, dry_run)


def add_debt(payload):
    proposal_id = str(payload.get("id", "")).strip()
    owner = str(payload.get("owner", "")).strip()
    priority = str(payload.get("priority", "P2")).strip()
    due = str(payload.get("due", "")).strip()
    note = str(payload.get("note", "")).strip()
    dry_run = bool(payload.get("dryRun"))
    proposals_by_id = {item.get("id"): item for item in proposals()}
    if proposal_id not in proposals_by_id:
        return 400, {"ok": False, "output": "unknown proposal id"}
    if not owner:
        return 400, {"ok": False, "output": "owner (name or e-mail) is required"}
    if priority not in ("P1", "P2", "P3"):
        return 400, {"ok": False, "output": "priority must be P1/P2/P3"}
    if not due:
        due = (datetime.date.today() + datetime.timedelta(days=14)).isoformat()
    title = proposals_by_id[proposal_id].get("title", proposal_id)
    args = ["bash", "scripts/debt.sh", "add", "--kind", "proposal",
            "--source", "proposal", "--ref", proposal_id, "--title", title,
            "--owner", owner, "--priority", priority, "--due", due,
            "--note", note or "deferred from sign-off"]
    result = run(args, dry_run)
    if result["ok"] and not dry_run:
        record_decision(proposal_id, "debt", owner, note)
    return 200, result


def sync(payload):
    name = str(payload.get("service", "")).strip()
    dry_run = bool(payload.get("dryRun"))
    target = next((s for s in services() if s["name"] == name), None)
    if not target:
        return 400, {"ok": False, "output": "unknown service"}
    if target["exists"]:
        args = ["bash", "scripts/sync-cognition.sh", ".", target["localPath"]]
    elif target["remote"]:
        caps = tooling()
        if not dry_run and not (caps["ghAuth"] or caps["token"]):
            return 400, {"ok": False, "output": "remote sync needs gh (installed + logged in) or GH_TOKEN; "
                                                 "otherwise edit .sdlc/cognition-pack.json and service.json in the web UI"}
        args = ["bash", "scripts/sync-cognition-remote.sh", ".", target["repo"]]
        if dry_run:
            args.append("--dry-run")
    else:
        return 400, {"ok": False, "output": "service repo is neither local nor an org/repo slug"}
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
main{max-width:1020px;margin:0 auto;padding:28px 18px 64px}
h1{font-size:24px;margin:0 0 4px}h2{font-size:16px;margin:0 0 12px}h3{font-size:14px;margin:16px 0 8px}
.sub{color:var(--muted);margin:0 0 24px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:18px;margin-bottom:16px}
.row{display:flex;gap:12px;flex-wrap:wrap;align-items:flex-end}
label{display:block;font-size:13px;color:var(--muted);margin-bottom:4px}
input,select{font:inherit;color:inherit;background:transparent;border:1px solid var(--line);border-radius:8px;padding:8px 10px;min-width:150px}
button{font:inherit;border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:8px;padding:8px 14px;cursor:pointer}
button.primary{background:var(--accent);border-color:var(--accent);color:#fff}
button:disabled{opacity:.5;cursor:not-allowed}
.chip{display:inline-block;font-size:12px;border:1px solid var(--line);border-radius:999px;padding:2px 8px;color:var(--muted);margin-right:6px}
.chip.warn{color:var(--warn);border-color:var(--warn)}.chip.ok{color:var(--ok);border-color:var(--ok)}.chip.bad{color:var(--bad);border-color:var(--bad)}
pre{background:var(--bg);border:1px solid var(--line);border-radius:8px;padding:12px;overflow:auto;white-space:pre-wrap;margin:12px 0 0;font-size:12.5px}
.muted{color:var(--muted)} .mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
.ai{background:var(--bg);border:1px solid var(--line);border-radius:10px;padding:12px;margin:12px 0}
.ai ul{margin:6px 0 0 18px;padding:0}
#log{min-height:70px}
</style></head><body><main>
<h1>知识签核</h1>
<p class="sub">人工门禁：由人填写 owner 并签核；AI 不能代签。页面只监听 127.0.0.1。</p>
<section class="card"><h2>现状</h2><div id="state" class="muted">加载中…</div><div id="debt" class="muted"></div></section>
<section class="card"><h2>Active 认知</h2><div id="active" class="muted">加载中…</div></section>
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
const plusDays = (days) => { const d = new Date(); d.setDate(d.getDate() + days); return d.toISOString().slice(0, 10); };
const suggestionEnf = (s) => (s && s.indexOf("deterministic") >= 0) ? "deterministic" : "advisory";
function commandFor(id) {
  const owner = document.getElementById("owner-" + id).value.trim() || "<你的名字或邮箱>";
  const enforcement = document.getElementById("enf-" + id).value;
  return "bash scripts/promote-proposal.sh . " + id + " " + owner + " " + enforcement;
}
function updateCmd(id) {
  const el = document.getElementById("cmd-" + id);
  if (el) el.textContent = commandFor(id);
}
function aiBlock(review) {
  if (!review || !review.ai || !review.ai.suggestion) return '<p class="muted">还没有 AI 预判；运行 scripts/review-proposals.sh 生成。</p>';
  const ai = review.ai;
  const cls = ai.confidence === "high" ? "ok" : (ai.confidence === "low" ? "warn" : "");
  const reasons = (ai.reasons || []).map(r => "<li>" + esc(r) + "</li>").join("");
  const human = review.human ? `<div class="muted" style="margin-top:8px">人工决定：<span class="chip">${esc(review.human.decision)}</span> owner ${esc(review.human.owner)} · 与 AI ${review.human.agreed ? "一致" : "不一致"}</div>` : "";
  return `<div class="ai"><div><b>AI 预判</b>
    <span class="chip ${cls}">${esc(ai.suggestion)}</span>
    <span class="chip">confidence ${esc(ai.confidence)}</span>
    <span class="chip ${ai.risk === "high" ? "warn" : ""}">risk ${esc(ai.risk)}</span></div>
    <ul>${reasons}</ul>
    ${(ai.gateHits || []).length ? `<div class="muted mono">gate hints: ${esc(ai.gateHits.join(", "))}</div>` : ""}
    ${human}</div>`;
}
async function load() {
  const state = await call("GET", "/api/state");
  document.getElementById("state").innerHTML =
    `项目 <b>${esc(state.project)}</b> · pack <span class="mono">v${esc(state.pack.version)}</span> · active ${state.pack.items.length} 条 · 待签核 ${state.proposals.length} 条 · 已驳回 ${state.rejectedCount || 0} 条`;
  const remoteReady = state.tooling.ghAuth || state.tooling.token;
  document.getElementById("state").innerHTML +=
    ` · 远端下发：<span class="chip ${remoteReady ? "ok" : "warn"}">${remoteReady ? (state.tooling.ghAuth ? "gh" : "token") : "不可用"}</span>`;
  const activeItems = state.pack.items.filter(i => (i.status || "active") === "active");
  document.getElementById("active").innerHTML = activeItems.length
    ? activeItems.map(i => `<div class="row" style="margin:8px 0">
        <div><span class="chip">${esc(i.enforcement)}</span> ${esc(i.title)}
          <span class="muted mono">${esc(i.id)}</span></div>
        <button onclick="retireItem('${esc(i.id)}')">退役</button></div>`).join("")
    : '<p class="muted">没有 active 条目。</p>';
  document.getElementById("debt").innerHTML = state.debt.length
    ? `<h3>债务到期提醒（7 天内 ${state.debt.length} 条）</h3>` + state.debt.map(d => `<div>${esc(d.id)} due=${esc(d.due)} ${esc(d.priority)} — ${esc(d.title)}</div>`).join("")
    : '<h3>债务</h3><div>7 天内没有到期债务</div>';
  const list = document.getElementById("list");
  if (!state.proposals.length) {
    list.innerHTML = '<section class="card"><h2>待签核</h2><p class="muted">没有待签核的 proposal。</p>'
      + '<p class="muted">服务本地（S1）规则不进这里：在服务仓用 <code>bash scripts/local-cognition.sh add …</code>，只上报证据。</p></section>';
  } else {
    list.innerHTML = state.proposals.map(p => `
      <section class="card">
        <h2>${esc(p.title)}</h2>
        <div><span class="chip">${esc(p.type)}</span><span class="chip">${esc(p.id)}</span>
          <span class="chip">scope ${esc(p.scope || "project")}</span>
          <span class="chip ${p.repeat ? "warn" : ""}">repeat ${p.repeatCount ?? 1}${p.repeat ? " · 建议提升" : ""}</span></div>
        ${aiBlock(state.reviews[p.id])}
        <p>${esc(p.statement || "")}</p>
        <p class="muted mono">provenance: ${esc((p.provenance || []).join(", "))}</p>
        <div class="row">
          <div><label>owner（你的名字或邮箱）</label><input id="owner-${esc(p.id)}" placeholder="例如 zhangsan@example.com" oninput="updateCmd('${esc(p.id)}')"></div>
          <div><label>enforcement</label><select id="enf-${esc(p.id)}" onchange="updateCmd('${esc(p.id)}')">
            <option value="deterministic">deterministic（需落成 hook/lint/CI）</option>
            <option value="advisory">advisory（建议性）</option></select></div>
          <div><label>债务优先级</label><select id="prio-${esc(p.id)}"><option>P1</option><option selected>P2</option><option>P3</option></select></div>
          <div><label>债务到期</label><input type="date" id="due-${esc(p.id)}" value="${plusDays(14)}"></div>
          <button onclick="rejectProposal('${esc(p.id)}')">驳回</button>
          <button class="primary" onclick="promote('${esc(p.id)}')">签核</button>
          <button onclick="addDebt('${esc(p.id)}')">登记债务</button>
        </div>
        <pre class="mono" id="cmd-${esc(p.id)}"></pre>
      </section>`).join("");
    state.proposals.forEach(p => {
      const review = state.reviews[p.id];
      const sel = document.getElementById("enf-" + p.id);
      if (sel && review && review.ai) sel.value = suggestionEnf(review.ai.suggestion);
      updateCmd(p.id);
    });
  }
  const services = document.getElementById("services");
  services.innerHTML = state.services.map(s => {
    const label = s.exists ? "本地下发" : (s.remote ? (remoteReady ? "远端 PR" : "远端不可用") : "不可用");
    const disabled = (!s.exists && (!s.remote || !remoteReady)) ? "disabled" : "";
    return `<div class="row" style="margin:8px 0">
      <div><b>${esc(s.name)}</b> <span class="muted mono">${esc(s.repo)}</span>
        ${s.exists ? '<span class="chip ok">本地可用</span>' : (s.remote ? '<span class="chip">远端</span>' : '<span class="chip warn">不可用</span>')}
        ${(!s.exists && s.remote && !remoteReady) ? '<span class="muted">安装 gh 或设置 GH_TOKEN，或按 README 在网页改两个文件</span>' : ""}</div>
      <button ${disabled} onclick="sync('${esc(s.name)}', ${s.exists})">${label}</button>
    </div>`;
  }).join("") || '<p class="muted">services.json 里没有服务。</p>';
}
async function promote(id) {
  const owner = document.getElementById("owner-" + id).value.trim();
  const enforcement = document.getElementById("enf-" + id).value;
  if (!owner) { alert("请填写 owner：签核必须由人完成"); return; }
  const command = commandFor(id);
  if (!confirm("将执行：\\n" + command + "\\n\\n确认签核？")) return;
  const data = await call("POST", "/api/promote", {id, owner, enforcement});
  log(data); load();
}
async function retireItem(id) {
  const owner = prompt("owner（退役也必须由人确认）");
  if (!owner) return;
  const reason = prompt("退役原因", "superseded or no longer applicable");
  if (reason === null || !reason.trim()) return;
  if (!confirm("退役该条目？pack 版本 +1；服务下次同步后不再显示。")) return;
  const data = await call("POST", "/api/retire", {id, owner, reason});
  log(data); load();
}
async function rejectProposal(id) {
  const owner = document.getElementById("owner-" + id).value.trim();
  if (!owner) { alert("请填写 owner：驳回同样必须由人确认"); return; }
  const reason = prompt("驳回原因（可选，例如：与 active 规则重复）", "duplicate of an active rule");
  if (reason === null) return;
  if (!confirm("驳回该 proposal？它会标记为 rejected，从待签列表移除且不再重新生成。")) return;
  const data = await call("POST", "/api/reject", {id, owner, reason});
  log(data); load();
}
async function addDebt(id) {
  const owner = document.getElementById("owner-" + id).value.trim();
  if (!owner) { alert("请填写 owner：登记债务也需要负责人"); return; }
  const priority = document.getElementById("prio-" + id).value;
  const due = document.getElementById("due-" + id).value;
  if (!confirm("把该 proposal 登记为债务（owner " + owner + ", " + priority + ", due " + due + "）？")) return;
  const data = await call("POST", "/api/debt", {id, owner, priority, due});
  log(data); load();
}
async function sync(name, local) {
  const msg = local ? ("把 pack 下发到本地服务仓 " + name + "？service.json 会被钉版本。")
                    : ("对 " + name + " 开一个认知包升级 PR？需要 gh 已登录且有权限。");
  if (!confirm(msg)) return;
  const data = await call("POST", "/api/sync", {service: name});
  log(data); load();
}
load();
</script></body></html>
"""


class Handler(BaseHTTPRequestHandler):
    server_version = "Signoff/1.1"

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
            if project.endswith("-control-plane"):
                project = project[:-len("-control-plane")]
            with LOCK:
                self.send_json(200, {"project": project, "pack": pack(), "proposals": proposals(),
                                     "rejectedCount": len(rejected_proposals()),
                                     "services": services(), "reviews": reviews(),
                                     "debt": debt_items(7), "tooling": tooling()})
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
            elif self.path == "/api/reject":
                status, data = reject(payload)
            elif self.path == "/api/retire":
                status, data = retire(payload)
            elif self.path == "/api/debt":
                status, data = add_debt(payload)
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
