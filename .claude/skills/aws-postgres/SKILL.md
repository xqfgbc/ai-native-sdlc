---
name: aws-postgres
description: Apply AWS RDS PostgreSQL conventions for datasource config, migrations, and secret handling. Use for any schema, datasource, or migration change.
---

# AWS PostgreSQL

Use for any datasource, schema, or migration change. Production databases are
AWS RDS PostgreSQL; local/dev use H2, integration tests use Testcontainers
PostgreSQL (`postgres:16`).

## Datasource

- `org.postgresql:postgresql` driver (runtime). For RDS **IAM auth**, use the AWS
  Advanced JDBC Wrapper (`jdbc:aws-wrapper:postgresql://...`) and keep HikariCP
  `maximum-lifetime` ≈14 min (below the 15-min token TTL).
- Credentials come from the environment, injected by **External Secrets Operator
  (ESO)** from AWS Secrets Manager / SSM, or via **IRSA** for IAM auth. **Never**
  hardcode credentials in `application.yml` or committed config.

## Migrations

- Use a versioned migration tool (Flyway/Liquibase) — no `ddl-auto: update` in
  production; `validate` only.
- Backward-compatible migrations: expand → migrate → contract. Never drop or
  migrate the database as part of a rollback (see `gitops-deploy`).

## Data classification

- Mark PII columns in the schema; they must never appear in logs or error
  messages (`secure-api-review`).
- Money is `BigDecimal`, never `double`; use `NUMERIC`/`DECIMAL` columns.

## Testing

- Integration tests run against Testcontainers PostgreSQL for parity with RDS.
- Unit tests may use H2 for speed, but any SQL-specific behavior must have a
  Testcontainers-backed test.

## Done when

Datasource, migration, and secret handling follow the above, and no credential
is committed.
