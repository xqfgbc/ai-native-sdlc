# Test plan — {{PROJECT}}

Status: draft

## 策略

- 分层：单元 → 切片（`@WebMvcTest`/`@DataJpaTest`）→ 集成（`@SpringBootTest` + Testcontainers）→ E2E/验收。
- 集成测试用真实 PostgreSQL（Testcontainers），不用 H2 替代 SQL 行为。

## 环境

- dev / uat / prod；测试数据隔离，不连生产库。

## 质量门禁

- 覆盖率 ≥ __%（按服务设下限）。
- 首次 CI 通过率 ≥ __%。
- P0/P1 逃逸缺陷 = 0；每个需求至少一条验收测试。

## 需求覆盖

- 见 `matrix.md`（需求 ↔ 测试用例）；事故复盘后补充用例。
