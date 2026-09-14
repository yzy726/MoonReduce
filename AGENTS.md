# Project Agents.md Guide

## Git 自动提交授权

2026-09-09：用户授权按 goal.md 完成初验目标，每个可验证小步提交本地 Git。
使用功能分支，完成后合并本地主分支。
2026-09-15：用户明确授权 push 并测试 GitHub Actions CI，覆盖此前禁止上传的限制。

2026-09-15 后续授权：现有提交 e3d64bc 已上传。此后只提交并合并本地 Git，禁止再次 push 或发布远程制品。项目申报书已完成；用户随后明确要求继续开发，已授权推进终验。注册表发布状态须以实际证据核实，不推断已发布。申报书必须命名为 .gitignore 已忽略的 项目申报书.md，仅保留本地，不得强制 git add、提交或 push。不得恢复已删除的 AI_USAGE.md，README 不描述上传或 CI 状态。

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.
