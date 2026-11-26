---
name: spring-data-jpa
description: Apply correct JPA, transaction, and persistence practices for any Spring Data JPA change. Use whenever an entity, repository, transaction, or migration is created or changed.
---

# Spring Data JPA

Persistence is the highest-risk area for AI-generated Spring code. Apply these
rules for every entity, repository, transaction, or migration change.

## Transactions

- `@Transactional` on **public** methods of the layer that owns the boundary
  (service). Never on private/final methods — the proxy is bypassed.
- **Self-invocation is silently ignored**: calling `this.otherTxMethod()` from
  inside the bean bypasses the proxy. Move it to another bean or inject self.
- Read paths: `@Transactional(readOnly = true)`.
- Set `rollbackFor = Exception.class` when the method can throw checked
  exceptions (by default only unchecked exceptions roll back).
- Keep transactions short: **no remote/HTTP/messaging calls inside a
  transaction**. Never hold a transaction across user think time.
- `spring.jpa.open-in-view` must be `false` (set it; do not rely on the default).

## Entities

- `@Data`/`@EqualsAndHashCode` on entities is forbidden — use `@Getter` +
  explicit business `equals`/`hashCode` (or none). Lombok on entities is a root
  cause of broken identity and lazy-loading bugs.
- Use `@Version` for optimistic locking on mutable aggregates.
- Enums: `@Enumerated(EnumType.STRING)`, never `ORDINAL`.
- Time: `Instant` / `OffsetDateTime`, never `java.util.Date`.
- Money: `BigDecimal` mapped to `NUMERIC/DECIMAL`, never `double`/`float`.
- No `@Entity` in `api/`; entities live in `adapters/persistence/` and never
  leave `core/`.

## Repositories and queries

- Never return entities from controllers. Map to DTO records in `core/`
  (projections or explicit mappers). This prevents lazy-loading leaks and
  domain coupling.
- Avoid N+1: use `join fetch`, `@EntityGraph`, or projection queries. Verify
  with SQL logging in tests (`spring.jpa.show-sql` in a test profile only).
- No unbounded `findAll()` on user-facing paths — always accept `Pageable` and
  cap page size (e.g. 100).
- Prefer JPQL/criteria; `nativeQuery` only when necessary and reviewed.

## Schema and migrations

- Production `ddl-auto: validate` only. Schema changes go through versioned
  migrations (Flyway/Liquibase) — see `aws-postgres`.
- Backward-compatible: expand → migrate → contract. Never drop columns/change
  types in the same deploy that stops reading them.
- Test against real PostgreSQL (Testcontainers), not H2, for anything SQL-specific.

## Done when

Every transaction/threshold above holds, no entity escapes the persistence
layer, and the change has an itest against Testcontainers PostgreSQL.
