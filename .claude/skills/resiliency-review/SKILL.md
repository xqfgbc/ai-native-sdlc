---
name: resiliency-review
description: Apply timeout, circuit-breaker, and retry policy to any outbound call or event consumer. Use for any outbound HTTP call, Kafka/SQS consumer, or external integration.
---

# Resiliency review

Use for any outbound call or event consumer. The rule is simple: **every outbound
call is bounded in time, wrapped in a circuit breaker, and retried with backoff.**

## Outbound HTTP (RestClient/WebClient/Feign)

1. Explicit connect **and** response timeouts (never rely on defaults).
2. Resilience4j circuit breaker: bounded failure-rate threshold, a wait-duration
   in the open state, and a sliding window.
3. Bounded retries with exponential backoff and jitter; never retry non-idempotent
   calls without an idempotency key.

## Event consumers (Kafka/SQS)

- Dead-letter queue (DLQ) + redrive for poison messages.
- Bounded processing time; ack/commit after success; idempotent consumers.

## Data layer

- HikariCP: explicit pool size; for RDS IAM auth keep `maximum-lifetime` below the
  15-minute token TTL (≈14 min).
- Set `spring.jpa.open-in-view: false`.

## Conventions

- Money is `BigDecimal` (never `double`); timeouts are configurable via Config
  Server, never hardcoded.
- Hystrix is legacy — use Resilience4j
  (`spring-cloud-starter-circuitbreaker-resilience4j`).

## Done when

Every outbound call in the change has timeouts + breaker + retries, and no
unbounded external dependency remains.
