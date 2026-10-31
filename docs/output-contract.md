# 公开结果字段与兼容性

`contracts/result.schema.json` 定义 schema_version=1 的基础分析、比较及五种研究报告（reliability、signal_study、cohort、pores、pore_compare）。`node scripts/validate-result.mjs 文件.json` 检查这份契约；验证器实现该文件实际使用的 JSON Schema 子集，不是通用 JSON Schema 实现。

这份统一契约不套用到所有辅助导出：Betti/景观向量、预处理信息、切片、轨迹等仍遵守各自字段说明。它们的 schema_version 不可直接当成此包络的版本。HTML 只显示预计算结果，完整数值以 JSON/CSV 为准。

| 字段 | 解释 |
| --- | --- |
| schema_version | 此报告族的格式版本，当前 1；不是项目版本 |
| generator.name/version | 生成库名称与补丁版本；CLI 文件清单另记录 Node 版本 |
| result_contract.scope | 本次分析或研究的中文适用范围 |
| result_contract.dimensions | 基础分析 H0/H1/H2 的计算、空结果、截断存活及代表链状态；其他报告不使用时为空数组 |
| result_contract.approximation | declared_approximation 表示来源明确声明近似；not_declared 不证明外部输入未经采样或变换 |
| *_verified=false | 单位、研究设计、配准真实性未由格式检查证明，不表示这些条件一定错误 |
| intervals[].birth/death | 半开区间 [birth,death)；death=null 表示截止时仍存活，不证明无限寿命 |
| representatives_computed | false 时空代表数组表示未计算，不代表没有拓扑 |
| comparison.distances[].bottleneck | null 为此比较规则下不可得，例如截断类数目不同；不是零距离 |
| cutoffs_equal/complex_kinds_equal | 只检查两个结构条件；不证明相同单位、变换或采样方案 |
| signal.evaluation | 未提供事件真值时为 null；显式 events=[] 表示标注全部阴性，与缺失真值不同 |
| precision/recall | 分母为零时 null；不能填成零或一 |
| pores.solid_clearance | 固体位置或没有观察到固体时为空；结合标签判断，不把未知外部当自由空间 |

新增字段允许消费者忽略；删除字段、改类型或改变已有字段含义需要新的格式版本与迁移说明。补丁版本不改变既有数值字段含义。新增契约字段不改变原区间、匹配、分割或统计量的定义。消费者读取时应检查格式版本，并区分 null、空数组、0 与未计算状态。

## 可复现与完整性

CLI 成功交付的目录附 run-manifest.json，记录每份输出相对路径、字节数与 SHA-256，读取输入的编号/字节数/哈希，以及生成版本。输入编号依实际读取顺序，不是样本 ID。清单不记录自己哈希，也不保证清单未被恶意替换；它用于完整性和普通重现核对，不是签名或数据真实性认证。

用 `node scripts/check-report.mjs 目录` 核对清单。研究保存 study-request.json，CSV 点云保存 csv-request.json；信号窗口另有普通 request。相同配置与版本重复计算应有相同数值结果；CPU 计时、Node 版本和来源附加信息不承诺逐字节跨环境一致。
