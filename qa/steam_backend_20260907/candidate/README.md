# Steam 测试分支候选复验（2026-09-07）

构建源码固定为 `df7ed189c1b04a501ca6c3d2fe1c45e781231c18`，分支 `codex/sync-20260905-stable`。相较首份 Steam 接入候选，新增八个尚无 Battle/菜单调用方的续玩组件及对应 UID；原有 Battle、Steam 服务、UI、素材未改变。本次重新冻结完整源码，避免沿用旧收据遗漏新增脚本。

- 原生隔离 QA：176 项通过，import/catalog/contracts 全部 exit 0，受测源码前后 SHA 一致；冻结 2,841 项（2,837 个运行文件及 4 个测试/导出工具）。
- 新候选：白名单 2,604 项；import/export、实际内嵌 PCK 的 65 项合同及真实发行 EXE 短启动全部通过。额外对照 PCK 文件清单，确认新增八个恢复模块均已入包；不据此声称续玩功能已接入或完整战局恢复通过。
- 实际发行 PID 16708，13.2 秒后正常 exit 0。进程回读到候选目录中的 GodotSteam release DLL 与 steam_api64.dll，哈希和固定依赖一致。引擎锁及本轮 Godot 进程已释放。
- ZIP：219,811,886 字节，SHA-256 `768d1c15dedfd0cd19f89bb3528028171f2abf0115d3ca51a244e90e8f3b44d5`；只有 EXE、两个 DLL 与 GodotSteam 许可证，逐项哈希见 `delivery_manifest.json`。

候选位于本地忽略目录 `.godot/steam_candidates/20260907_034452_e661f0ee/LiangshanHeroes_Steam_candidate.zip`。EXE 为 287,589,608 字节，SHA-256 `2a633b1a7dbf2161e7e5d69410203093668e65553dcbe82dbeb1734518b20c05`。本目录不包含二进制导出物。

## 收据与边界

`native_qa/` 保存本次行为报告与日志；`export/` 保存新构建收据、PCK 文件清单、发行验证和日志。`summary.json` 汇总本次事实，`archive_manifest.json` 映射原始收据 SHA 与脱敏副本 SHA。本地工作区和用户主目录改为占位符；原始收据留在忽略的隔离目录，没有覆盖历史失败轮。

自动检查均在私有 APPDATA/LOCALAPPDATA/TEMP/TMP 下运行，强制 `STEAM_DISABLED=1`，不初始化真实 Steam 账号，不读取玩家 profile。这里没有服务器发布、BuildID、实际成就解锁、订阅下载或双账号验收证据；线上结果应由本轮后台收据另行记录。本轮没有重新验证未改变的六张 UI 画面，也没有改变完整商业发布门槛。

## 复现

在上述源码、配置本机 Godot 4.6.3 路径并确认共用引擎槽空闲后：

```powershell
python -X utf8 -B tools/run_steam_integration_qa.py --run --native
python -X utf8 -B tools/build_steam_candidate.py --run --qa-run .godot/steam_integration_qa/新成功目录
```

本次仅用 `--cache-from .godot/steam_integration_qa/20260907_021628_5741e91a` 复用旧隔离纹理缓存以节省导入时间；未复用玩家数据或旧测试结果。
