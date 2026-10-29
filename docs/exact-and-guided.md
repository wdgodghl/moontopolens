# 精确分析与分步报告

## 分步教学

每份分析报告提供“开始分步教学”。五步依次读取输入、观察 H0 合并、定位 H1 出生、
观察死亡或截止、完成计数测验。步骤直接操作当前报告的尺度和区间，不使用预制动画替代计算结果。
没有 H1 时明确说明未检出；截止仍存活时解释截断语义；仅区间模式不会伪造代表链。
上一页、下一页、退出与测验按钮支持键盘操作，步骤标题与退出后焦点有明确落点。

```sh
moon run --target js cmd/main -- analyze examples/square.json --out out-lesson
```

打开 `out-lesson/report.html` 即可，无需服务器。测验答案由当前尺度的实际 Betti 数决定。

## 键盘与辅助技术

分析、比较、参数扫描、稳定性、点云序列、体数据序列、体素切片与距离热图报告共享跳转入口、
可见焦点、主内容地标及表格语义。溢出区域可以聚焦并用方向键滚动，区间选择重绘后保留焦点。
分析页通过状态区域播报尺度与 H0/H1/可选 H2；图表提供名称，详细数值另有表格与文本。
热图数字使用固定深色底，颜色编码不再影响文字对比度。静态热图仍无需脚本。

```sh
npm ci --ignore-scripts
npx playwright install chromium
npm run test:accessibility
```

自动检查固定使用 axe-core 4.14.0 的 WCAG 2.0/2.1 A/AA 规则，结合真实 Chromium 的
键盘操作与辅助技术语义树，在 1280×900 和 390×844 检查九类报告，并另测无环路、
截止存活和仅区间教学路径。这是指定流程的自动验证，不等同于完整 WCAG 认证，
也不宣称已经人工验证所有屏幕阅读器或浏览器组合。

## 大点集精确 Rips

新增 `rips_sparse` 库接口和 JSON `kind: "points_sparse"`。使用首坐标排序扫描、
距离提前终止和稀疏加权邻接表，不构造完整点对距离矩阵，也不选择子样本。
在同一截止尺度、同一骨架维度下，输出与普通 Rips 的细胞顺序和区间一致。
支持 H0/H1，以及显式 `homology_dimension: 2` 所需的三维骨架。

```sh
moon run --target js cmd/main -- analyze examples/large-circle.json --out out-large-circle
moon run --target js cmd/main -- csv-points INPUT.csv 1 --engine sparse --max-cells 10000 --out out-large-csv
```

`large-circle.json` 包含 1024 个等角单位圆点；截止 0.007 时 H0=1、H1=1，保留全部点。
稀疏入口最多 8192 点、32 维；细胞预算最高仍为 10000。JSON 默认细胞预算仍为 4000；
库 `rips_sparse` 默认 10000。另设 4000 万次坐标距离更新和 200 万次候选团枚举预算。
最坏情况仍可能二次增长或超限，较高截止尺度的稠密输入不会因切换入口而无限扩容。
旧 `points` 与距离矩阵入口保持 128 点限制。
CSV 的 `--engine sparse` 与 `--sample` 互斥，仅支持点云；仍按显式选列与变换后的坐标计算。

`node scripts/exact-analysis.mjs` 对照 8/32/96/128 点的完整报告，验证
4096 点直线的 8191 个细胞、H0=1/H1=0、全部坐标顺序与请求回放，另测 8192 个互不相连点。
这些是已验证规模，不承诺任意 8192 点都能在预算内完成。

## 指定同调类的最短代表链

```sh
moon run --target js cmd/main -- analyze examples/square.json --out out-square
moon run --target js cmd/main -- shortest examples/square.json 4 --out out-shortest
```

区间编号与分析 JSON/HTML 一致。输出 `shortest.json`；库接口为
`shortest_representative(analysis, interval_index)` 和对应 JSON 接口。

精确目标为：在所选 H1 类的出生尺度下、与给定代表链属于同一 GF(2) 同调类的所有链中，
使边数最少。算法约化该尺度的二维边界空间，得到独立基，再按 Gray code 枚举整个边界陪集。
所有候选恰好覆盖给定类；完整枚举后的最小边数具有全局最优性。
候选链可能包含多个连通部分；这不是最小欧氏周长、任意类别中最短的环，也不是 H2 代表面优化。
相同边数时保留首先遇到的候选，结果可重复。

最多允许二维边界秩 20、1048576 个状态和 2000 万项稀疏异或工作量；任一预算超限都返回错误，
不返回未经证明的“最优”标记。调用方可降低状态预算。未计算代表链、H0/H2、非法索引或非闭链均拒绝。
现有 `simplify_representative` 保留为快速贪心方法，两者接口和保证不同。

测试包含一个由填充三角盘与未填充三角环构造的同调类：贪心停在 6 条边，精确求解得到 3 条边，
且恰好保留未填充三角环；另测网格、正方形、状态预算和错误路径。
