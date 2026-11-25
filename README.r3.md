# R3 Collection 候选

从固定的 v11.0.0 源码生产 `Du.AutoMapper.Collection`。候选保留 `net8.0`、程序集名称和签名、公共命名空间、MIT 许可及图标。项目的普通构建和打包继续使用 `AutoMapper.Collection` 与 `AutoMapper [14.0.0, 15.0.0)`。

在 macOS ARM64 上使用 .NET SDK `10.0.404` 和兼容的 .NET 8 运行时。从本仓根目录运行以下命令，`ENGINE_SHA256` 使用冻结引擎主包清单的值，`OUT` 指向尚不存在的输出目录。

```sh
bash pack-r3-candidate.sh 11.0.0-r3.4 "$ENGINE_NUPKG" "$ENGINE_SHA256" "$OUT"
```

入口将校验后的同批引擎主包复制到隔离的本地源。干净缓存从该源还原 `Du.AutoMapper [14.0.0-r3.4]`，编译 Collection 并执行原有的 `AutoMapper.Collection.Tests`。成功后使用同一次编译输出打包，保留 `feed/`、`symbols/`、编译与打包日志、实际还原图、TRX 和 SHA-256。复跑使用新目录，主仓冻结批次继续使用其登记的原件。
