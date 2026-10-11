# GUDHI 外部区间对照

MoonTopoLens 的 Rips 与方格复形结果由 MoonBit 独立计算。`scripts/reference_gudhi.py` 是可选验证程序，
用 GUDHI 3.13.0 重新构造 Rips 和以顶点值定义的 cubical 复形，比较请求维度的 H0/H1/H2 持续区间。
GUDHI 不参与项目的日常分析、发布包核心算法或输出生成。

## 复现

安装 Python 3.12、Node.js 22 和项目要求的 MoonBit 工具链。在仓库根目录执行：

```sh
python -m pip install numpy==2.3.5 gudhi==3.13.0
moon build --target js
python scripts/reference_gudhi.py
```

预期：`GUDHI 3.13.0: 30 Rips/cubical cases agree in requested H0/H1/H2 dimensions`。
CI 在检查、构建和核心测试之后运行同一脚本。

## 比较口径

- 5 个仓库示例：正方形、矩形、分离簇、距离矩阵和周期信号延迟嵌入。
- 5 个正方形截止尺度：0.5、1、1.25、√2、2。
- 12 组固定生成的六点二维云，每组截止尺度 5。
- 1 个六顶点八面体度量样例，请求 H2，预期区间 `[1,2)`。
- 1 个二维环形网格、2 个空心体截止尺度（空腔存在与填充后），另有 4 个确定性三维体数据；cubical 用各角点最大值决定细胞进入尺度。
- Rips 采用边长/直径尺度，边长等于截止值时进入复形；普通样例构建至二维，H2 样例构建至三维。Cubical 细胞由其顶点最大值确定进入尺度；两类计算均使用 GF(2)。
- 默认省略零长度区间；GUDHI 的无限死亡映射为 MoonTopoLens 的截止时仍存活 `null`。
- 每个维度对区间多重集按出生/死亡排序，再以绝对/相对误差 `1e-6` 比较。

2026-10-10 本地执行：原 22/22 案例的 H0/H1 区间一致。2026-10-11 本地扩展对照：30/30 个 Rips/cubical 案例一致，包含八面体和空心体 H2；CI 也运行同一脚本。
这一结论不覆盖瓶颈匹配、代表链或所有可能输入。

参考接口：[GUDHI RipsComplex](https://gudhi.inria.fr/python/latest/rips_complex_ref.html)、
[GUDHI SimplexTree.persistence](https://gudhi.inria.fr/python/latest/simplex_tree_ref.html)。
三维体数据使用 [GUDHI CubicalComplex 顶点值接口](https://gudhi.inria.fr/python/latest/cubical_complex_ref.html) 对照。
