# GitHub-Sourced Spring Guardrails for the AI-Native SDLC Framework

Research date: **2026-11-24**. All repos/versions verified via GitHub API, Maven Central,
Gradle Plugin Portal, or the repo's own docs on this date. Maintenance status = stars /
last push at verification time. Anything not directly verified is flagged **[UNVERIFIED]**.

Framework context used for mapping: Spring Boot 4.1.3, Spring Cloud 2025.1.5 (Oakwood),
Java 21, Gradle Kotlin DSL + version catalog, skills in `.agents/skills/`, hooks in
`hooks/`, CI in GitHub Actions.

> Headline findings
> 1. **Spring Cloud Contract is dead** — archived (`spring-attic`), removed from the 2025.1
>    and 2026.0 trains, handed to Stubborn.sh on 2026-07-06. Do **not** build a contract
>    guardrail on it; use an OpenAPI diff gate (`oasdiff`) instead.
> 2. **Spring's own repos ship ArchUnit rule factories you can copy** (`spring-boot`
>    `buildSrc/.../ArchitectureRules.java` + `ArchitecturePlugin.java`, `spring-framework`
>    `ArchitectureRules.java`), and ArchUnit has first-class `NO_CLASSES_SHOULD_USE_FIELD_INJECTION`
>    and `FreezingArchRule`.
> 3. **Community Boot-4 checklists contain verifiable falsehoods** (e.g. "@AutoConfigureMockMvc
>    removed") — an agent-facing migration skill must be derived from the official wiki, and a
>    deterministic grep hook must enforce the rename list.
> 4. **Spring Cloud 2026.0.0 went GA on 2026-11-20** (two days before research); the framework's
>    pinned 2025.1.5 is the matching stable line, but a 2026.0 upgrade is now the next platform task.

---

## 1. Real Spring Boot / Spring Cloud agent instruction files

| Repo | What it is | Why it matters / what it encodes | Framework piece it should inform |
|---|---|---|---|
| [kousen/spring-and-spring-boot](https://github.com/kousen/spring-and-spring-boot/blob/main/CLAUDE.md) (303★, pushed 2026-11-16) | Ken Kousen's Boot 4.1.0 / Java 21 / Gradle 9.6.1 lab monorepo, 619-line CLAUDE.md | Boot-4 idioms: `@MockitoBean` (not `@MockBean`), RFC 7807 `ProblemDetail` errors, record DTOs, `BigDecimal` money, `@DirtiesContext` test-isolation rationale, `@RequiredArgsConstructor` DI, explicit Boot 4.1.0 pin | `CLAUDE.md` "Spring idioms" section; `spring-testing` examples |
| [piomin/course-spring-microservices](https://github.com/piomin/course-spring-microservices/blob/master/CLAUDE.md) (158★, pushed 2026-11-24) | Piotr Mińkowski's Spring Cloud 2025.1.1 / Boot 4.0.3 multi-module course repo; 103-line CLAUDE.md | Best *Spring Cloud*-shaped file found: module map (config+discovery, inter-communication via OpenFeign / `@HttpExchange` / WebClient, gateway, Spring Cloud Stream), package convention, plus a "Spring Boot 4 Breaking Changes" checklist. **Two claims are wrong** — see flags | `spring-boot-4-migration` skill (adopt list, correct the errors); `spring-service-conventions` |
| [rrezartprebreza/spring-boot-skills](https://github.com/rrezartprebreza/spring-boot-skills) (363★, pushed 2026-11-17, MIT) | 88 `SKILL.md` files (44 skills × Boot 3 / Boot 4), 6 specialists for Claude + 6 for Codex, verification matrix, eval scripts, and `templates/spring-boot-4/CLAUDE.md` | The single most reusable repo. Boot-4 template CLAUDE.md (31 lines) is a clean drop-in; `spring-boot-migration` SKILL.md is accurate on `@AutoConfigureMockMvc`, properties-migrator workflow, starter matrix, Jackson 3, Undertow removal | Nearly every skill; specialists → `.claude/agents/` / `.codex/agents/`; see §5 |
| [Tencent/spring-cloud-tencent](https://github.com/Tencent/spring-cloud-tencent/blob/2025.1/AGENTS.md) (branch `2025.1`, 351 lines) | AGENTS.md of a Spring Cloud 2025.1 framework (51 modules) | Mature-team rules: module structure, "remove `-SNAPSHOT`" release checklist, CI check list, **Checkstyle bound to Maven `validate` with `failsOnViolation=true` including test sources**, unit-test template, and the note that running `checkstyle:check` standalone surfaces pre-existing unrelated violations (so agents should run compile, not a bare style goal) | `AGENTS.md` §4/§5; `hooks/pre-commit` (bind style check to compile); CI |
| [pig-mesh/pig](https://github.com/pig-mesh/pig/blob/master/AGENTS.md) (~Spring Cloud suite, 65 lines) | AGENTS.md for Nacos/Spring Cloud Gateway/Auth/UPMS services | Long "Behavioral Guidelines" block: think-before-coding, minimum code, surgical changes (every changed line traces to a requirement), goal-driven "write the failing test first" | `AGENTS.md` §1 operating principles |
| [lets-mica/mica](https://github.com/lets-mica/mica/blob/master/AGENTS.md) (78 lines) | Spring Cloud toolkit AGENTS.md | `.editorconfig`-driven formatting (tabs for Java), naming, per-module test commands | Formatting guardrail (Spotless/editorconfig) |
| [Ericsson/ecchronos](https://github.com/Ericsson/ecchronos/blob/master/application/CLAUDE.md) (Apache-2.0, pushed today) | **Nested per-module** CLAUDE.md for the Spring Boot entry-point module | Demonstrates module-scoped instruction files ("this module owns `@Configuration`, no business logic"); also usefully warns *"auto-generated by Claude, not yet manually verified"* | `scaffold-microservice` — generate a per-service `CLAUDE.md`; note the AI-generated-content caution |
| [hortonworks/cloudbreak](https://github.com/hortonworks/cloudbreak/blob/master/AGENTS.md) (361★, pushed 2026-11-20) | AGENTS.md + `.agent/skills/` playbook dir of a large Spring Boot 3.3 codebase | The best repo-native skills layout: `cb-db-migration` (mandatory `@UNDO`, reversible DDL), `cb-testing` (Jacoco commands + coverage gates), `cb-swagger-check` (**oasdiff gate + `openapi-breaking-allowlist.txt`**), `cb-code-reviewer` distilled from real review history | New skills (`spring-data-jpa` migration section, `pr-review`); CI: oasdiff contract gate |
| [appsmithorg/appsmith](https://github.com/appsmithorg/appsmith/blob/release/.cursor/rules/backend.mdc) (41k★) | `.cursor/rules/*.mdc` for a Spring Boot WebFlux backend | Cursor rule format (`description`, `globs`, `alwaysApply`) + module/package map + "Spotless `./mvnw spotlessCheck`" as the style command | `.cursor/rules/` adapter; Spotless |
| [wiz-sec-public/secure-rules-files](https://github.com/wiz-sec-public/secure-rules-files/blob/main/java/spring/copilot-instructions.md) (247★, pushed 2025-12-23) | CWE-mapped secure Spring rules for Copilot/Windsurf | Concrete CWEs for Java+Spring: XSS-79, SQLi-89, input validation-20, deserialization-502, hardcoded creds-798, auth-287/306, SSRF-918, weak crypto-327, plus "avoid slopsquatting, don't guess package existence" (directly relevant for AI dependency hallucination) | `secure-api-review` checklist; `AGENTS.md` dependency rules |
| [fxcl/.dotfiles spring-boot.windsurfrules](https://github.com/fxcl/.dotfiles/blob/main/windsurfrules/spring-boot.windsurfrules) | Generic `.windsurfrules` template | Only a template — layering, constructor injection, 80% coverage, Flyway/Liquibase; no real project behind it | Format reference only; do not cite as evidence of practice |

Conventions mature teams actually encode (synthesis): fixed module layout + package map,
constructor injection, records for DTOs, `BigDecimal` for money, RFC 7807 errors,
`@Valid`, test-container-backed itests, migration discipline (UNDO/reversible), style
bound to the build, and explicit Boot-4 rename lists. Edit/verify rules for security and
"ask before assuming" appear only in the better files (pig, tencent, cloudbreak).

---

## 2. Architectural guardrails as code

### 2.1 ArchUnit (TNG) — 1.5.1, 3.9k★, pushed 2026-09-20
- Repo: https://github.com/TNG/ArchUnit
- **`GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION`** exists out of the box:
  `archunit/src/main/java/com/tngtech/archunit/library/GeneralCodingRules.java` L430
  (`"no classes should use field injection"`, reason: constructor/setter injection preferred).
  This is the cheapest deterministic enforcement of the framework's "constructor injection only" rule.
- **Canonical examples** (copy-paste-able): https://github.com/TNG/ArchUnit-Examples (654★)
  - `example-junit5/.../LayeredArchitectureTest.java` — the canonical layering rule:
    ```java
    @AnalyzeClasses(packages = "com.example.orders")
    class ArchitectureTest {
      @ArchTest static final ArchRule layers = layeredArchitecture()
        .consideringAllDependencies()
        .layer("Api").definedBy("..api..")
        .layer("Core").definedBy("..core..")
        .layer("Adapters").definedBy("..adapters..")
        .whereLayer("Api").mayNotBeAccessedByAnyLayer()
        .whereLayer("Core").mayOnlyBeAccessedByLayers("Api", "Adapters")
        .whereLayer("Adapters").mayOnlyBeAccessedByLayers("Core");
    }
    ```
  - `CyclicDependencyRulesTest.java` — `SlicesRuleDefinition.slices().matching("..(*)..").should().beFreeOfCycles()`
  - `NamingConventionTest.java`, `DependencyRulesTest.java`, `DaoRulesTest.java`, `ControllerRulesTest.java`
  - **`FrozenRulesTest.java` → `FreezingArchRule.freeze(rule)`** — records current violations
    and only fails on *new* ones. Ideal for introducing guardrails into existing services
    without a big-bang cleanup; ratchet by deleting frozen entries.
- Dependency/wiring: `com.tngtech.archunit:archunit-junit5:1.5.1` (api+engine). No official
  Gradle plugin; JabRef pins `archunit` + `archunit-junit5-api` + `archunit-junit5-engine`
  1.5.1 in its version catalog (`JabRef/jabref versions/build.gradle.kts`). Rules live in
  `src/test/java` so `./gradlew test` (already in `make test`) fails the build.

### 2.2 Spring's own ArchUnit usage (the "what Spring teams actually adopt" answer)
- `spring-projects/spring-boot`:
  `buildSrc/src/main/java/org/springframework/boot/build/architecture/ArchitectureRules.java` (718 lines)
  and `ArchitecturePlugin.java`.
  - `allPackagesShouldBeFreeOfTangles()` = `SlicesRuleDefinition.slices().assignedFrom(new SpringSlices()).should().beFreeOfCycles()` with a custom `SliceAssignment` that slices by top-level package area and can `SliceIdentifier.ignore()` specific packages.
  - Other rules: forbidden class calls (`Objects.requireNonNull`, `URLEncoder` with String encoding, `Collectors.toList`), AOT-compat bean-method rules, `@ConfigurationProperties` rules (use `LinkedHashSet`/`LinkedHashMap` implementations, `@Deprecated` requires `since`).
  - `ArchitecturePlugin` registers an `ArchitectureCheck` task **per source set**, depends on that source set's compile + processResources, and wires it into `check`. Reusable pattern for the framework's `itest` source set.
- `spring-projects/spring-framework`:
  `buildSrc/src/main/java/org/springframework/build/architecture/ArchitectureRules.java` (113 lines)
  — enum of rules: free-of-tangles slices, forbidden type imports (reactor `Assert`,
  `org.slf4j.LoggerFactory`, `org.springframework.lang.NonNull/@Nullable`), locale-safe
  `String.toLowerCase/UpperCase`, no Kotlin annotations in Java.

### 2.3 Spring Modulith — 2.2.0 GA (2026-11-19), 1.2k★
- Repo: https://github.com/spring-projects/spring-modulith
- `ApplicationModules.of(Application.class).verify();` throws on boundary violations
  (`src/docs/antora/modules/ROOT/pages/verification.adoc`); named interfaces and
  `allowedDependencies` express what a module may use (fundamentals.adoc).
- `@ApplicationModuleTest(BootstrapMode.DIRECT_DEPENDENCIES)` + `Scenario` for slice tests
  (`readme.adoc`, example project `spring-modulith-examples`).
- Event externalization: `spring-modulith-events-*` (Kafka/AMQP/JPA outbox) +
  `@Externalized("target::#{#this.…}")` (`pages/events.adoc` L445-516). The outbox example
  (`spring-modulith-example-outbox`) is the model for reliable cross-service events.
- Mapping: optional step 2 of `architecture-guardrails` for services that grow past 3
  modules; `ApplicationModules.verify()` is the module-boundary equivalent of the
  framework's `api/core/adapters` layering. **Compatibility**: Modulith 2.x targets Boot 4.x;
  pin via `spring-modulith-bom` and confirm the exact Boot 4.1 pairing on the project's
  compatibility page before adoption **[UNVERIFIED pairing]**.

### 2.4 Boot 4 test slices (verified paths in `spring-projects/spring-boot` @ main)
- `module/spring-boot-webmvc-test/src/main/java/org/springframework/boot/webmvc/test/autoconfigure/AutoConfigureMockMvc.java`
- `module/spring-boot-webflux-test/src/main/java/org/springframework/boot/webflux/test/autoconfigure/WebFluxTest.java`
- Starters: `spring-boot-starter-webmvc-test`, `spring-boot-starter-webflux-test`,
  `spring-boot-starter-data-jpa-test`(family), `spring-boot-starter-security-test` —
  Boot 4 splits test support per technology. The migration guide (see §4) adds the
  **semantic** change: `@SpringBootTest` no longer supplies MockMvc/`TestRestTemplate`/`WebClient`.
- Mapping: `spring-testing` skill decision table + a grep check that a `@SpringBootTest`
  intending MVC also has `@AutoConfigureMockMvc`.

### 2.5 Contract testing — **project is archived**
- https://github.com/spring-attic/spring-cloud-contract — **archived**, last push 2026-07-06, 726★.
- Official transition: https://spring.io/blog/2026/07/06/spring-cloud-contract-transition-to-stubbornsh
  — maintenance/ownership moved to Marcin Grzejszczak under **Stubborn.sh**, and Spring Cloud
  Contract is **removed from all future release trains**. Confirmed absent from the
  `v2025.1.5` and `v2026.0.0` release-train project lists
  (https://github.com/spring-cloud/spring-cloud-release/releases).
- Successors: `stubborn-sh/stubborn-openapi`, `stubborn-sh/stubborn-samples` — created
  Nov 2026, 2★/0★, **too immature to adopt**.
- Recommendation: replace the contract-checking gap with a **deterministic OpenAPI diff gate**:
  `oasdiff` on committed OpenAPI specs per service, plus an explicit allowlist for deliberate
  breaks (pattern proven in cloudbreak `cb-swagger-check` / `openapi-breaking-allowlist.txt`).
  WireMock / `MockRestServiceServer` for consumer-side stubs remains fine.

---

## 3. Build / quality tooling (versions verified 2026-11-24)

| Tool | Coordinate / plugin id | Verified version | How to wire | Informs |
|---|---|---|---|---|
| Spotless | `com.diffplug.spotless` (plugin portal) | **8.12.0** | `spotless { java { googleJavaFormat("2.0.0") } }`; `spotlessCheck` in CI + pre-commit. `googleJavaFormat('2.0.0')` supports `maxLineLength(120)`, `formatJavadoc(false)`, `reorderImports(false)`, `cleanup(false)` (Spotless `plugin-gradle/README.md` L446-452) | `hooks/pre-commit`, CI lint job — replaces hand-formatting and ends format-only diffs |
| google-java-format | `com.google.googlejavaformat:google-java-format` | **2.0.0** | pinned through Spotless step | same |
| OWASP dependency-check | **`org.owasp.dependencycheck`** (plugin portal) | **13.0.0** | `dependencyCheckAnalyze`; `dependencyCheck { failBuildOnCVSS = 7; formats = ['HTML','SARIF']; suppressionFile = ...; nvdApiKey = env }`. Plugin id docs: `dependency-check/DependencyCheck src/site/markdown/dependency-check-gradle/index.md.vm` | CI security gate (deterministic, no account) — §5 of the framework's hard rules |
| JaCoCo | core `jacoco` plugin | **0.8.16** (`org.jacoco.agent`) | `jacocoTestCoverageVerification` + `check.dependsOn(...)`. A report is **not** a gate — must wire the verification task (rrezart `spring-boot-verification` SKILL.md makes this exact point) | CI quality gate on agent-written code |
| Checkstyle | core `checkstyle` plugin | repo 10.12.5; latest **14.4.0** (major) | Keep 10.12.5 for now; 14.x likely needs config migration **[UNVERIFIED compat]**. Tencent's pattern: bind to `validate`/compile so agents never see unrelated pre-existing violations | existing `make lint` |
| PMD | core `pmd` plugin | **7.29.0** (`net.sourceforge.pmd:pmd-core`) | Optional; ArchUnit + Checkstyle likely cover the agent failure modes | `make lint` (optional) |
| Flyway | `org.flywaydb.flyway` (plugin portal) + `org.flywaydb:flyway-core` / `flyway-database-postgresql` | **13.13.0** | `flywayMigrate` local only; CI runs `flywayValidate`/`info` against an ephemeral Testcontainers DB; **ban `ddl-auto: update`** in `spring-guard.sh`. Boot 4 starter: `spring-boot-starter-flyway` | `aws-postgres` + `spring-data-jpa` skills |
| Liquibase | `org.liquibase.gradle` + `org.liquibase:liquibase-core` | **3.1.1** / **5.0.4** | Alternative to Flyway — pick one, never both | `aws-postgres` |
| `spring-boot-properties-migrator` | `org.springframework.boot:spring-boot-properties-migrator` (runtimeOnly) | from Boot BOM | Temporary during migration: prints diagnostics at startup + temporarily migrates properties; **must be removed before release** (migration guide §"Configuration Properties Migration") | `spring-boot-4-migration` + a CI check that fails if it is in `main` deps |
| Boot Testcontainers | `org.springframework.boot:spring-boot-testcontainers` + `org.testcontainers:postgresql` | from Boot BOM | `@ServiceConnection` (`core/spring-boot-testcontainers/.../service/connection/ServiceConnection.java` in Boot main) removes manual `@DynamicPropertySource` wiring | `spring-testing` itest samples |
| Snyk | `snyk/gradle-plugin` (20★, pushed 2026-11-16) / Snyk CLI | n/a | Needs account token + network → **not deterministic** for the agent loop. Use OWASP dep-check as the hard gate; Snyk as scheduled/optional | CI (optional) — **[UNVERIFIED official Gradle guidance]** |

Already present in the repo and therefore "keep": Checkstyle (`config/checkstyle`),
Testcontainers BOM, `spring-boot-starter-test`. Missing: Spotless, JaCoCo gate,
dependency-check, Flyway validation, ArchUnit.

---

## 4. Spring Boot 4 migration guardrails (as of 2026-11-24)

Official sources (wiki is a git repo — clone `spring-projects/spring-boot.wiki.git`):
- **Migration guide** (1,508 lines): https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide
  (raw: `releasenotes/Spring-Boot-4.0-Migration-Guide.asciidoc`)
- **Config property changelog** (1,345 lines): https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Configuration-Changelog
  — sections "Deprecated in 4.0.0" / "Added in 4.0.0" / "Removed in 4.0.0"
- **4.1 release notes**: https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.1-Release-Notes
  — key line: *"Classes, methods and properties that were deprecated in Spring Boot 4.0 have been removed in this release"*.
  So 4.0→4.1 is itself a breaking upgrade; `layertools` jar mode and Derby are gone.

Verified breaking changes agents get wrong:

1. **`@MockBean`/`@SpyBean` removed** → `@MockitoBean`/`@MockitoSpyBean`
   (`org.springframework.test.context.bean.override.mockito`). Behavior differs: one
   `@MockitoBean(types = {A.class, B.class})` can replace several old annotations; `name`
   selects the bean. Guide §1419-1508.
2. **Starters renamed** (guide "Deprecated Starter | Replacement" table):
   `spring-boot-starter-web` → `spring-boot-starter-webmvc`;
   `spring-boot-starter-web-services` → `-webservices`;
   `spring-boot-starter-oauth2-*` → `spring-boot-starter-security-oauth2-*`;
   web/DB technology **test starters** split out (`spring-boot-starter-webmvc-test`, …);
   Jackson starter is `spring-boot-starter-jackson`.
3. **Spring Cloud Gateway 5**: artifact `spring-cloud-starter-gateway-server-webflux`
   (official docs `spring-cloud-gateway-server-webflux/starter.adoc`); config namespace
   becomes `spring.cloud.gateway.server.webflux.*` (Gateway 5) — old
   `spring-cloud-starter-gateway` must not be used. Framework already pins the right name.
4. **Jackson 3**: group/package `com.fasterxml.jackson` → `tools.jackson`
   (annotation module keeps `com.fasterxml.jackson.annotation`).
   `spring.jackson.read/write.*` → `spring.jackson.json.read/write.*`.
5. **Jakarta EE 11 / Servlet 6.1 baseline**; **Undertow dropped**; Jersey 4 (no Jackson 3 support).
6. **Removed config properties** (examples from changelog): `management.endpoint.*.enabled`
   → `management.endpoint.*.access`; `spring.http.client.*` → `spring.http.clients.*`;
   `spring.session.redis.*` → `spring.session.data.redis.*`. Detect with
   `spring-boot-properties-migrator`, then remove it.
7. **Testing semantics** (the ones community checklists get wrong):
   - `@SpringBootTest` no longer provides MockMvc → add `@AutoConfigureMockMvc`.
   - No `TestRestTemplate`/`WebClient` beans → add `@AutoConfigureTestRestTemplate` /
     `@AutoConfigureRestTestClient`; `TestRestTemplate` moved to
     `org.springframework.boot:spring-boot-resttestclient`, package
     `org.springframework.boot.resttestclient`.
   - `MockitoTestExecutionListener` removed → use `MockitoExtension`.
   - `@PropertyMapping` moved to `org.springframework.boot.test.context`.
8. **`HttpMessageConverters` deprecated** → `ClientHttpMessageConvertersCustomizer` /
   `ServerHttpMessageConvertersCustomizer` (contributing raw `HttpMessageConverter` beans no longer supported).
9. Bridge: `spring-boot-starter-classic` + `spring-boot-starter-test-classic` as a temporary
   two-step migration aid, then remove.

Community "Boot 4 migration" checklists:
- **rrezartprebreza `skills/spring-boot-4/spring-boot-migration/SKILL.md`** — accurate and
  the best template: baseline (Java 17+, Framework 7, Jakarta EE 11, Servlet 6.1, GraalVM 25),
  starter matrix, `@AutoConfigureMockMvc` requirement, Jackson 3, properties-migrator workflow
  (`add → start every profile → fix → remove → compare /actuator/configprops`).
- **piomin CLAUDE.md** — useful but has **two disproven claims**: "@AutoConfigureMockMvc
  removed" and "@WebFluxTest removed". Both classes exist in Boot 4
  (`module/spring-boot-webmvc-test/...`, `module/spring-boot-webflux-test/...`); they moved
  modules/packages, and MockMvc support must now be opted into. **Do not copy uncorrected.**
- **arconia-migrations** Spring Cloud 2026.0 migration doc
  (`arconia-io/arconia-migrations`, `docs/.../spring-cloud/2026-0.adoc`) records the
  contract→Stubborn migration recipe **[community doc, not independently verified]**.
- rrezart claims "Boot 4.1 support starts with Spring Cloud 2025.1.2" **[UNVERIFIED]** —
  plausible; confirm against the 2025.1.x train notes before encoding.

Deterministic hook checks (`hooks/spring-guard.sh`) that follow from the above:
```
@MockBean|@SpyBean                                  -> fail (use @MockitoBean)
spring-boot-starter-web\b (not webmvc/webflux)      -> fail
spring-cloud-starter-gateway\b (not -server-webflux)-> fail
com\.fasterxml\.jackson\.(databind|core|dataformat) -> fail (Jackson 3)
ddl-auto:\s*(update|create|create-drop)             -> fail
open-in-view:\s*true                                -> fail
spring-boot-properties-migrator in main deps        -> fail (temporary only)
```
Plus a build-log gate: run `./gradlew dependencyInsight --dependency spring-boot` and fail on
anything below 4.x.

---

## 5. AI-agent-specific Spring skills / subagents

| Repo | What it ships | Reusability |
|---|---|---|
| [rrezartprebreza/spring-boot-skills](https://github.com/rrezartprebreza/spring-boot-skills) — 363★, MIT, pushed 2026-11-17 | 44 skills × (Boot 3, Boot 4): `spring-boot-migration`, `spring-data-jpa`, `layered-architecture`, `spring-security-review`, `spring-security-jwt`, `spring-cloud-gateway`, `spring-modulith`, `transactional-patterns`, `flyway-migrations`, `problem-details-rfc9457`, `testing-pyramid`, `rest-api-conventions`, `spring-boot-verification`, `java-supply-chain-security`, `observability`, `idempotency-patterns`, `hexagonal-architecture`, …; 6 specialist agents for Claude (`specialists/claude/*.md`) + 6 Codex TOML; eval scripts + verification matrix | **Highest.** Directly adapt into `.agents/skills/` (MIT licence, keep attribution); specialists into `.claude/agents/` and `.codex/agents/` |
| [jabrena/plinth](https://github.com/jabrena/plinth) — 466★, Apache-2.0, pushed today | "AI-native Java enterprise toolkit": 125 skills, 9 agents, 14 commands, installable via `npx skills add`; Spring skills use a numeric taxonomy, e.g. `305-frameworks-spring-boot-modulith` | Skill packaging/naming convention + Spring Modulith content; borrow structure, not wholesale |
| [kumaran-is/claude-code-onboarding](https://github.com/kumaran-is/claude-code-onboarding) — 37★, MIT | Onboarding kit with Java 21 / Spring Boot WebFlux agents, skills, commands, MCP | Pattern reference only |
| [DIL8654/claude-code-springboot-template](https://github.com/DIL8654/claude-code-springboot-template) — 1★ | Gradle Spring Boot template with shared `AGENTS.md` for Claude/Copilot/local LLMs | Too small; skip |
| [mduongvandinh/skills-java-spring](https://github.com/mduongvandinh/skills-java-spring) — 6★, stale (2025-12) | `.windsurfrules` Spring skill variants | Stale; skip |
| [hortonworks/cloudbreak](https://github.com/hortonworks/cloudbreak/tree/master/.agent/skills) — 361★ | Repo-native playbooks: db-migration, testing, swagger-check, code-reviewer | Best model for repo-specific skills; borrow `cb-db-migration` / `cb-swagger-check` content |
| [MassimilianoPili/agent-framework](https://github.com/MassimilianoPili/agent-framework) | Backend agent `SKILL.md` with context isolation between dependency tasks | Pattern reference for multi-agent scoping **[relevance unverified beyond one file]** |

---

## Recommended additions to this framework (priority order)

1. **`architecture-guardrails` made executable**: generate `services/*/src/test/java/.../ArchitectureTest.java`
   from TNG/ArchUnit-Examples — layering (`api → core → adapters`), `NO_CLASSES_SHOULD_USE_FIELD_INJECTION`,
   `beFreeOfCycles`, naming/location; add `com.tngtech.archunit:archunit-junit5:1.5.1`, run under `make test`.
   Use `FreezingArchRule` for pre-existing services.
2. **`spring-boot-4-migration` skill** corrected against the official wiki (§4 list) + expand
   `hooks/spring-guard.sh` with the grep table above (catches what agents forget even when told).
3. **Spotless + CI**: `com.diffplug.spotless` 8.12.0 with `googleJavaFormat("2.0.0")`, `spotlessCheck`
   in pre-commit and CI; terminate format-only diffs.
4. **Quality gates in CI**: OWASP `org.owasp.dependencycheck` 13.0.0 (`failBuildOnCVSS`), JaCoCo
   0.8.16 `jacocoTestCoverageVerification` wired into `check`, Flyway `validate` against ephemeral
   Testcontainers PostgreSQL.
5. **Contract gate without Spring Cloud Contract**: oasdiff on per-service OpenAPI + allowlist
   (`openapi-breaking-allowlist.txt`) — replaces the archived project; flag the retirement in
   `requirements-and-design`.
6. **`spring-testing` skill**: Boot 4 slice decision table (@WebMvcTest vs @SpringBootTest +
   @AutoConfigureMockMvc), `@ServiceConnection` Testcontainers, no `@MockBean`.
7. **CLAUDE.md / AGENTS.md additions**: per-module nested `CLAUDE.md` (ecchronos pattern) for each
   `services/*` module; RFC 7807 error contract; "ask before assuming" + surgical-change rules
   (pig/tencent); security CWE list into `secure-api-review` (wiz-sec).
8. **Platform follow-up (Stage 6 candidate)**: Spring Cloud **2026.0.0 GA 2026-11-20** and Boot
   **4.1** remove 4.0 deprecations — schedule a platform-owned migration intent; also track
   Spring Modulith 2.2.0 as the module-boundary upgrade path.

## Verification log / caveats
- Liveness + license checked via GitHub API for all repos cited (stars/pushed dates in table headers).
- Maven Central / Gradle Plugin Portal consulted for every version number (note: the OWASP plugin
  marker on the portal is 13.0.0 while the old Central artifact `org.owasp:dependency-check-gradle`
  sits at 10.0.3 — the portal is authoritative).
- The Spring Boot wiki has **no 4.1 migration guide** (only 4.0; 4.1 is covered by release notes).
- Disproven claims flagged inline (piomin: `@AutoConfigureMockMvc`/`@WebFluxTest` "removed").
- Unverified: Modulith 2.2 ↔ Boot 4.1 exact pairing; rrezart's "Boot 4.1 needs SC 2025.1.2+";
  Checkstyle 14.x config compatibility; Snyk's official Gradle guidance; Stubborn.sh maturity.
