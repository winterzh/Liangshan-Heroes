# 单位跟随及贴图特效原生 QA

来源`0a51107243da347707386309ecfc2d9edd1bdabc`，最终运行`overlay_20260908T004341Z_877c6ad4`，freeze`f3c73048aa1b262fd21372dce822afabe7ccf233ac3d5bff324fc524bd82ac64`。最终6587条记录=5810来源SHA+776非来源断言+1像素诊断，全部通过。原有439项回归保留；新增337项。12个原生类、68个脚本字段；实际帧记录['linked_entity_frames=164', 'linked_none_frames=252', 'linked_expired_frames=237']。主窗口0×0、Windows Vulkan Forward+、隔离user://，Godot版本/二进制SHA、保护门禁和终止回执见runs内文件。

三组真实idle对照覆盖有效/空/已释放引用、目标移动、蓄力和锁定结束、死亡及释放、贴图/缓存/自然退出保持；完整HELD世界中默认Art准备和新Unit引用回绑单列。没有把组件生命周期或环境专用像素回归当作新增特效可见画面、整场激活和跨进程验收。完整范围见[实现说明](../../docs/LINKED_FX_RESUME_20260908.md)。

R1原生6535条记录通过；复核增加了激活前实际实体释放/编号变化、回调/元数据/渲染/变换变更拒绝，以及默认工厂贴图飞斧的准备核对。所有实际运行均归档于runs，SOURCE_PINS核对来源及受测副本，installation列明晋级文件。生产文件从最终受测字节复制，保留原有换行；新UID来自隔离Godot导入。

复现需来源提交独立checkout，将candidate中的.gd.txt恢复为原.gd文件名放入scratchpad/linked_fx_20260908，保留.gdignore、manifest和freeze；新脚本UID由原生导入生成：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 0a51107243da347707386309ecfc2d9edd1bdabc --freeze-sha256 f3c73048aa1b262fd21372dce822afabe7ccf233ac3d5bff324fc524bd82ac64 --candidate scratchpad/linked_fx_20260908 --expected-files 4 --driver driver.gd --driver-destination tools/linked_fx/driver.gd --suite linked-fx-resume-native --prefix "[linked fx QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可更换受控短绝对路径。完整玩家继续、Steam持久绑定及原性能/美术/长时/双机/真人要求仍待完成。
