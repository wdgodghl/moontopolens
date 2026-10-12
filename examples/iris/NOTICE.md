# Iris 示例数据来源

Fisher, R. (1936). Iris [Dataset]. UCI Machine Learning Repository.
https://doi.org/10.24432/C56C76

来源：https://archive.ics.uci.edu/dataset/53/iris
下载：https://archive.ics.uci.edu/static/public/53/iris.zip
原始文件：`bezdekIris.data`。

UCI 将此数据集按 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) 授权。
此目录的四份 CSV 是该数据集的改编数据，沿用 CC BY 4.0；项目代码的 MIT 许可证不替代数据许可证。

改编方式：每个物种块取前 12 行（原文件第 1–12、51–62、101–112 行）；删除物种标签列，增加数值列名。
四列依次为萼片长、萼片宽、花瓣长、花瓣宽，单位均为 cm。未标准化、去重或修改测量值。
合并文件依次拼接 setosa、versicolor、virginica；选择索引及源文件 SHA-256 见 `source.json`。
这是固定的小样本演示，不代表全数据集的分布或分类准确率。
