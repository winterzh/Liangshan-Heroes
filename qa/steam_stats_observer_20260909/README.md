# Steam 独立只读观察器：隔离验收归档

本批完成独立观察者账号与目标账号的读取实现，并通过隔离原生/Godot 验证。**真实第二账号尚未验收；本批不能确认某个持久统计发送意图，outbox 继续保持 `BLOCKED`。**

## 最终受测版本

最终运行：`.godot/steam_observer_validation/20260909_032214_59eb343a`，收据 `complete=true`、共享锁已释放。重新核对 21 项源码输入 SHA-256 均一致；7 个命令退出码均为 0，最终运行日志无引擎错误。

| 验证层 | 结果 | 范围 |
| --- | --- | --- |
| C++ 原有自身账号读取器 | 61/61 | 未改变原接口的隔离回归 |
| C++ 独立观察器 | 184/184 | 双账号身份、请求句柄、getter、失败与超时隔离 |
| Godot facade | 119/119 | 合成原生对象、旧接口拒绝、完整快照及错误输入 |
| Godot 无 Steam | 2/2 | 新类注册；未初始化 Steam 时明确失败 |
| Godot 合成 ABI | 14/14 | 实际构建 DLL 读取合成第二目标、重复/错账号回调拒绝 |
| 构建器原有 reader 无 Steam / 合成 ABI | 2/2、23/23 | 同一隔离 DLL 的旧读取器回归 |

这些是不同层次的断言，不累加为真人测试、真实账号测试或玩法完成数。C++ 测试还会在构建器中重复执行，重复运行不增加独立覆盖。

本次复用构建 `58e3895e2199`；观察器 DLL 为 370,688 字节，SHA-256 `b62f1371d212b95f27b7e1257228ff6f2eb3066d4b165ea02591f944c98bc7a8`。合成 Steam DLL 的 15 个导出经过白名单检查；它只用于隔离测试，不得进入 vendor 或玩家安装包。最终收据确认生产 `vendor/steam_stats_reader` 未替换。

## 保留的失败历史

`20260909_031324_0975ded7` 的 facade 断言虽然全部通过，但故意输入非法 JSON 时，旧 `JSON.parse_string()` 打出引擎 `ERROR`，验证器正确判该次运行失败（`complete=false`）。修复改为 `JSON.new().parse()` 检查返回码并返回 `BAD_NATIVE_RESPONSE`，随后才有上述最终成功结果。没有删除这次失败，也没有把它计为验收通过。

`sources/history_0975ded7/scripts/steam_stats_observer.gd.txt` 保留该次受测旧文件；最终的 21 项输入位于 `sources/current/`。`native/steam_stats_reader/OBSERVER.md` 的“交接时只跑过原生测试”属于受测源码快照中的历史时间点，当前验收进展以本 README 与 `docs/STEAM_STATS_OBSERVER_20260909.md` 为准，未为改文档而改写受测输入。

## 归档结构与脱敏

- `validation_final/`：最终收据、三份报告、必要运行日志。
- `validation_failed_0975ded7/`：先前失败收据、运行日志及当时输出的 facade 报告。
- `reader_build_58e3895e2199/`：复用 DLL 的构建收据、旧 reader 报告与编译/运行日志。
- `native_final_f8fcccaf7d2d/`：最终 C++ 测试收据与日志；`native_prior_19a654b961df/` 保留先前失败运行引用的 C++ 证据。
- `sources/`：受测源码的逐字节 `.txt` 快照；保留原始 SHA-256 和原始相对路径。
- `manifest.json`：每份归档文件大小和 SHA-256、原始证据路径/大小/SHA-256、转换方式及范围检查结果。
- `validate.py`：只读核验归档完整性，不运行引擎、编译器或 Steam。

收据及日志中的本机用户目录、工程绝对路径、编译器和隔离目录已改为占位符；JSON 仍可解析。原始 SHA-256 与归档 SHA-256 分开记录，不能拿脱敏文件字节去冒充原始收据。出现的账号号码均来自源码中固定的合成 fixture，不是真实账号资料。源文件快照保留原始字节及许可，不进行内容脱敏替换。

没有归档 DLL、EXE、OBJ、PDB、安装包、Godot 缓存、运行 profile、真实 Steam 日志、真实账号或玩家存档。

```powershell
py -3.14 -X utf8 -B qa/steam_stats_observer_20260909/validate.py
```

该命令只核验已归档证据，不重新执行测试。观察器仍须遵守主线程及同一目标读取独占约束；这里的成功不代表跨设备合并、统计写入确认、经典 30 波或八关续玩通过，也不代表 Steam 上传/激活或客户端下载验收。
