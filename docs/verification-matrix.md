# 公开承诺与验证证据

本表把承诺连接到测试，不以测试数量、代码量或覆盖率替代行为正确性。CI 结果以对应提交的实际运行状态为准；本地 Windows 通过不代表其他平台已经通过。

| 承诺 | 自动验证 | 实际范围与未证明事项 |
| --- | --- | --- |
| 关键输入上限与 CLI 帮助一致 | sync-contracts.mjs --check、boundary_contract_wbtest.mbt | 验证共享常量及实际上限前/上限/超限；点数可接受不保证复杂度预算足够 |
| 稀疏与普通精确分析结果一致 | exact-analysis.mjs、reference_gudhi.py | 固定案例和 GUDHI 对照，不宣称覆盖全部可能输入 |
| 点编号与平移不影响持久图 | boundary_contract_wbtest.mbt | 多组含并列和重复点的 H0/H1/H2 性质验证 |
| 正比例单位换算保持对应关系 | boundary_contract_wbtest.mbt、research_wbtest.mbt | 区间、景观与置换概率；不证明任意预处理都不改变拓扑 |
| 研究统计量符合声明的定义 | research-cases.mjs、research_wbtest.mbt | 解析景观穷举参考分布、均值带公式、无未来训练泄漏；IID 与交换性需研究设计保证 |
| 孔隙空间量正确 | research-cases.mjs、research_wbtest.mbt | 各向异性几何、暴力最近固体盒距离、网格面面积；没有真实材料效用或渗透率验证 |
| 输入错误可定位和恢复 | host-failures.mjs、platform-smoke.mjs | 缺失、空值、字节边界、UTF-8、权限、压缩与路径；不将损坏数据当有效输入 |
| 写出失败不交付半成品 | host-failures.mjs | 可控注入 ENOSPC/EACCES/EPERM、部分写出、交付失败和目标出现；强杀、断电与外部非协作并发另见限制 |
| 不覆盖已有报告 | platform-smoke.mjs、host-failures.mjs | 已有内容逐字节保留；不模拟所有恶意文件系统竞争 |
| 输出字段与空值语义稳定 | result.schema.json、validate-result.mjs、boundary_contract_wbtest.mbt | 明确的报告族和 schema-1 包络；不覆盖全部辅助 JSON 的单独格式 |
| 报告可重算且文件完整 | verify-docs.mjs、check-report.mjs、research-cases.mjs | CSV 重放、信号窗口、内容哈希；清单不是签名或真实性证明 |
| 首次使用文档命令实际可运行 | verify-docs.mjs | 执行标记命令并核对预期；是自动化复现，不是独立用户体验 |
| 报告离线、可操作和可访问 | browser-regression.mjs、accessibility.mjs、research-browser.mjs | Chromium 桌面/窄屏、键盘、axe 与无外部请求；不宣称所有浏览器/辅助技术认证 |
| 跨平台路径与文本处理 | platform-contracts 三平台任务 | Linux/Windows/macOS，CRLF、UTF-8、中文/空格目录、错误和完整路径复现 |
| 实际发布包可安装 | 发布后独立消费者双后端验证 | 注册表下载验证，与源码工作目录测试分开；不以本地打包代替发布 |

## 尚未获得的证据

独立首次使用者试用未开展，材料见 first-use-trial.md。真实 PM2.5 片段无事件真值，不据此报告检测准确率；孔隙案例为人工几何参考，不宣称已在工业材料实测中验证。跨浏览器和人工辅助技术实测未覆盖。

覆盖率只说明被执行的计数点，现有历史记录按版本保留。本轮重点增加性质、失败恢复与文档闭环，不通过复制实现来增加测试数量。
