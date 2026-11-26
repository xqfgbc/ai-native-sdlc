---
name: spring-testing
description: Choose and write the right Spring test for the change (unit, slice, or full integration), with Testcontainers @ServiceConnection and Spring Boot 4 APIs. Use whenever tests are created or changed.
---

# Spring testing

AI agents write tests that are too broad, too slow, or that assert nothing.
Choose the smallest test that proves the behavior.

## Pick the right test

| Scope | Annotation | Use for |
|---|---|---|
| Pure unit | plain JUnit 5 + Mockito | domain logic in `core/`, no Spring context |
| Web slice | `@WebMvcTest` | controller mapping, validation, error responses |
| JPA slice | `@DataJpaTest` | repository queries; Testcontainers PostgreSQL |
| Full | `@SpringBootTest` | wiring across layers; lives in `src/itest/java` |

- Prefer slices; a full `@SpringBootTest` for a unit concern is a defect.
- `src/test/java`: unit + slice tests (fast, no Docker).
- `src/itest/java`: integration tests with Testcontainers, wired into `./gradlew check`.

## Spring Boot 4 test APIs (agents get these wrong)

Imports moved to per-technology modules. Use exactly these:

```java
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import tools.jackson.databind.json.JsonMapper;   // Jackson 3 (not com.fasterxml.jackson.databind.ObjectMapper)
```

- `@SpringBootTest` **no longer provides MockMvc/RestTestClient** — add
  `@AutoConfigureMockMvc` (or `@AutoConfigureRestTestClient`).
- `@MockBean`/`@SpyBean` are **removed** — use `@MockitoBean`/`@MockitoSpyBean`.
- Test slices need the per-technology starter: `@WebMvcTest` →
  `spring-boot-starter-webmvc-test`; `@DataJpaTest` → the JPA test starter.
- `RestTestClient` (the Boot 4 replacement for `TestRestTemplate`) needs
  `spring-boot-resttestclient` (test scope) + `@AutoConfigureRestTestClient`.
  The scaffold's itest uses the JDK `HttpClient` instead, so it needs no extra
  dependency — either is fine, but do not use `TestRestTemplate` (deprecated in 4.2).

## Testcontainers with `@ServiceConnection` (preferred)

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Testcontainers
class UserEndpointIT {

    @Container
    @ServiceConnection                 // auto-configures the datasource; no @DynamicPropertySource
    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16");

    // ...
}
```

- Dependencies: `org.springframework.boot:spring-boot-testcontainers`,
  `org.testcontainers:junit-jupiter`, `org.testcontainers:postgresql`
  (all `testImplementation`, versions from the platform BOM).
- `@ServiceConnection` replaces `@DynamicPropertySource` for the connection
  properties (URL/username/password). Use `@DynamicPropertySource` only for
  properties `@ServiceConnection` does not cover.
- With Flyway, tests need no datasource overrides: real migrations run and
  `ddl-auto: validate` checks the entities.

## Test discipline

- Every endpoint has an integration test in `src/itest/java` asserting status,
  body shape, and auth behavior.
- Positive **and** negative cases (validation error → 400 `ProblemDetail`,
  unauthorized → 401/403, conflict → 409).
- Deterministic: no `Thread.sleep`, no order dependence, no real network, no
  shared mutable state.
- Assert behavior, not implementation.
- **Never weaken a test to make it pass** — a failing test is a fix-the-code signal.

## Done when

The smallest sufficient test exists, it is deterministic, and `make test`
(unit/slice) plus `make itest` (integration) are green with pasted output.
