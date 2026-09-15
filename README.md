# MoonReduce

用 MoonBit 编写的失败用例约减库与原生命令行工具。在独立项目副本中删除无关文件、声明、语句和 Token，并通过外部命令持续确认目标失败仍然存在。

[English](README.mbt.md) · [项目模式](docs/PROJECT_MODE.md) · [判定规则](docs/PREDICATES.md) · [库 API](docs/API_STABILITY.md) · [终验记录](artifacts/acceptance/final/summary.md)

## 能力

- 单文件和多文件约减，支持包目录删除、保护／忽略 glob，以及可选清单字段约减。
- 文本、Token 和 16 类结构化变换；轻量语法扫描失败时可继续文本层约减。
- 退出码、超时、输出文本、有限正则、诊断码、测试名、崩溃类别、差分命令和 JSON wrapper 判定。
- repeat/quorum 与三态结果，记录稳定率和置信区间；默认最终三次无缓存复验。
- 确定性批次调度、并行工作进程、次数／时间预算、检查点与恢复。
- SHA-256 证据清单、diff、环境摘要和独立重放。
- 可复用的 evaluator、pass、事件回调及 `check/reduce` 库入口。

## 快速开始

需要 MoonBit 工具链及其原生 C 编译环境。已固定的依赖是 `moonbitlang/async@0.20.4`。
在仓库根目录执行：

```text
moon update
moon run cmd/main -- --help
moon run cmd/main -- reduce --project --config testdata/final/compile_diagnostic/predicate.json --workspace testdata/final/compile_diagnostic/input --output ./compile-result
moon run cmd/main -- replay ./compile-result/report.json
```

最后一条命令校验证据文件，然后在新副本中重新执行最终判定。输出目录必须尚不存在、位于输入目录之外，且父目录已经存在。再次运行请换新目录名。

构建和安装到自选目录：

```text
moon build --target native --release cmd/main
moon install ./cmd/main --bin ./local-bin
```

开发时推荐 `moon run cmd/main -- ...`。本项目固定工具链的原生构建文件位于 `_build/native/release/build/cmd/main/main.exe`；Linux 下该文件也是原生可执行程序。

## 命令

| 命令 | 用途 |
| --- | --- |
| `check` | 验证原始失败，不执行约减 |
| `reduce` | 约减并进行最终复验 |
| `resume checkpoint.json` | 从已保存状态继续，可增大预算 |
| `replay report.json` | 校验证据并无缓存重放结果 |
| `diff report.json` | 校验后输出统一 diff |
| `explain report.json` | 展示 JSON 报告 |
| `passes` | 列出变换名称 |
| `config validate FILE` | 检查配置，不运行外部命令 |
| `cache stats --run DIR` | 查看结果目录中的缓存统计 |
| `cache clean --run DIR` | 清除该运行的候选缓存，保留结果与恢复状态 |

常用选项包括 `--project`、`--jobs 4`、`--repeat 5 --quorum 4`、`--score bytes|tokens|lines`、`--include`、`--protect`、`--ignore`、`--pass-include`、`--pass-exclude`、`--keep-workdir`。完整参数见 `--help`；配置文件提供默认值，命令行覆盖同名配置。

## 输出与成功判定

```text
result/
├── reduced/
├── original-summary.json
├── report.json
├── report.md
├── events.ndjson
├── checkpoint.json
├── environment.json
├── checksums.txt
├── reduction.diff
└── reproduce.txt
```

`completed` 要求正常结束、达到配置的最终复验阈值，且原始文件未改变。预算停止、取消或最终验证失败的候选可以保留供继续处理，但不会被标为成功。详见[报告格式](docs/REPORT_FORMAT.md)。

## 示例和开发

[examples](examples/) 包含十二个示例，覆盖真实编译／测试失败、多文件、诊断指纹、差分、不稳定判定、恢复、并行和自定义 pass。

```text
moon run examples/custom_pass --target native
```

PowerShell 完整检查入口：

```powershell
./scripts/verify.ps1
./scripts/benchmark-final.ps1
./scripts/determinism-final.ps1
```

验证会先构建有界测试辅助进程。纯核心支持 native、JavaScript、wasm-gc；外部进程和 CLI 使用 native。测量口径和结果见[测试说明](docs/TESTING.md)、[基准说明](docs/BENCHMARKS.md)和[终验记录](artifacts/acceptance/final/summary.md)。

## 使用边界

仅运行可信项目和可信命令。副本不是安全沙箱，命令仍有当前用户权限。

- 轻量结构树不等于完整 MoonBit 编译器，候选始终需要目标失败谓词验证。
- 正则支持有界子集，具体限制见[判定规则](docs/PREDICATES.md)。
- 快照最多 1000 文件／16 MiB，单文件最多 1 MiB，MoonBit 源文件最多 64 KiB。
- 报告省略环境变量值；私有检查点为恢复保存显式环境覆盖。不要把秘密放进 argv，也不要公开含秘密的检查点。
- 校验和检测损坏，不证明证据来源可信。对主动逃逸进程不提供操作系统级约束。

详见[安全模型](docs/SECURITY_MODEL.md)和[已知限制](docs/LIMITATIONS.md)。许可证为 Apache-2.0。
