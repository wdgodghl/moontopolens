# 首次运行：完成一次可解释的分析

目标是从固定示例走完输入检查、分析、查看、复现与完整性核验。下面标记为 `sh verify` 的命令由 CI 原样执行；`{OUT}` 由验证程序替换为独立临时目录，手动操作时将其替换为尚不存在的目录名，例如 out-first-use。

先按 README 安装固定工具链与 Node.js 22，克隆仓库并进入根目录。运行 `moon version --all` 确认版本，然后 `moon build --target js`。文件命令只支持 JS/Node，核心库还支持 Wasm GC。

## 路径一：CSV 点云

先检查实际表头和选中数值列；未选的文本列可以保留。Iris 的下面两列单位为 cm，默认不归一化。

```sh verify
moon run --target js cmd/main -- csv-preview examples/iris/subset.csv --columns petal_length_cm,petal_width_cm
moon run --target js cmd/main -- csv-points examples/iris/subset.csv 1.2 --columns petal_length_cm,petal_width_cm --out {OUT}/csv
node scripts/check-report.mjs {OUT}/csv
```

预期：36 个分析顶点，选中两列；打开目录中的 report.html。先阅读“本次结果的适用范围”，再查看尺度下的分量、区间和代表链。1.2 的单位是所选原坐标的 cm，不能沿用到归一化后的数据。文件 csv-info.json 保留原始数据映射与变换，csv-request.json 可重算。

```sh verify
moon run --target js cmd/main -- analyze {OUT}/csv/csv-request.json --out {OUT}/replayed
node scripts/check-report.mjs {OUT}/replayed
```

预期：重算与首次 CSV 分析得到相同区间和细胞；来源附加信息可能不同。某个尺度的分组不等于生物分类准确率。

## 路径二：有时间戳的信号

```sh verify
moon run --target js cmd/main -- signal-csv examples/beijing-pm25/signal.csv examples/beijing-pm25/config.json --out {OUT}/signal
node scripts/check-report.mjs {OUT}/signal
```

预期：128 个小时观测、15 个有效窗口；没有事件真值，evaluation 为 null。打开 report.html，选择一个监测窗口，查看原始 CSV 记录、时间范围、延迟嵌入和四种方法的分数。拓扑变化提示不能解释为确认的污染事件或原因。

下载所选窗口分析请求后，可使用 `analyze 下载的文件.json --out 新目录` 重算。完整研究配置与来源保存在 study-request.json；窗口的 request 保存预处理后的序列，报告另保留偏移、缩放、去趋势和插值映射。

## 如何确认运行成功

命令退出码为 0，最终目录中有 run-manifest.json，且 check-report 校验通过。清单记录输出文件的相对路径、字节数与 SHA-256，以及读取输入的字节数和哈希，不记录绝对路径。哈希证明内容未变化，不证明算法、单位或输入真实性。

最终目录只在全部文件写完后交付，已有目录不覆盖。若进程被强制终止或系统断电，父目录可能残留 `.moontopolens-*` 临时目录；不得把它当成完成报告。正常可捕获失败会尝试清理，清理本身受权限影响。不要让其他程序同时创建或修改目标目录。

错误恢复、参数和格式说明见 [处理自己的数据](own-data.md)；计算和推断边界见 [能力边界](capabilities.md) 与 [输出字段](output-contract.md)。
