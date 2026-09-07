# 相机恢复原生 QA

来源 `4c0fafce921bfa98e31c9f9b7c1b0824a9c73962`，单次原生运行 `overlay_20260907T215752Z_14d9f297` 通过。5909项中5790是来源SHA、119是状态/输入/生命周期/回滚断言。使用Godot4.6.3、Windows Forward+/Vulkan及RTX4060 Laptop，私有user://；实际窗口最小化、viewport0×0。滚轮/中键事件通过真实Viewport.push_input分发，不是直接调用相机处理方法，也不是Windows人工鼠标或可见画面验收。

native保留实际生产候选、驱动、执行器、manifest/freeze、日志、报告与保护收据；candidate为最终输入，preparation仅供审计。SOURCE_PINS记录原字节SHA，installation记录晋级和原生UID。整个QA由.gdignore隔离，字节由Git属性保留。

在来源提交的独立checkout核对原生Godot和runner/guard SHA，将candidate三份生产.gd.txt和driver.gd.txt恢复为.gd原名，连同overlay_manifest.json、freeze.json置于scratchpad/camera_resume_20260908并加.gdignore；不要把新模块归档UID复制进来源scripts，隔离导入会生成。运行：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 4c0fafce921bfa98e31c9f9b7c1b0824a9c73962 --freeze-sha256 2318e00e4286dc9b7d21c58082aa1704b3508f70472b0a77fbde3e1034504321 --candidate scratchpad/camera_resume_20260908 --expected-files 3 --driver driver.gd --driver-destination tools/camera_resume/driver.gd --suite camera-resume-native --prefix "[camera resume QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可换受控短绝对路径；历史路径不作新写入目的地。未提供完整Battle继续、磁盘槽、跨进程、Steam账号或画面排版结论。[合同与后续](../../docs/CAMERA_RESUME_20260908.md)。
