# Skill authoring — skill 管流程与判断，命令住进 CLI

> poteto：随着模型变强，skill 应该**越来越短**——保留流程与判断，把具体命令移进 CLI。
> 目标不是"教 AI 更聪明"，而是让每个 session 复用同一把刀（`scripts/app-verify.sh` / `make`），
> 而不是各自重造一次性脚手架。

## 一个 skill 应该包含

1. **何时触发**（trigger）——一句话，能被 `description` 命中。
2. **流程**（steps）——有序、可执行；每步产出一个 artifact。
3. **判断点**（judgment）——需要人/AI 做取舍的地方（这是模型替代不了的，必须留下）。
4. **完成标准**（done）——可验证的条件。
5. **失败/边界**（failure modes）——已知坑、什么时候停。

## 一个 skill 不应该包含

- 长篇命令清单（`mvn`/`gradle`/`kubectl` 的完整参数）→ 移进 `scripts/` 或 `Makefile`。
- 易变的版本号/URL → 移到 `libs.versions.toml` / config。
- 与代码重复的规则细节 → 引用 `AGENTS.md` / `CLAUDE.md` / ArchUnit，别抄一遍。

## 瘦身操作（P2 起）

- 看到 skill 里有大段命令 → 抽成 `scripts/<tool>.sh`，skill 只写 `bash scripts/<tool>.sh <cmd>`。
- 命令索引见 `scripts/README.md`。
- skill 改动后跑 `scripts/sync-agent-adapters.sh` + `scripts/validate-skills.sh`。

## 反模式

- **把规则写两遍**：prompt 一遍、代码一遍 → 代码赢了（原则 10）。
- **skill 变教程**：超过 ~200 行通常意味着该拆 skill 或该建 CLI。
- **命令即规则**：把"必须跑 checkstyle"写成 prompt，而不是 CI/`make verify`。
