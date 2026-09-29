# Mooncakes 发布说明

当前发布状态：**尚未发布**。包名暂定 `wdgodghl/moontopolens`，版本 `0.3.0`。
账号命名空间必须与实际 Mooncakes 用户名一致，不能只凭 GitHub 用户名假定拥有发布权限。

当前官网公开验收摘要没有强制发布条款。先前九条参考标准包含此项，
正式章程当前未能读取，应按赛事通知确认。此处保留后续生态发布操作说明。

## 发布前

1. 检查 CI 绿色，确认 README 仅声明已经完成的功能。
2. 确认 OSI MIT 许可证、来源记录、安装与八个输入示例。
3. 检查 `moon.mod` 包名、版本、repository、license、readme、description。
4. 运行 `moon package --list`，检查归档没有本地输出、工具链、凭据或 Git 历史。
5. 如账号命名空间不同，同步修改模块名、内部 import、文档和 CI。

## 登录及发布

```sh
moon login
moon publish
```

登录和凭据由账号持有人完成，不把 token 写入仓库。
发布后查询 https://mooncakes.io/ 的模块条目，记录实际链接；
在一个独立示例项目中通过 `moon add wdgodghl/moontopolens` 安装并运行示例，
再将 README 和验收表更新为“已发布”。

发布不可被本地打包代替；必须得到注册表成功响应并核实包条目。
同版本如已上传，需要按真实变更递增版本，不能覆盖既有版本。
