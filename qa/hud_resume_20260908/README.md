# HUD 整体恢复原生 QA

来源 `b19aed5f63ac9f7657204176350ef8362352555a`，最终运行 `overlay_20260907T231246Z_18d8d00f`。6002项通过，其中5798为来源SHA、204为其他检查。Godot4.6.3 / Windows / Forward+ / Vulkan，私有user://，最小化窗口。界面值、小地图缓存像素和处理状态经过原生验证；不是可见布局截图或人工鼠标手感验收。

真实经典战斗正常运行后，按正常spawn接口补足12个可选单位和英雄，设置资源、选区、物品栏及暂停确认状态，再通过真实HELD屏障捕获。最终夹具额外覆盖实际Viewport拖拽取消、已有HeroChip信号与非零重绘相位。新世界先准备、绑定真实根时钟和数据，再挂载禁用Battle并构建HUD；同帧激活仅HUD消费者。Escape经Viewport.push_input分发，第二次Escape确实调用Battle._close_pause；驱动同步重新暂停，未让战斗世界运行一帧。0/1/10/12单位和生产建筑使用真实还原的Unit及HUD入口。取消手势后的松开测试直接调用真实控件_gui_input，不能写成OS输入测试。

runs保留本批原始失败及通过的脚本、执行器、manifest/freeze、日志、report/receipt。R1为驱动过早引用全局HUD/Unit类型导致autoload尚不可用；R2初始经典模式无英雄，补实际英雄夹具；R3驱动错误地用字符串比较整型Steam局编号。后续结果以各自报告为准。生产文件仅从最后受测字节晋级，既有混合换行保留。

在来源提交的独立checkout核对Godot、runner/guard SHA，将candidate中的.gd.txt恢复.gd原名，连同overlay_manifest.json、freeze.json放到scratchpad/hud_resume_20260908并保留.gdignore；不要提前把归档UID复制进来源scripts，隔离导入会生成。复现：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head b19aed5f63ac9f7657204176350ef8362352555a --freeze-sha256 9acd58031c0a521423e09acba3cc3bb5bada5d9d1140200371ed8211377b59dc --candidate scratchpad/hud_resume_20260908 --expected-files 5 --driver driver.gd --driver-destination tools/hud_resume/driver.gd --suite hud-resume-native --prefix "[hud resume QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可换受控短绝对路径。源码、玩家文件、私有源码、候选保护及原生退出/锁释放均以最终receipt为准。未完成全世界物理激活、磁盘槽、跨进程、Steam真实账号及人工/性能验收。[合同](../../docs/HUD_RESUME_20260908.md)。
