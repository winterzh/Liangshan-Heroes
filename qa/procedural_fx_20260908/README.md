# 三十类程序化特效原生 QA

来源提交 `ccfc190ea37cbc4e35cab5aea3687c95dba3572d`，最终 `overlay_20260908T001323Z_80be002e`，freeze `03c13a0c3698345ea188f69b1f03599e0c095fe996b3937343e9c037bb2d6883`。6246条记录通过=5806来源SHA+439非来源断言+1条诊断。新批205项断言及既有234项回归，未把来源哈希或诊断记录当功能用例数。Windows/Forward+/Vulkan，主窗口0×0、私有user://；完整源码/候选/玩家文件保护与原生退出/锁释放见最终receipt。

R1真实30类字段清单通过，捕获在Lightning打包坐标处被既有Codec拒绝UNSUPPORTED_TYPE；未接生产。R2将两个PackedVector2Array字段显式转换为Vector2列表，并原生恢复类型/坐标核对，最终全套通过。runs保留两轮实际输入、执行器、来源清单、日志、报告和收据，SOURCE_PINS给出归档SHA。字段生成依据见candidate/field_manifest.json，生产固定白名单，无运行时任意反射。

30类使用真实当前构造器与_ready；暂停树下只启用独立特效舞台原生idle，捕获后禁用舞台，重建/挂载/激活副本，再逐帧比较原/恢复变量与变换、自然退出次数。全core夹具在真实HELD Battle中加入30个正常节点并捕获/准备，未激活该Battle。新增代码只给普通_ready增加恢复闸；保留原来完整回归驱动。没有新30类的可见像素对比或真人观感结论，前序环境的专用SubViewport像素用例继续执行。

复现需在来源提交独立checkout，核对Godot/runner/guard SHA，把candidate的.gd.txt还原.gd原名到scratchpad/procedural_fx_20260908，保留.gdignore、manifest和freeze；新UID由隔离原生导入产生，不预先放进来源scripts：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head ccfc190ea37cbc4e35cab5aea3687c95dba3572d --freeze-sha256 03c13a0c3698345ea188f69b1f03599e0c095fe996b3937343e9c037bb2d6883 --candidate scratchpad/procedural_fx_20260908 --expected-files 3 --driver driver.gd --driver-destination tools/procedural_fx/driver.gd --suite procedural-fx-resume-native --prefix "[procedural fx QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可换受控短绝对路径。生产文件从最终受测字节晋级，既有混合换行保留。[实现、30类清单及剩余工作](../../docs/PROCEDURAL_FX_RESUME_20260908.md)。完整世界/Steam/光标上下文、磁盘槽及跨进程、八战役、性能/人工验收继续开放。
