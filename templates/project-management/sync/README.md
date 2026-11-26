# sync/ — 契约与状态

## 内容

- `schemas/`：正式 JSON Schema（与框架仓 `schemas/` 同源）：execution-report、service-registry、cognition-pack。
- `state.json`：analyzer 的采集/分析状态（上次处理到哪个报告、上次 pack 版本）。

## 报告流转

1. 服务仓 `.sdlc/config.json` 记录 `managementRepo` 与 `lastCollectedSha`。
2. 采集器产出 `sync/reports/<toSha>.json`（服务仓）。
3. 上传 = 复制到 `execution/<stage>/<service>/reports/<toSha>.json`（幂等键 `toSha`）。
4. analyzer 定时/手动读取，生成 `wiki/` 与 `knowledge/proposals/`。

## 校验

`scripts/validate-project.sh` 用 `schemas/` 校验 registry / reports / pack；CI 同源校验（D15）。
