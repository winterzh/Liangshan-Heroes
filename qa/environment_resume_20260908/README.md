# 战场环境原生恢复 QA

来源提交 `6481a1fc358ca3ed30aabdc401e4b48bf3c79858`。最终 `overlay_20260907T235430Z_c9de9b57`，freeze `ed28117ee729909b0622bb3c37202e4e452411262e52fb28904b2d79c690428e`，6037项通过=5802来源SHA+235非来源记录（234断言+1条像素诊断）检查；来源/玩家文件/私有源码/候选保护、退出及锁释放以原始receipt为准。

R1根清单遗漏真实保存屏障；R2严格Node2D信号检查拒绝氛围父层的Control尺寸连接；R3原生诊断确认item_rect_changed → 唯一ColorRect的Control::_size_changed，flags=0。R4加入精确认可和像素测试，R5用独立World2D排除相机串扰后确认新/旧锚定矩形均0×0，128×96纹理全黑，不能把相同黑图当PASS；据此修正实际全屏布局，并给参考矩形和背景显式尺寸。R6几何与真实绘制通过，精确逐字节等值失败；R7量化为36864通道中仅1通道相差1/255并通过全套；最终另覆盖激活前改变真实Viewport画布变换后的全屏重算。后续结果以最终报告为准。全部原始通过/失败保留在runs，各自结论以各自report/receipt为准。一次手输freeze重复字符被预检拒绝，没有启动原生进程。

真实经典战斗运行并通过HELD捕获全部20分区；新Battle禁用准备、真实根绑定挂载，再仅激活环境。原生idle对照时仅把源/新环境消费者临时设为ALWAYS，游戏仍HELD；对照结束恢复源模式/相位。没有伪造delta调用生产_process。保留HUD、消息Tween、相机、世界显示、死亡残留及坏分区回滚套件。游戏主窗口0×0；专用128×96及192×108 SubViewport由Forward+/Vulkan真实渲染，非可见战斗截图。

在来源提交独立checkout核对引擎/runner/guard SHA，把candidate内.gd.txt恢复.gd原名至scratchpad/environment_resume_20260908，保留.gdignore、manifest及freeze，UID让隔离原生导入生成，然后运行：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 6481a1fc358ca3ed30aabdc401e4b48bf3c79858 --freeze-sha256 ed28117ee729909b0622bb3c37202e4e452411262e52fb28904b2d79c690428e --candidate scratchpad/environment_resume_20260908 --expected-files 3 --driver driver.gd --driver-destination tools/environment_resume/driver.gd --suite environment-resume-native --prefix "[environment resume QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可替换成受控短绝对路径。生产文件只从最终受测字节晋级，原混合换行保留。SOURCE_PINS固定归档来源，installation固定晋级来源及SHA。[实现与范围](../../docs/ENVIRONMENT_RESUME_20260908.md)。无完整游戏续玩/磁盘槽/跨进程/Steam验收结论。
