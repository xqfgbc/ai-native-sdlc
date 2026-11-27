---
name: local-cognition
description: Use when a rule is true only for this service (domain invariant, local API/DB/ops policy). Records it with origin, problem and gate evidence; the statement stays local, only evidence is reported.
---

# Service-local cognition (S1)

A rule that only this service needs must not go through project sign-off. Record it here:

```bash
bash scripts/local-cognition.sh add \
  --statement "speaker 的 email 必须唯一" \
  --problem "重复邮箱导致创建接口产生两条记录" \
  --origin-type incident --origin-ref INC-42 \
  --summary "写入前校验唯一性，并用集成测试覆盖" \
  --enforcement deterministic \
  --gate-type test --gate-name "SpeakerServiceTest#duplicateEmail" \
  --gate-path src/test/java/.../SpeakerServiceTest.java
```

## When to use

- the rule names this service's domain, schema, API shape or local ops;
- it is not a cross-service contract or project-wide policy;
- you can point at a real gate (test / ArchUnit / hook / lint / CI).

`deterministic` requires `--gate-type` plus `--gate-name` or `--gate-path`; there is no "promise only"
mode. `statement` never leaves the repo: `collect` uploads `origin/problem/summary/gate` evidence only.

## Check

```bash
bash scripts/local-cognition.sh list --json
bash scripts/local-cognition.sh show <id> --json
```

## Promote to project level

If another service has the same problem (control plane shows a promotion candidate), a human writes a
`scope=project` proposal and signs it. Do not edit the project pack from this repo.
