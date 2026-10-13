# 数据准备、追溯与批量特征

## CSV 选列与变换

```sh
moon run --target js cmd/main -- csv-preview examples/labelled-loop.csv --columns x,y,z
moon run --target js cmd/main -- csv-points examples/iris/subset.csv 1.2 --columns petal_length_cm,petal_width_cm --normalize zscore --out out-iris-scaled
```

选列按给定顺序执行，允许忽略文本标签列。列名必须存在且不重复；
默认不选列时仍严格要求全数值。当前命令用逗号分隔列名，包含逗号的列名请通过库 API 的数组传入。
选中的缺失值或非法数值直接报错，不自动填充、去重或重排数据行。

`none` 保持原值；`minmax` 使用最小值和极差；`zscore` 使用均值和总体标准差。
变换公式为 `(value-offset)/scale`，常量列采用其常量值作为偏移和 1 作为缩放，结果为零。
`none` 的偏移始终为 0，缩放始终为 1，常量列也保留原值。
`csv-info.json` 保存列名、变换参数、原始数据编号、实际分析点对应的原始数值。
不同样本各自标准化会改变距离含义，不能仅凭相同选项就认定结果可比较。

点云可以再加 `--sample SIZE`，规则见 [采样说明](point-sampling.md)。
时间序列只支持选择一列，不支持该采样选项；时间顺序和延迟窗口保持原有定义。
CSV 时间序列记录每个分析顶点的窗口数据编号和变换前窗口数值。
编号是去除表头和空白行后的零起始数据行编号，不是物理文件行号。

## 报告里的数据追溯与三维视图

可以用以下完整示例查看三维环路及其变换前数据：

```sh
moon run --target js cmd/main -- csv-points examples/labelled-loop.csv 2 --columns x,y,z --normalize minmax --out out-labelled-loop
```

选择区间后，“代表链对应的原始数据”列出组成代表链的分析顶点、原始编号和原值。
CSV 显示变换前数据，采样报告映射回完整输入编号；时间序列显示延迟窗口及其采样位置。
这些编号解释计算代表链，不证明物理对象身份，也不表示全局最短代表。
仅区间模式未计算代表链，追溯表不会显示。

三维及更高维点云可切换二维 XY 或三维旋转，通过水平和俯仰控件调整视角。
三维显示只使用前三个坐标，全部输入维度仍用于距离计算；不会投影降维后重新计算同调。
网格使用原有二维坐标，体数据继续使用专用切片页。
当前三维视图显示顶点、边和 H1 代表边，不绘制 Rips 三角形或四面体，也不是实体体渲染。

`Filtration.positions` 对 Rips 点云现在保留全部坐标（1 维补零到 2 维）。
使用该字段的调用方应接受 2–32 个坐标；二维 SVG 继续读取前两个坐标。
报告新增可选 `source`，不改变区间和细胞编号。
截止处仍存活的区间在报告中单独说明；有限持续熵和持久景观排除它们，Betti 数仍计入。

## 一张表导出多个样本

```sh
moon run --target js cmd/main -- batch examples/feature-study.json --out out-features --features 1 0 2
```

参数依次为同调维度、共同采样起点和终点。终点不得超过任何样本的截止尺度，
且所选维度必须在全部样本中已计算；错误在创建输出目录之前返回。
CLI 采用 101 个采样点、3 层景观，库 API 可明确设置采样数和层数。
原有批量命令不加 `--features` 时保持原来的输出。

新增 `features.json` 和 `features.csv`。每个样本一行，列包括案例名、复形类型、截止尺度、
被排除的存活区间数、有限持续熵、共同终点的 Betti 数、共同网格的 Betti 向量和景观向量。
景观按层优先、尺度递增排列。JSON 保存网格、完整列名及每个样本的向量。
熵采用该样本截止处之前的全部有限区间，不是采样范围内的截断熵。

复形类型与截止尺度不同时标记条件不同。类型和截止相同也不证明单位、预处理或采样相同，
这些条件需从输入来源判断。特征表不自动训练分类器。

## 可复现检查

```sh
moon build --target js
node scripts/data-pipeline.mjs
npm ci --ignore-scripts
npx playwright install chromium
npm run test:browser
```

数据流程检查包括选列、参数回放、512 点采样、16 点精确对照、批量向量与单独景观计算一致性，
以及非法范围不创建输出目录。真实 Chromium 在 1280×900 与 390×844 检查旋转、原始数据追溯、
短寿命环路事件、近似标记、仅区间模式、页面溢出与无网络请求；CI 重复运行。
目前没有 Firefox、Safari 或全部报告类型的视觉基准覆盖。
