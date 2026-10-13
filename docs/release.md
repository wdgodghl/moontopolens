# Mooncakes 发布说明

当前源码版本：**0.20.4**。模块名 `wdgodghl/moontopolens`，首次发布版本 `0.11.0`。
公开模块页：https://mooncakes.io/docs/wdgodghl/moontopolens 。
注册表：https://mooncakes.io/api/v0/modules/wdgodghl/moontopolens 。
已发布版本和构建状态以注册表为准；源码版本号本身不作为发布成功证明。

0.20.2 提供 CSV 选列与显式变换，0.20.3 提供确定性点云采样，
0.20.4 提供三维点云旋转、原始数据追溯、共同网格批量特征与 Chromium 回归。
变更详情见 CHANGELOG.md，使用方法见 data-workflows.md。

历史安装验证：0.20.0 在全新独立项目调用完整与仅区间分析 API，核对正方形区间与代表链模式；
JS 与 Wasm GC 各一项最小样例通过。新版本应按下面的流程继续验证实际发布包。

## 发布前

1. 检查 CI 绿色，确认 README 仅声明已经完成的功能。
2. 确认 OSI MIT 许可证、来源记录、安装与 JSON/PGM/批量输入示例。
3. 检查 `moon.mod` 包名、版本、repository、license、readme、description。
4. 运行 `moon package --list`，检查归档没有本地输出、工具链、凭据或 Git 历史。
5. 如账号命名空间不同，同步修改模块名、内部 import、文档和 CI。

## 登录及发布

```sh
moon login
moon publish
```

登录凭据不写入仓库。
后续版本发布后继续查询公开模块条目；
在独立示例项目中通过 `moon add wdgodghl/moontopolens@<version>` 安装并运行示例。

发布不可被本地打包代替；必须得到注册表成功响应并核实包条目。
同版本如已上传，需要按真实变更递增版本，不能覆盖既有版本。
