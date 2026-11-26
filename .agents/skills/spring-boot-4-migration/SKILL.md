---
name: spring-boot-4-migration
description: Apply Spring Boot 4.x migration rules when upgrading or adding code. Use when a change touches build files, tests, or the framework version and may use pre-4 APIs.
---

# Spring Boot 4 migration

Spring Boot 4.0 GA (Nov 2025) and 4.1.x change APIs that agents learned from
Boot 3. The platform team owns versions; this skill is the checklist the agent
must satisfy so the build stays green.

## Rules that break Boot 4 code

| Pre-Boot 4 | Boot 4 |
|---|---|
| `spring-boot-starter-web` | `spring-boot-starter-webmvc` |
| `spring-cloud-starter-gateway` | `spring-cloud-starter-gateway-server-webflux` |
| `spring.cloud.gateway.*` | `spring.cloud.gateway.server.webflux.*` |
| `@MockBean` / `@SpyBean` | `@MockitoBean` / `@MockitoSpyBean` |
| Jackson 2 `Jackson2ObjectMapperBuilderCustomizer` | Jackson 3 `JsonMapperBuilderCustomizer`; `@JacksonComponent` |
| `spring.cloud.config.import-check.enabled` | removed — rely on `spring.config.import` |
| `javax.*` | `jakarta.*` (Jakarta EE 11) |
| `matchTrailingSlash` on `Path` predicate | no longer has any effect |

Also in Boot 4: actuator liveness/readiness probes are enabled by default;
`spring-boot-jackson2` is a deprecated stop-gap.

## Migration steps

1. **Never bump versions in a feature change.** If the upgrade itself is the
   change, update `gradle/libs.versions.toml` only (platform team), one line.
2. Add `spring-boot-properties-migrator` temporarily to surface renamed/removed
   properties, then remove it after the migration.
3. Let the compiler drive renames (starters, annotations, customizers).
4. Fix tests to the Boot 4 test APIs (`@MockitoBean`, Jackson 3, probes).
5. Gate on `make build && make lint && make test && make itest` before reporting.

## Deterministic layer

`hooks/spring-guard.sh` greps the diff for the pre-Boot 4 patterns above and
blocks them. It runs from the git hooks and CI; do not bypass it — change the
code.

## Done when

No pre-Boot 4 API remains in the change, and the full verification loop is green.
