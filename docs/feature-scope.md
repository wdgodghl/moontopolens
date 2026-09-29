# 选题功能落实情况

MoonTopoLens 的主线是将小规模数据的多尺度连接分量与环路变得可计算、可比较、可解释。
截至 0.4.0，以下功能均有代码、示例和验证路径。

| 功能主线 | 当前实现 | 可复现入口 |
| --- | --- | --- |
| 点云/距离分析 | 欧氏距离、严格矩阵校验、Rips 二维骨架 | square、rectangle、matrix |
| 时间序列场景 | 指定维数、滞后、步长的延迟嵌入 | periodic-series |
| 网格场景 | 顶点 lower-star 方格复形与洞填充 | ring-grid、two-holes-grid |
| 多尺度同调 | GF(2) 稀疏约化、H0/H1 区间、精确 Betti 事件 | analyze、betti-events.csv |
| 代表环路解释 | 出生代表链、离线选择、高亮与独立 SVG | report.html、slice --out --interval |
| 连通分组 | 原始顶点 ID、尺度快照、分组着色 | clusters、slice |
| 拓扑比较 | 精确瓶颈距离、最优匹配见证、存活类计数差异 | compare --out |
| 特征提取 | 观察寿命、有限持续熵、持久景观采样向量 | summary、landscape |
| 可分享成果 | JSON/CSV、条形码与持续图 SVG、两类离线 HTML | analyze --out、compare --out |
| 参赛工程要求 | 公开提交、MIT、README、双后端测试、CI、可运行样例 | README、Actions、acceptance.md |

## 当前边界

- 已实现 H0/H1；完整 H2、整数系数、最短代表环路未实现。
- 面向小规模数据；大规模 Rips 优化、流式分析和性能基准未实现。
- 时间序列的嵌入参数由用户指定；不自动估计周期、选择滞后或做分类。
- 比较解释的是区间集合，不建立真实对象身份对应；匹配可能不唯一。
- 有坐标数据使用二维投影；不从距离矩阵重建几何位置，也不在切片 SVG 中绘制二维填充。
- 两类 HTML 可离线运行；在线上传服务、真实浏览器视觉 QA 和外部 Ripser/GUDHI 差分仍待后续。
- Mooncakes 尚未发布，是否强制发布仍以正式赛事章程为准。

本轮优先完善已实现算法的解释和演示流程，上述工作量较大的扩展不作为 0.4.0 已完成成果。
