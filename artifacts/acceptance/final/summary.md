# MoonReduce 1.0.0 本地终验报告

日期：2026-09-15。最终实现与平台复验对应 Git 提交 `da06f78`；后续提交只整理文档、门槛审计与证据。

**结论：本轮授权范围内的本地开发、测试、基准、安装验证与文档交付完成。**
用户要求只提交本地 Git，不执行 push；因此不把本地验证称为 GitHub Actions 通过，F-18 的公开发布仍未执行。原始 goal.md 中要求全部 F-01～F-18 通过的正式发布验收，不在本报告中冒称完成。

## 量化结果

| 项目 | 实测 | 证据 |
|---|---|---|
| Windows native | 492/492 通过 | [Windows 日志](platforms/windows-verify.log) |
| Linux native | 492/492 通过 | [Linux 日志](platforms/linux-verify.log) |
| JS / wasm-gc | 两平台各 435/435、435/435 | 同上，跨后端不累加测试数 |
| 明确标记的 native E2E | 43 个声明；另有边界与故障注入测试 | [native 清单](native-e2e-inventory.txt) |
| 纯核心行覆盖率 | 1467/1585，92.56% | [逐文件覆盖率](core-coverage.json) |
| 结构变换 | 16 个独立 family，format 显式启用 | [语法与 pass 合约](../../../docs/MOONBIT_SYNTAX.md) |
| 示例 / 固定夹具 | 12 / 10 | examples/、testdata/final/ |
| 确定性夹具质量 | 9/9 减少 ≥50%，字节中位数 88.76% | [原始测量](benchmarks.json) |
| 全部夹具质量 | 10/10 减少 ≥50%，字节中位数 88.30%，Token 中位数 95.28% | 同上 |
| 预算 | 10/10 在 600 秒且 2500 次命令内完成；最大 167.45 秒、164 次命令 | 同上 |
| 最终验证 / 重放 | 每个夹具 final 3/3，独立 replay 3/3，均未使用最终验证缓存 | [replays](replays/) |
| 确定性并发 | jobs=1 与 jobs=4 各 10 次，20 次结果哈希全部相同 | [20 次记录](determinism/runs.json) |
| 已结算缓存候选重复执行 | ≥20 个已知候选，重复 0 个，0% | [恢复验证](resume-verification.json) |
| 证据完整性 | 10 个封存证据包、110 个 SHA-256 条目及原夹具文件哈希一致 | [审计日志](audit.log) |

覆盖率口径是 JS 后端输出的全部受测纯库插桩行，不包括仅支持 native 的进程、文件系统和 CLI adapter，不把该值称为全仓库覆盖率。App 包本身共 43 个测试声明，和跨 native 包的 43 个 E2E 标签声明是不同统计口径；实际清单保留全部 56 个 native async 测试声明。

代码规模单独披露：43 个非测试、非示例 MoonBit 源文件，共 6545 物理行，去掉空行与行注释后 5923 行，见 [逐文件统计](source-lines.json)。这低于设计阶段的 7000～9500 行估算；未通过增加冗余实现补齐行数。goal.md 自身规定规模用于排期和完整性估算、不得凑数，本报告以可执行功能和测试为验收依据，明确保留这一估算偏差。

## 固定基准

| 夹具 | 字节减少 | Token 减少 | 命令次数 | 秒 |
|---|---:|---:|---:|---:|
| compile_diagnostic | 87.84% | 96.94% | 95 | 24.56 |
| noisy_source | 88.76% | 96.94% | 95 | 24.58 |
| type_diagnostic | 95.26% | 97.31% | 84 | 21.58 |
| test_failure | 86.94% | 94.90% | 89 | 95.95 |
| assert_failure | 92.58% | 95.65% | 81 | 87.65 |
| array_failure | 92.69% | 93.30% | 115 | 116.11 |
| nonzero_exit | 80.56% | 88.18% | 164 | 123.40 |
| exit_code | 87.74% | 88.18% | 163 | 117.68 |
| multi_file_project | 94.23% | 97.35% | 104 | 27.19 |
| timeout | 81.32% | 89.34% | 20 | 167.45 |

九个确定性质量夹具按不含 timeout 计算；预算考核包含 timeout。多文件夹具删除了 5 个源文件中的 4 个，保留失败文件和受保护清单，满足删除 ≥50% 可约减文件的目标。实际失败来自 MoonBit 编译、测试、运行退出和有标记的超时；不是仅对字符串长度使用模拟 evaluator。

基准在 Windows 11、i7-14700HX、约 16 GiB 内存、moonc 0.10.10+f8a486b6f 上完成。每次候选缓存为空，工具链缓存为热状态；部分运行期间有开发校验及 WSL 设置并行进行，保留全部测量，不选最佳用时。编译 predicate 约 200 ms，native 测试/运行约 1 秒以上，timeout 为 10 秒：不能宣称全部满足“单次 predicate ≤200 ms”的假设。完整环境及逐次 baseline 用时见 [environment.json](environment.json) 与 benchmarks.json。

基准和 20 次确定性记录在功能完成后的开发过程中采集，当时程序仍带 `0.1.0` 开发标识。保存的 JSON、checkpoint、environment 和 reduced 字节保持原样，未把历史版本改写为 1.0.0。之后的进程错误信息、报告计数、平台字段和版本整理有独立回归；最终 `da06f78` 的完整三后端测试及安装缩减/重放另外留证。原始夹具通过 `.gitattributes` 禁用自动换行转换，避免检出后证据哈希改变。

20 次目录树哈希均为 `357a4c9b4b1bc65a8be8efcf45eacd0b1f4879b7f5c8d87089d4138bd5419fa7`，每次 104 次实际命令、final 3/3。哈希协议为排序后的路径及每文件 SHA-256 拼接再取 SHA-256，详见 scripts/determinism-final.ps1。恢复重复率只统计已返回、已结算并写入缓存的候选；未完成批次和必须重新执行的最终验证不计为已知候选重复。

## 两平台安装验证

两平台均使用 `moon install ./cmd/main --bin DEST` 从本地源码安装，再由安装出的程序缩减 compile_diagnostic 并完成 3/3 无缓存重放。

- Windows 安装程序 SHA-256：`ed5b194c60ebf5ab5660450fe80a01d410867f37e4e3e9e227064cdefbc223e2`，见 [安装日志](platforms/windows-install.log)、[缩减](platforms/windows-installed-report.json)、[重放](platforms/windows-installed-replay.json)。
- Linux 安装程序 SHA-256：`a5c0251b46060cb14f282746d0080fc43b859b1a5f903d03e206033571e816b2`，见 [完整构建与安装日志](platforms/linux-verify.log)、[缩减](platforms/linux-installed-report.json)、[重放](platforms/linux-installed-replay.json)。

Linux 为 Ubuntu / WSL2，在原生文件系统中使用干净 Git archive 和隔离 SDK。依赖 `moonbitlang/async@0.20.4` 通过现有 registry index/cache 解析；受网络限制，未验证全新在线 registry 下载。安装验证证明本地源码可安装，不代表远程发布包已经存在。构建二进制留在忽略的 `.moonreduce` 中，不作为源码提交。

## F-01～F-18 追踪

| ID | 本轮结论 | 对应实现与证据 |
|---|---|---|
| F-01 | 本地回归通过；远程部分未复验 | 三后端完整日志、原始单文件 E2E、legacy CLI/报告兼容测试 |
| F-02 | 通过 | workspace/manifest、reducer/project、package/manifest pass、真实多文件基准 |
| F-03 | 通过 | moon_syntax：UTF-8 字节 span、字符串/注释隔离、畸形输入回退测试 |
| F-04 | 通过 | 16 个结构 family，逐 pass 前置条件、风险和 fallback 文档 |
| F-05 | 通过 | bounded regex、crash、诊断/测试名指纹、wrapper、差分 native E2E |
| F-06 | 通过 | repeat/quorum/consecutive 三态；真实进程 4/5 匹配、baseline/final rate 0.8、重放 |
| F-07 | 通过 | schema-4 checkpoint、原子替换/部分写入/取消测试、native resume 和 0% 已知重复 |
| F-08 | 通过 | jobs=1/4 各十次原始 report 与统一目录哈希 |
| F-09 | 通过 | 九个确定性夹具全部 ≥50%，中位数 88.76% |
| F-10 | 通过 | 十个夹具全部满足 600 秒和 2500 次执行预算 |
| F-11 | 通过 | 十个 final 3/3 + 十个新副本 replay 3/3 |
| F-12 | 通过 | 492 场景、43 个标记 E2E、92.56% 核心覆盖率 |
| F-13 | 通过 | 越界/符号链接/UTF-8/输出限额/子进程树/超时取消/写入失败原工作区保护测试 |
| F-14 | 本地验证通过；远程 CI 待执行 | Windows/Linux 干净构建与安装日志；现有工作流留待用户推送 |
| F-15 | 通过 | [公共 API diff](api-changes.diff)、[审查记录](review.md)、版本化 schema 与篡改拒绝测试 |
| F-16 | 通过 | 中英文 README、12 示例、项目/语法/predicate/checkpoint/安全/API/测试/报告/基准/兼容文档 |
| F-17 | 按用户修改后的范围完成 | Apache-2.0、THIRD_PARTY.md、夹具 LICENSE；按明确要求不恢复开发披露文件 |
| F-18 | 未执行 | 不 push、不发布 mooncakes/GitHub；正式发布和远程安装由后续用户操作完成 |

## 失败记录与边界

- 最初 timeout 夹具使用 2 秒，进程虽然超时，但未及时输出指定标记，baseline 失败。改为 10 秒并限定 text:line-block 后完整缩减和重放通过。保留 [初次失败报告](failures/timeout-short-budget.json)，不是把 baseline 失败算作成功。
- Linux 首次环境遇到旧 SDK、离线 registry 和 Git archive 换行问题，已改为相同版本 SDK、离线缓存和固定 LF 生产源码；在 Windows 挂载盘上运行时还出现一次真实编译测试 final 0/3，保留 [失败日志](failures/linux-mounted-verify.log)。迁移干净源码和 SDK 到 Linux 原生文件系统后完整 492/492 通过，最终版本也独立复验通过。不保证高延迟挂载文件系统满足紧凑测试超时。
- Windows 版本收尾时出现一次超时清理错误，报告维持 ExecutionFailed 且原工作区不变，未把它当作匹配成功；见 [失败报告](failures/windows-timeout-cleanup-report.json)。旧错误格式只保留类型名，无法追溯该次清理错误的更细原因；现已保留具体 ProcessError 文本。单项复测、最终完整 Windows 回归均通过，不能据此声称所有机器上的进程清理不再可能超时。
- 结构层是约减扫描器，正则是有界子集，均非完整编译器/完整 PCRE。副本执行不是操作系统安全沙箱，只执行可信命令。证据 SHA-256 用于损坏检测而非来源认证。
- cache key 保存完整内容，checkpoint 上限 256 MiB。清缓存的 checkpoint/checksums 两文件更新若遇 I/O 故障会拒绝不一致证据；不会默默继续。Replay 的项目输入仍须包含至少一个 MoonBit 源文件。详见 docs/LIMITATIONS.md 与 docs/SECURITY_MODEL.md。

## 复核入口

在已安装对应工具链与依赖的仓库运行：

```powershell
./scripts/verify.ps1
./scripts/audit-final-evidence.ps1
moon build --target native --release cmd/main
./scripts/benchmark-final.ps1 -RunName fresh-final
./scripts/determinism-final.ps1
```

审计脚本仅复核已保存的证据，不把它等同于重新执行测试。基准与确定性复跑结果默认进入忽略的 `.moonreduce`。项目申报书与 goal.md 按 .gitignore 保持本地，不进入 Git 或推送内容。