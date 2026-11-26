---
name: feedback-loop-green
prompt: |
  You are working in this repository. Run the verification feedback loop and
  report the result: run `bash scripts/selftest.sh` then `./scripts/validate-skills.sh`. If anything fails, fix the
  code (never the test) and re-run until both pass. Finish by reporting the
  exact output of the final `bash scripts/selftest.sh` and `./scripts/validate-skills.sh`.
allowed_tools:
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Bash(make *)
  - Bash(bash scripts/*)
verify:
  - cmd: bash scripts/selftest.sh
    expect: ""
  - cmd: ./scripts/validate-skills.sh
    expect: "BUILD SUCCESSFUL"
---
Guards the verify-work feedback loop: the agent must be able to run lint+test,
fix what it broke, and reach a green state. Added at framework bootstrap.
