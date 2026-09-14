# MoonReduce

用 MoonBit 编写的失败测试用例约减库与原生命令行工具。在项目副本中删除无关内容，让一个失败的 `.mbt` 文件变小，同时通过外部命令确认指定的失败特征仍然存在。

适用于整理编译诊断、测试失败、非零退出或超时的最小复现。

[English](README.mbt.md) · [设计](docs/DESIGN.md) · [测试说明](docs/TESTING.md) · [验收记录](artifacts/acceptance/initial/summary.md)

## 当前状态

版本：`0.1.0`。本地技术验收已通过；正式 mooncakes 发布与公开安装验证尚未完成。

截至 2026-09-14 的验证记录：

| 项目 | 结果 |
| --- | --- |
| Windows / Ubuntu 原生测试 | 各 149/149 通过 |
| JavaScript / wasm-gc 测试 | 两个平台分别各 130/130 通过 |
| 核心包行覆盖率 | 439/458，95.85%（不含原生专用包） |
| 真实约减夹具 | 5/5 通过，每个均完成 3 次最终复验 |
| 约减比例中位数 | 89.80% |
| 确定性 | 编译诊断夹具独立运行 10 次，最终 SHA256 一致 |

完整门槛、历史失败和剩余事项见[初验报告](artifacts/acceptance/initial/summary.md)。

## 核心能力

- 直接通过 argv 执行判定命令，组合退出码、非零退出、超时与 stdout/stderr 文本规则。
- 两次原始基线验证，随后执行 ddmin 和 12 种文本/Token 变换。
- 仅接受 UTF-8 字节数严格减少且仍匹配失败特征的候选。
- 每个候选使用独立项目副本；运行内按完整内容缓存，最终三次验证绕过缓存。
- 支持次数预算、总时间预算、单次超时和取消；中断时保存当前结果并标记未完成状态。
- 输出约减项目、JSON/Markdown 报告、统一 diff、复现说明和事件记录。

## 快速开始

需要 MoonBit 工具链、原生目标所需的 C 编译器，以及项目依赖。当前依赖为 `moonbitlang/async@0.20.4`。在仓库根目录运行：

```text
moon check --target native --deny-warn
moon run cmd/main -- --help
moon run cmd/main -- passes
```

使用项目自带的编译诊断夹具：

```text
moon run cmd/main -- reduce --config testdata/compile_diagnostic/predicate.json --workspace testdata/compile_diagnostic/input --output ./compile-diagnostic-result
moon run cmd/main -- explain ./compile-diagnostic-result/report.json
```

输出目录必须尚不存在，位于输入工作区之外，且父目录已经存在。再次运行时请换一个新的输出目录。

构建 CLI：

```text
moon build --target native cmd/main
```

已验证的 Windows、Ubuntu 工具链会生成 `_build/native/debug/build/cmd/main/main.exe`；Linux 下它也是原生可执行文件。开发时可统一使用 `moon run cmd/main -- ...`。

## 命令与输出

| 命令 | 用途 |
| --- | --- |
| `check` | 连续验证两次原始失败，不执行约减 |
| `reduce` | 运行完整约减流程 |
| `passes` | 列出变换 |
| `explain <report.json>` | 格式化展示 JSON 报告 |

`--help` 包含命令、输出匹配、预算和进度选项。配置文件提供默认值，CLI 参数可以覆盖配置。详见[判定规则](docs/PREDICATES.md)。

一次约减的输出：

```text
output/
├── reduced/
├── report.json
├── report.md
├── reduction.diff
├── reproduce.txt
└── events.ndjson
```

成功的基线检查不等于成功约减。`report.json` 的 `completed` 只有在状态为 Completed、最终匹配达到三次且原始文件未改变时才为 true。预算停止、取消或最终复验失败的结果应按报告状态处理。

## 实测约减结果

| 夹具 | 原始字节 | 最终字节 | 减少比例 |
| --- | ---: | ---: | ---: |
| 编译诊断 | 450 | 39 | 91.33% |
| 测试失败 | 451 | 46 | 89.80% |
| 非零退出 | 476 | 100 | 78.99% |
| 超时 | 441 | 79 | 82.09% |
| 噪声源码 | 544 | 45 | 91.73% |

输入、配置和许可证位于 [testdata](testdata/)，使用说明位于 [examples](examples/)。这些是固定夹具的实测结果，不代表任意输入都能达到相同比例。

## 开发与验证

在 PowerShell 中运行统一检查：

```powershell
./scripts/verify.ps1
```

或者逐项执行：

```text
moon info --target native
moon fmt --check
moon check --target native --warn-list +73 --deny-warn
moon build --target native tools/process_probe
moon test --target native --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
```

原生生命周期测试需要先构建 `tools/process_probe`。它只创建受控测试进程，最长十秒自行退出；统一脚本已包含构建步骤。

作为库使用时，可导入 `Ag108/MoonReduce/reducer/engine` 的纯 `Session` 状态机，或使用 `predicate/matcher`、`report` 等包。当前公开接口见各包的 `pkg.generated.mbti`；0.x API 尚未承诺稳定。

## 使用边界

仅运行可信项目和可信命令。隔离副本不是安全沙箱，外部命令仍拥有当前用户的权限。

- 初验只约减一个 UTF-8 `.mbt` 文件，不提供完整语法树、多文件约减或断点恢复。
- 目标文件上限 64 KiB，单文件上限 1 MiB，项目快照上限 1000 文件/16 MiB。
- 进程回收针对本次父 PID 的可识别后代；无法保证约束主动逃逸、重设父进程或改变权限的程序。
- 环境变量值不写入报告，但命令参数会保留原文，不要把密钥放在 argv 中。
- FNV-1a 用于稳定标识，不是安全校验哈希；缓存以完整内容判断相等。

详见[安全说明](SECURITY.md)、[进程验证](docs/PROCESS_VALIDATION.md)和[已知限制](docs/LIMITATIONS.md)。不要通过关闭安全软件来让测试通过。

## 许可证与贡献

采用 [Apache-2.0](LICENSE)。依赖与来源见 [THIRD_PARTY.md](THIRD_PARTY.md)、[REFERENCES.md](REFERENCES.md)。

贡献流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。本项目按小步提交 Git；pre-push hook 通过 PowerShell 7（`pwsh`）运行统一验证脚本，检查失败时拒绝推送。
