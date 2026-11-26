# Upstream study: piomin/claude-ai-spring-boot + github/awesome-copilot

Studied 2026-11-24. Both repos are multi-agent Spring/enterprise customization
libraries. This note records what we learned and what the framework adopted.

## piomin/claude-ai-spring-boot (v1.3.2)

A Claude Code **plugin** (also a Codex plugin + plain `SKILL.md` skills) for
Spring Boot 4.x / Java 21. Structure: `conventions` skill (mandatory rules),
`spring-boot` skill + 7 `references/`, `code-quality` skill + 6 references,
`review-triage`, `jpa-patterns`, `testing-patterns`, `logging-patterns`,
`java-modern`, `design-patterns`, 7 agents (`architect`, `code-reviewer`,
`spring-boot-engineer`, `security-engineer`, `kubernetes-specialist`,
`devops-engineer`, `docker-expert`), and `.github/scripts/validate.sh`.

Genuinely reusable patterns:

- **One `conventions` skill** holding every mandatory rule, with other skills as
  detail references (progressive disclosure).
- **`review-triage`**: review remarks are hypotheses; verify and accept /
  partly / reject / defer / answer with a one-line reason.
- **`architect` agent**: read-only; turns one large issue into ≤8 ordered,
  reviewable child issues with implementation plans.
- **`code-reviewer` agent**: read-only; fixes scope (`git diff <ref>...HEAD`),
  cites `File:line`, skips linter-enforced items, calibrated severity output.
- **Boot 4 test APIs** (exact imports): `org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest`,
  `org.springframework.boot.testcontainers.service.connection.ServiceConnection`,
  `org.springframework.test.context.bean.override.mockito.MockitoBean`,
  `tools.jackson.databind.json.JsonMapper`.
- **Testcontainers `@ServiceConnection`** instead of `@DynamicPropertySource`.
- `validate.sh` checks skill/agent frontmatter + tag/version consistency before
  publishing.

## github/awesome-copilot

A large curated customization library: `instructions/` (glob-scoped rules),
`prompts/`, `agents/`, `skills/` (e.g. `create-spring-boot-java-project`,
`api-breaking-change-detector`, `create-specification`, `create-implementation-plan`),
`hooks/`, `plugins/`, `workflows/`, `cookbook/`, `docs/`.

Genuinely reusable patterns:

- **`agent-safety.instructions.md`** — governance for agent systems: fail
  closed, policy as configuration, least privilege, append-only audit, tool
  allowlists, most-restrictive-wins across agents, don't log prompts.
- **`create-spring-boot-java-project`** — scaffold via start.spring.io; *detect
  before you create*, never upgrade versions implicitly, then verify
  (`build/actuator/health` returns `UP`).
- **`java-junit5-assertions`**, `kubernetes-deployment-best-practices`,
  `api-breaking-change-detector`, `create-specification`/`create-implementation-plan`
  — content to borrow for testing, K8s, contract, and SDLC skills.

## Adopted into this framework

| Learning | Where |
|---|---|
| `review-triage` skill | `.agents/skills/review-triage/SKILL.md` |
| `code-quality` checklist skill | `.agents/skills/code-quality/SKILL.md` |
| `architect` subagent | `.claude/agents/architect.md`, `.codex/agents/architect.toml`, `.opencode/agents/architect.md` |
| Read-only reviewer with scope + citation + calibration | `.claude/agents/pr-reviewer.md` (+ Codex/openCode) |
| Boot 4 test API imports + `@ServiceConnection` | `.agents/skills/spring-testing/SKILL.md`, scaffold itest |
| `spring-boot-testcontainers` dependency | `gradle/libs.versions.toml`, `platform/`, `scripts/new-service.sh` |
| Mandatory Spring conventions (RestClient, PagedModel, ProblemDetail, `@Transactional(readOnly=true)`, graceful shutdown, virtual threads) | `.agents/skills/spring-service-conventions/SKILL.md`, `CLAUDE.md` |
| Agent-safety principles (fail closed, least privilege, append-only audit) | `AGENTS.md` §1 principles 7–8 |
| Config validation script | `scripts/validate-skills.sh` + CI step |
| Pr-review checklist citation | `REVIEW.md`, `.agents/skills/pr-review/SKILL.md` |

## Deliberately not adopted

- **Maven** — the framework is Gradle (user requirement); keep the `platform`
  BOM + version catalog instead.
- **Maven-specific rules** (`pl.piomin.services` group id, artifact-name = dir).
- **Lombok ban** — already implicit: the scaffold writes explicit constructors
  and the ArchUnit check forbids field injection; we keep "no Lombok on entities".
- **RestTestClient in the scaffold** — Boot 4 moved/deprecated the test HTTP
  clients; the scaffold uses the JDK `HttpClient` so the template needs no extra
  test-client dependency. `RestTestClient` + `@AutoConfigureRestTestClient` is
  documented in `spring-testing` for services that want it.
- **`/api` (vs `/api/v1`) + OpenAPI export** — situational (only for UI-backed
  APIs); recorded in `spring-testing`/`spring-service-conventions`, not forced.

## Sources

- https://github.com/piomin/claude-ai-spring-boot
- https://github.com/github/awesome-copilot
