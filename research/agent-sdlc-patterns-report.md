# AI-Native SDLC — Open-Source Patterns, Skills, Agents & Guardrails Inventory

**Purpose:** Ground the framework's six-stage SDLC (Plan → Design → Build → Test → Deploy → Maintain) in *real, open-source* practice rather than invention. Every entry below cites an exact repo (owner/repo) and, where verified, a file/directory path.

**Method note:** Findings were collected via web search and direct reads of repo READMEs. "Which framework piece" maps each source to your four assets: **skills** (`.claude/skills/*/SKILL.md`), **agents** (subagent/role `.md` files), **hooks** (`.claude/settings.json`, hook scripts, git/pre-commit gates), **evals** (`evals/` + CI workflow).

---

## 1. Agent skills / skill libraries

### 1.1 Canonical skill repo — `anthropics/skills`
- **URL:** https://github.com/anthropics/skills
- **What it is:** Anthropic's reference implementation of the **Agent Skills standard** (spec at https://agentskills.io/). Structure: `skills/<name>/SKILL.md` (YAML frontmatter `name` + `description`, then Markdown instructions), a `spec/` folder for the skills specification, and a `template/` starting point. Production document skills are Apache-2.0 and open: `skills/docx`, `skills/pdf`, `skills/pptx`, `skills/xlsx`.
- **Framework piece → informs:** **skills** — this is the exact `SKILL.md` format your `.claude/skills/<name>/SKILL.md` files should follow (frontmatter `name`/`description`, one skill = one domain, instructions + examples + guidelines). Also informs how to register your skills as an installable plugin marketplace.

### 1.2 Skill index lists (curation + discovery)
- **`itgoyo/awesome-claude-code-skills`** — https://github.com/itgoyo/awesome-claude-code-skills — curated index of top-starred Claude Code skills/tools/MCP.
- **`ComposioHQ/awesome-claude-skills`** — https://github.com/ComposioHQ/awesome-claude-skills — skills, tools, MCP integrations.
- **`Gentleman-Programming/Gentleman-Skills`** — https://github.com/Gentleman-Programming/Gentleman-Skills — community skills that work across Claude Code, OpenCode, Gemini CLI, Cursor, VS Code Copilot, Codex, Windsurf. Documents install paths (`~/.config/opencode/skills/`, `.agents/skills/`).
- **`nimser/skills`** — https://github.com/nimser/skills — "skills for coding agents (opencode, claude code, etc.)"; notes both discover skills from `.agents/skills/`.
- **Framework piece → informs:** **skills** — use as a source for skill *names/scope* and cross-agent portability (so your skills aren't Claude-Code-only).

### 1.3 Reusable security / review skills (the most valuable ones to lift)
- **`davethegut/security-review-skill`** — https://github.com/davethegut/security-review-skill — structured security review skill for automation skills, deployment plans, live setups (credential exposure, injection vectors, blast radius, failure cascading). Works with 40+ agents.
- **`natolitech/security-skill`** — https://github.com/natolitech/security-skill — distributable application security review + threat-modeling skill; point at a local project or a git URL.
- **`Hahaknight/claude-skills-pro`** — https://github.com/Hahaknight/claude-skills-pro — 15 engineering skills: code review, testing, debugging, security (`security-audit` = real attack-surface review, not rote OWASP), zero-downtime migrations; open `SKILL.md` format.
- **`MCKRUZ/claude-code-mastery`** — https://github.com/MCKRUZ/claude-code-mastery — "17 curated skills + rules + agents + hooks" end-to-end setup (a ready-made reference for your whole `.claude/` layout).
- **Framework piece → informs:** **skills** — these map directly to your `secure-api-review`, `pr-review`, and `resiliency-review` skills; study their checklists and "findings report" output format.

### 1.4 The "built-in" skills you should know (in `anthropics/claude-code`)
- **`anthropics/claude-code`** — https://github.com/anthropics/claude-code — the CLI itself ships a built-in **`/security-review`** slash command and a **`security-reviewer`** subagent for pre-merge security review (see §2.2). Also exposes `/test`, hooks, subagents, permissions, and an eval/plugin-eval system.
- **Framework piece → informs:** **skills + agents** — your `pr-review`/`secure-api-review` skills should *invoke* a dedicated security-reviewer subagent rather than inlining a long checklist in the primary context (matches Anthropic's own pattern).

---

## 2. Agent subagent / role definitions

### 2.1 The subagent format (`.claude/agents/*.md`)
- **`anthropics/claude-code`** subagents docs — https://code.claude.com/docs/en/sub-agents — Markdown files with YAML frontmatter (`name`, `description`, `tools`, `model`) placed in `.claude/agents/`. The `description` doubles as the routing prompt (when to spawn).
- **`mongodb/docs`** — https://github.com/mongodb/docs → `.claude/agents/` (README at `.claude/agents/README.md`) — a **production** example of an orchestrator that invokes bounded sub-agents via the Task tool; documents the rule "a sub-agent cannot spawn further sub-agents, so orchestration always lives in the primary agent."
- **`linkedajay2018/claude-agent-teams`** — https://github.com/linkedajay2018/claude-agent-teams — working example of the "agent-teams" pattern: `.claude/agents/*.md` definitions + an orchestrating slash command, runnable as-is.
- **Framework piece → informs:** **agents** — the exact frontmatter and "orchestrator + bounded subagents (no recursion)" topology your `reviewer`, `security-auditor`, `verifier`, `researcher`, `planner` roles should use.

### 2.2 Curated subagent collections (role names to adopt)
- **`VoltAgent/awesome-claude-code-subagents`** — https://github.com/VoltAgent/awesome-claude-code-subagents — 100+ ready-to-use subagents (code review, refactor, CI/CD orchestration, research).
- **`frankxai/awesome-claude-code-subagents`** — https://github.com/frankxai/awesome-claude-code-subagents — 100+ specialized subagents grouped by domain.
- **`cristopherlee/awesome-claude-code-subagents`** — https://github.com/cristopherlee/awesome-claude-code-subagents — e.g. `refactoring-specialist`, `api-documenter`, `tooling-engineer`.
- **`rahulvrane/awesome-claude-agents`** — https://github.com/rahulvrane/awesome-claude-agents — collection + setup walkthrough.
- **Framework piece → informs:** **agents** — mine these for the canonical role set: `code-reviewer`, `security-reviewer`, `test-writer`, `debugger`, `refactoring-specialist`, `api-documenter`, `researcher`.

### 2.3 Subagents in other harnesses (portability for your "4 agents" constraint)
- **`openai/codex`** — https://github.com/openai/codex — Codex CLI subagents are TOML files under `.agents/agents/*.toml` (see §5.3); skills are folders under `.agents/skills/<name>/`.
- **`sst/opencode`** — https://github.com/sst/opencode — subagents as `.opencode/agents/<name>.md` with frontmatter `description`, `mode`, `model`, `temperature`, `permission`; MCP servers + commands in `opencode.json`.
- **Framework piece → informs:** **agents** — if you want Claude Code / Codex / opencode / DSH parity, keep role *definitions* in Markdown and let a thin adapter emit `.claude/agents/*.md`, `.agents/agents/*.toml`, `.opencode/agents/*.md` (the `chemaclass/agnostic-ai` project does exactly this emission).

---

## 3. Hooks / guardrails / policy gates

### 3.1 Claude Code hooks + permissions (the core mechanism)
- **`anthropics/claude-code`** hooks/settings reference — https://code.claude.com/docs/en/hooks and https://code.claude.com/docs/en/settings — hook events (`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`, `SubagentStart/Stop`, `PreCompact`, `Notification`); a hook script can **block** by exiting non-zero with JSON on stdout. Permissions in `.claude/settings.json`: `allow`/`ask`/`deny` matchers, `additionalDirectories`, `blockWritesOutsideWorkingDirectories`.
- **`chenglou/claude-config-learnings`** — https://github.com/chenglou/claude-config-learnings — field notes on `~/.claude/settings.json`: `additionalDirectories`, `defaultMode`, `Bash` matchers, and the caveat that user-level hooks merge with project-level hooks and can mask bugs.
- **Framework piece → informs:** **hooks** — your `production-gate.sh` and protected-path guards should be `PreToolUse`/`PostToolUse` hooks that emit structured JSON and exit non-zero to deny; keep them in `.claude/settings.json` with explicit matchers.

### 3.2 Hardened, copy-able guardrail configs
- **`dwarvesf/claude-guardrails`** — https://github.com/dwarvesf/claude-guardrails — hardened Claude Code config in "full" and "lite" variants: **21 credential deny rules** (SSH/AWS/GPG/kube/Azure/`.env`/`.pem`…), **4 PreToolUse hooks** (destructive deletes, direct push, pipe-to-shell), prompt-injection defense, telemetry-disable env flags.
- **`hnts/claude-code-security-snippets`** — https://github.com/hnts/claude-code-security-snippets — copy-paste `settings.json` snippets for permissions, sandboxing, shell guardrails (against prompt injection + supply-chain).
- **`openrec0n/agent-armor`** — https://github.com/openrec0n/agent-armor — generator that emits a secure `settings.json` blocking prompt-injection vectors (credential theft, source exfiltration, destructive commands).
- **Framework piece → informs:** **hooks** — these give you the exact deny-rule + PreToolUse-hook corpus for "never edit `build/`, `.gradle/`, generated schema", "never push", "never pipe to shell".

### 3.3 Reference hook implementations
- **`disler/claude-code-hooks-mastery`** — https://github.com/disler/claude-code-hooks-mastery — widely cited as the **most complete public example**: `Stop` hook + `PostToolUse` linting + transcript conversion, wired via `.claude/settings.json`.
- **`blader/taskmaster`** — a `Stop` hook scanning for a `TASKMASTER_DONE` token — machine-checkable completion tokens instead of LLM self-assessment (a pattern directly relevant to your "verify-work" gate).
- **Framework piece → informs:** **hooks** — model your `verify-work`/`pr-review` "paste the output" gate on a `Stop` hook that *machine-checks* a completion token + runs lint, rather than trusting the model's self-report.

### 3.4 Git / pre-commit guardrails (authoritative CI boundary)
- **`Sting25/ai-coding-rules-scaffold`** — https://github.com/Sting25/ai-coding-rules-scaffold — **two-layer enforcement** for small teams: local pre-commit hook + unskippable CI mirror (`check-secrets` regex gate + optional `gitleaks`), plus `scaffold-doctor` to detect "guardrail installed but not running." Key principle: *the CI gate is the authoritative boundary; the local hook fails open.*
- **`pre-commit/pre-commit`** — https://github.com/pre-commit/pre-commit — framework for git pre-commit hooks (use with `gitleaks`, `detect-secrets`).
- **`gitleaks/gitleaks`** — https://github.com/gitleaks/gitleaks — secret scanning for pre-commit + CI.
- **Framework piece → informs:** **hooks + CI** — your secrets/path-protection gates should be enforced twice: a local hook (fail-open, convenience) and a CI check (fail-closed, authoritative). GitHub push protection is the equivalent server-side.

---

## 4. Agent evals / regression suites

### 4.1 The eval harness itself
- **`anthropics/claude-code`** evals — https://code.claude.com/docs/en/plugin-evals — Claude Code's built-in eval system; each case pins `model`, `--runs`, and asserts pass/fail. Guidance to **pin the model in CI** so a model rollout isn't mistaken for a config regression.
- **The AI-Native SDLC Playbook's `agent-evals.yml`** (captured at `uygnoey/skills-from-claude-blog` → `skills/ai-native-sdlc/examples/agent-evals.yml`) — the canonical CI pattern: `.github/workflows/agent-evals.yml`, runs **non-interactively on a schedule and on any PR touching `CLAUDE.md` / `.claude/**`**, with `npm install -g @anthropic-ai/claude-code`. Each eval = a prompt + "acceptable" checks (tests pass, lint clean, policy obeyed); **every production incident becomes a new eval**.
- **Framework piece → informs:** **evals + CI** — this is your `evals/run.py` + "run on PRs touching `CLAUDE.md`, `.claude/**`, `evals/**`" gate, nearly verbatim.

### 4.2 CI agent-run patterns
- **`anthropics/claude-code-action`** — https://github.com/anthropics/claude-code-action — official GitHub Action to run Claude Code non-interactively in CI (review PRs, run evals, generate reports).
- **`UKGovernmentBEIS/inspect_evals`** — https://github.com/UKGovernmentBEIS/inspect_evals → `.github/workflows/claude-review.yaml` — production example: gate on `claude-review.yaml`, run `anthropics/claude-code-action@v1` for automated PR code review, write the review comment back to the PR.
- **`wm-agent-evals`** (PyPI) — a lightweight regression suite with `--gate` (exit 1 if any task regresses against baseline) and `[injection]`-tagged prompt-injection tasks — a concrete template for your eval runner's pass/fail contract.
- **Framework piece → informs:** **evals + CI** — separate "agent config regression" from "product tests"; run evals as a GitHub Action that must stay green on any change to governance files.

---

## 5. AI-native SDLC / spec-driven development flows

### 5.1 GitHub Spec Kit (the canonical SDD implementation)
- **`github/spec-kit`** — https://github.com/github/spec-kit — docs at https://github.github.io/spec-kit/. Slash commands: `/speckit.constitution` → `constitution.md` (guiding principles/constraints), `/speckit.specify` → `spec.md`, `/speckit.plan` → `plan.md`, `/speckit.tasks` → `tasks.md` (dependency-ordered, parallelizable), `/speckit.implement` → source. The SDD flow: **Specify → Plan → Tasks → Implement → Converge.** A portable `SKILL.md` reimplementation ships at `meshtastic/meshtastic-android` → `.skills/speckit/SKILL.md`.
- **Framework piece → informs:** **skills + CI (the loop)** — Spec Kit's `constitution.md` ≈ your `AGENTS.md`/`CLAUDE.md` guardrails; its `spec → plan → tasks → implement → converge` loop is the direct analogue of your Stage 2–4. `tasks.md`'s "dependency-ordered, parallelizable tasks" is exactly what your `plan.md` work items should encode so multiple subagents can work safely.

### 5.2 GitHub platform glue (non-interactive agents)
- **`github/github-mcp-server`** — https://github.com/github/github-mcp-server — official GitHub MCP server (issues, PRs, code, CI, security) — the bridge your deploy/rollback and PR-review agents use.
- **Framework piece → informs:** **CI + agents** — your reviewer/release agents should act through MCP tool calls (typed, auditable) rather than raw shell, so "review in both directions" and "prepare-but-don't-authorize" gates are enforceable.

### 5.3 The cross-agent instruction-file standard
- **`openai/agents.md`** — https://github.com/openai/agents.md — the **AGENTS.md** spec: "a simple, open format for guiding coding agents," MIT-licensed, plain Markdown, any headings, scoped to the containing directory tree, adopted by 20k+ repos. `openai/codex` (https://github.com/openai/codex) consumes it and adds `.agents/agents/*.toml` subagents + `.agents/skills/`.
- **Framework piece → informs:** **skills + agents** — `AGENTS.md` is the portable sibling of your `CLAUDE.md`; adopting it keeps Codex/openCode/DSH agents following the same stage loop, not just Claude Code.

---

## 6. Security for agentic development

### 6.1 OWASP Top 10 for Agentic Applications (ASI01–ASI10)
- **Project:** https://owasp.org/www-project-top-10-for-agentic-applications/ (GenAI Security Project; published Dec 2025) and resource doc https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/. Risks run **ASI01 (agent goal hijack / prompt injection) … ASI10 (rogue agents)**, incl. supply-chain, tool/memory poisoning, permission sprawl, unauthorized actions, data exfiltration.
- **Framework piece → informs:** **hooks + evals + skills** — turn each ASI code into (a) a deny/permission rule and (b) a prompt-injection eval case; your `secure-api-review` and `incident-to-intent` skills should reference the ASI taxonomy.

### 6.2 Governance/control reference implementations
- **`microsoft/agent-governance-toolkit`** — https://github.com/microsoft/agent-governance-toolkit — "Agent OS" governance stack claiming **10/10 OWASP Agentic Top 10 coverage**: MCP-server approval workflows (`extensions/mcp-server/src/services/approval-workflow.ts`), `docs/OWASP-COMPLIANCE.md`, and a Python package (`agent-governance-python`).
- **`dwarvesf/claude-guardrails`**, **`hnts/claude-code-security-snippets`**, **`openrec0n/agent-armor`** (see §3) — concrete prompt-injection + secrets + sandbox mitigations for coding agents.
- **`anthropics/claude-plugins-official`** — https://github.com/anthropics/claude-plugins-official — official plugin repo that itself runs a **policy-scan CI** on contributed plugins (rejects plugins that register ungated `UserPromptSubmit`/`PreToolUse` hooks observing every session, credential exposure, etc.) — a model for *vetting third-party skills/plugins* you might pull into your framework.
- **Framework piece → informs:** **hooks + evals** — adopt a "guardrail linter" for skills/hooks (no ungated hooks, no secrets, mask credentials in findings) and mirror the ASI mapping into your `config/bands.yaml` / risk classes (schema, auth, money, cross-service contract).

---

## 7. Agent orchestration / multi-agent workflows

### 7.1 Orchestration framework + patterns
- **`anthropics/workflows`** — https://github.com/anthropics/workflows — Anthropic's open-source multi-agent orchestration framework (Python/TypeScript/Rust cores) for durable, parallel, typed agent workflows with an MCP server.
- **`anthropics/claude-cookbooks`** — https://github.com/anthropics/claude-cookbooks → `patterns/agents/` — minimal reference implementations of **Orchestrator-Workers**, **Orchestrator-Subagents**, **Evaluator-Optimizer**, **Multi-LLM Parallelization**, **Async Multi-Agent Orchestration**, **Multi-Agent Teams Under Latency Pressure and Budgets**.
- **`anthropics/skills`** — `skills/claude-api/shared/managed-agents-multiagent.md` — how a run's threads map to a predefined-agent roster with per-agent config, plus an `advisor` agent consulted mid-task.
- **Framework piece → informs:** **agents + CI** — your `reviewer`/`verifier`/`researcher`/`planner` split is the "Orchestrator-Workers" pattern; the "Evaluator-Optimizer" pattern is your verify→review→fix loop; the "advisor" concept maps to your escalation gate ("stop and ask a human").

### 7.2 Parallel work / worktrees in real repos
- **Git worktrees for parallel sessions** — `scarrow/tool-capability-protocol` (https://codeberg.org/scarrow/tool-capability-protocol, commit "feat(worktrees): Implement Git Worktree support for parallel Claude sessions") — concrete pattern for isolated parallel agent sessions via `git worktree` + session-coordination notes.
- **Claude Code workflows feature** — https://code.claude.com/docs/en/workflows — bundled/`.claude/workflows/` multi-stage workflow runs (e.g. `/deep-research`), sharable via the repo.
- **Framework piece → informs:** **CI + agents** — for `spec → plan → tasks → implement` fan-out, give each subagent its own `git worktree` (isolated write scope) and use a dependency-ordered `tasks.md`/`plan.md` so parallel agents never touch the same files (this also satisfies your advisory write-scope separation).

---

## Recommended grounding map (framework piece ← strongest source)

| Framework piece | Primary source(s) to ground it on |
|---|---|
| `AGENTS.md` / `CLAUDE.md` stage loop | `openai/agents.md`, `github/spec-kit` (constitution + SDD loop), Anthropic "AI-Native SDLC Playbook" |
| `.claude/skills/*/SKILL.md` | `anthropics/skills` (format + `skills/spec`), `davethegut/security-review-skill`, `natolitech/security-skill`, `Hahaknight/claude-skills-pro` |
| `.claude/agents/*.md` roles | `anthropics/claude-code` subagents docs, `mongodb/docs/.claude/agents`, `VoltAgent/awesome-claude-code-subagents`, `linkedajay2018/claude-agent-teams` |
| `.claude/settings.json` + hooks | `dwarvesf/claude-guardrails`, `hnts/claude-code-security-snippets`, `disler/claude-code-hooks-mastery`, `chenglou/claude-config-learnings` |
| `evals/` + `agent-evals.yml` | AI-Native SDLC Playbook `agent-evals.yml`, `anthropics/claude-code` plugin-evals, `anthropics/claude-code-action`, `UKGovernmentBEIS/inspect_evals` |
| Deploy/review gates (MCP) | `github/github-mcp-server`, `microsoft/agent-governance-toolkit` (approval-workflow), `anthropics/claude-plugins-official` policy-scan CI |
| Security / ASI mapping | OWASP Top 10 for Agentic Applications (ASI01–ASI10), `microsoft/agent-governance-toolkit` OWASP mapping |
| Parallel subagents | `anthropics/claude-cookbooks` patterns, `anthropics/workflows`, git-worktree pattern |

*All links above point to GitHub (or official project) pages; verify branch/path names against the live repos before copying file paths into your templates.*
