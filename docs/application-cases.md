# 从 CSV 到可解释的拓扑报告

这些案例分别演示多维测量数据的连接结构、样本组的拓扑比较和信号延迟嵌入。
前两个使用公开真实测量数据；第三个使用明确标注的合成参考信号。

先执行 `moon build --target js`，然后运行：

```sh
node scripts/application-cases.mjs
```

输出到尚不存在的 `out-application-cases`；也可传入另一个新目录名。
脚本核对以下数值并生成 `case-results.json`，CI 会复跑同一流程。

## 1. 探索 Iris 测量数据的连接结构

数据取自 UCI Iris 的 `bezdekIris.data`，每个物种前 12 行，共 36 个样本。
输入包含萼片长/宽、花瓣长/宽，单位均为 cm，原始数值不做标准化。
[来源与 CC BY 4.0 授权](../examples/iris/NOTICE.md)及具体选择索引在仓库中保留。

```sh
moon run --target js cmd/main -- csv-preview examples/iris/subset.csv
moon run --target js cmd/main -- csv-points examples/iris/subset.csv 1.2 --out out-iris
moon run --target js cmd/main -- slice out-iris/csv-request.json 0.5
moon run --target js cmd/main -- slice out-iris/csv-request.json 1.2
```

预览显示 36 行、4 列。尺度 0.5 时 H0=18、H1=0；尺度 1.2 时 H0=2、H1=0。
含义是在四维欧氏距离阈值增大后，更多样本经邻接链连到一起。
两个连接分量不等于自动识别三个物种；H0 不提供分类准确率。
报告的几何图只画前两列，因此图上的邻近关系不能替代四维距离。

打开 `out-iris/report.html`，输入精确尺度或跳转出生/死亡事件，观察连接分量随尺度合并。
配套 `csv-request.json` 可以直接用于 `slice`、`compare`、`stability` 等既有命令。

## 2. 比较两组花卉测量的拓扑结构

```sh
moon run --target js cmd/main -- csv-points examples/iris/setosa.csv 1.2 --out out-setosa
moon run --target js cmd/main -- csv-points examples/iris/versicolor.csv 1.2 --out out-versicolor
moon run --target js cmd/main -- compare out-setosa/csv-request.json out-versicolor/csv-request.json --out out-species-comparison
```

在相同单位、维度和截止值下，H0 瓶颈距离约为 0.4123105626，H1 约为 0.0426472096。
打开 `comparison.html` 查看区间对应与对角线匹配。
这些数值描述所选样本的持续图区别，不是显著性检验，也不是物种判别概率。
当前两个样本组各有一个短寿命有限 H1；短环路可能与采样有关，不能仅凭它推断生物结构。

## 3. 用可控信号验证周期结构分析流程

```sh
moon run --target js cmd/main -- csv-preview examples/periodic-series.csv
moon run --target js cmd/main -- csv-series examples/periodic-series.csv 2 2 1 1 --out out-signal
```

此文件是 13 个合成样本，按 `[0,1,0,-1]` 重复并以 0 结束；不是设备实测数据。
参数依次为截止值 2、嵌入维数 2、滞后 1、步长 1。
延迟嵌入产生菱形顶点，H1 在 √2 出生、在 2 死亡。
用这个已知答案核对导入、参数与报告，然后将自己的单列测量信号替换进去。
工具不自动推断周期，真实信号还需结合采样率、单位、噪声和嵌入参数解释。

## CSV 格式约定

- 必须有表头，列名非空且不重复；点云每列都是数值，单列序列只接受一列数值。
- 支持 UTF-8 BOM、LF/CRLF、字段引号、表头中的逗号与双引号转义；忽略空白行。
- 数值采用 JSON 十进制/指数格式，例如 `-0.5`、`1.2e-3`；不接受 `NaN`、缺失值、类别列、千分位或多行字段。
- 最多 32 列、10000 行、字段 256 字符；CLI 文件最多 1 MB。点云与嵌入后的点数仍受 128 点上限及细胞预算约束。
- 使用 `--columns` 显式选列；默认不变换。可选择 `--normalize zscore|minmax`，变换参数与零起始数据行编号保存在 `csv-info.json`。不自动去重、插值或排序。
- `csv-preview` 输出列名、行列数及前五行；分析导出额外保存 `csv-info.json` 和可复现请求 `csv-request.json`。

## 0.20.6 研究流程

时间戳信号变化、真实 PM2.5 测量子集、物理孔隙定量与分组统计比较见 [研究工作流](research-workflows.md)。
运行 `node scripts/research-cases.mjs` 可生成完整报告，并核对解析置换分布、几何量和窗口回放。
