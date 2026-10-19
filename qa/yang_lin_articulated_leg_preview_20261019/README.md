# 杨林连续原画的分段关节候选

双击[viewer.html](viewer.html)可看四向走路、依次收脚、停走和三档速度。复用连续腿v2与原上身PNG，不重绘或清理原像素。腿部原画在膝踝处分区：膝前后各18源像素、踝前后各14源像素保留重叠，鞋、小腿、大腿依次绘制；三维骨长仍各135，图像宽度固定0.32，鞋固定0.28。具体分层/步态是美术实现，非原著规定或伤残状态。

上一轮WebGL连续网格在弯膝处出现翻折。本候选改用三个保持方向的矩形变换，独立核对实际Canvas `getTransform()`所得2424次腿部绘制、4848个矩形角点三角形，有向面积均为正。这只证明各分段内部不翻转，不证明不同分段间没有重叠、接缝或穿插。旧失败网格和来源边界报告原样保留，后继不补签旧批次。

## 实际结果

13秒、812次浏览器绘制，覆盖半速/正常/加速及三次停止区间；[原始报告](actual/run_v1/browser_report.json)、8张PNG和[连续画布视频](actual/run_v1/continuous_canvas.webm)保留。8图与完整页面已目检，膝部仍有尖角/接缝，腿部偏细、上身僵硬和步频尚需调整，没有人工完整连续视频验收。

[独立复核](actual/run_v1/independent_verification.json)核对808条记录、8条腿各至少90次样本、212组支撑点、实际绘制矩阵、相机与位移积分、视频解码。[收脚复核](actual/run_v1/recovery_verification.json)确认三个停止区间四方向依次抬脚收回，根位置不动。

首次独立核对因沿用1e-6数学容差失败，原代码与失败数值保留。复核发现本次Edge的实际鞋部Canvas矩阵为float32：逐项与理想矩阵的float32舍入相同，靴底参照映射误差最大约1.06e-5地图单位，固定支撑点显示误差最大约1.83e-5。后继检查按系数的实际舍入误差计算上界；骨长/相机/距离等数学检查仍用原容差，不把渲染舍入称为绝对零漂移。这不是物理接地或自然步态标准。

腿原稿八个外部采样边界通过，上身旧alpha来源资格仍失败，内部关节分区为有意重叠绘制，不宣称内部切线透明。第44回只据人形和浑铁笔管枪，服饰/腿部拓扑属于美术解释；普通/获救/被缚状态与既有技能不变。

本批未接入真实Unit/Godot，没有转向、坡地、碰撞、完整鞋底/重心、图鉴/HUD、包内、性能或自然步态资格，生产采用0。全库人物其他动作、场景、船只、特效、UI和性能继续。

## 复现与冻结

HTML已嵌入两张原PNG，无需依赖即可看。自动入口沿用独立已有Edge与工程外私有Playwright/profile：

```text
python -X utf8 -B qa/yang_lin_articulated_leg_preview_20261019/run_playwright.py --deps <私有SDK目录> --output <全新工程外目录> --browser-exe <已有Edge路径>
python -X utf8 -B qa/yang_lin_articulated_leg_preview_20261019/verify_runtime.py <该证据目录>
python -X utf8 -B qa/yang_lin_articulated_leg_preview_20261019/verify_recovery.py <该证据目录>
```

需要已有Pillow、ffprobe和Playwright 1.64.0。依赖/profile不进入Git，未更改用户登录profile或系统配置。冻结输入/原始DOM/POST/视频/截图、第一次数值失败及后继复核逐字节归档，索引见`actual/archive_index.json`。runtime_receipt存在后禁止覆盖构建。

129项当前运行基线、16项车轮保护、81项其他任务文件与HUD、26份此前待验证本地文件保持，main/Steam未操作。原Godot单一等待队列仍在，外来占用标记未改。
