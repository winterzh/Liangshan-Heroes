# 世界显示恢复 QA

来源提交 `ea4f9d6c73c68a6d1dca6aa416c2345b37180bb3`；最终运行 `overlay_20260907T214557Z_386afef6`。R1—R5为失败原文，R6首次通过，R7补容量及尸体真实物理消失，R8补完整继承绘制属性与挂载前拒绝。R8为5884项，其中5786来源SHA，98其他断言；不是5884个玩法场景。

runs保存原始日志、收据、manifest/freeze、实际执行的三份生产脚本及驱动；不存在的报告不补造。candidate是最终受测输入，preparation仅供审计。SOURCE_PINS可逐文件复核，installation记录生产晋级字节和原生UID。QA通过.gdignore隔离，原字节由Git属性保留。

在上述来源提交的独立checkout配置Godot4.6.3；把candidate的battle.gd.txt、run_world_display_state.gd.txt、run_battle_world_core.gd.txt、driver.gd.txt恢复为.gd原名，连同overlay_manifest.json、freeze.json放到scratchpad/world_display_20260908并加.gdignore。不要把归档UID复制进来源scripts；原生import在隔离工程生成。执行器和guard应与归档版本同SHA。

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head ea4f9d6c73c68a6d1dca6aa416c2345b37180bb3 --freeze-sha256 fb54c7536ff856f4c4181eca167b453a36f8517aa44d63ac5cd8a0df82a75d27 --candidate scratchpad/world_display_20260908 --expected-files 3 --driver driver.gd --driver-destination tools/world_display/driver.gd --suite world-display-native --prefix "[world display QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可换受控短绝对路径；历史路径不作新写入目的地。最终驱动使用Windows/Forward+/Vulkan，窗口最小化、viewport0×0；校验纹理像素数据，不是画面排版或可见像素验收。原生回调只启用显示层及单个临近消失的尸体夹具，Battle玩法/时钟保持关闭；没有整场或跨进程继续结论。[实现与剩余工作](../../docs/WORLD_DISPLAY_RESUME_20260908.md)。
