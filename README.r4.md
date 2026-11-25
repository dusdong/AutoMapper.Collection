# R4 Collection 打包

在干净的生产提交使用 .NET SDK `10.0.404` 和 .NET 8 运行时。使用引擎 R4 入口生成的稳定主包，将 `ENGINE_SHA256` 设为该次生产记录的主包摘要，`OUT` 设为尚未创建的输出目录。

```sh
DOTNET="$DOTNET" bash pack-r3-candidate.sh --r4 "$ENGINE_NUPKG" "$ENGINE_SHA256" "$OUT"
```

入口从隔离本地源安装 `Du.AutoMapper [14.0.0]`，编译并运行原有 Collection 测试，复用通过测试的构建生成 `feed/Du.AutoMapper.Collection.11.0.0.nupkg` 和配对符号包。输出记录生产提交、SDK、还原和构建证据、TRX 及摘要。
