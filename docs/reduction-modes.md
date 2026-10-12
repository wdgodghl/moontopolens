# 完整模式与仅区间模式

默认模式继续计算出生代表链。只需要持续区间、Betti 数、距离或景观时，可关闭代表链换基计算：

```sh
moon run --target js cmd/main -- analyze examples/square.json --intervals-only --out out-square-intervals
node scripts/benchmark-modes.mjs
```

库调用使用 `analyze(filtration, representatives=false)` 或 `analyze_json(text, representatives=false)`。
JSON 请求也可添加 `"representatives": false`。CLI 开关优先关闭代表链；请求中的 `true` 不会覆盖 CLI 的关闭选择。

仅区间模式仍构造和约化相同过滤复形，保留出生/死亡值、原始细胞索引、截止语义与列加法预算。
不累计、异或或保存代表链矩阵，区间中的 `representative` 返回空数组。
`representatives_computed=false` 明确区分“未计算代表链”和“没有拓扑特征”。
`reduction_entries` 是保存的约化边界列加换基链的整数索引项数，不是字节数或进程内存。

Betti 数、瓶颈距离、景观、事件与普通 JSON/CSV/SVG 条形码导出可继续使用。
报告禁用代表区间选择按钮并显示原因；三维代表面及切片文件不生成。
`cycle_edges`、`simplify_representative` 和代表面导出接口对未计算的代表链报错，不伪造空代表。
分析结果仍保留过滤细胞与显示坐标；此模式不是流式算法，也不是仅包含区间的紧凑 JSON 格式。

## 对比基准

脚本使用 16/24/28/38 点稠密输入和 32/64/128 点稀疏输入，各模式三次独立 Node 进程运行，交替运行顺序。
稠密 38 点构建 9177 个细胞，基准显式使用 10000 细胞预算；常规请求仍默认 4000。
逐次核对 H0/H1 区间一致，分别记录核心耗时、分析后 RSS、进程峰值 RSS 和保存索引项数。
CI 只检查结果一致性与存储项减少，不对易受环境影响的耗时或 RSS 设置性能通过阈值。

峰值来源是 [Node process.resourceUsage().maxRSS](https://nodejs.org/api/process.html#processresourceusage)，
单位由 KiB 转为 MiB；不支持或返回零时汇总为 `null`。
它是到测量点为止的进程内存高水位，包含 Node 启动、运行时、输入构建与约化；不是拓扑算法单独分配的内存。
核心耗时只涵盖复形构建与约化，不包含启动或报告导出。

2026-10-12 Windows x64、Node v24.15.0、Ryzen 9 7845HX 的本地结果：

| 分布/点数 | 保存项数：完整 → 仅区间 | 核心耗时 ms：完整 → 仅区间 | 峰值 MiB：完整 → 仅区间 |
| --- | ---: | ---: | ---: |
| 稠密 16 | 1019 → 351 | 17.07 → 17.30 | 46.66 → 46.82 |
| 稠密 24 | 3080 → 809 | 35.69 → 38.87 | 52.61 → 52.15 |
| 稠密 28 | 4670 → 1111 | 49.74 → 50.42 | 55.00 → 55.19 |
| 稠密 38 | 9551 → 2086 | 75.81 → 77.59 | 67.40 → 66.09 |
| 稀疏 128 | 544 → 192 | 14.90 → 13.41 | 46.48 → 46.49 |

原始汇总见 `benchmarks/reduction-modes-20261012.json`。
稠密 38 点的保存项减少约 78.2%，但总体峰值仅减少约 1.3 MiB；其他样本的峰值与耗时有正负波动。
这些结果支持“减少代表链存储”，不支持“所有输入都更快”或“进程内存降低 78.2%”。
输入点数、细胞数和工作预算上限仍保持原有范围；后续规模优化需继续测量复形构建和边界约化的成本。

## 接口变化

0.20.0 为 `Analysis` 增加 `representatives_computed` 与 `reduction_entries` 字段。
通过分析函数获取结果的调用仍沿用默认完整行为；自行构造 `Analysis` 的调用需补充两个字段。
报告 JSON 增加同名字段，既有字段保留。
