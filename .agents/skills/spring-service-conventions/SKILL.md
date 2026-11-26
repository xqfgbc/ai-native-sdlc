---
name: spring-service-conventions
description: Apply the mandatory Spring Boot 4 / Spring Cloud 2025 conventions and module layout for any service code change. Use for every service code change.
---

# Spring service conventions

Mandatory rules for all code in this monorepo. They are enforced by review and,
where possible, by ArchUnit / `hooks/spring-guard.sh`.

## Mandatory rules

- **Constructor injection** — no field `@Autowired`/`@Resource`/`@Inject`.
- **No Lombok on entities** — use explicit accessors; never `@Data` on `@Entity`.
- **REST DTOs are Java records** — `<Resource>Response` / `<Resource>CreateRequest` /
  `<Resource>UpdateRequest`; controllers **never** expose entities.
- **`RestClient`** for outbound blocking HTTP (not `RestTemplate`); bound every
  call with timeouts + Resilience4j (see `resiliency-review`).
- **`@ConfigurationProperties`** (validated) for grouped config, not scattered `@Value`.
- **`@HttpExchange`** interfaces for declarative HTTP clients.
- **`ProblemDetail` (RFC 9457)** for every error; enable
  `spring.mvc.problemdetails.enabled: true`; the catch-all 500 never returns the
  exception message.
- **List endpoints return `PagedModel`**, never raw `Page`/`PageImpl`.
- **Optimistic locking** with `@Version`; a lost update returns **409**.
- **`@Transactional(readOnly = true)`** at service class level; plain
  `@Transactional` on mutating methods.
- **Actuator probes**: permit `/actuator/health/**` (not only `/actuator/health`)
  so liveness/readiness work behind security; expose an allow-list, never `*`.
- **Virtual threads** enabled (`spring.threads.virtual.enabled: true`);
  **graceful shutdown** configured (`server.shutdown: graceful`).
- **Flyway owns the schema**; `ddl-auto: validate`, `open-in-view: false`;
  every entity change ships its migration in the same commit (see `aws-postgres`).
- **Jackson 3** (`tools.jackson`): inject `JsonMapper`; `@JacksonComponent`
  replaces `@JsonComponent`; only `com.fasterxml.jackson.annotation` keeps its package.
- **Java 21 / Boot 4.x / Cloud 2025.1**; JUnit 5 with `@MockitoBean` (see `spring-testing`).

## Layering

- `api/` — REST controllers + DTOs (records).
- `core/` — domain logic. Must not import web/http classes.
- `adapters/` — external systems: `persistence/` (Spring Data + JPA entities),
  HTTP clients, messaging clients. `api/` never calls an adapter directly.

## Module and platform rules

- Service names kebab-case. Ports: config-server 8888, gateway 8080, services 8081+.
- Discovery is Kubernetes-native (`spring-cloud-starter-kubernetes-client`) —
  **no Eureka**. Config comes from Spring Cloud Config (`optional:configserver:`)
  — no hardcoded environment values.
- Never bump `gradle/libs.versions.toml` or `platform/build.gradle.kts` in a
  feature change — the platform team owns versions.

## See also

- `spring-data-jpa` — transactions, N+1, entity leaks, migrations.
- `spring-testing` — slices, Testcontainers `@ServiceConnection`, Boot 4 APIs.
- `spring-boot-4-migration` — Boot 4 renames/properties.
- `architecture-guardrails` — the ArchUnit rules that fail `make test`.

## Done when

The change follows the rules, layering, and version policy above.

## Concurrency / async

- Background work uses the injected `taskExecutor` (AsyncConfig). It wraps tasks with
  `ContextPropagatingTaskDecorator` and registers `Slf4jThreadLocalAccessor`, so the current span,
  `traceparent` on outbound calls, and MDC `traceId` survive the thread switch.
- Never call `Executors.*`, construct `Thread`, or use one-arg `CompletableFuture.supplyAsync/runAsync`
  (default pool). ArchUnit fails the build.
- A custom executor must set the same TaskDecorator and MDC accessor; outbound clients still use the
  auto-configured `RestClient.Builder`.
- Messaging consumers propagate context through the starter's observation support, not manual headers.
