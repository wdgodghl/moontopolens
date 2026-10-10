# Mooncakes 发布说明

发布状态：**2026-10-11 已发布**。模块名 `wdgodghl/moontopolens`，首次发布版本 `0.11.0`。
验收指南要求发布到 Mooncakes；以注册表中的实际模块条目作为完成证据。

公开页面：https://mooncakes.io/docs/wdgodghl/moontopolens 。
注册表 `https://mooncakes.io/api/v0/modules/wdgodghl/moontopolens` 返回版本 `0.11.0`、许可证 `MIT`。
在独立新项目执行 `moon add wdgodghl/moontopolens@0.11.0`，运行正方形最小样例得到 `H1 at scale 1 = 1`。

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
