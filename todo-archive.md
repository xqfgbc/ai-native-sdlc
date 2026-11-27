# todo archive — 已完成的门禁改进

> `todo.md` 只保留**未完成**项。完成一条时，把整条从 `todo.md` 移到这里：
> 保留原 ID 与验收内容，补上完成日期与验证证据（命令 + 关键输出）。
> 不要在两处重复；本文件只做历史索引与证据留存。

## 索引

| ID | 标题 | 完成日期 | 验证证据 |
|---|---|---|---|
| TODO-07 | 存量仓同步护栏 | 2026-11-27 | `selftest: 95 passed`；speaker 同步 2 个文件 |
| TODO-10 | managementRepo 解析与显式失败 | 2026-11-27 | `collect --resolve-mgmt` 三种路径；selftest 用例 |
| TODO-11 | 采集位/上传位分离 + 本地补传 | 2026-11-27 | 离线 collect + replay；speaker 报告 `520e68b` 上传 |
| TODO-12 | upload-report 基线分支可配置 | 2026-11-27 | gh stub 探测 `master` / `--base develop` |

## 条目

### [x] TODO-07（P3）存量仓同步护栏

- 完成：2026-11-27
- 改动：`scripts/sync-guardrails.sh`（dry-run / `--write` / `--check` / `--service` / `--source` / `--json`；
  源码根默认脚本所在仓，控制平面内运行时用 `--source` 或 `SDL_FRAMEWORK_REPO` 指向框架仓）；
  `new-project.sh` 把它复制进控制平面；对比 `hooks/`、`.githooks/`、`.claude/settings.json`、
  `.codex/hooks.json` 与 10 个公共脚本（含 `collect.sh → .sdlc/collect.sh`），写完后重新 `install-hooks.sh`。
- 验收：dry-run 列差异不写；`--check` 有漂移退出 1；`--write` 后 `cmp` 一致且 `--check` 通过。
- 验证证据：
  ```bash
  bash scripts/sync-guardrails.sh ../ses-control-plane --write
  # sync-guardrails: speaker has 2 difference(s)  (hooks/README.md, .sdlc/collect.sh)
  # sync-guardrails: wrote 2 file(s) into speaker
  bash scripts/selftest.sh    # 95 passed, 0 failed
  ```

### [x] TODO-10（P1）managementRepo 解析与显式失败

- 完成：2026-11-27
- 改动：`scripts/collect.sh` 解析顺序 `SDL_MGMT_REPO` → 同级 `<project>-control-plane` → config；
  `SDL_MGMT_REPO` 显式但目录不存在时**不回落**、打印 `management repo not found at <path>` 并保留本地报告；
  新增 `--resolve-mgmt` 便于 AI/CI 查询；六类 `config.json.tpl` 增加 `project` 字段。
- 验收：只放服务仓时报告生成 + 警告 + exit 0；`SDL_MGMT_REPO` 生效；同级克隆自动找到。
- 验证证据：
  ```bash
  bash .sdlc/collect.sh --resolve-mgmt          # /Users/.../ses-control-plane
  SDL_MGMT_REPO=/tmp/missing bash .sdlc/collect.sh --resolve-mgmt
  # collect: management repo not found ...; exit=1
  bash scripts/selftest.sh                      # 95 passed, 0 failed
  ```

### [x] TODO-11（P1）采集位与上传位分离 + 本地补传

- 完成：2026-11-27
- 改动：`scripts/collect.sh` 增加 `lastUploadedSha`（仅本地上传成功才推进）；
  新增 `scripts/replay-reports.sh <management-repo> [--dry-run] [--json]`，按报告时间顺序补传、
  已存在的报告跳过、成功后推进上传位；配置文件增加 `lastUploadedSha`；`new-service-repo.sh` 复制 replay 脚本。
- 验收：离线连续 collect → 报告在本地、上传位不动；replay 后进入控制平面；重复 replay 幂等。
- 验证证据：
  ```bash
  bash scripts/selftest.sh    # 95 passed, 0 failed（离线/replay/幂等 6 条用例）
  # speaker：collect 上传 520e68b 后 lastCollectedSha=lastUploadedSha=520e68b
  ```

### [x] TODO-12（P2）upload-report 的基线分支可配置

- 完成：2026-11-27
- 改动：`scripts/upload-report.sh` 新增 `--base <branch>`；未指定时用
  `gh repo view --json defaultBranchRef` 探测默认分支，clone 与 PR 使用同一分支；
  新增 `--dry-run` / `--json` 便于验证。
- 验收：默认分支 `master` 的控制平面可用；`--base develop` 生效；无 token 时保持 skipped/exit 0。
- 验证证据：
  ```bash
  GH_TOKEN=dummy bash scripts/upload-report.sh org/demo r.json build order-service abc --dry-run
  # upload-report: dry-run repo=org/demo base=master ...
  # selftest: 95 passed, 0 failed
  ```
