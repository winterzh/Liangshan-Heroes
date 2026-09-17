# 持久局回执模型封存

这是通过原生测试的隔离草稿，不在生产加载。GDScript使用`.gd.txt`封存，目录有`.gdignore`；`SOURCE_PINS.json`记录原名、原字节和SHA。不能从本目录直接运行Python入口，因为它按自身位置推导工程根。

复现时将四个文件按`original_name`恢复到工程内全新、被忽略的`scratchpad/<新名称>/`目录，先逐文件核对SHA，不复用已有实验或玩家目录。随后运行：

```text
py -3 -X utf8 -B scratchpad/<新名称>/run_receipt_tests.py
py -3 -X utf8 -B scratchpad/<新名称>/run_receipt_tests.py --run --profile-root <短绝对私有目录>
```

第一条只预检；第二条须独占Godot，按本机`godot.local.txt`创建新极小工程和私有用户目录，运行模型及七阶段夹具，保存到该草稿的`runs/`。源码依赖当前生产`steam_achievement_catalog.gd`与`steam_achievement_state.gd`，其实际SHA写入当轮收据。不要将QA成功解释为真实Steam SDK或文件事务成功；范围和未解决的回调落盘窗口见[专项说明](../../../docs/STEAM_RUN_RECEIPT_DRAFT_20260907.md)。
