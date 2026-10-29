# MoonTopoLens · 月拓镜

[![CI](https://github.com/wdgodghl/moontopolens/actions/workflows/ci.yml/badge.svg)](https://github.com/wdgodghl/moontopolens/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**基于 MoonBit 的持续同调与数据拓扑分析工具箱。**

让点云、距离数据、时间序列、二维网格和三维体素中的连接分量、环路与空腔变得可计算、可比较、可解释。
提供可复用库、命令行分析器、JSON/CSV 导出、SVG 图表与离线交互 HTML 报告。
核心算法由 MoonBit 实现，不调用 Python/C++ 拓扑库。

当前版本：**0.20.5 精确稀疏计算与分步教学版**。
分步教学、键盘操作、精确稀疏点云与最短同调代表链见 [功能与保证](docs/exact-and-guided.md)。
Mooncakes 模块：[wdgodghl/moontopolens](https://mooncakes.io/docs/wdgodghl/moontopolens)。
已实现内容、验证证据与后续计划见 [验收记录](docs/acceptance.md)。
选题功能的落实情况与暂缓项见 [功能范围](docs/feature-scope.md)。
从表格数据到拓扑报告的完整流程见 [应用案例](docs/application-cases.md)。
选列、变换、原始数据追溯、三维旋转和统一批量特征见 [数据工作流](docs/data-workflows.md)。
无需代表环路时，可使用[仅区间模式](docs/reduction-modes.md)，查看两种模式的耗时和峰值内存对照。

```sh
moon run --target js cmd/main -- analyze examples/square.json --intervals-only --out out-intervals
node scripts/benchmark-modes.mjs
```

此模式保持区间结果，关闭代表链计算和高亮。资源预算及输入上限不变；实测存储项减少，但不保证所有输入都更快。

## 能做什么

| 输入/功能 | 实现 |
| --- | --- |
| 点云 | 1–32 维欧氏距离、Vietoris–Rips 过滤复形；可选 H2、确定性近似采样及三维旋转 |
| CSV 导入 | 显式选列、可选 Z 分数或 min-max 变换、单列信号与原始数据追溯 |
| 距离/不相似度矩阵 | 校验对称非负矩阵，构建 Rips 2-骨架或 H2 所需的 3-骨架 |
| 二维网格 | 顶点值的 lower-star 方格复形，检测连接区域和洞 |
| 三维体素 | 小型三维顶点网格的 lower-star 立方复形，分析 H0/H1/H2，浏览可旋转的代表面与联动 Z 层切片 |
| 灰度图像 | PGM P2/P5 或 8 位 PNG 灰度/RGB/RGBA，经灰度转换后进入网格过滤复形 |
| 图像预处理 | 可选 Otsu 自动截止值与亮暗反转，记录可复现的实际参数 |
| 批量项目 | 多份输入、指定比较及总索引；可在共同网格上导出 Betti、熵和景观特征表 |
| 全对比较 | 可选 H0/H1 与已计算的 H2 距离方阵、CSV、离线热图和单链接层次分组，提示比较条件不一致 |
| 时间序列 | 指定维数、滞后、步长的延迟嵌入，随后进行 Rips 分析 |
| 参数敏感性 | 同一时间序列扫描多组维数/滞后值，导出环路摘要、对齐的景观向量和候选排序 |
| 滞后参考值 | 对原始时间序列计算逐滞后自相关与分箱互信息，提示首次自相关降至 1/e 和首次互信息局部极小值 |
| 多帧拓扑追踪 | 按顺序分析多组点云，比较相邻帧的 H0/H1，按区间匹配串联 H1 观察轨迹，离线查看时间线和变化图 |
| 稳定性分析 | 对点云做确定性有界扰动，比较 H0/H1 距离和 H1 匹配保留情况 |
| 持续同调 | GF(2) 稀疏边界矩阵约化、H0/H1 区间与可选 H2 区间、出生时的代表链 |
| 比较与特征 | 精确瓶颈距离、Betti 数与曲线、寿命排名/筛选、有限区间持续熵 |
| 尺度与向量 | 精确 Betti 事件、指定尺度的连通分组、持久景观采样与特征向量 |
| 观察尺度推荐 | 按 H1 已观察寿命挑选区间内尺度；无环路时可提示合并前分组尺度 |
| 解释与演示 | 区间最优匹配明细、离线双图对比、分组着色的尺度 SVG、网格填充、存活代表链高亮 |
| 输出 | 完整 JSON、区间/曲线 CSV、SVG 条形码/持续图、分析与研究用离线 HTML 报告 |
| 可复现验证 | GUDHI Rips 与方格复形外部区间对照、稠密与稀疏输入的耗时和进程内存基准 |

H0 对应连接分量，H1 对应闭合环路。长寿命特征在较多尺度存在，
可以作为进一步分析的线索；其物理意义需要结合输入数据判断。

### 较大点云的显式近似分析

```sh
moon run --target js cmd/main -- points-sample examples/square.json 3 --out out-sampled
moon run --target js cmd/main -- csv-points examples/iris/subset.csv 1.2 --sample 16 --out out-sampled-csv
```

采样入口接受最多 10000 点、1–32 维，选取 1–128 点；受 4000 万坐标距离更新预算约束。
使用从原始编号 0 开始的最远点采样，距离并列时选择较小编号。点数不超过采样量时保留全部点和顺序。
CSV 按先选列、再变换、最后采样执行。结果记录原始编号、点数和分析坐标中的覆盖半径；半径不是持久图误差保证。
`points-sample` 导出 `sample-request.json` 与 `sampling-info.json`；CSV 的对应信息保存在 `csv-info.json`。
报告显式标注近似分析。精确 Rips 的细胞预算保持不变，采样后仍可能因截止尺度过大而超预算。

### 精确稀疏点云与教学

```sh
moon run --target js cmd/main -- analyze examples/large-circle.json --out out-exact
moon run --target js cmd/main -- shortest examples/square.json 4 --out out-shortest
```

1024 点圆环示例不采样，截止 0.007 时 H0=1、H1=1。打开报告的“开始分步教学”即可跟随五步观察并完成计数测验。
CSV 可用 `--engine sparse --max-cells 10000`。精确稀疏入口最多 8192 点，旧点云/矩阵入口仍最多 128 点；稠密输入仍可能超预算。
`shortest` 精确最小化所选 H1 类在出生尺度的边数；候选可能包含多个连通部分，不是最小欧氏周长。
独立二维边界秩最多 20，并设状态和工作预算；超限明确报错，不冒充最优。
报告增加键盘入口、重绘焦点保持和可滚动区域，九类报告接受键盘、语义树和 axe 自动检查。

## 安装与运行

需要 [MoonBit 官方工具链](https://docs.moonbitlang.com/en/latest/toolchain/moon/tutorial.html)，
**moonc ≥ 0.10.14**，以及 Node.js 22（命令行文件读写）。
本地及主 CI 固定使用 moonc `0.10.14+7d59c7ec9`、moon `0.1.20260920`。
为复现格式检查，Linux/macOS 可用官方安装命令 `curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash -s 0.10.14+7d59c7ec9`。
CI 另用当前官方稳定工具链执行双后端检查、构建和测试。
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

命令行文件操作适配器目前仅支持 JS/Node。也可以在自己的 MoonBit 项目中运行
`moon add wdgodghl/moontopolens` 引入已发布的核心库。

## 三个完整使用场景

### 从自己的 CSV 开始

```sh
moon run --target js cmd/main -- csv-preview examples/square.csv
moon run --target js cmd/main -- csv-points examples/square.csv 2 --out out-csv-square
moon run --target js cmd/main -- csv-series examples/periodic-series.csv 2 2 1 1 --out out-csv-signal
```

CSV 必须有唯一非空表头。默认所有列必须为数值；使用 `--columns` 可按列名选择并排序特征，未选列可包含文本。时间序列必须选取一列。
序列参数依次是截止值、嵌入维数、滞后、步长。不自动去重或插值；`--normalize zscore` 使用总体标准差，`--normalize minmax` 映射到 [0,1]，默认 `none`。常量列在变换后为零。
`csv-preview` 默认要求全数值，也支持 `--columns` 预览选中的数值列。标准化参数仅从当前输入计算，跨样本比较时必须保证变换规则与尺度可比。

```sh
moon run --target js cmd/main -- csv-points examples/iris/subset.csv 1.2 --columns petal_length_cm,petal_width_cm --normalize zscore --out out-selected
```

请按实际表头指定列名。预览显示列名、行列数及前五行；完整分析额外保存 `csv-info.json` 和 `csv-request.json`。
后者可直接用于既有 `slice`、`compare` 等命令。格式、限制及真实 Iris 测量数据案例见 [应用案例](docs/application-cases.md)。

```sh
moon build --target js
node scripts/application-cases.mjs
```

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

如需先挑选参数扫描的滞后范围，可计算原始序列的探索性参考值：

```sh
moon run --target js cmd/main -- lag-hints examples/periodic-lag-hints.json --out out-lag-hints
```

输出 `lag-hints.json` 和 `lag-hints.csv`，每个滞后值包含配对样本数、Pearson 自相关与分箱互信息（自然对数单位）。
建议采用首次自相关不高于 `1/e` 及首次互信息严格局部极小值；不存在时保留空建议，不伪造最佳值。
`max_lag` 默认不超过 32 且不超过样本数一半，`bins` 默认 8；分别可设 2–128 和 2–32。
互信息使用整条序列上的固定等宽分箱；边界、样本量和分箱数都会影响估计，应将提示用作 `sweep` 的起点。

### 追踪连续帧中的环路变化

把按时间排列的点云直接写入一个 JSON 文件：

```sh
moon run --target js cmd/main -- sequence examples/evolving-loop.json --out out-evolving-loop
```

示例依次包含正方形、略放大的正方形和三角形。前两帧各有一个有限 H1 环路，
其持久图区间被匹配为同一条轨迹；第三帧没有对应环路。输出包括逐帧摘要、
相邻帧 H0/H1 瓶颈距离、H1 轨迹的 `sequence.json`，三份 CSV 与可离线打开的 `sequence.html`。
报告中的轨迹时间线标出各帧匹配区间及观察寿命，变化条形图突出最大有限 H1 距离；
`null` 过渡会显示“不可比较”，不会冒充零变化。

输入限定 2–12 帧，每帧 3–64 点、相同坐标维数，并使用同一个截止尺度；
单帧和全序列仍受细胞预算约束。轨迹使用一种最优持久图匹配，可能不唯一，
不能证明不同帧中的真实对象身份相同。截止时未死亡类数量不同时，距离为 `null`；
CSV 留空，而不是当作零距离。

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
- `recommendations.json` / `recommendations.csv`：建议查看的尺度、依据、区间编号和该尺度 H0/H1。
- `report.html`：可离线打开的完整交互报告。

### 离线报告怎么用

直接用浏览器打开输出目录中的 `report.html`，无需服务器或网络：

1. 拖动尺度滑块，观察当前 H0/H1 数量、进入复形的顶点和边。
   也可输入精确尺度，或用“上一个事件 / 下一个事件”定位真实出生/死亡事件。
2. 选择维度、最小观察寿命或“仅当前存活”，筛选并逐页查看全部区间排名。
3. 点击区间编号，在该环路存活的尺度上查看橙色代表边。
   选择当前未存活的 H1 区间会自动切到出生尺度，并显示选择说明。
4. 查看 Betti 曲线，或将 CSV 导入表格/绘图工具继续分析。

高维点云使用全部维度计算距离；报告保留完整坐标，二维展示前两个坐标，也可用前三个坐标旋转查看三维投影。
一维点云投影到横轴；网格使用 `(列,-行)`；距离矩阵没有几何坐标时显示说明。
网格的已进入二维方格面以青绿色显示，可以观察洞的填充；Rips 点云的三角形不绘制，
应结合 H1 数字判断环路是否已死亡。HTML 表格每页显示 50 行，JSON 和 CSV 保留全部区间。

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
选中的存活 H1 出生代表链使用橙色边。投影保持横纵等比例；
网格中已进入的方格以青绿色填充，点云 Rips 三角形不绘制。
距离矩阵和空坐标输入只输出 JSON；不虚构几何位置。

### 0.5.0：直接读取 PGM 图像与批量分析

直接分析纯文本 P2 或二进制 P5 PGM 灰度图：

```sh
moon run --target js cmd/main -- image examples/ring-image.pgm 1 --out out-ring-image
```

`CUTOFF` 是原始像素值尺度；默认不反色、不归一化。示例外围为 0、中心为 1，
在尺度 0 有一个 H1 洞，在尺度 1 消失。输出与网格分析相同的报告文件，
另有 `image-info.json` 记录 PGM 编码、尺寸、最大灰度和截止值。
支持 P2/P5、8 位及 16 位 P5；16 位样本按大端读取。
PGM 和 PNG 均限定单幅、最大 64×64 且不超过 1 MB；JPEG 尚未支持。
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

### 0.7.0：批量全对距离热图

在批量清单顶层添加 `"all_pairs": true`，运行同一条 `batch` 命令即可为最多八个案例
计算全部无序案例对的 H0/H1 瓶颈距离。示例清单已启用：

```sh
moon run --target js cmd/main -- batch examples/batch-study.json --out out-study
```

输出新增 `distance-matrix.json`、`distance-h0.csv`、`distance-h1.csv` 和
`distance-heatmap.html`。HTML 可离线打开，行标题链接到各案例报告；
现有 `comparisons` 中具名配对仍各自生成详细匹配报告。
矩阵顺序与清单中的 `cases` 顺序相同，主对角线为 0、矩阵对称。
若两侧截止时存活的类数量不同，完整距离没有有限匹配，JSON 使用 `null`、
CSV 留空、热图显示“—”，不能解释为距离 0。

热图用橙框标出复形类型或截止值不同的案例对；即使两项相同，也仍须核对
尺度单位、灰度变换及数据含义。颜色仅在各自维度内部按有限距离缩放，
请用 CSV/JSON 数值比较。`all_pairs` 缺省为 `false`，保留旧清单行为。

### 0.8.0：推荐值得查看的尺度

```sh
moon run --target js cmd/main -- recommend examples/ring-grid.json
moon run --target js cmd/main -- recommend examples/clusters.json --out out-recommend-clusters
moon run --target js cmd/main -- slice examples/ring-grid.json 0.5 --out out-recommended-slice
```

第一个示例的 H1 在 `[0,1)` 存活，因此建议在 `0.5` 观察环路。
工具最多按已观察寿命排序列出五个 H1 区间的内部尺度，并附上最终截止尺度。
若没有 H1，但连接分量曾合并，还会给出一个精确的合并前 H0 事件尺度。
`recommendations.json` 提供原因代码、原始区间编号、实际尺度和该处 H0/H1；
`recommendations.csv` 便于表格处理。分析、图像和批量案例的输出目录也自动包含这两份文件。

原因 `h1_finite` 表示有限环路；`h1_alive_at_cutoff` 表示环路仍活到输入截止，
其已观察寿命仅是下界；`h0_before_merges` 表示更多分组尚未合并的事件尺度；
`final_cutoff` 用作最终状态基线。可将推荐尺度传给 `slice` 查看细胞与分组；
仅 H1 项的 `interval_index` 可用于 `slice --out ... --interval INDEX` 高亮代表链。
这些建议用于浏览，不是最优阈值，也不自动判断数据的实际含义。

### 0.9.0：检查时间序列嵌入参数的影响

```sh
moon run --target js cmd/main -- sweep examples/periodic-sweep.json --out out-periodic-sweep
```

输入中 `kind` 为 `series_sweep`，提供同一组 `series`、正数 `threshold`、
`dimensions` 和 `lags` 数组；`stride` 默认为 1，`max_cells` 默认为 4000。
工具分析维数与滞后值的所有组合，最多 12 组，且总细胞数不得超过 16000。
每组参数若使信号太短、嵌入超过 128 点或超过细胞预算，将明确报错。

`sweep.json` 记录每组嵌入点数、H1 有限区间和截止时存活区间数量、
最长已观察寿命、截止处 H1，以及 303 维持久景观向量；
`sweep-summary.csv` 便于比较摘要，`sweep-landscape.csv` 每行是一组参数的向量。
所有向量都在 `[0,threshold]` 上以相同的 101 个采样点和 3 层计算，
按层和尺度顺序排列；存活至截止的环路不进入向量，因此应同时查看其数量。
维数和滞后值可能改变嵌入点数，扫描结果只能说明敏感性，不能自动选出最佳参数或证明周期。

### 0.12.0：批量分组、稳定性、PNG 与 H2

```sh
moon run --target js cmd/main -- batch examples/batch-cluster-study.json --out out-clusters-study
moon run --target js cmd/main -- stability examples/square.json 0.02 --out out-stability
moon run --target js cmd/main -- sweep examples/periodic-sweep.json --out out-sweep-study
moon run --target js cmd/main -- image examples/ring-image.png auto --out out-png
moon run --target js cmd/main -- analyze examples/octahedron-h2.json --out out-h2
```

批量全对比较现在还生成 `cluster-h0/h1.json`、CSV 和 SVG 树图。
分组采用确定性的单链接算法，只连接同复形类型、同截止值且距离有限的案例；
无法比较的案例留在独立分组。`suggested_cut` 是最大相邻合并距离间隙的中点，
只提供探索用分组，并不代表统计显著性。`examples/batch-cluster-study.json` 演示两组相近形状。

`stability` 在每个坐标上加入不超过 ε 的可复现扰动，运行 8 次，输出各次 H0/H1
瓶颈距离及原 H1 区间在指定匹配容差下保留的次数。输入目前限不超过 24 个点；
`stability.html` 可离线查看，`stability.json` 保留完整数值。该次数不是概率或显著性结论。

`sweep.json` 现在给出最多三个 `recommended_parameters`，按有限 H1 最长寿命、
有限 H1 数量排序，只在用户提交的组合之间比较。`sweep.html` 将参数与候选理由集中展示；
它不会推断真实周期或保证最优嵌入维数。

PNG 输入支持非交错的 8 位灰度、灰度加透明度、RGB 和 RGBA；透明像素合成在白底，
RGB 使用亮度权重转换到 0–255 灰度。PNG 解码使用 Node 的 zlib 与有界输入适配，
拓扑及图像过滤复形仍由 MoonBit 计算。批量清单也可设 `"format":"png"`；
示例见 `examples/batch-png-study.json`。调色板、16 位和交错 PNG 会明确拒绝。

输入 JSON 对 `points`、`matrix` 或 `series` 设置 `"homology_dimension":2`，
即可建立 Rips 三维骨架并计算 H2 空腔；默认保持 H0/H1 的二维骨架以控制开销。
H2 在完整报告、区间、Betti CSV、SVG 和离线分析页中可见。
两份输入均计算 H2 时，`compare` 还会给出 H2 瓶颈距离和匹配明细；
批量全对矩阵、CSV、热图及单链接分组也支持 H2。若至少一侧未分析 H2，
对应 H2 矩阵单元为 `null`，`h2_analyzed` 标明各案例是否分析；若两侧均已分析但
截止时存活空腔数不同，同样为 `null`。八面体样例的 H2 为 `[1,2)`。
可运行完整示例：

```sh
moon run --target js cmd/main -- batch examples/batch-h2-study.json --out out-h2-study
```

输出包含 `distance-h2.csv`、`cluster-h2.json`、`cluster-h2.svg` 和具名比较中的
H2 匹配；截止值不同的案例会被标出，分组只使用条件一致且距离有限的案例对。
稀疏 Rips 构建使用邻接点枚举三角形和四面体，仍受 128 点与 10000 细胞的硬预算保护。

### 0.16.0：三维体素与空腔

`volume[z][y][x]` 提供采样顶点值；每条棱、每个方形面和每个立方体在所有角点进入后出现。
`volume` 默认计算 H0/H1/H2；0.16.0 的输入宽、高、深均为 2–12。细胞总数受
`max_cells` 默认 4000、最高 10000 的预算限制。

```sh
moon run --target js cmd/main -- analyze examples/hollow-volume.json --out out-hollow-volume
moon run --target js cmd/main -- slice examples/hollow-volume.json 0 --out out-volume-slice
moon run --target js cmd/main -- batch examples/batch-volume-study.json --out out-volume-batch
```

空心 3×3×3 示例的中心顶点值为 1，其余为 0：尺度 0 的完整三维复形有一个 H2 空腔；
尺度 1 中心进入并填充空腔，H2 区间为 `[0,1)`。
`out-hollow-volume/volume-slices.html` 可离线选择 Z 层和尺度，显示该层进入的采样顶点，
同时显示整个三维复形的 H0/H1/H2。普通 `report.html` 保留全部区间和 Betti 曲线。
`slice` 对体数据输出全复形的 JSON 快照，避免把重叠层投影成误导性的二维 SVG。
批量示例将空心体与实心体比较，H2 瓶颈距离为 0.5。
切片是采样顶点视图，不是医学影像空间渲染。NIfTI-1 的空间坐标作为独立元数据导出。

### 0.17.0：空腔解释、动态体数据与文件导入

体数据现在允许宽、高、深各 2–32，但仍受默认 4000、最高 10000 个过滤细胞限制。
较大的低尺度稀疏体数据可以分析；稠密体数据仍可能因预算明确报错。
`volume-surfaces.json` 导出 H2 出生时代表链的方形面、角点和对应区间；
`volume-slices.html` 可选中 H2 区间，橙色标出代表面经过的采样顶点。
代表链不是唯一或最短的物理空腔边界。

```sh
moon run --target js cmd/main -- analyze examples/hollow-volume.json --out out-hollow-017
moon run --target js cmd/main -- volume-sequence examples/volume-evolution.json --out out-evolution
moon run --target js cmd/main -- field-stability examples/hollow-volume.json 0.05 --out out-field-stability
moon run --target js cmd/main -- field-stability examples/ring-image.png 1 0.05 --out out-image-stability
moon run --target js cmd/main -- volume sample.nii.gz 1 --out out-nifti
```

`volume-sequence` 比较 2–8 帧同尺寸体数据，导出逐帧摘要、相邻 H0/H1/H2
瓶颈距离、H2 区间轨迹和离线 HTML。轨迹是一种最优持久图匹配，不能证明
物理空腔身份。`field-stability` 对顶点值或图像灰度值施加确定性有界扰动，
给出各维瓶颈距离及截止尺度 Betti 数；这不是置信区间。

`volume` 接受未压缩 `.nii` 和 gzip 压缩 `.nii.gz` 的 NIfTI-1 单文件、
单幅三维图像；支持小端/大端 uint8、int16、int32、float32，按头部线性
缩放读取。压缩前后均限制 1 MB；过滤分析仍由 MoonBit 实现。
格式定义参照 [NIfTI-1 官方说明](https://nifti.nimh.nih.gov/nifti-1/)；
项目未复制其参考实现代码。

### 0.18.0：时空元数据、代表面与有界粗网格

`volume-slices.html` 在 Z 层切片之外绘制可旋转的 H2 代表面投影。选择 H2 区间后，
点击面片或用键盘聚焦并按 Enter/空格，可以跳到相应切片。代表链由 MoonBit
在同一出生尺度内贪心加入高维细胞边界以缩短；它保留同调类，但不保证全局最短。
报告增加跳转链接、键盘焦点提示和状态播报。

`volume` 另外导出 `nifti-info.json`（sform/qform/pixdim 选用结果、体素到物理坐标
的仿射矩阵、单位代码、时间间隔）和 `volume-surfaces-world.json`（代表面角点的
物理坐标）。`volume-sequence` 可直接读取 2–8 帧的 4D `.nii` / `.nii.gz`，
并导出相同的时空元数据。拓扑仍在原体素网格上计算，不做空间重定向或重采样。

```sh
moon run --target js cmd/main -- volume sample.nii.gz 1 --out out-nifti
moon run --target js cmd/main -- volume-sequence study-4d.nii.gz 1 --out out-study
moon run --target js cmd/main -- volume-coarse dense-volume.json --out out-coarse
moon run --target js cmd/main -- volume-coarse dense.nii.gz 1 --out out-coarse-nifti
```

`volume-coarse` 是稠密数据超出细胞预算时的显式近似选项：选择满足预算的最小
步长，局部均值采样，再在粗网格上计算 H0/H1/H2；输出 `coarsening-info.json`
记录步长和 `approximate`。步长大于 1 的结果**不是原始分辨率的精确持续同调**，
可与普通 `volume` 命令的精确、小规模结果对照。每轴仍限 2–32，输入限 1 MB；
NIfTI-2、多文件 NIfTI 和超过 8 帧的时间序列暂不支持。

## 自定义输入

```json
{
  "kind": "points",
  "threshold": 2,
  "max_cells": 4000,
  "points": [[0, 0], [1, 0], [1, 1], [0, 1]]
}
```

普通分析的 `kind` 支持 `points` / `matrix` / `grid` / `volume` / `series`，对应数据字段同名。
`series_sweep` 是独立的扫描输入类型，只用于 `sweep` 命令。
`threshold` 必填；`max_cells` 默认 4000。
`series` 可指定 `dimension`（默认 2）、`lag`（默认 1）、`stride`（默认 1）。
未知字段、非法形状、非有限值和超出预算的输入会返回错误，CLI 退出码为 2。
全部格式见 [examples](examples)。

## MoonBit 库用法

包导入（先运行 `moon add wdgodghl/moontopolens@0.18.0`）：

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
参数扫描库入口为 `@topo.series_sweep(request_text)`，返回 JSON 报告、摘要 CSV 和景观向量 CSV。

## 算法约定与边界

- Rips 使用**直径约定**：距离 d 的边在 d 出现，无半径除二。
- 矩阵要求严格对称、对角线为零；无需满足三角不等式，不偷偷修正输入。
- 计算系数域为 GF(2)，通常默认分析 H0/H1；三维体数据默认分析 H0/H1/H2，Rips 显式构建三维骨架时也分析 H2。不支持整数同调。
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
  参数扫描固定 101 点、3 层；最多 12 组参数和 16000 个总细胞。
  连通分组要求零细胞/边保留一/两个原始顶点 ID；不支持缺失该编码的自定义过滤。
- 只处理有资源预算的内存数据。`points_sparse` 支持最多 8192 点的精确构建，仍受细胞和工作预算限制；`shortest` 在所选 H1 类的出生尺度最小化边数，超限报错。在线上传应用尚未提供。

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
node scripts/application-cases.mjs
python -m pip install numpy==2.3.5 gudhi==3.13.0
python scripts/reference_gudhi.py
node scripts/benchmark.mjs
moon package --list
```

外部对照先运行 `moon build --target js`，再用 GUDHI 3.13.0 独立计算
30 组 Rips 点云、距离矩阵、延迟嵌入和 cubical 网格/体数据的相应 H0/H1/H2 区间；CI 会执行这一检查。
基准使用确定性二维点云的稠密和稀疏分布，每组运行三次独立进程，报告 MoonBit 构造/约化的中位耗时与分析后的进程 RSS。
RSS 包含 Node 运行时且**不是峰值**；基准仅说明已测规模，不代表大规模性能承诺。
测试细节见 [外部对照](docs/reference-validation.md) 与 [性能记录](docs/performance.md)。

测试覆盖已知形状、重复点、截止语义、稀疏预算、无效输入、网格与嵌入、导出与比较。
JS 与 Wasm GC 的最新测试数量及结果见 [验收记录](docs/acceptance.md)，另有 CLI 端到端验证。
另外使用独立的稠密行消元算法核对 12 个点云在 11 个尺度的 Betti 数，
使用穷举匹配核对瓶颈距离。CI 包含类型检查、构建、两种后端测试、覆盖率摘要和 CLI 场景。
每个示例在全部 Betti 事件处验证快照分组数，持久景观用已知帐篷函数核对。
匹配见证在 12 对形状中检查每个区间恰好出现一次、代价符合公式、最大代价等于瓶颈距离。
另有三组离线对比报告、尺度 SVG、存活选择/无坐标/输出冲突的端到端验证。
生成的 HTML 通过 DOM 替身检查滑块、精确尺度、事件跳转、筛选、选中环路与显示数值。
分析报告另经真实浏览器在桌面与窄屏视口检查，范围及局限见 [浏览器验证](docs/browser-validation.md)。

## 项目来源与许可证

选题公开查重记录见 [duplicate-review](docs/duplicate-review.md)。
算法依据计算拓扑公开研究，当前源码为独立 MoonBit 实现；
未复制或移植 Ripser/GUDHI 源码。采用 OSI 认可的 [MIT](LICENSE) 许可证。
`examples/iris` 的改编数据另按 CC BY 4.0 授权，来源与改编范围见该目录的 NOTICE；数据授权与代码 MIT 许可分开说明。

本项目是独立实现的 MoonBit 原创作品。算法约定、验证方法和适用范围均在仓库中说明，
发布步骤见 [release](docs/release.md)。
