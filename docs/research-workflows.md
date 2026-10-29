# 从拓扑结果到应用判断

0.20.6 增加四类 MoonBit 研究工作流。统计量、分割和来源映射在核心库计算；HTML 只负责离线显示。每个工作流都可单独运行，不要求已有批量项目。

```sh
moon build --target js
moon run --target js cmd/main -- reliability examples/reliability-points.json --out out-resampling
moon run --target js cmd/main -- reliability examples/reliability-band.json --out out-band
moon run --target js cmd/main -- signal-study examples/signal-change.json --out out-signal
moon run --target js cmd/main -- signal-csv examples/beijing-pm25/signal.csv examples/beijing-pm25/config.json --out out-measurement
moon run --target js cmd/main -- pores examples/pores-before.json --out out-pores
moon run --target js cmd/main -- pore-compare examples/pores-before.json examples/pores-after.json --out out-pore-change
moon run --target js cmd/main -- cohort examples/cohort-loops.json --out out-cohort
```

输出目录必须尚不存在，且父目录已存在。每份报告提供 `report.html`、`report.json`、`rows.csv`；有原始研究请求时另存 `study-request.json`。附表单独导出 CSV。报告包含原始配置、数据和参数，可以复制请求重新计算。

## 可靠性与敏感性

`kind=reliability` 的 `input` 为普通分析 JSON，支持以下 `mode`：

| 模式 | 作用 | 来源记录 |
| --- | --- | --- |
| `subsample_points`（默认） | 从点云无放回抽取不同大小的子集 | 每次抽样的原始点编号 |
| `bootstrap_points` | 有放回抽取点云，保留重复观测 | 每次抽样的原始点编号 |
| `block_series` | 从序列抽取连续块，拼接到原长度后嵌入 | 每个位置的原序列编号 |
| `jitter` | 对点坐标或 grid/volume/series 数值作有界均匀伪随机扰动 | 完整输入、种子、幅度和试验顺序 |
| `mean_band` | 独立样本的平均有限第一层景观同时置信带 | 全部分析请求与截断排除数 |

前四种模式可配置 `seed`（0–65535，默认 1）、`trials`（2–64，默认 16）、`dimension`（默认 1）、`thresholds`、`start`、`match_tolerance`。点云重采样另用 `sizes`，序列用 `block_length`，扰动用 `jitter`。种子驱动固定的 16 位 LCG，便于重放；它不用于置信带或穷举置换的数学保证。默认匹配容差是当前观察范围的 10%。

报告按每个截止尺度和样本量分别提供景观 RMS 变化、瓶颈距离、有限/截断区间的匹配重复率、31 个固定尺度处的 2.5%/50%/97.5% 经验分位数。截止存活类数量不等时距离为空。截断类仍受观察窗口限制，不能当成已知无限寿命类。重复率受区间匹配和容差影响，不能解释为特征真实的概率；经验分位包络不宣称覆盖率。块拼接产生人工接缝，其解释需要局部平稳依赖等条件。

### 有条件的正式置信带

`mode=mean_band` 使用 `inputs` 数组替代 `input`，必须显式写出 `assumption="iid_independent_samples"`。这些输入应是来自同一总体的独立、同分布采样单位，使用一致的测量和观察条件，不能直接把重叠窗口或同一样本的重采样当成独立样本。

共同范围为 `[start,end]`，所有输入的截止必须等于 `end`，所有过滤值不小于 `start`。每份数据只取在截止前已死亡的区间，对应第一层有限景观；这是明确的截断观察统计量，未估计被排除的长寿命特征。该景观在每个尺度处落在 `[0,R]`，其中 `R=(end-start)/2`。对 n 个独立同分布样本、31 个固定网格点，以置信度 `confidence`（默认 0.95）：

```text
epsilon = R * sqrt( log(62 / (1-confidence)) / (2*n) )
band(t) = [max(0, mean(t)-epsilon), min(R, mean(t)+epsilon)]
```

这是 Hoeffding 不等式和联合界给出的总体均值景观网格同时带。它不覆盖整条连续曲线，也不对应某一个区间的置信集。样本少时可能很宽；`epsilon>=R` 时标记 `vacuous=true`。算法能检查数据格式与观察条件，不能从数据本身证明独立同分布假设。

预算：点云重采样 2–128 点；1–8 个样本量及 1–8 个截止，总重复分析不超过 96 次、累计 64000 个细胞；块序列不超过 512 点。均值带支持 2–64 个输入、累计 64000 个细胞。单次分析仍遵守原有复形预算。

## 长信号变化分析

`kind=signal_study` 接收 8–8192 个 `values`（缺失写 null）和可选等长 `times`（严格递增；省略时为 0、1、2…）。CSV 入口默认读取 `time,value` 列，支持 `time_column,value_column`；空数值单元格作为缺失值，未选文本列原样留在 `csv_source` 中。

配置项：`window`（默认 32，8–128）、`hop`（默认半窗，1–window）、`baseline_windows`（默认 3，2–16）、`dimension`、`lag`、必填 `threshold`、`max_cells`、`normalization=none|baseline_zscore`、`detrend=none|linear`。最多 64 个窗口，必须保留基准之后的监测窗口，总细胞数不超过 64000。每个延迟嵌入至少产生三个点。

- 默认 `interpolation=reject`，拒绝缺失及不规则采样；容许步长的微小舍入误差，但保留原始时间戳。
- 显式 `interpolation=linear` 后，按 `grid_step`（默认首个时间差）生成均匀网格。只有相邻观测间距不超过 `max_gap`（默认三倍步长）时插值，不外推。每个位置记录左右原始行编号与右侧权重。
- 无法补齐的基准窗口报错；无法补齐的监测窗口列在 `invalid_windows`，不悄悄填零。基准插值也不能借用基准时段之后的观测。
- Z 分数偏移和缩放只用基准窗口覆盖的数据并集拟合；线性去趋势在各自窗口内完成并记录参数。改变未来数据不会改变拟合偏移、缩放与报警阈值。

每个窗口使用 31 个尺度的有限 H1 景观、最长已观察 H1 寿命和截止存活 H1 比例形成拓扑向量。向量对截止尺度归一。对照方法为原始数据的均值/RMS、自相关峰值绝对值、离散傅里叶正频率谱峰能量比例；频率单位是输入时间单位的倒数。谱指标是窗口内未加窗 DFT 的相对峰值，不是校准后的功率谱密度。

四种分数均与基准均值比较，阈值为基准留一距离的最大值乘 `threshold_factor`（默认 1.5，1–100），另设 1e-9 数值下限。这是探索性变化检测，不承诺误报率。重叠窗口有相关性。报告合并拓扑报警时间段，并保留逐窗口分数、嵌入点、代表边、原始网格映射、去趋势参数及普通分析 `request`。选中窗口可下载请求重算，并查看对应原始 CSV 行。

可选 `events=[[start,end],…]` 必须排序且不相交。监测窗口与事件重叠不少于自身时长一半时视为正例，按窗口报告四种方法的 TP/FP/FN、precision、recall，分母为零时为空。`events=[]` 表示已标注全部阴性；省略表示没有标签，不计算准确性。时间段评价不是逐点或事件级评价。

`signal-change.json` 是周期幅值变化的合成参考。当前预期结果：拓扑与均值/RMS 都是 TP=5、FP=1、FN=0；这不构成拓扑方法优于简单统计量的证据。真实测量示例来自 UCI Beijing PM2.5 的固定 128 小时子集，产生 15 个窗口、其中 1 个拓扑变化提示；它没有事件真值，不能据此报告准确率或判断污染原因。数据来源和改编步骤见 [数据说明](../examples/beijing-pm25/NOTICE.md)。

## 孔洞与材料体素定量

`kind=pores` 使用**体素中心值分割**，与原有 `kind=volume` 的**顶点 lower-star 复形**分别提供两种分析。此处不把 H2 区间直接视为孔洞标签。

`volume[z][y][x]` 的每个体素是一整个轴对齐长方体。`polarity=high` 默认以值 ≥ `threshold`（默认 0.5）作为孔隙；`low` 使用 ≤。`spacing=[sx,sy,sz]` 默认全 1，`origin` 是 (0,0,0) 体素的中心，默认全 0；`unit` 默认 voxel。物理单位需要来自数据的实际标定。

输出包括：

- 六面邻接的孔隙标签、孔隙率、体积、世界坐标质心、索引/物理包围盒。
- 接触裁剪边界的开放区域、完全封闭区域，以及 X/Y/Z 两端贯通标记。
- 实际固体界面面积与裁剪封口面积分别统计；它们是分割体素面的面积，不是光滑表面的估计。
- 每个体素中心到最近实际固体体素长方体的精确欧氏距离，支持各向异性间距。无观察到的固体时距离为空。
- 同时受固体和裁剪边界约束的内切球半径与中心，中心限制为体素中心，因此不是连续空间的全局最大内切球求解。
- 在 `radii` 指定的净空半径下重新检查中心采样路径的六邻接连通/贯通性。它使用已观察固体，不对裁剪外部作假设；没有观察固体时正半径结果标为 unavailable。
- `labels.json` 保存标签和几何；`pores.obj` 按标签分组导出物理坐标下的体素边界三角面。离线页支持标签筛选、Z 切片和表面旋转。

每轴 1–64 个体素，组件不超过 1024，最多八个净空半径。OBJ 不超过 20000 个四边形面（导出为 40000 个三角形）；超限时仍生成标签和完整数值报告，并写 `mesh-status.json` 说明未生成 OBJ。页面预览最多 5000 个面，有明确提示。间距范围 1e-6–1e6，输入 JSON 不超过 1 MB。

`pores-nifti INPUT.nii[.gz] CONFIG.json` 将 NIfTI 解析器的单帧值、正对角仿射间距、原点和空间单位传入分割。配置示例为 `examples/pores-nifti.json`。现有 NIfTI 解码预算为每轴 2–32、文件/解压后均 ≤1 MB。旋转、错切和翻转轴会明确拒绝，需先在外部重定向/重采样；未声明空间单位时保留 `NIfTI_unit_unspecified`，不猜测 mm。

`pore-compare` 的两个输入均为分割请求 JSON；两者必须已经配准到相同尺寸、间距、原点和单位。报告逐标签交集、IoU、可能分裂/合并、出现/消失标签与总孔隙体积变化；它不执行配准，不证明物理对象身份。示例中的两个独立孔隙加入桥接体素后合并，体积从 48 增到 72 um³。该示例是可核对几何的人工模型，未宣称真实材料实验或渗透率预测。

## 分组与配对比较

`kind=cohort` 接收 `samples=[{name,group,request},…]`，`group` 只用 A/B。CLI 也支持 `{name,group,input}`，文件必须在清单所在目录之下。`unit` 必填，样本应具有相同测量意义和单位，使用相同复形种类与观察截止。`dimension` 默认 1，`start` 默认 0，`end` 必填且不能超过截止。

- `preprocessing=none` 默认使用原坐标。`pooled_zscore` 仅限点云，在全部样本点上共同、组别盲地拟合 Z 分数，记录偏移/缩放，所有置换复用这套共同变换。不同样本点数会影响这个拟合，因此应在设计阶段声明采样方案。
- `design=independent` 默认穷举所有固定组大小的标签划分；每组 2–8 个独立采样单位，总数不超过 14。
- `design=paired` 按各组出现顺序将 A[i] 与 B[i] 配对，穷举组内标签翻转；2–8 对。各对之间应独立，零假设下对内标签应可交换。

使用共同 31 点网格的有限第一层景观。统计量为平均景观差的 RMS；两侧检验按绝对差计算。每个尺度报告原始 p，以及以该次排列全部尺度最大绝对差为参考的 max-statistic 校正 p。这里的整体校正保证以联合标签可交换的完整零假设为条件，不额外宣称任意部分零假设下的强家族错误率控制。所有排列包含观察划分，使用计数/排列总数，不套用蒙特卡洛加一公式。浮点相等比较使用全部景观数值最大绝对值的 1e-12 作为容差，并在结果中记录；这使容差随单位变换同比缩放。

输出样本景观、截断排除数、距组均值的描述性分数、完整分析与原始请求。离线页选择样本可回到原始坐标和出生代表边，定位差异线索；组内距离不代表因果贡献。最多累计 32000 个细胞，组别盲缩放最多汇集 10000 行/32 列。独立性、共同采样方案和标签交换性需要研究设计支持，工具不能自动验证。把同一个对象的多帧或重叠窗口作为独立个体会造成伪重复。

## 库接口与验证

公开接口：`reliability_study`、`signal_study`、`signal_csv_request`、`cohort_study`、`pore_study`、`pore_nifti_request`、`pore_compare`、`pore_surface_obj`、`research_html`、`research_csv`、`research_files`。分析入口返回 Json，资源/输入错误抛出 TopologyError；核心库可用 JS 和 Wasm GC，文件命令使用 Node.js。

```sh
moon test --target js
moon test --target wasm-gc
node scripts/research-cases.mjs
# 安装开发依赖和 Chromium 后：
node scripts/research-browser.mjs
```

`research_wbtest.mbt` 覆盖重采样重放、块内连续性、零扰动、置信带公式、可手算独立/配对置换、无未来数据泄漏、常量基准、缺失/插值、各向异性孔洞和 NIfTI 几何等。`research-cases.mjs` 另用正方形解析景观穷举统计参考分布，暴力最近长方体距离、OBJ 三角面积核对空间结果，并验证窗口独立重算、真实数据来源及失败时不创建输出目录。浏览器检查覆盖九份新增报告的桌面/窄屏、键盘、导出、代表边、切片、旋转、离线网络和 axe 规则；它不等同于所有辅助技术的人工审计。
