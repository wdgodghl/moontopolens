# 选题与名称查重（2026-09-29）

选定：MoonTopoLens（月拓镜），MoonBit 持续同调与数据拓扑分析工具箱。

GitHub 仓库搜索 `MoonTopoLens`、`persistent homology language:MoonBit`、
`vietoris rips language:MoonBit`、`betti language:MoonBit` 均未返回匹配仓库。
此前还检查过 `homology`、`simplicial`、`ripser` 及 README 关键词。
README 命中 Across2005/yimai-prophecy-moonbit，但其内容是记忆预测引擎，
持续同调出现在示例知识目录中，未找到对应同调计算实现。

检索 Mooncakes 官方公开索引 https://mooncakes.io/api/v0/modules 的
2,728 条记录，按包名、描述、关键词查找 `moontopolens`、`homology`、
`simplicial`、`ripser`、`betti`、`vietoris`、`persistence.diagram`、
`topological.data`，未发现匹配包。索引下载于 2026-09-29。

结论：当前公开检索未发现直接同类 MoonBit 项目，重复风险较低；
检索无法覆盖未公开项目、不完整元数据和未索引代码，也无法判断作者是否参赛。

算法已有成熟研究和其他语言实现。参考背景：
- https://arxiv.org/abs/1506.08903
- https://github.com/Ripser/ripser （C++ Vietoris–Rips 持续同调）
- https://gudhi.inria.fr/ （计算拓扑工具箱）

本项目定位为独立 MoonBit 实现及应用工具，不宣称发明持续同调算法。
目前没有复制或移植上述项目源码，采用 MIT 许可证。
