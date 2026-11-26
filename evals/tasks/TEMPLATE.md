---
name: TEMPLATE-add-endpoint
prompt: |
  Work from the accepted plan in the newest intent folder that has a plan.md
  with status accepted. Implement work item 1 exactly as planned, following
  the spring-service-conventions and secure-api-review skills. Run the
  feedback loop and commit per the implement-change skill.
allowed_tools:
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Bash(make *)
  - Bash(bash scripts/*)
  - Bash(git status)
  - Bash(git add *)
  - Bash(git commit *)
verify:
  - cmd: bash scripts/selftest.sh
    expect: ""
  - cmd: ./scripts/validate-skills.sh
    expect: "BUILD SUCCESSFUL"
---
Replace this with a real task collected from recent work (see evals/README.md
rule 1). Keep 20-50 tasks in the suite; add one per production incident.
