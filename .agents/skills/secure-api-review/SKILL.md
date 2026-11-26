---
name: secure-api-review
description: Apply the API security standard when creating or changing any endpoint. Use for any external-facing endpoint, API code, or OpenAPI spec change.
---

# Secure API review

Use whenever you create or change an API endpoint. The policy is advisory; the
deterministic layer behind it is `scripts/check-endpoints.sh` plus CI/hooks.

## Checklist

1. **Authentication** — every endpoint is reached through the gateway and requires
   its JWT; no anonymous routes outside `/actuator/health`.
2. **Input validation** — request bodies are validated (`@Valid`/`@Validated` +
   jakarta.validation), reject unknown fields; validate against the OpenAPI schema
   where one exists.
3. **Audit** — every state-changing endpoint emits an audit event (actor, action,
   entity, timestamp).
4. **Data classification** — fields tagged PII in the schema must never appear in
   logs or error messages.
5. **Authorization** — object-level checks, not just endpoint-level; no IDOR.

## Also check (OWASP ASI for agentic apps)

- Prompt-injection surfaces: never pass untrusted text into a downstream agent,
  tool, or prompt without an explicit allowlist/deny boundary.
- No secrets in source, logs, or committed config values (ESO/IRSA inject them).

## Close out

Run `scripts/check-endpoints.sh` and paste its output into your summary.

## Done when

`check-endpoints.sh` reports no findings and every checklist item holds for each
changed endpoint.
