# MoonTopoLens · 月拓镜

[![CI](https://github.com/wdgodghl/moontopolens/actions/workflows/ci.yml/badge.svg)](https://github.com/wdgodghl/moontopolens/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**基于 MoonBit 的持续同调与数据拓扑分析工具箱。**

让点云、距离数据、时间序列和二维网格中的连接分量与环路变得可计算、可比较、可解释。
提供可复用库、命令行分析器、JSON/CSV 导出、SVG 图表与离线交互 HTML 报告。
核心算法由 MoonBit 实现，不调用 Python/C++ 拓扑库。

当前版本：**0.6.0 图像阈值与亮暗预处理版**。当前尚未发布到 Mooncakes；官网公开验收摘要未将其列为必需项，
正式章程的执行口径尚待确认。发布作为生态扩展计划，不阻碍当前开发。
已实现内容、验证证据与后续计划见 [验收记录](docs/acceptance.md)。
选题功能的落实情况与暂缓项见 [功能范围](docs/feature-scope.md)。

## 能做什么

| 输入/功能 | 实现 |
| --- | --- |
| 点云 | 1–32 维欧氏距离、Vietoris–Rips 过滤复形 |
| 距离/不相似度矩阵 | 校验对称非负矩阵，构建 Rips 2-骨架 |
| 二维网格 | 顶点值的 lower-star 方格复形，检测连接区域和洞 |
| 灰度图像 | 直接解析 PGM P2/P5，保留原始灰度并进入网格过滤复形 |
| 图像预处理 | 可选 Otsu 自动截止值与亮暗反转，记录可复现的实际参数 |
| 批量项目 | 从一个 JSON 清单分析多份输入并生成指定两两比较和总索引 |
| 时间序列 | 指定维数、滞后、步长的延迟嵌入，随后进行 Rips 分析 |
| 持续同调 | GF(2) 稀疏边界矩阵约化、H0/H1 区间、出生时的代表链 |
| 比较与特征 | 精确瓶颈距离、Betti 数与曲线、寿命排名/筛选、有限区间持续熵 |
| 尺度与向量 | 精确 Betti 事件、指定尺度的连通分组、持久景观采样与特征向量 |
| 解释与演示 | 区间最优匹配明细、离线双图对比、分组着色的尺度 SVG、存活代表链高亮 |
| 输出 | 完整 JSON、区间/曲线 CSV、SVG 条形码/持续图、离线 HTML 报告 |

H0 对应连接分量，H1 对应闭合环路。长寿命特征在较多尺度存在，
可以作为进一步分析的线索；其物理意义需要结合输入数据判断。

## 安装与运行

需要 [MoonBit 官方工具链](https://docs.moonbitlang.com/en/latest/toolchain/moon/tutorial.html)，
**moonc ≥ 0.10.14**，以及 Node.js 22（命令行文件读写）。
本地验证版本为 moonc `0.10.14+7d59c7ec9`、moon `0.1.20260920`。
核心库不依赖第三方 Mooncakes 包。

```sh
git clone https://github.com/wdgodghl/moontopolens.git
cd moontopolens
moon version --all
moon check --target js
moon build --target js
moon test --target js
moon run --target js cmd/demo
```

库与纯 MoonBit 演示也支持 WebAssembly GC：

```sh
moon check --target wasm-gc
moon build --target wasm-gc
moon test --target wasm-gc
moon run --target wasm-gc cmd/demo
```

命令行文件操作适配器目前仅支持 JS/Node。未发布前请从本仓库运行；
`moon add wdgodghl/moontopolens` 将在 Mooncakes 发布成功后可用。

## 三个完整使用场景

### 1. 识别点云环路并比较形状变化

输入四个正方形顶点，计算多尺度拓扑并导出图表：

```sh
moon run --target js cmd/main -- analyze examples/square.json --out out-square
moon run --target js cmd/main -- compare examples/square.json examples/rectangle.json
moon run --target js cmd/main -- summary examples/square.json
```

正方形的 H1 环路在边长 `1` 出生，在对角线 `√2` 消失。
比较输出 H0/H1 的瓶颈距离，量化区间集合的变化。
`examples/clusters.json` 则在截止尺度 `0.5` 保留两个连接分量。

### 2. 从采样信号提取周期结构

对重复 `[0, 1, 0, -1]` 信号进行二维、滞后 1 的延迟嵌入：

```sh
moon run --target js cmd/main -- analyze examples/periodic-series.json --out out-series
```

嵌入得到菱形顶点；尺度 `1.5` 有一个 H1 环路，到尺度 `2` 被填充。
可修改输入信号、lag 和 stride，比较周期结构在所选参数下的变化。
本工具不自动推断周期，也不输出诊断结论。

### 3. 检测二值图案中的洞及填充过程

3×3 网格外围值为 0、中心值为 1：

```sh
moon run --target js cmd/main -- analyze examples/ring-grid.json --out out-grid
```

尺度 `0` 形成一个洞；尺度 `1` 中心进入并填充该洞，对应 H1 区间 `[0,1)`。
适用于小型图案、占据网格和教学数据。采用顶点 lower-star 与四方向相邻约定，
不等同于所有图像库的像素连接规则。

`examples/two-holes-grid.json` 包含两个洞，可以在 HTML 报告中分别选择其代表环路：

```sh
moon run --target js cmd/main -- analyze examples/two-holes-grid.json --out out-two-holes
```

输出目录必须尚不存在，且父目录已存在。每次分析保存：

- `report.json`：所有区间、细胞、边界、代表链与约化统计。
- `barcode.svg`：最多显示前 80 个区间；完整数据保留在 JSON 中。
- `diagram.svg`：出生/死亡散点图；顶部表示在输入截止处仍存在的类。
- `intervals.csv`：所有区间、死亡状态、观察寿命和代表细胞索引。
- `betti.csv`：101 个尺度上的 H0/H1，包含截止尺度。
- `betti-events.csv`：全部出生/死亡尺度的精确 H0/H1，合并同尺度事件。
- `report.html`：可离线打开的完整交互报告。

### 离线报告怎么用

直接用浏览器打开输出目录中的 `report.html`，无需服务器或网络：

1. 拖动尺度滑块，观察当前 H0/H1 数量、进入复形的顶点和边。
2. 选择维度、最小观察寿命或“仅当前存活”，筛选并查看区间排名。
3. 点击区间编号，在该环路存活的尺度上查看橙色代表边。
4. 查看 Betti 曲线，或将 CSV 导入表格/绘图工具继续分析。

绘图坐标不参与同调计算：高维点云保留原维度距离，仅前两个坐标用于展示。
一维点云投影到横轴；网格使用 `(列,-行)`；距离矩阵没有几何坐标时显示说明。
图中未绘制二维填充细胞，应结合 H1 数字判断环路是否已死亡。
HTML 表格最多显示筛选后的前 200 行，JSON 和 CSV 保留全部区间。

`summary` 命令只精简输出，计算过程与 `analyze` 相同。
比较命令额外记录双方截止尺度和复形类型是否一致，供判断结果的可比性。

### 0.3.0：尺度快照与持久景观

查看指定尺度有哪些分组、多少细胞和环路：

```sh
moon run --target js cmd/main -- slice examples/square.json 1
moon run --target js cmd/main -- slice examples/clusters.json 0.5
```

快照包含 H0/H1、各维度活跃细胞数、连通分组的原始顶点编号和存活区间索引。
正方形在尺度 `1` 为一个分组、一个环路；分离簇在 `0.5` 为两个分组。
允许查询首个细胞出现之前的空快照；超出输入截止尺度返回错误。
原始网格编号为 `行×列数+列`，不会把未进入的顶点重新编号。

把有限区间转换成持久景观向量，便于后续统计分析：

```sh
moon run --target js cmd/main -- landscape examples/two-holes-grid.json 1 0 1 --out out-landscape
```

参数依次为输入、同调维度、采样起点和终点；输出目录可省略，仅向标准输出打印 JSON。
CLI 固定 101 个采样点、3 层，保存 `landscape.json` 和 `landscape.csv`。
两个 `[0,1)` 的洞在尺度 `0.5` 对应前两层各 `0.5`，第三层为 `0`。
JSON 同时提供采样网格、分层值和长度 303 的按层拼接向量。
库 API 可自定义采样点数和层数。这里使用原始三角帐篷高度，不缩放或归一化；
截止时仍未死亡的区间明确排除并记录数量，不能将截止当作死亡值。
比较向量必须使用一致维度、采样范围、点数、层数、尺度单位和可比的截断条件。
这些是采样特征，不代表已经实现分类器。

HTML 曲线现在使用精确事件，保留短暂环路；`betti.csv` 仍供均匀采样分析。
`examples/short-loop-grid.json` 的 H1 仅在 `[0.004,0.005)` 存活：
101 点的均匀采样全部为 0，事件 CSV 和 HTML 曲线仍保留该环路。

### 0.4.0：解释比较结果并导出尺度图

```sh
moon run --target js cmd/main -- compare examples/square.json examples/rectangle.json --out out-comparison
moon run --target js cmd/main -- slice examples/clusters.json 0.5 --out out-clusters-slice
moon run --target js cmd/main -- slice examples/square.json 1 --out out-loop-slice --interval 4
```

正方形默认分析中，区间 `#4` 是 H1 环路；自定义输入的编号应从其 `report.json` 或 `slice` 的存活区间列表获取。
`--interval` 必须位于 `--out` 之后，且所选类必须是当前尺度仍存活的 H1。
无效选择在创建输出目录前报错，不留下伪完整的结果。

比较输出五个文件：`comparison.json`、`matches.csv`、`comparison.html`、
`left-diagram.svg`、`right-diagram.svg`。直接打开 HTML 可看双侧持续图、距离、
截止条件提示及可按维度/对角线筛选的匹配表。表格最多显示 200 行，CSV/JSON 保留完整匹配。
比较命令原有 JSON 字段保留，新增匹配与摘要字段。

匹配明细使用左右原始区间编号，区分有限配对、对角线配对、截止仍存活配对及未匹配存活类。
这是瓶颈距离的一种最优匹配，可能不唯一；不保证最小总代价，也不代表真实对象身份对应。
对角线代价为有限寿命的一半；未匹配存活类代价为空，完整距离为 `null`。
不能将截止条件不同造成的差异直接解释为数据结构变化。

尺度导出保存 `slice.json`；有坐标时还保存 `slice.svg`。
SVG 顶点按 MoonBit 算出的连通分组着色，保留原始编号；七种颜色循环使用。
选中的存活 H1 出生代表链使用橙色边。投影保持横纵等比例，未绘制二维填充。
距离矩阵和空坐标输入只输出 JSON；不虚构几何位置。

### 0.5.0：直接读取 PGM 图像与批量分析

直接分析纯文本 P2 或二进制 P5 PGM 灰度图：

```sh
moon run --target js cmd/main -- image examples/ring-image.pgm 1 --out out-ring-image
```

`CUTOFF` 是原始像素值尺度；默认不反色、不归一化。示例外围为 0、中心为 1，
在尺度 0 有一个 H1 洞，在尺度 1 消失。输出与网格分析相同的七个报告文件，
另有 `image-info.json` 记录 PGM 编码、尺寸、最大灰度和截止值。
支持 P2/P5、8 位及 16 位 P5；16 位样本按大端读取。
当前只读取单幅、最大 64×64 且不超过 1 MB 的 PGM；PNG/JPEG 尚未支持。
格式遵循 [Netpbm PGM 规范](https://netpbm.sourceforge.net/doc/pgm.html) 的单图像子集。

一次运行多份输入与指定比较：

```sh
moon run --target js cmd/main -- batch examples/batch-study.json --out out-study
```

清单中的 `cases` 包含 `name`、相对于清单所在目录的 `input`；
PGM 案例还需 `"format":"pgm"` 和数值或 `"auto"` 的 `threshold`，JSON 案例的格式默认是 `json`。
可选的 `comparisons` 数组用 `name`、`left`、`right` 引用案例名。
示例比较正方形与矩形，并核对 PGM 导入与等价 JSON 网格的结果。
`out-study/batch.json` 是汇总索引；`cases/<名称>/` 保存每份完整分析，
`comparisons/<名称>/` 保存比较 JSON、匹配 CSV、离线 HTML 和两侧持续图。
案例名只接受 ASCII 字母、数字、`-`、`_`。清单最多 8 个案例、12 个比较，
合计最多 16000 个过滤细胞。输入路径限于清单所在目录及子目录；
所有输入和比较先完成计算，再创建全新的输出目录。

### 0.6.0：自动阈值与亮色前景

若图像前景是亮色，可先反转灰度；若没有预先选定的截止值，可用 `auto`：

```sh
moon run --target js cmd/main -- image examples/bright-ring.pgm auto --invert --out out-bright-ring
```

反转按 `max_value - 原像素值` 计算，然后在处理后的灰度图上使用 Otsu 类间方差选择截止值。
亮环示例因此在截止值 `0` 出现一个 H1 洞。`image-info.json` 记录最终 `cutoff`、
`cutoff_mode` 和 `inverted`，便于复现。常量图的自动截止值是该图唯一灰度。
自动阈值只是直方图分割启发式，不保证给出拓扑上最有意义的尺度；
跨图比较应使用可比的灰度尺度和截止条件。

批量清单中的 PGM 案例也可写为
`{"format":"pgm","threshold":"auto","invert":true}`。
`examples/batch-study.json` 同时演示手动与自动阈值，并以等价 JSON 网格核对结果。

## 自定义输入

```json
{
  "kind": "points",
  "threshold": 2,
  "max_cells": 4000,
  "points": [[0, 0], [1, 0], [1, 1], [0, 1]]
}
```

`kind` 支持 `points` / `matrix` / `grid` / `series`，对应数据字段同名。
`threshold` 必填；`max_cells` 默认 4000。
`series` 可指定 `dimension`（默认 2）、`lag`（默认 1）、`stride`（默认 1）。
未知字段、非法形状、非有限值和超出预算的输入会返回错误，CLI 退出码为 2。
全部格式见 [examples](examples)。

## MoonBit 库用法

包导入（发布后，或通过本地路径依赖）：

```text
import {
  "wdgodghl/moontopolens" @topo,
}
```

```moonbit
let points = [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]
let filtration = @topo.rips(points, threshold=2.0)
let analysis = @topo.analyze(filtration)
let loops = @topo.betti(analysis, 1, 1.0) // 1
let finite_diagram = @topo.diagram(analysis, 1)
let json = @topo.report_json(analysis)
let strongest = @topo.ranked_intervals(analysis, dimension=1, min_lifetime=0.1)
let summary = @topo.summary_json(analysis)
let html = @topo.html_report(analysis)
let events = @topo.betti_events(analysis)
let groups = @topo.connected_components(analysis, 1.0)
let snapshot = @topo.snapshot_json(analysis, 1.0)
let landscape = @topo.persistence_landscape(
  analysis, dimension=1, start=0.0, end=2.0, samples=101, layers=3,
)
let matching = @topo.interval_matching(analysis, analysis, dimension=1)
let comparison = @topo.comparison_json(analysis, analysis)
let scale_picture = @topo.scale_svg(analysis, scale=1.0)
```

调用者需要处理 `TopologyError`。公开 API 见 [pkg.generated.mbti](pkg.generated.mbti)，
可运行库样例见 [cmd/demo/main.mbt](cmd/demo/main.mbt)。

## 算法约定与边界

- Rips 使用**直径约定**：距离 d 的边在 d 出现，无半径除二。
- 矩阵要求严格对称、对角线为零；无需满足三角不等式，不偷偷修正输入。
- 计算系数域为 GF(2)，实现 H0/H1，不宣称完整 H2 或整数同调。
- `death: null` 表示在**输入截止处仍存在**，不能据此证明在完整过滤中无限存活。
- 区间为 `[birth,death)`，默认省略零长度区间；代表环路在出生时有效，不保证最短。
- 比较包含有限区间和未死亡区间；后者数量不等时结果为 null。
  输入的尺度、单位与截止条件应具有可比性。
- 点云/矩阵最多 128 个点，维度最多 32；网格最多 64×64；有限图匹配各最多 64 个区间。
- 最大细胞数默认 4000、硬上限 10000；约化默认最多 2,000,000 次列加法，
  存储最多 2,000,000 个稀疏条目。Rips 三角形数量可快速增长，超过预算时明确报错。
- 持续熵仅统计有限区间，使用自然对数；无正寿命有限区间时约定为 0。
  未死亡类的观察寿命为 `cutoff-birth` 下界，不能当作完整寿命。
- 持久景观限 2–1001 个采样点、1–16 层，并限制 `有限区间数×采样点数×层数 ≤ 2,000,000`。
  连通分组要求零细胞/边保留一/两个原始顶点 ID；不支持缺失该编码的自定义过滤。
- 只处理小规模内存数据，未做大数据性能承诺；完整 H2、最短环路和在线上传应用仍属后续计划。

算法结构与正确性说明见 [architecture](docs/architecture.md)。

## 测试与持续集成

```sh
moon fmt --check
moon check --target js
moon check --target wasm-gc
moon build --target js
moon build --target wasm-gc
moon coverage clean
moon test --target js --enable-coverage
moon test --target wasm-gc
moon coverage report -f summary
node scripts/check-source.mjs
node scripts/smoke.mjs
moon package --list
```

测试覆盖已知形状、重复点、截止语义、稀疏预算、无效输入、网格与嵌入、导出与比较。
JS 与 Wasm GC 各 47 个测试通过，另有 CLI 端到端验证。
另外使用独立的稠密行消元算法核对 12 个点云在 11 个尺度的 Betti 数，
使用穷举匹配核对瓶颈距离。CI 包含类型检查、构建、两种后端测试、覆盖率摘要和八个 CLI 场景。
每个示例在全部 Betti 事件处验证快照分组数，持久景观用已知帐篷函数核对。
匹配见证在 12 对形状中检查每个区间恰好出现一次、代价符合公式、最大代价等于瓶颈距离。
另有三组离线对比报告、尺度 SVG、存活选择/无坐标/输出冲突的端到端验证。
生成的 HTML 通过 DOM 替身检查滑块、筛选、选中环路与显示数值；该方法不验证真实浏览器视觉布局。

## 项目来源与许可证

选题公开查重记录见 [duplicate-review](docs/duplicate-review.md)。
算法依据计算拓扑公开研究，当前源码为独立 MoonBit 实现；
未复制或移植 Ripser/GUDHI 源码。采用 OSI 认可的 [MIT](LICENSE) 许可证。

使用了 AI 辅助设计与实现。参赛者需理解尺度约定、约化步骤、测试方法和限制，
并对提交成果负责。发布步骤见 [release](docs/release.md)。
