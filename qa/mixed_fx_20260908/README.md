# 混合FxRoot原生QA

来源 `231f560d4f5ccc39cc61e032dac0a17162a18283`。R1 `overlay_20260907T200149Z_8462800e`、R2 `overlay_20260907T200445Z_36fa9ff9`均通过。生产候选只有 `run_visual_graph.gd`，两轮字节相同；R2在原回归中增加攻击图腾与箭矢/飞斧同时存在的场景。

`runs/r1`和`runs/r2`保存各轮原始日志、报告、manifest、freeze、执行器和实际驱动。`candidate/`保存最终R2冻结文件及源码/驱动原字节（.gd.txt）；`SOURCE_PINS.json`记录每份归档的SHA与原路径，`installation.json`记录受测字节接入。准备期失败单列在 `preparation/history.json`，未更改任何原生结果。

实际覆盖和未完成范围见[实现说明](../../docs/MIXED_FX_RESUME_20260908.md)。R2共6218项=5774来源SHA+444其他断言，不是6218个游戏场景。混合引擎场景104个idle观察帧，真正physics/idle消费者推进；图腾组合场景为65对明确固定步长消费者。双方最终HP972/974及920分别绑定不同场景，不能混为一组数据。

## 重现R2

使用上述来源SHA的独立checkout，配置Godot4.6.3到本机被忽略的 `godot.local.txt`。先按SOURCE_PINS验证归档SHA；将candidate中的 `run_visual_graph.gd.txt`、`driver.gd.txt`恢复为原名，连同 `overlay_manifest.json`、`freeze.json`复制到 `scratchpad/mixed_fx_20260908/`，该目录加 `.gdignore`。不要在含未提交来源修改或已有Godot进程的目录执行。

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 231f560d4f5ccc39cc61e032dac0a17162a18283 --freeze-sha256 2efa86cee6b346cf0685e7d0621521cde94d3a81b3ddee3962f17c0cbd6dc5b9 --candidate scratchpad/mixed_fx_20260908 --expected-files 1 --driver driver.gd --driver-destination tools/mixed_fx/driver.gd --suite mixed-fx-native --prefix "[mixed Fx QA] " --profile-root D:/CodexTemp/lshqa --run
```

profile-root可换为本机受控短路径父目录。runner负责独占公共锁、私有用户目录、生产白名单复制和候选覆盖；每次新建运行/报告。R1复现使用其原driver及freeze（9d72f20119b972382d276b143c5570c55c128e9e6e6564ca2e0121f4ad1a4496），生产候选和overlay_manifest相同。换源码基线须重新审查before SHA与冻结清单。旧绝对路径仅为历史观察，不能当作新环境写入目标；preparation脚本也不是直接从QA目录执行的入口。

尚未验收：完整世界工厂、退出/冷启动战斗、玩家槽、保存菜单、全局视觉随机状态、像素绘制对照、所有特效与显示节点、30波/八关胜利、长期性能、真人与Steam账号流程。
