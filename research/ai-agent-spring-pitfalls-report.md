# AI Coding Agents on Spring Boot / Spring Cloud — Failure Catalogue, Deterministic Guardrails, and Boring Conventions

**Scope:** Java 21 · Spring Boot 4.1.x · Spring Cloud 2025.1 (Oakwood) · Spring Framework 7 · JPA/Hibernate · Spring Security 7 · k8s-native discovery + Config Server + Resilience4j.

**Method:** canonical Spring/Hibernate docs and Javadoc, Spring blog/release notes, SonarSource rule sources, ArchUnit/Spring Modulith docs, practitioner references (Vlad Mihalcea, Thorben Janssen, Baeldung), plus AI-code evidence (Veracode, CACM, GitClear, Thoughtworks). Repo facts verified against this checkout (`gradle/libs.versions.toml`, `hooks/`, `scripts/`, `.agents/skills/`).

**Bottom line:** the failure mode is not "the agent doesn't know Spring". It is that **the model's priors are Boot 2/3-era, tutorial-grade, and happy-path**, while this repo is Boot 4.1.3 and production-shaped. Knowledge already lives in `AGENTS.md`, `CLAUDE.md` and the skills; the leverage is the **deterministic layer** (ArchUnit tests, config-invariant tests, CI grep/Semgrep, OpenRewrite, Sonar gate) that makes stale priors impossible to merge.

At the time of this research the deterministic layer has just been **partially built** (verified in this checkout): `hooks/spring-guard.sh` exists and is wired into `.githooks/pre-commit`; `scripts/new-service.sh` now generates an `ArchitectureTest.java`; `services/demo-service` is scaffolded with it. Coverage is uneven, though: the guard checks **5 pattern groups**, the ArchUnit test **7 rules**, and neither checks runtime config invariants (OSIV bean, actuator allow-list, page cap, `ProblemDetail`), CSRF/`permitAll` pairing, Lombok-on-entity, N+1, timeouts, or scheduling locks. **Completing that coverage matrix is the highest-value work — not adding more prose.** §6.1 has the exact gap list.

---

## 0. Priority stack (highest value first)

Value = impact × frequency × determinism (how cheaply a machine can catch it).

| # | Pitfall | Impact if missed | Deterministic catch | Framework piece today | Gap to close |
|---|---|---|---|---|---|
| 1 | `@Transactional` proxy semantics: self-invocation, private/final methods, checked-exception rollback, long tx | silent partial commits / data corruption | Sonar `S6809` + `S2230`; ArchUnit "transactional methods are public"; review | `spring-data-jpa` (advisory) | ArchUnit rule + eval + review pass |
| 2 | `ddl-auto` outside `validate`/`none` in prod; no migration discipline | schema drift / data loss | config-invariant test; CI YAML guard; Flyway presence | `aws-postgres`, `spring-data-jpa` | `scripts/check-config-invariants.sh` + test |
| 3 | Entity leakage to API + OSIV (default **true**) + N+1 | PII leak, LazyInitializationException, latency/DoS | ArchUnit (api→`@Entity`); context test (no `OpenEntityManagerInViewInterceptor`); `SQLStatementCountValidator` | `architecture-guardrails`, `spring-data-jpa` | context test + N+1 budget itest |
| 4 | Actuator exposed unauthenticated; custom `SecurityFilterChain` silently turns off Boot's actuator protection | env/heapdump/threaddump exposure | config test; security slice test | `secure-api-review` | config test + Semgrep |
| 5 | Outbound HTTP without connect/read timeouts; retry on non-idempotent writes | thread-pool exhaustion, cascading failure, duplicate payments | ArchUnit (no `WebClient.create`/`new RestTemplate`); WireMock delay itest; idempotency test | `resiliency-review` | ArchUnit ban + timeout itest |
| 6 | `permitAll` misconfig + CSRF disabled without stateless session + secrets in `application.yml` | auth bypass, CSRF, credential leak | Semgrep/grep; `gitleaks`; security tests | `secure-api-review`, `hooks/no-secrets.sh` | Semgrep rules |
| 7 | Multi-replica `@Scheduled` without a distributed lock | duplicated side effects (charges, emails) | ArchUnit `@Scheduled`→`@SchedulerLock`; `LockProvider` bean test | none | new `spring-scheduling` skill + rules |
| 8 | Boot 4 API drift (`@MockBean`, Jackson 2, starter names, `spring.cloud.gateway.*` paths) | red build or silent mis-serialization | compiler + `hooks/spring-guard.sh` (exists, partial) + OpenRewrite | `spring-boot-4-migration` | extend hook (Jackson 2, `javax.*`, property prefixes); OpenRewrite dry-run in CI |
| 9 | Lombok `@Data`/`@EqualsAndHashCode` on entities; missing `@Version` | broken identity, lazy-load in `equals`, lost updates | source scan (Lombok is SOURCE-retention → **not** ArchUnit); metamodel/reflection test for `@Version` | `spring-data-jpa`, `architecture-guardrails` (rule 9) | source scanner (grep/Semgrep) |
| 10 | Unbounded `findAll()` / no page cap | heap exhaustion / DoS | Sonar `S7186`; config test `max-page-size`; contract test | none explicit | config test + contract test |
| 11 | Field `@Autowired` | hidden deps, circularity, bad tests | `GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION`; Checkstyle regex | `architecture-guardrails` (rule 5) | generated `ArchitectureTest` covers `@Autowired`/`@Resource`; add `GeneralCodingRules` for `@Inject`/`@Value` |
| 12 | Missing `@Valid` / `@ConfigurationProperties` without `@Validated` | 500s instead of 400s; invalid config at boot | `scripts/check-endpoints.sh` (weak); ArchUnit on `@ConfigurationProperties`; Semgrep | `secure-api-review` | strengthen both |
| 13 | REST contract drift: no `ProblemDetail`, no versioning, no pagination envelope | clients break on errors/versions | MockMvc error-shape test; `RequestMappingHandlerMapping` version test; `spring.mvc.apiversion.*` | none | new `spring-api-contract` skill + tests |
| 14 | Test shape: full `@SpringBootTest` for a slice concern; H2 for SQL; `@MockBean` | slow, green-but-wrong suite | ArchUnit on test classes; Testcontainers config check | `spring-testing` | ArchUnit test-class rules |
| 15 | `@Async`/`@Cacheable`/`@Retry` self-invocation | annotation silently does nothing | Sonar `S6809`; review | `spring-data-jpa` mentions tx only | add to skill + review |
| 16 | Gateway misconfig (hardcoded `uri`, missing timeouts, blocking calls in WebFlux filters) | routing failures, blocked event loop | route-definition test; ArchUnit ban `.block()` in gateway | `gitops-deploy`, `resiliency-review` | gateway config test |
| 17 | Money as `double`; time as `java.util.Date`/bare `LocalDateTime` | rounding errors, timezone bugs | ArchUnit field-type rules; Checkstyle `IllegalType` | `spring-service-conventions`, `architecture-guardrails` (rule 8) | ArchUnit field-type rules |
| 18 | Package-by-layer drift; `core` importing web/persistence | unmaintainable monolith | ArchUnit slices; Spring Modulith `verify()` | `architecture-guardrails` | generate rule set |

**Gate coverage in this checkout (verified):**

| Gate | Exists? | Covers | Does **not** cover |
|---|---|---|---|
| `hooks/spring-guard.sh` + `.githooks/pre-commit` | **yes** | `@MockBean`/`@SpyBean`; `spring-boot-starter-web`; `spring-cloud-starter-gateway`; `open-in-view: true`; `ddl-auto: update/create/create-drop` | Jackson 2 imports, `javax.*`, gateway property prefix, actuator `"*"`, `permitAll`, `csrf.disable()` pairing, literal secrets, `@Data` on entity, `findAll()` in controllers, missing `@SchedulerLock`, unbounded timeouts |
| Generated `ArchitectureTest` (ArchUnit 1.5.1) | **yes** | api↛adapters; core↛web/api; controller/entity placement; field `@Autowired`/`@Resource`; `java.util.Date`; transactional methods public | `@Inject`/`@Value` field injection; `@Async` public; entity→api leakage (indirectly only); `@ConfigurationProperties` validation; `@Scheduled` lock; `@Retryable` idempotency; money/`Double`; no-cycles slice rule; HTTP client construction; **`@Data` on entity (cannot be ArchUnit — SOURCE retention)** |
| `scripts/check-endpoints.sh` | **yes** | any `@Valid` in a controller with state-changing mappings | `@RequestBody` **without** `@Valid`; collection endpoints without `Pageable`; `ProblemDetail` handlers; CSRF/`permitAll` |
| Runtime config invariants (`ProductionConfigInvariantsTest`, `NoOsivTest`) | **no** | — | OSIV interceptor absent; actuator allow-list; `max-page-size`; `problemdetails.enabled`; profile-specific overrides |
| Behavioural itests (N+1 budget, timeout, idempotency, optimistic lock, pagination clamp, `ProblemDetail` shape) | **no** | — | all of the above |
| Sonar / Semgrep / OpenRewrite / gitleaks in CI | **no** (only `no-secrets.sh`) | local secret grep | everything static-analysis-grade |

---

## 1. Why AI agents produce these (evidence, not vibes)

1. **AI-generated code is measurably less secure.** Veracode's 2025 GenAI Code Security Report found security flaws in **45%** of generated samples across 100+ LLMs, with **Java the highest-risk language** and larger/newer models not improving security ([Veracode report](https://www.veracode.com/resources/analyst-reports/2025-genai-code-security-report), [press release](https://www.veracode.com/press-release/ai-generated-code-poses-major-security-risks-in-nearly-half-of-all-development-tasks-veracode-research-reveals/)).
2. **Copilot-class models reproduce vulnerable patterns.** "Asleep at the Keyboard?" measured **39.3%** of top and **40.7%** of all generated options vulnerable across security scenarios ([CACM](https://cacm.acm.org/research-highlights/asleep-at-the-keyboard-assessing-the-security-of-github-copilots-code-contributions/), [DOI](https://dl.acm.org/doi/10.1145/3610721)).
3. **AI assistance increases duplication and churn.** GitClear's 12-month study found duplicated ("copy/pasted") code rising from **8.3% to 12.3%** while refactoring/moved-line reuse declined ([GitClear 2025](https://www.gitclear.com/ai_assistant_code_quality_2025_research)); Thoughtworks' Radar lists **"Complacency with AI-generated code"** as a technique to watch ([Thoughtworks](https://www.thoughtworks.com/radar/techniques/complacency-with-ai-generated-code)).
4. **The model's version priors are wrong for this repo.** Spring Boot 4 removed `@MockBean`/`@SpyBean`, made Jackson 3 the default (`tools.jackson`), renamed starters (`spring-boot-starter-webmvc`, `spring-cloud-starter-gateway-server-webflux`), moved test annotations, and changed gateway property prefixes. Even the Boot 4 *migration* rules are now a skill in this repo ([`spring-boot-4-migration`](.agents/skills/spring-boot-4-migration/SKILL.md); sources: [Moderne migration guide](https://docs.moderne.io/user-documentation/recipes/popular-recipe-guides/migrate-to-spring-boot/), [Jackson 3 in Spring](https://spring.io/blog/2025/10/07/introducing-jackson-3-support-in-spring), [Spring Cloud 2025.0 gateway renames](https://spring.io/blog/2025/05/29/spring-cloud-2025-0-0-is-abvailable)).
5. **Agents optimize for compiling, happy-path code.** They rarely reason about proxy boundaries, transactional rollback, connection-pool exhaustion, replica concurrency, or production config. Spring's own docs describe these failure modes as *silent* ("no error is raised, but the annotated method does not exhibit the configured transactional settings") — the agent gets no compiler feedback, so it never learns it was wrong ([Spring `@Transactional` docs](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html)).
6. **The ecosystem is already writing "anti-prior" skills for agents.** Examples that enumerate exactly these pitfalls: [`github/awesome-copilot`](https://github.com/github/awesome-copilot) (`spring-boot-testing`, `spring-boot-4-migration`, `spring-security` references), [`jdubois/dr-jskill`](https://github.com/jdubois/dr-jskill), [`moonshineaitech/LunaStack` spring-boot-expert](https://github.com/moonshineaitech/LunaStack/blob/main/wiki/skills/frameworks/spring-boot-expert.md), [`wahidyankf/ose-primer` Spring Boot anti-patterns](https://github.com/wahidyankf/ose-primer/blob/0040410dcdab188d9d42c564b0acddbaf07da33b/docs/explanation/software-engineering/platform-web/tools/jvm-spring-boot/anti-patterns.md), [`IamP5/springboot-plugin` Boot 4 rules](https://github.com/IamP5/springboot-plugin/blob/35665c277a78112176eee13d63b5e8c47963fc5a/skills/java-spring-updates/rules/boot4-test-overrides.md), [`VincentChuWaiChow/vanguard-frontier-agentic` java-resilience-pattern](https://github.com/VincentChuWaiChow/vanguard-frontier-agentic/blob/master/skills/java/java-resilience-pattern/SKILL.md), [`kumaran-is/claude-code-onboarding` Spring Boot verification gates](https://github.com/kumaran-is/claude-code-onboarding/blob/develop/.claude/skills/java-spring-api/reference/spring-boot-verification-gates.md). That these repos exist is evidence the problem is systemic, not local.

**Implication:** do not spend more tokens telling agents what good code looks like. Spend them **failing the build** when they produce the bad shape, and reserve the model for diagnosis/fix. This matches `AGENTS.md` §1.5 ("Detection is deterministic; diagnosis can be yours").

---

## 2. P0 pitfalls — data loss, security, outage

### 2.1 `@Transactional` proxy semantics

**What AI code looks like**

```java
@Service
public class OrderService {
  @Transactional
  public void placeOrder(Order o) {
    repo.save(o);
    this.applyDiscount(o);          // ← self-invocation: no proxy, @Transactional ignored
  }
  @Transactional(propagation = REQUIRES_NEW)
  private void applyDiscount(Order o) { ... }   // ← private: never advised
}
```

Also common: `@Transactional` on a `final` method/class (CGLIB cannot override), `catch (IOException e)` after a DB write without `rollbackFor` (checked exceptions do **not** roll back by default), `readOnly=true` omitted on read paths, and transactions spanning HTTP calls (`restClient.get()` inside `@Transactional`) — "long transaction" that pins a DB connection for the duration of a remote call.

**Why it is silent:** proxy-based AOP only wraps calls entering through the proxy; self-invocation and private/final methods bypass it. Spring docs say the annotation should be applied only to public methods and that non-public annotations raise no error but do nothing ([Spring docs](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html)); rollback defaults are `RuntimeException`/`Error` only, so `rollbackFor` is required for checked exceptions ([`@Transactional` Javadoc](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/transaction/annotation/Transactional.html), [rolling back docs](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/rolling-back.html)).

**Deterministic detection**
- Sonar **S6809** "Methods with Spring proxy should not be called via `this`" (covers `@Transactional`, `@Async`, `@Cacheable`) and **S2230** non-public annotated methods ([sonar-java S6809](https://github.com/SonarSource/sonar-java/blob/master/sonar-java-plugin/src/main/resources/org/sonar/l10n/java/rules/java/S6809.html), [S2230](https://github.com/sonar-java/sonar-java/blob/master/sonar-java-plugin/src/main/resources/org/sonar/l10n/java/rules/java/S2230.html), [Sonar Spring rules](https://rules.sonarsource.com/java/tag/spring/)).
- ArchUnit: transactional and async methods must be `public` (rule below).
- Review pass: "does any `@Transactional` method call another method on `this`; does the boundary contain remote I/O?"

**Framework piece:** `spring-data-jpa` already states the rules; add the ArchUnit rules and one eval (transaction self-invocation) so the skill is enforced, not just read.

**Sources:** [Spring transaction docs](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html), [proxy explanation](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/tx-decl-explained.html), [Baeldung self-invocation](https://www.baeldung.com/spring-async), [Sonar S6809](https://rules.sonarsource.com/java/RSPEC-6809/).

### 2.2 JPA: OSIV, N+1, entity leakage, Lombok, `@Version`, `ddl-auto`, `findAll()`

**What AI code looks like**

```java
@GetMapping("/orders")
public List<Order> all() { return orderRepository.findAll(); }      // entity + unbounded
```
```java
@Data @Entity class Order { @Id Long id; @ManyToOne Customer customer; }  // @Data on entity
```
```java
// application-prod.yml
spring:
  jpa:
    hibernate:
      ddl-auto: update
    open-in-view: true
```

**Facts to encode**
- **OSIV defaults to `true` even in Boot 4.** Source of truth: `JpaBaseConfiguration.JpaWebConfiguration` is `@ConditionalOnBooleanProperty(name = "spring.jpa.open-in-view", matchIfMissing = true)` and logs "enabled by default" when unset ([Boot source](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-jpa/src/main/java/org/springframework/boot/jpa/autoconfigure/JpaBaseConfiguration.java)); the "disable by default in 4.0" issue was reconsidered ([#47547](https://github.com/spring-projects/spring-boot/issues/47547)). OSIV is an anti-pattern: it holds the persistence context/connection for the whole request and hides missing fetch plans ([Vlad](https://vladmihalcea.com/the-open-session-in-view-anti-pattern/), [Baeldung](https://www.baeldung.com/spring-open-session-in-view)).
- **N+1** is the default behavior for lazy associations and is invisible without instrumentation ([Vlad N+1](https://vladmihalcea.com/n-plus-1-query-problem/), [detect N+1 in tests](https://vladmihalcea.com/how-to-detect-the-n-plus-one-query-problem-during-testing/), [`SQLStatementCountValidator`](https://github.com/vladmihalcea/hypersistence-utils)).
- **Lombok `@Data` on entities** generates `equals`/`hashCode`/`toString` over all fields, including lazy associations → lazy loads outside a session, broken `HashSet` identity, stack overflows ([Thorben Janssen](https://thorben-janssen.com/lombok-hibernate-how-to-avoid-common-pitfalls/), [equals/hashCode guide](https://thorben-janssen.com/ultimate-guide-to-implementing-equals-and-hashcode-with-hibernate/)).
- **`@Version`** enables optimistic locking; without it, last-write-wins silently loses updates ([Spring Data `@Version`](https://docs.spring.io/spring-data/jpa/reference/data-commons/4.2/api/java/org/springframework/data/annotation/Version.html)).
- **`ddl-auto=update`** is not a migration strategy; use Flyway/Liquibase and `validate` in prod ([Hibernate schema generation warning](https://docs.jboss.org/hibernate/orm/current/userguide/html_single/Hibernate_User_Guide.html#schema-generation), [Boot DB initialization](https://docs.spring.io/spring-boot/how-to/data-initialization.html)).
- **Unbounded `findAll()`** on a user-facing path is a heap/DoS bug; Boot caps `Pageable` at `spring.data.web.pageable.max-page-size` (default 2000) but only if a `Pageable` is used ([Boot common properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html)); Sonar **S7186** requires `Page`/`Slice` methods to take `Pageable` ([S7186 source](https://github.com/sonarsource/sonar-java/blob/master/sonar-java-plugin/src/main/resources/org/sonar/l10n/java/rules/java/S7186.html)).

**Deterministic detection**
- ArchUnit: `api` must not depend on `@Entity` types; `@Entity` classes live in `..adapters.persistence..`.
- Context test: `assertThat(ctx.getBeanNamesForType(OpenEntityManagerInViewInterceptor.class)).isEmpty()` (or `Environment` test that the property is `false`).
- itest with `SQLStatementCountValidator.reset()` / `assertSelectCount(n)` per use case (N+1 budget).
- Entity check test: every `@Entity` type has an `@Version` field (reflection over `EntityManagerFactory.getMetamodel().getEntities()`).
- Source scanner for `@Data` on `@Entity` — **must be a source scan**, because Lombok annotations have SOURCE retention and ArchUnit (bytecode) cannot see them. Use grep/Semgrep/Checkstyle `RegexpMultiline`, not ArchUnit.

**Framework piece:** `spring-data-jpa` + `architecture-guardrails` (both advisory today). Add `NoOsivTest`, `EntityVersioningTest`, `NPlusOneBudgetTest`, and a `check-jpa-traps.sh` source scan.

### 2.3 Security: Actuator, CSRF, `permitAll`, secrets

**What AI code looks like**

```yaml
management.endpoints.web.exposure.include: "*"
management.endpoint.health.show-details: always
```
```java
http.csrf(csrf -> csrf.disable())
    .authorizeHttpRequests(a -> a.anyRequest().permitAll());   // "for local testing" that ships
```
```yaml
spring:
  datasource:
    password: postgres
```

**Facts to encode**
- Actuator: **only `health` is exposed over HTTP by default**; `include: "*"` exposes `env`, `configprops`, `heapdump`, `threaddump`, `loggers`, `shutdown` etc. ([Boot endpoints docs](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html)). Critical trap: **if you define any `SecurityFilterChain`, Boot's actuator auto-protection backs off** — the agent's custom chain must re-secure `/actuator/**` ([same docs, Security section](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html#actuator.endpoints.security)).
- CSRF: Spring Security protects unsafe methods by default; disabling it is only safe for stateless token APIs where the browser never sends ambient credentials ([Spring Security CSRF](https://docs.spring.io/spring-security/reference/servlet/exploits/csrf.html)). The dangerous combination is `csrf.disable()` **with** cookies/sessions or `SessionCreationPolicy.IF_REQUIRED`.
- `permitAll()` on `anyRequest()` / `"/**"` is an auth bypass; object-level authorization (BOLA/IDOR) is the #1 API risk ([OWASP API Security Top 10 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)).
- Secrets in `application.yml` violate 12-factor and leak via the repo, actuator `env`, and logs ([12-factor config](https://12factor.net/config), [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)); this repo already has `hooks/no-secrets.sh`.

**Deterministic detection**
- Config test: `management.endpoints.web.exposure.include == "health"` (or explicit allow-list), `show-details: never`.
- Security slice test: `GET /actuator/env` → 401/404; `GET /actuator/health` → 200.
- Semgrep/grep: `anyRequest().permitAll()`, `requestMatchers("/**").permitAll()`, `csrf.disable()` without `SessionCreationPolicy.STATELESS`, literal `password:`/`secret:`/`token:` values in `*.yml`.
- `gitleaks` in pre-commit + CI (fail-closed).

**Framework piece:** `secure-api-review` is advisory and `scripts/check-endpoints.sh` only checks `@Valid`. Add `ProductionSecurityConfigTest`, Semgrep rules, and a `spring-security-baseline` section.

### 2.4 Outbound resilience: timeouts, retries, circuit breakers

**What AI code looks like**

```java
WebClient client = WebClient.create(baseUrl);                 // no timeouts
return client.get().uri("/inventory/{id}", id).retrieve().bodyToMono(Stock.class).block();
```
```java
@Retryable(maxAttempts = 3)
public void charge(Payment p) { ... }                         // retry on a non-idempotent POST
```

**Facts to encode**
- Reactor Netty sets **no response timeout by default**; every `WebClient`/`RestClient`/`RestTemplate` needs explicit connect + read/response timeouts ([Spring WebClient docs](https://docs.spring.io/spring-framework/reference/web/webflux-webclient.html), [Baeldung WebClient timeouts](https://www.baeldung.com/spring-webflux-timeout), [Gateway HTTP timeouts](https://docs.spring.io/spring-cloud-gateway/reference/spring-cloud-gateway-server-webflux/http-timeouts-configuration.html)).
- Retries must be bounded, exponential with jitter, and only on idempotent operations or operations guarded by an idempotency key ([AWS Builders' Library](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/), [Stripe idempotency keys](https://docs.stripe.com/api/idempotent_requests), [RFC 9110 idempotent methods](https://www.rfc-editor.org/rfc/rfc9110.html#name-idempotent-methods), [Azure Retry pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/retry)).
- Circuit breakers isolate failures; this repo standardizes on Resilience4j via `spring-cloud-starter-circuitbreaker-resilience4j` ([Spring Cloud CircuitBreaker](https://docs.spring.io/spring-cloud-circuitbreaker/reference/), [Resilience4j](https://resilience4j.readme.io/docs)).

**Deterministic detection**
- ArchUnit ban: no `WebClient.create(...)`, `RestClient.create()`, `new RestTemplate()` outside `..config..` (forces a single timeout-configured client bean).
- WireMock itest: stub a 2s delay, configure 500ms timeout, assert the call fails fast (proves the timeout is wired, not just declared).
- ArchUnit rule: `@Retryable` only on methods also annotated with an org-specific `@Idempotent` (or on `GET`-only adapters).
- Config test: every `WebClient` bean's Reactor Netty `HttpClient` has `responseTimeout` (or assert `app.http.*` properties are present and non-null).

**Framework piece:** `resiliency-review` is the right home; add the ArchUnit bans and one WireMock itest to the service template.

### 2.5 Boot 4 API drift (compile-time and silent runtime)

**What AI code looks like:** `@MockBean`, `org.springframework.boot.test.mock.mockito.MockBean`, `com.fasterxml.jackson.databind.*` custom serializers, `spring-boot-starter-web`, `spring-cloud-starter-gateway`, `spring.cloud.gateway.routes[*]`, `javax.validation.*`, `@WebMvcTest` from the Boot 3 package.

**Facts to encode**
- Boot 4 removed `@MockBean`/`@SpyBean`; use `@MockitoBean`/`@MockitoSpyBean` from Spring Test ([Moderne migration guide](https://docs.moderne.io/user-documentation/recipes/popular-recipe-guides/migrate-to-spring-boot/), [`@MockitoBean` Javadoc](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/test/context/bean/override/mockito/MockitoBean.html), [awesome-copilot Boot 4 testing reference](https://github.com/github/awesome-copilot/blob/main/skills/spring-boot-4-migration/references/08-testing.md)).
- Boot 4 defaults to **Jackson 3** (`tools.jackson`), with `spring-boot-jackson2` as a deprecated stop-gap ([Spring blog](https://spring.io/blog/2025/10/07/introducing-jackson-3-support-in-spring)).
- Starters renamed: `spring-boot-starter-web` → `spring-boot-starter-webmvc`; gateway 5.x modules renamed (`spring-cloud-gateway-server-webflux`) and property prefix changed ([Moderne](https://docs.moderne.io/user-documentation/recipes/popular-recipe-guides/migrate-to-spring-boot/), [Spring Cloud 2025.0 blog](https://spring.io/blog/2025/05/29/spring-cloud-2025-0-0-is-abvailable)).
- Boot 4 also relocated test-slice annotations into module-specific packages (e.g. `WebMvcTest`), so imports copied from Boot 3 tutorials fail or test the wrong slice.
- This repo already documents these in `CLAUDE.md` and `spring-boot-4-migration`; the skill references `hooks/spring-guard.sh` **which does not exist yet**.

**Deterministic detection:** OpenRewrite dry-run in CI (`org.openrewrite.java.spring.boot4.UpgradeSpringBoot_4_0`, `org.openrewrite.java.jackson.UpgradeJackson_2_3`, `AddModularStarters`) ([OpenRewrite Boot 4 recipe](https://docs.openrewrite.org/recipes/java/spring/boot4/upgradespringboot_4_0)); `hooks/spring-guard.sh` grep for the forbidden symbols; Checkstyle `IllegalImport` for `com.fasterxml.jackson`, `javax.`, `org.springframework.boot.test.mock.mockito`.

### 2.6 Multi-replica `@Scheduled` without a distributed lock

**What AI code looks like**

```java
@Scheduled(fixedDelay = 60_000)
public void closeExpiredAuctions() { ... }     // runs on every replica
```

`@Scheduled` is **not clustered**; with `replicas: 2+` (this repo runs on EKS) every pod runs the job. Detection: ArchUnit `@Scheduled` ⇒ `@SchedulerLock`; config test that a `LockProvider` bean exists; ShedLock (`lockAtMostFor` safety net, `lockAtLeastFor` dedupe) ([ShedLock](https://github.com/lukas-krecan/ShedLock), [Spring scheduling docs](https://docs.spring.io/spring-framework/reference/integration/scheduling.html)). Also check `spring.task.scheduling.pool.size` (default 1) so tasks don't block each other ([Boot task scheduling](https://docs.spring.io/spring-boot/reference/features/task-execution-and-scheduling.html)). Note: `@Scheduled` methods are invoked by the scheduler, not through a proxy — the self-invocation trap applies to `@Async`, not `@Scheduled`; the scheduled-specific risk is duplicate execution and a single-threaded scheduler.

**Framework piece:** new `spring-scheduling` skill + ArchUnit rule + itest that two context instances contending for the lock run the job once (can be simulated with two `LockProvider`s against one Postgres container).

### 2.7 Unbounded queries, pagination bounds, and list endpoints

Already covered in 2.2; add a **contract test** that every GET collection handler returns `Page`/`Slice` (or a bounded DTO) and that `GET /orders?size=100000` is clamped to `max-page-size`. Use `RequestMappingHandlerMapping` in a `@SpringBootTest` to enumerate mappings and assert the return type / `Pageable` parameter; pair with Sonar S7186.

---

## 3. P1 pitfalls

### 3.1 Field `@Autowired`
AI code: `@Autowired private OrderRepository repo;`. Constructor injection is the Spring team's recommendation (immutable, non-null, testable) ([Spring DI docs](https://docs.spring.io/spring-framework/reference/core/beans/dependencies/factory-collaborators.html)). Deterministic catch: `GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION` ([ArchUnit Javadoc](https://javadoc.io/doc/com.tngtech.archunit/archunit/latest/com/tngtech/archunit/library/GeneralCodingRules.html); Jakarta annotations included since ArchUnit 1.3.0) + Checkstyle `RegexpSinglelineJava`.

### 3.2 Validation
AI code: `@PostMapping public Order create(@RequestBody Order order)` with no `@Valid`; `@ConfigurationProperties` class with `@NotBlank` fields but no `@Validated` (so invalid config silently starts). Detection: strengthen `scripts/check-endpoints.sh` to look for `@RequestBody` **not** preceded by `@Valid`; ArchUnit `classes().that().areAnnotatedWith(ConfigurationProperties.class).should().beAnnotatedWith(Validated.class)`; MockMvc test asserting 400 + `ProblemDetail` for invalid body.

### 3.3 REST contract: `ProblemDetail`, versioning, pagination
- Enable RFC 9457: Boot's `spring.mvc.problemdetails.enabled` is still **`false` by default** in Boot 4 (`WebMvcProperties.Problemdetails.enabled` has no initializer — verified in [Boot source](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-webmvc/src/main/java/org/springframework/boot/webmvc/autoconfigure/WebMvcProperties.java)); set it `true` and return `ProblemDetail` from `@RestControllerAdvice` ([Spring error responses](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html), [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457.html)).
- Versioning: Spring Framework 7 adds a `version` attribute to `@RequestMapping`/`@GetMapping`, and Boot exposes `spring.mvc.apiversion.*` (required/default/supported/use.header|query-parameter|path-segment|media-type) ([Spring blog](https://spring.io/blog/2025/09/16/api-versioning-in-spring), [Boot source `Apiversion`](https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-webmvc/src/main/java/org/springframework/boot/webmvc/autoconfigure/WebMvcProperties.java)). AI code tends to hardcode `/api/v1/` in paths and never bump; catch with a mapping test that every handler declares a version or lives under a registered version strategy.
- Pagination envelope: `content`, `page`, `size`, `totalElements`, `totalPages`; cap size server-side.

### 3.4 Testing shape
- Boot 4 removed `@MockBean` (compile error is actually the *good* case; agents "fix" it by pinning old Boot).
- Agents default to full `@SpringBootTest` for controller/repository concerns; use `@WebMvcTest` / `@DataJpaTest` / plain JUnit ([Boot testing docs](https://docs.spring.io/spring-boot/reference/testing/spring-boot-applications.html), [test slices](https://docs.spring.io/spring-boot/appendix/test-auto-configuration/slices.html)).
- DB tests must use Testcontainers PostgreSQL, not H2 ([Boot Testcontainers](https://docs.spring.io/spring-boot/reference/testing/testcontainers.html)); a `@DataJpaTest` on H2 hides PostgreSQL-specific SQL. Require `@AutoConfigureTestDatabase(replace = NONE)` + `@ServiceConnection`.
- Deterministic: ArchUnit on test classes (`*ControllerTest` must be `@WebMvcTest`), CI check that `src/itest` contains a `@ServiceConnection`/Testcontainers usage, and a `make itest` gate (Docker).

### 3.5 `@Async` / `@Cacheable` self-invocation
Same proxy rule as `@Transactional`; Sonar S6809 covers all three. `@Async` additionally requires public methods and a configured executor with bounded queue (default `SimpleAsyncTaskExecutor` — unbounded thread creation; set `spring.task.execution.*`).

### 3.6 Gateway misconfiguration
AI code: `uri: http://localhost:8082` instead of `lb://order-service`; no `connect-timeout`/`response-timeout`; blocking `.block()` in a WebFlux filter; wildcard CORS; wrong `Path` predicate ordering. Detection: route-definition test (`RouteDefinitionLocator` → assert `uri` scheme `lb` and timeouts), ArchUnit ban `.block(` in `gateway` module, contract itest through the gateway. Docs: [Gateway](https://docs.spring.io/spring-cloud-gateway/reference/), [HTTP timeouts](https://docs.spring.io/spring-cloud-gateway/reference/spring-cloud-gateway-server-webflux/http-timeouts-configuration.html), [k8s discovery](https://docs.spring.io/spring-cloud-kubernetes/reference/).

### 3.7 Money and time discipline
`double`/`float` for money; `java.util.Date`; bare `LocalDateTime` for instants. Money as `BigDecimal` with explicit precision/scale (and currency) ([Fowler Money](https://martinfowler.com/eaaCatalog/money.html), [JSR-354](https://github.com/JavaMoney/jsr354-api)); instants as `Instant`/`OffsetDateTime` ([`java.time` docs](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/time/Instant.html)). Detection: ArchUnit field-type rules (see §5) + Checkstyle `IllegalType` for `java.util.Date`.

### 3.8 Idempotency
Every non-idempotent write exposed to retries (client, gateway, `@Retryable`) needs an `Idempotency-Key` persisted with the request hash and the response, returning the original response on replay ([Stripe](https://docs.stripe.com/api/idempotent_requests), [AWS](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/)). Test: POST twice with same key → one row, same body/status.

### 3.9 Package-by-feature / module boundaries
`api/core/adapters` is already the repo layout; enforce with ArchUnit now and migrate to Spring Modulith (`@ApplicationModule`, `@NamedInterface`, `ApplicationModules.of(App.class).verify()`) when services grow ([Modulith verification](https://docs.spring.io/spring-modulith/reference/verification.html), [fundamentals](https://docs.spring.io/spring-modulith/reference/fundamentals.html), [JetBrains Modulith guide](https://blog.jetbrains.com/idea/2026/02/migrating-to-modular-monolith-using-spring-modulith-and-intellij-idea/)).

---

## 4. Boring, opinionated conventions from mature teams

| Convention | Rule | Reference |
|---|---|---|
| Package by feature, not by layer | One package per capability; internal packages hidden; no cycles | [Spring Modulith fundamentals](https://docs.spring.io/spring-modulith/reference/fundamentals.html), [JetBrains](https://blog.jetbrains.com/idea/2026/02/migrating-to-modular-monolith-using-spring-modulith-and-intellij-idea/) |
| DTO/record discipline | Controllers take/return records in `api/dto`; entities never cross the boundary; map in `core` | [JHipster DTO guidance](https://www.jhipster.tech/using-dtos/), repo `spring-service-conventions` |
| Constructor injection | Final fields, no field `@Autowired`, no `@Autowired` on a single constructor | [Spring DI docs](https://docs.spring.io/spring-framework/reference/core/beans/dependencies/factory-collaborators.html) |
| `@ConfigurationProperties` over `@Value` | Typed, validated, metadata-generating config records; `@Validated` + JSR-303 | [Boot external config](https://docs.spring.io/spring-boot/reference/features/external-config.html#features.external-config.typesafe-configuration-properties.validation) |
| `ProblemDetail` / RFC 9457 | One error shape; `type` URI, `title`, `status`, `detail`, `instance`; no stack traces | [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457.html), [Spring docs](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html) |
| Idempotency keys | Non-idempotent writes accept `Idempotency-Key`, dedupe on (key, user), return original response | [Stripe](https://docs.stripe.com/api/idempotent_requests), [AWS](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/) |
| Optimistic locking | `@Version` on every mutable aggregate; map `OptimisticLockException` to 409 `ProblemDetail` | [Spring Data `@Version`](https://docs.spring.io/spring-data/jpa/reference/data-commons/4.2/api/java/org/springframework/data/annotation/Version.html) |
| Money | `BigDecimal`, `NUMERIC(19,2)`, currency code; never `double`/`float`; rounding mode explicit | [Fowler Money](https://martinfowler.com/eaaCatalog/money.html), [JSR-354](https://github.com/JavaMoney/jsr354-api) |
| Time | `Instant` for instants, `OffsetDateTime` when offset matters; store `timestamptz`; never `java.util.Date` | [`java.time`](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/time/Instant.html), repo `architecture-guardrails` rule 8 |
| No Lombok on entities | `@Getter`/`@Setter` only (or none); explicit `equals`/`hashCode` on business key/id | [Thorben Janssen](https://thorben-janssen.com/lombok-hibernate-how-to-avoid-common-pitfalls/) |
| Migrations | Flyway/Liquibase only; `ddl-auto: validate`; expand→migrate→contract | [Boot DB init](https://docs.spring.io/spring-boot/how-to/data-initialization.html), [Hibernate schema gen](https://docs.jboss.org/hibernate/orm/current/userguide/html_single/Hibernate_User_Guide.html#schema-generation) |
| Config & secrets | Externalized via Config Server; secrets from ESO/IRSA; no literal secrets in YAML | [12-factor](https://12factor.net/config), [Boot external config](https://docs.spring.io/spring-boot/reference/features/external-config.html) |
| API versioning | `version` attribute or explicit path segment; never mix; deprecate with headers | [Spring blog](https://spring.io/blog/2025/09/16/api-versioning-in-spring) |
| Pagination | Every collection endpoint Pageable; server cap 100; stable sort key | [Sonar S7186](https://rules.sonarsource.com/java/RSPEC-7186/), Boot properties |
| Resilience | Every outbound call: connect+read timeout, circuit breaker, bounded retry+jitter, idempotency key on writes | `resiliency-review`, [Resilience4j](https://resilience4j.readme.io/docs), [AWS](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/) |
| Scheduling | Any `@Scheduled` that mutates state gets ShedLock; scheduler pool > 1 | [ShedLock](https://github.com/lukas-krecan/ShedLock) |
| Observability | Micrometer + OTel; correlation ID; AI calls instrumented (`gen_ai.*`) | [Spring AI observability](https://docs.spring.io/spring-ai/reference/observability/index.html) |

Repo examples to mine: `github/awesome-copilot` (skills that encode Boot 4 + testing + security conventions), `jdubois/dr-jskill` (Spring references as agent skills), `spring-projects/spring-modulith` (boundaries + verification), `jhipster/jhipster-sample-app` (DTO/mapper discipline), `spring-projects/spring-petclinic` (reference app shape).

---

## 5. Deterministic rulebook (copy-paste ready)

### 5.1 ArchUnit — `ArchitectureTest` per service

Dependency: `com.tngtech.archunit:archunit-junit5` (already pinned: `archunit = "1.5.1"` in `gradle/libs.versions.toml`).

```java
@AnalyzeClasses(packages = "com.example.order", importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

  // 1. Layering: api -> core -> adapters (no api -> adapters)
  @ArchTest
  static final ArchRule layering = layeredArchitecture().consideringOnlyDependenciesInLayers()
      .layer("Api").definedBy("..api..")
      .layer("Core").definedBy("..core..")
      .layer("Adapters").definedBy("..adapters..")
      .whereLayer("Api").mayNotBeAccessedByAnyLayer()
      .whereLayer("Core").mayOnlyBeAccessedByLayers("Api")
      .whereLayer("Adapters").mayOnlyBeAccessedByLayers("Core", "Api");

  // 2. No web/http/persistence in core
  @ArchTest
  static final ArchRule core_is_framework_free = noClasses()
      .that().resideInAPackage("..core..")
      .should().dependOnClassesThat().resideInAnyPackage(
          "org.springframework.web..", "org.springframework.http..",
          "jakarta.servlet..", "jakarta.persistence..", "org.springframework.data..");

  // 3. Controllers live in api, entities in adapters/persistence and never leak
  @ArchTest
  static final ArchRule controllers_in_api = classes()
      .that().areAnnotatedWith(org.springframework.web.bind.annotation.RestController.class)
      .should().resideInAPackage("..api..");

  @ArchTest
  static final ArchRule entities_in_persistence = classes()
      .that().areAnnotatedWith(jakarta.persistence.Entity.class)
      .should().resideInAPackage("..adapters.persistence..");

  @ArchTest
  static final ArchRule api_never_sees_entities = noClasses()
      .that().resideInAPackage("..api..")
      .should().dependOnClassesThat().areAnnotatedWith(jakarta.persistence.Entity.class);

  // 4. No field injection (ArchUnit's built-in rule; also covers @Resource/@Inject)
  @ArchTest
  static final ArchRule no_field_injection = GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION;

  // 5. Proxy semantics: transactional/async methods must be public
  @ArchTest
  static final ArchRule transactional_methods_public = methods()
      .that().areAnnotatedWith(org.springframework.transaction.annotation.Transactional.class)
      .should().bePublic();

  @ArchTest
  static final ArchRule async_methods_public = methods()
      .that().areAnnotatedWith(org.springframework.scheduling.annotation.Async.class)
      .should().bePublic();

  // 6. Controllers are not transactional (transaction boundary belongs to core/service)
  @ArchTest
  static final ArchRule controllers_not_transactional = noClasses()
      .that().areAnnotatedWith(org.springframework.web.bind.annotation.RestController.class)
      .should().beAnnotatedWith(org.springframework.transaction.annotation.Transactional.class);

  // 7. Scheduled jobs are distributed-locked
  @ArchTest
  static final ArchRule scheduled_jobs_locked = methods()
      .that().areAnnotatedWith(org.springframework.scheduling.annotation.Scheduled.class)
      .should().beAnnotatedWith(net.javacrumbs.shedlock.spring.annotation.SchedulerLock.class);

  // 8. No raw HTTP client construction outside config (forces timeout-configured beans)
  @ArchTest
  static final ArchRule http_clients_only_from_config = noClasses()
      .that().resideOutsideOfPackage("..config..")
      .should().callMethod(org.springframework.web.reactive.function.client.WebClient.class, "create")
      .orShould().callMethod(org.springframework.web.client.RestClient.class, "create")
      .orShould().callConstructor(org.springframework.web.client.RestTemplate.class);

  // 9. @Retryable only on explicitly idempotent operations
  @ArchTest
  static final ArchRule retry_only_idempotent = methods()
      .that().areAnnotatedWith(org.springframework.retry.annotation.Retryable.class)
      .should().beAnnotatedWith(com.example.platform.Idempotent.class);

  // 10. Money is never floating point; no legacy Date
  @ArchTest
  static final ArchRule money_not_floating = fields()
      .that().haveNameMatching("(?i).*(amount|price|balance|fee|cost|total).*")
      .should().notHaveRawType(double.class);

  @ArchTest
  static final ArchRule no_java_util_date = noClasses()
      .should().dependOnClassesThat().haveFullyQualifiedName("java.util.Date");

  // 11. @ConfigurationProperties are validated
  @ArchTest
  static final ArchRule config_props_validated = classes()
      .that().areAnnotatedWith(org.springframework.boot.context.properties.ConfigurationProperties.class)
      .should().beAnnotatedWith(org.springframework.validation.annotation.Validated.class);

  // 12. No cycles between feature packages
  @ArchTest
  static final ArchRule no_feature_cycles = slices()
      .matching("com.example.(*)..").should().beFreeOfCycles();
}
```

Notes:
- `@Data` on entities **cannot** be an ArchUnit rule (Lombok = SOURCE retention). Detect with a source scan (below).
- If your ArchUnit version doesn't have member-level `beAnnotatedWith`, implement an `ArchCondition<JavaMethod>`; behaviour is identical.
- Rule changes are a platform-team PR; agents must fix code, never weaken rules (`architecture-guardrails`).

### 5.2 Source-level traps ArchUnit can't see (Lombok, annotations, YAML)

`scripts/check-spring-traps.sh` (proposed companion to the existing `hooks/spring-guard.sh`, which already blocks `@MockBean`, `spring-boot-starter-web`, `spring-cloud-starter-gateway`, `open-in-view: true`, and `ddl-auto: update` — extend it rather than adding a second hook):

```bash
# forbidden Boot 3 / tutorial patterns in changed Java/YAML
grep -RnE '@MockBean|@SpyBean|org\.springframework\.boot\.test\.mock\.mockito|com\.fasterxml\.jackson|javax\.(validation|persistence|servlet)|WebSecurityConfigurerAdapter|spring-boot-starter-web[^m]|spring-cloud-starter-gateway[^-]' \
  --include='*.java' --include='*.kts' --include='*.yml' --include='*.yaml' services/ || true
# Lombok on entities (@Entity and @Data in the same file)
grep -Rl '@Entity' --include='*.java' services/ | xargs grep -lE '@Data|@EqualsAndHashCode|@ToString' || true
# dangerous config
grep -RnE 'ddl-auto:\s*(create|create-drop|update)|open-in-view:\s*true|exposure:\s*include:\s*"?\*"?|permitAll\(\)|csrf\([^)]*disable|password:\s*[^$]' \
  --include='*.yml' --include='*.yaml' services/ config-repo/ || true
# unbounded list endpoints
grep -RnE 'findAll\(\)' --include='*Controller.java' services/ || true
```

For the `@RequestBody`/`@Valid` and `permitAll` patterns, a Semgrep rule is cleaner because it understands structure:

```yaml
rules:
  - id: java-spring-requestbody-without-valid
    languages: [java]
    message: "@RequestBody must be validated with @Valid/@Validated"
    severity: ERROR
    patterns:
      - pattern: $RET $M(@RequestBody $T $X) { ... }
      - pattern-not: $RET $M(@Valid @RequestBody $T $X) { ... }
      - pattern-not: $RET $M(@Validated @RequestBody $T $X) { ... }

  - id: java-spring-permit-all
    languages: [java]
    message: "anyRequest()/requestMatchers(\"/**\") must not be permitAll()"
    severity: ERROR
    patterns:
      - pattern-either:
          - pattern: $A.anyRequest().permitAll()
          - pattern: $A.requestMatchers("/**").permitAll()

  - id: java-spring-csrf-disable-without-stateless
    languages: [java]
    message: "csrf.disable() requires SessionCreationPolicy.STATELESS and no cookies"
    severity: WARNING
    patterns:
      - pattern: $H.csrf($C -> $C.disable())
      - pattern-not-inside: |
          ...
          sessionManagement(...STATELESS...)
          ...
```

### 5.3 Spring Modulith (optional, when services move to package-by-feature)

```java
@Test
void verifiesModuleStructure() {
  ApplicationModules.of(OrderApplication.class).verify();
}
```

`verify()` enforces: no module cycles, access to other modules only through API packages/named interfaces, and only declared `@ApplicationModule(allowedDependencies = ...)` dependencies ([Spring Modulith verification](https://docs.spring.io/spring-modulith/reference/verification.html)). Optionally add jMolecules ArchUnit rules via `VerificationOptions.withAdditionalVerifications(...)`.

### 5.4 SonarQube / static analysis stack

| Tool | Catches | Notes |
|---|---|---|
| **SonarQube** Java + Spring rules | S6809 self-invocation, S2230 non-public `@Async`/`@Transactional`, S7186 `Page` without `Pageable`, S7179/S7180 cache annotation misuse | Run as a quality gate in CI; Spring tag rules: [rules.sonarsource.com/java/tag/spring](https://rules.sonarsource.com/java/tag/spring/), [new Spring rules write-up](https://securityboulevard.com/2025/03/new-spring-framework-rules-in-sonarqube-9/) |
| **ArchUnit** | layering, cycles, annotation presence, dependency bans, method visibility | fastest, deterministic, runs in `./gradlew test` |
| **Spring Modulith** | module boundaries, named interfaces, allowed dependencies | after package-by-feature migration |
| **OpenRewrite** | Boot 4 / Jackson 3 / `@MockBean` / starter migrations | run `dryRun` in CI to fail on leftover pre-4 APIs; [Boot 4 recipe](https://docs.openrewrite.org/recipes/java/spring/boot4/upgradespringboot_4_0) |
| **Semgrep** (custom rules) | annotation/pair patterns Sonar/ArchUnit miss | [Semgrep docs](https://semgrep.dev/docs/writing-rules/overview/) |
| **Checkstyle** | `IllegalImport`/`IllegalType`/regex bans (Jackson 2, `javax.*`, `java.util.Date`, field `@Autowired`) | already wired in `config/checkstyle/checkstyle.xml`; extend it |
| **ErrorProne + NullAway** | Java bug patterns + null-safety; JSpecify annotations now used by Spring 7 | [ErrorProne](https://errorprone.info/), [NullAway](https://github.com/uber/NullAway) |
| **SpotBugs / PMD** | general bug patterns; PMD rule sets for JPA/persistence exist in community packs | [SpotBugs](https://spotbugs.github.io/), [PMD](https://pmd.github.io/) |
| **gitleaks / trufflehog** | secrets in diff/history | already `hooks/no-secrets.sh`; add CI fail-closed |
| **CodeQL** | taint/SSRF/injection queries for Java | optional GitHub Advanced Security |

### 5.5 Runtime config invariants (the ones static analysis cannot prove)

Plain JUnit + Boot config (no DB needed):

```java
class ProductionConfigInvariantsTest {
  private final Environment env = new StandardEnvironment(); // or load application-prod.yml

  @Test void osiv_off() {
    assertThat(env.getProperty("spring.jpa.open-in-view", Boolean.class)).isFalse();
  }
  @Test void ddl_auto_is_validate() {
    assertThat(env.getProperty("spring.jpa.hibernate.ddl-auto")).isEqualTo("validate");
  }
  @Test void actuator_exposes_health_only() {
    assertThat(env.getProperty("management.endpoints.web.exposure.include")).isEqualTo("health");
  }
  @Test void page_size_is_capped() {
    assertThat(env.getProperty("spring.data.web.pageable.max-page-size", Integer.class))
        .isLessThanOrEqualTo(100);
  }
  @Test void problem_details_enabled() {
    assertThat(env.getProperty("spring.mvc.problemdetails.enabled", Boolean.class)).isTrue();
  }
}
```

Plus a context-level test for OSIV (catches profile-specific overrides):

```java
@SpringBootTest(properties = "spring.profiles.active=prod")
class NoOsivTest {
  @Autowired ApplicationContext ctx;
  @Test void osiv_interceptor_absent() {
    assertThat(ctx.getBeanNamesForType(OpenEntityManagerInViewInterceptor.class)).isEmpty();
  }
}
```

### 5.6 Behavioural tests that prove non-functional properties

- **Timeout**: WireMock stub `delay(2000)`, client timeout 500ms, assert `WebClientRequestException`/`TimeoutException` within 1s.
- **Idempotency**: two POSTs with same `Idempotency-Key` → one row, identical response.
- **N+1 budget**: `SQLStatementCountValidator.assertSelectCount(2)`.
- **Optimistic locking**: two concurrent updates → second gets 409/`OptimisticLockException`.
- **Pagination clamp**: `GET /orders?size=100000` → `page.size <= 100`.
- **ProblemDetail**: invalid body → 400, `application/problem+json`, `$.type/$.title/$.status/$.detail`.
- **Actuator**: `/actuator/env` → 401/404; `/actuator/health` → 200.
- **CSRF/session**: token API POST without CSRF succeeds and no `JSESSIONID` set.

---

## 6. How to wire this into *this* framework

### 6.1 Current state (verified in this checkout) and the exact gaps

**Already in place**
- Advisory skills: `architecture-guardrails`, `spring-boot-4-migration`, `spring-data-jpa`, `spring-testing`, `resiliency-review`, `secure-api-review`, `spring-service-conventions`. `AGENTS.md`/`CLAUDE.md` now also list the "common Spring mistakes" and name the deterministic gates.
- `hooks/spring-guard.sh`, called from `.githooks/pre-commit`; `hooks/no-secrets.sh`, `protect-paths.sh`, `test-freeze.sh`, `production-gate.sh`.
- `scripts/new-service.sh` generates `ArchitectureTest.java` and wires `archunit-junit5` (pinned `1.5.1`); `services/demo-service` is scaffolded and its `application.yml` already sets `ddl-auto: validate`, `open-in-view: false`, and an actuator allow-list.
- `scripts/check-endpoints.sh` (weak `@Valid` heuristic); minimal Checkstyle config.

**Gaps that still let the P0 defects through**

| Gap | Add to | Effort |
|---|---|---|
| `spring-guard.sh` does not check: Jackson 2 imports, `javax.*`, `spring.cloud.gateway.*` prefix, actuator `include: "*"`, `permitAll`, `csrf.disable()` without STATELESS, literal secrets, `@Data`+`@Entity`, `findAll()` in controllers, missing `@SchedulerLock` | `hooks/spring-guard.sh` | S |
| Hook only scans staged files when run from a shell without stdin; CI must run it **full-tree** (or on the PR diff), otherwise a file merged by another path escapes | `.github/workflows/ci.yml` + hook | S |
| `ArchitectureTest` lacks: `GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION` (covers `@Inject`/`@Value`), api→`@Entity`, `@Async` public, `@Scheduled`→`@SchedulerLock`, `@ConfigurationProperties`→`@Validated`, `@Retryable`→`@Idempotent`, money-float ban, `slices().beFreeOfCycles()`, raw `WebClient.create`/`new RestTemplate` ban | `scripts/new-service.sh` template | M |
| No runtime config invariant test (OSIV interceptor bean, actuator allow-list, `max-page-size`, `problemdetails.enabled`, prod-profile overrides) | scaffolder + `src/test` | S |
| No behavioural itests: N+1 budget, WireMock timeout, idempotency replay, optimistic-lock 409, pagination clamp, `ProblemDetail` shape, `/actuator/env` 401/404 | scaffolder + `src/itest` | M |
| `check-endpoints.sh` misses `@RequestBody` without `@Valid`, collection endpoints without `Pageable`, `ProblemDetail` handlers, CSRF/`permitAll` | `scripts/` or Semgrep rules | S |
| No Sonar / Semgrep / OpenRewrite / `gitleaks` CI jobs | `.github/workflows/ci.yml` | M |
| No scheduling, security-baseline, API-contract, or Spring AI skills | `.agents/skills/` | M |

### 6.2 Recommended additions (ordered by coverage gained per unit effort)

1. **Extend `hooks/spring-guard.sh`** with the P0 patterns listed above (Jackson 2, `javax.*`, property prefixes, actuator `"*"`, `permitAll`, CSRF pairing, literal secrets, `@Data` on `@Entity`, `findAll()` in `*Controller.java`, `@Scheduled` without lock). Keep it a **diff/staged-file** check locally and run it **full-tree in CI** (fail-closed); pattern: [`Sting25/ai-coding-scaffold`](https://github.com/Sting25/ai-coding-rules-scaffold) (two-layer enforcement, cited in `research/agent-sdlc-patterns-report.md`).
2. **Extend the generated `ArchitectureTest`** with rules 1–12 from §5.1 (use `GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION`; the current custom `noFields()` rule misses `@Inject`). This is a template change in `scripts/new-service.sh`, so every new service gets it; back-fill `services/demo-service` too.
3. **Add runtime config invariants** to the service template: `ProductionConfigInvariantsTest` (property assertions) + `NoOsivTest` (bean-name assertion, profile-aware). This catches `open-in-view` set back to `true` in a profile, actuator over-exposure, unbounded page size, and `problemdetails` left off — none of which are visible to ArchUnit.
4. **Add behavioural itests** to the template (one class each, Testcontainers PostgreSQL + WireMock): N+1 statement budget, timeout-fires, idempotency replay, optimistic-lock 409, pagination clamp, `ProblemDetail` error shape, actuator route protection.
5. **Strengthen `scripts/check-endpoints.sh`** (or replace its checks with Semgrep rules from §5.2): `@RequestBody` ⇒ `@Valid`/`@Validated`; collection GET ⇒ `Pageable`; `@RestControllerAdvice` returns `ProblemDetail`; `permitAll`/`csrf.disable` pair checks.
6. **CI jobs** (`.github/workflows/ci.yml`): `guardrails` (full-tree `spring-guard.sh` + config invariants + `check-endpoints.sh`), `openrewrite-dryrun`, `semgrep`, `sonar` quality gate, `gitleaks` (authoritative, fail-closed). Keep `make build/test/lint/itest` as the human-facing loop.
7. **`REVIEW.md`**: add a **"Spring pitfalls"** pass (or fold into Compliance) with five questions: proxy/transaction boundaries; transaction scope + rollback; entity/DTO boundary + fetch plan; outbound timeout/retry/idempotency; production config/actuator/security. The `pr-review` reviewer agent already has tagged-finding output; this gives it the right questions.
8. **Evals** (`evals/tasks/`): one per high-frequency mistake, `verify` commands run the deterministic gate — `boot4-mockbean.md`, `transaction-self-invocation.md`, `nplus1-budget.md`, `actuator-hardening.md`, `webclient-timeout.md`, `pagination-problemdetail.md`. These are regression tests for agent config/model changes (`evals/README.md`).
9. **New skills for uncovered areas** (short; the deterministic layer carries the weight): `spring-security-baseline` (actuator/CSRF/`permitAll`/secrets), `spring-api-contract` (`ProblemDetail`, versioning, pagination, idempotency), `spring-scheduling` (ShedLock, pool sizing, `@Async` executor bounds), `spring-ai-guardrails` (tool authorization, prompt-injection boundary, observability).
10. **Spring Modulith** only when a service moves to package-by-feature; until then ArchUnit slice rules are enough.

### 6.3 Roadmap

- **Week 1 (P0, cheapest):** extend `spring-guard.sh` + run it full-tree in CI; extend the `ArchitectureTest` template; add `ProductionConfigInvariantsTest`/`NoOsivTest`; back-fill `demo-service`.
- **Week 2:** behavioural itests in the template (N+1/timeout/idempotency/optimistic lock/pagination/`ProblemDetail`/actuator); Semgrep rules; Checkstyle `IllegalImport`/`IllegalType`; Sonar quality gate; OpenRewrite dry-run; `gitleaks` in CI.
- **Week 3:** new skills (`spring-security-baseline`, `spring-api-contract`, `spring-scheduling`, `spring-ai-guardrails`); `REVIEW.md` pass; eval tasks; Spring Modulith when needed.

---

## 7. Spring AI (secondary — only if the org builds agents on Spring Boot)

Spring AI 2.x (`spring-projects/spring-ai`) fits this stack; use its abstractions instead of raw provider SDKs:

- **`ChatClient`** as the single entry point (fluent API, portable across providers), not `ChatModel` calls scattered in controllers ([ChatClient docs](https://docs.spring.io/spring-ai/reference/api/chatclient.html)).
- **Advisors** for cross-cutting concerns (memory, RAG, guardrails, logging) — keeps prompt logic out of business code ([Advisors](https://docs.spring.io/spring-ai/reference/api/advisors.html)).
- **Tool calling**: tools are a security boundary — validate arguments, authorize per caller, log invocations; don't forward untrusted text into a tool/agent without an allowlist (OWASP Top 10 for LLM Apps: prompt injection, excessive agency) ([Tool calling](https://docs.spring.io/spring-ai/reference/api/tools.html), [OWASP LLM Top 10](https://genai.owasp.org/llm-top-10/), [OWASP Agentic Top 10](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications/)).
- **RAG/ETL** for grounding; **structured output with schema validation/self-correction** for machine-consumed responses ([Structured output validation](https://docs.spring.io/spring-ai/reference/api/structured-output/validation.html)).
- **Observability**: Micrometer observations `gen_ai.client.operation`, token usage, `spring.ai.*` keys; prompt/completion content is **not** exported by default — keep it that way in prod (PII) ([Observability](https://docs.spring.io/spring-ai/reference/observability/index.html)).
- **MCP**: MCP security is still WIP upstream; treat MCP servers as untrusted network services (timeouts, allowlists, no secrets in tool results) ([MCP security](https://docs.spring.io/spring-ai/reference/api/mcp/mcp-security.html)).
- **Evaluation**: `ModelEvaluation`/LLM-as-judge for regression-testing prompts ([Model evaluation](https://docs.spring.io/spring-ai/reference/api/testing.html)).
- AI-specific CI guardrails: idempotent tool calls, token/cost budgets, per-tool authorization tests, and a prompt-injection regression suite — same "detection is deterministic" principle as the rest of this report.

---

## 8. Sources

**AI-code evidence**
- Veracode, *2025 GenAI Code Security Report* — https://www.veracode.com/resources/analyst-reports/2025-genai-code-security-report
- Veracode press release (45%, Java riskiest) — https://www.veracode.com/press-release/ai-generated-code-poses-major-security-risks-in-nearly-half-of-all-development-tasks-veracode-research-reveals/
- Pearce et al., *Asleep at the Keyboard?* (CACM) — https://cacm.acm.org/research-highlights/asleep-at-the-keyboard-assessing-the-security-of-github-copilots-code-contributions/ · https://dl.acm.org/doi/10.1145/3610721
- GitClear, *AI Copilot Code Quality 2025* — https://www.gitclear.com/ai_assistant_code_quality_2025_research
- Thoughtworks Radar, *Complacency with AI-generated code* — https://www.thoughtworks.com/radar/techniques/complacency-with-ai-generated-code

**Spring Framework / Boot / Security**
- `@Transactional` — https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html
- Proxy/declarative implementation — https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/tx-decl-explained.html
- Rolling back — https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/rolling-back.html
- `@Transactional` Javadoc — https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/transaction/annotation/Transactional.html
- Dependency injection — https://docs.spring.io/spring-framework/reference/core/beans/dependencies/factory-collaborators.html
- Error responses (ProblemDetail) — https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html
- WebClient — https://docs.spring.io/spring-framework/reference/web/webflux-webclient.html
- Task execution & scheduling — https://docs.spring.io/spring-framework/reference/integration/scheduling.html
- Bean validation — https://docs.spring.io/spring-framework/reference/core/validation/beanvalidation.html
- `@MockitoBean` Javadoc — https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/test/context/bean/override/mockito/MockitoBean.html
- Boot SQL/JPA — https://docs.spring.io/spring-boot/reference/data/sql.html
- Boot DB initialization — https://docs.spring.io/spring-boot/how-to/data-initialization.html
- Boot external config / `@ConfigurationProperties` validation — https://docs.spring.io/spring-boot/reference/features/external-config.html#features.external-config.typesafe-configuration-properties.validation
- Boot validation — https://docs.spring.io/spring-boot/reference/io/validation.html
- Boot test slices — https://docs.spring.io/spring-boot/appendix/test-auto-configuration/slices.html
- Boot testing — https://docs.spring.io/spring-boot/reference/testing/spring-boot-applications.html
- Boot Testcontainers — https://docs.spring.io/spring-boot/reference/testing/testcontainers.html
- Boot task execution & scheduling — https://docs.spring.io/spring-boot/reference/features/task-execution-and-scheduling.html
- Boot actuator endpoints (default exposure + security back-off) — https://docs.spring.io/spring-boot/reference/actuator/endpoints.html
- Boot common application properties — https://docs.spring.io/spring-boot/appendix/application-properties/index.html
- Boot source: OSIV default (`JpaBaseConfiguration`) — https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-jpa/src/main/java/org/springframework/boot/jpa/autoconfigure/JpaBaseConfiguration.java
- Boot issue #47547 OSIV default — https://github.com/spring-projects/spring-boot/issues/47547
- Boot source: `WebMvcProperties` (`problemdetails`, `apiversion`) — https://github.com/spring-projects/spring-boot/blob/main/module/spring-boot-webmvc/src/main/java/org/springframework/boot/webmvc/autoconfigure/WebMvcProperties.java
- Spring Security CSRF — https://docs.spring.io/spring-security/reference/servlet/exploits/csrf.html
- Spring Security authorize requests — https://docs.spring.io/spring-security/reference/servlet/authorization/authorize-http-requests.html
- Spring Boot 4.0 release — https://spring.io/blog/2025/11/20/spring-boot-4-0-0-available-now
- Boot 4.0 migration guide — https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide
- Boot 4.1 release highlights — https://spring.io/projects/release-highlights

**Spring Data / JPA / Hibernate**
- Spring Data `@Version` — https://docs.spring.io/spring-data/jpa/reference/data-commons/4.2/api/java/org/springframework/data/annotation/Version.html
- Vlad Mihalcea, N+1 — https://vladmihalcea.com/n-plus-1-query-problem/
- Vlad, detect N+1 in tests — https://vladmihalcea.com/how-to-detect-the-n-plus-one-query-problem-during-testing/
- Hypersistence Utils — https://github.com/vladmihalcea/hypersistence-utils
- Vlad, OSIV anti-pattern — https://vladmihalcea.com/the-open-session-in-view-anti-pattern/
- Baeldung, OSIV — https://www.baeldung.com/spring-open-session-in-view
- Thorben Janssen, Lombok + Hibernate — https://thorben-janssen.com/lombok-hibernate-how-to-avoid-common-pitfalls/
- Thorben Janssen, equals/hashCode — https://thorben-janssen.com/ultimate-guide-to-implementing-equals-and-hashcode-with-hibernate/
- Hibernate schema generation warning — https://docs.jboss.org/hibernate/orm/current/userguide/html_single/Hibernate_User_Guide.html#schema-generation

**Spring Cloud / resilience**
- Spring Cloud 2025.1 release notes — https://github.com/spring-cloud/spring-cloud-release/wiki/Spring-Cloud-2025.1-Release-Notes
- Spring Cloud 2025.0 gateway/module renames — https://spring.io/blog/2025/05/29/spring-cloud-2025-0-0-is-abvailable
- Spring Cloud Gateway — https://docs.spring.io/spring-cloud-gateway/reference/
- Gateway HTTP timeouts — https://docs.spring.io/spring-cloud-gateway/reference/spring-cloud-gateway-server-webflux/http-timeouts-configuration.html
- Spring Cloud CircuitBreaker — https://docs.spring.io/spring-cloud-circuitbreaker/reference/
- Resilience4j — https://resilience4j.readme.io/docs
- Spring Cloud Kubernetes — https://docs.spring.io/spring-cloud-kubernetes/reference/
- Spring Cloud Config — https://docs.spring.io/spring-cloud-config/reference/
- ShedLock — https://github.com/lukas-krecan/ShedLock
- AWS Builders' Library, idempotent APIs — https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/
- Stripe idempotency — https://docs.stripe.com/api/idempotent_requests
- RFC 9110 idempotent methods — https://www.rfc-editor.org/rfc/rfc9110.html#name-idempotent-methods
- Azure Retry pattern — https://learn.microsoft.com/en-us/azure/architecture/patterns/retry

**Serialization / Boot 4 migration**
- Jackson 3 in Spring — https://spring.io/blog/2025/10/07/introducing-jackson-3-support-in-spring
- Moderne Spring Boot migration guide — https://docs.moderne.io/user-documentation/recipes/popular-recipe-guides/migrate-to-spring-boot/
- OpenRewrite Boot 4 recipe — https://docs.openrewrite.org/recipes/java/spring/boot4/upgradespringboot_4_0
- API versioning in Spring — https://spring.io/blog/2025/09/16/api-versioning-in-spring
- RFC 9457 — https://www.rfc-editor.org/rfc/rfc9457.html

**Static analysis / architecture**
- ArchUnit user guide — https://www.archunit.org/userguide/html/000_Index.html
- `GeneralCodingRules` — https://javadoc.io/doc/com.tngtech.archunit/archunit/latest/com/tngtech/archunit/library/GeneralCodingRules.html
- Spring Modulith verification — https://docs.spring.io/spring-modulith/reference/verification.html
- Spring Modulith fundamentals — https://docs.spring.io/spring-modulith/reference/fundamentals.html
- Sonar Java Spring rules — https://rules.sonarsource.com/java/tag/spring/
- Sonar S6809 — https://rules.sonarsource.com/java/RSPEC-6809/
- Sonar S2230 — https://rules.sonarsource.com/java/RSPEC-2230/
- Sonar S7186 — https://rules.sonarsource.com/java/RSPEC-7186/
- New Spring rules in SonarQube — https://securityboulevard.com/2025/03/new-spring-framework-rules-in-sonarqube-9/
- ErrorProne — https://errorprone.info/
- NullAway — https://github.com/uber/NullAway
- SpotBugs — https://spotbugs.github.io/
- PMD — https://pmd.github.io/
- Semgrep rule syntax — https://semgrep.dev/docs/writing-rules/overview/
- gitleaks — https://github.com/gitleaks/gitleaks

**Conventions / reference repos**
- Spring Modulith — https://github.com/spring-projects/spring-modulith
- JetBrains, modular monolith with Spring Modulith — https://blog.jetbrains.com/idea/2026/02/migrating-to-modular-monolith-using-spring-modulith-and-intellij-idea/
- JHipster DTOs — https://www.jhipster.tech/using-dtos/
- Spring PetClinic — https://github.com/spring-projects/spring-petclinic
- github/awesome-copilot (Spring Boot skills) — https://github.com/github/awesome-copilot
- jdubois/dr-jskill — https://github.com/jdubois/dr-jskill
- Fowler Money — https://martinfowler.com/eaaCatalog/money.html
- JSR-354 / JavaMoney — https://github.com/JavaMoney/jsr354-api
- 12-factor config — https://12factor.net/config
- OWASP Secrets Management — https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html
- OWASP API Security Top 10 — https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- OWASP Top 10 for LLM Applications — https://genai.owasp.org/llm-top-10/
- OWASP Top 10 for Agentic Applications — https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications/

**Spring AI**
- Reference — https://docs.spring.io/spring-ai/reference/
- ChatClient — https://docs.spring.io/spring-ai/reference/api/chatclient.html
- Advisors — https://docs.spring.io/spring-ai/reference/api/advisors.html
- Tool calling — https://docs.spring.io/spring-ai/reference/api/tools.html
- Structured output validation — https://docs.spring.io/spring-ai/reference/api/structured-output/validation.html
- Observability — https://docs.spring.io/spring-ai/reference/observability/index.html
- MCP security (WIP) — https://docs.spring.io/spring-ai/reference/api/mcp/mcp-security.html
- Model evaluation — https://docs.spring.io/spring-ai/reference/api/testing.html
- Building effective agents — https://docs.spring.io/spring-ai/reference/api/effective-agents.html
- Repo — https://github.com/spring-projects/spring-ai
