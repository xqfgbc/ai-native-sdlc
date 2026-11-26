---
name: code-quality
description: Review checklist for a Spring Boot change — correctness, security, performance, Spring signals, REST semantics, and code smells. Use with pr-review when reviewing a diff or before requesting review.
---

# Code quality review checklist

Load this before `pr-review` on any Java/Spring diff. It is the *what to look for*;
`pr-review` is the *how to report*. Stay concise: cite `File:line`, skip what
linters/CI already enforce, and phrase smells as "possible …".

## Correctness

- Transactions: `@Transactional` scope, self-invocation, `rollbackFor`, long
  transactions, remote calls inside a transaction.
- Nullability and optional paths; error paths return a `ProblemDetail`, never a raw stack.
- Concurrency: shared mutable state, `@Async`/`@Scheduled` multi-replica, lost updates
  (`@Version` → 409).
- Pagination: collection endpoints take `Pageable` and return `PagedModel`; no unbounded `findAll()`.
- Idempotency on retries and duplicate submissions.

## Security

- Authn/authz on every endpoint; object-level checks (no IDOR/BOLA).
- Input validation (`@Valid`/`@Validated`), output encoding, no injection.
- No secrets in source/config; PII out of logs; actuator not wildcard-exposed.
- Prompt-injection/agentic: untrusted text never forwarded into a downstream agent/tool
  (OWASP ASI01/ASI10).

## Performance

- N+1 queries (fetch plans/`@EntityGraph`), missing indexes on FKs, large payloads.
- Outbound calls have timeouts + circuit breaker; no `.block()` on request threads.
- Caching where read-heavy and safe; bounded page sizes.

## Spring signals

- Constructor injection, records for DTOs, entities never leave the persistence layer.
- `@ConfigurationProperties` (validated) over scattered `@Value`.
- `@RestControllerAdvice` for errors; consistent status codes (201/204/409).
- Virtual threads / graceful shutdown configured when relevant.

## REST semantics

- Correct verbs/status codes; `Location` on 201; `ProblemDetail` content type.
- Versioning strategy respected; no breaking contract change without a version bump.
- Filtering/sorting/paging parameters typed and bounded.

## Code smells (heuristic — say "possible")

- Long methods, deep nesting, duplicated logic, feature envy, primitive obsession.
- Over-general abstractions, dead code, misleading names.

## Do not report

Formatting/import order (linters), generated code, `build/`, and anything CI enforces.
