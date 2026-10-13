# 确定性点云采样

0.20.3 为较大输入提供显式近似入口，精确 Rips 仍最多处理 128 点。
采样最多读入 10000 点，维度最多 32，距离更新工作预算为 4000 万个坐标。
选择量为 1–128；完整输入不超过选择量时原样保留。

```sh
moon run --target js cmd/main -- points-sample examples/square.json 3 --out out-sample
moon run --target js cmd/main -- csv-points examples/iris/subset.csv 1.2 --columns petal_length_cm,petal_width_cm --normalize zscore --sample 16 --out out-csv-sample
node scripts/data-pipeline.mjs
```

最远点采样从编号 0 开始，每轮选择到已选点集合的最近距离最大的点，
距离并列时选择较小原始编号。重复点仍有独立编号，不自动去重。
覆盖半径是所有输入点到所选集合的最大最近距离；它使用变换后的坐标单位，
不直接声明拓扑误差保证。CSV 流程为选列、变换、采样、精确计算所选点的同调。

JSON 入口导出 `sample-request.json` 和 `sampling-info.json`；CSV 信息保存在 `csv-info.json`。
报告 JSON 的 `source.sampling` 记录近似标志、原始点数、选择点数、原始编号和半径。
CSV 原始编号采用去除表头和空白行之后的零起始数据行编号，不是物理文件行号。
报告 HTML 明确显示近似标记，保存的普通请求可以重复分析。

## 小规模对照

脚本生成单位圆上的 16 个等角点，完整选择 16 点时所有区间与原始分析一致。
选择 8 点时，覆盖半径为 0.39018064403225655；同截止尺度 2 下，
H0 与 H1 瓶颈距离分别约为 0.375186220697923 和 0.3751862206979226。
这是该输入的实测差异，不是所有输入的误差上界。

另以 512 个等角点验证 CSV 入口，选择 32 点，在截止尺度 0.3 下完成报告导出，
核对原始编号和原始坐标。CI 重复运行上述场景和非法采样量检查。
采样不会解除细胞预算；较大截止尺度仍可能超限。
