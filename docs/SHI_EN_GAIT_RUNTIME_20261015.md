# 施恩四向待机与行走接入：2026-10-15

普通施恩现在采用原生四向待机和行走资源：四向各1个待机、4个步态，合计20姿势、8份SpriteFrames。12张运行PNG与已保存候选原图逐字节一致，没有镜像、改画、拉伸人物或重写PNG。原Level7仍使用原施恩、原头像、攻击0、非战斗属性和空技能；剧情造型仍走原variant入口。

生产变更只有`Art.ORDINARY_CHARACTER_FAMILIES`中施恩的idle/walk一行，以及`assets/characters/shi_en_gait_runtime_20261015/`、对应8份`assets/anim/character_traits_v1_shi_en_gait_*.tres`和`assets/direction4/ordinary_shi_en_20261015_gait_v1.json`。同一来源统一等比；AtlasTexture透明边距对齐原生脚点，弱alpha轮廓扩大虚拟画布时以draw_scale补偿，不缩小或裁掉人物。导入启用mipmap、上限2048，实际12张导入尺寸与原图一致。

原始通过批：`D:/CodexTemp/shi_en_gait_runtime_20261015/20261015_090616_bdbaf976`。冷导入、mipmap重新导入、60项原生尺寸/来源检查和原Level7窗口均退出0、错误0。窗口372项检查全部通过，保存三尺寸65张PNG；原Battle移动指令入口驱动原Unit四方向实际寻路，各方向均有真实位移、正确朝向并到达原目标5像素内。其余单位和Battle模拟明确冻结，施恩身份/血量、其他单位和地图格不变。逐帧矩阵为冻结后的视觉采样，不能当作完整关卡或循环流畅度证明。

四向1280待机、NE实际移动、1920 SW步态、960 NW步态已直接看图，人物完整、脚点落地，没有白框、截断或借用镜像朝向。旧头像保留可见；近距离脸部精确一致和完整循环的审美验收仍开放。原始日志/报告/65图完整归档于`qa/shi_en_gait_20261015/native_pass/`，逐文件与外部原件SHA一致。

此前失败记录另存`native_failures/`：JSON数字数组类型比较、隔离APPDATA找不到Pillow、SceneTree入口不能直接引用Art，以及屏幕外窗口的模拟事件不能更新引擎鼠标位置。最后一项经独立最小程序确认。本批使用原移动指令处理器验证移动和美术，**没有把它写成真实鼠标点击通过**；旧失败报告未覆盖。输入投递问题仍是该屏幕外测试方法的限制。

`runtime_adoption_receipt.json`证明34个生产运行文件（含一行路由所在脚本）与通过批完全一致，其余5190项冻结输入在接入前一致、接入后仅路由及新增资源发生预期变化，新增12个导入UID与已有UID无冲突。生成清单保留最初`production_qualified=false`的来源/导入阶段字段，不追改旧证明；接入结果以独立adoption收据为准。

来源只读复核：`python -X utf8 -B tools/prepare_shi_en_gait_candidates_20261015.py`；运行几何只读复核：`python -X utf8 -B tools/build_shi_en_runtime_candidate_20261015.py`。`run_shi_en_gait_candidate_20261015.py --run`是接入前候选构建入口，拒绝覆盖已有资源；该轮实际输入及源码SHA保存在native收据和外部冻结工程，不能把接入后的工程当作无资源的初始候选重新生成。

后续攻击、受击和倒地已完成普通施恩接入及受控真实回调验证，见[三类动作接入](SHI_EN_FULL_ACTIONS_20261015.md)。本待机/行走批本身没有执行完整游戏、完整资源PCK、发布EXE、原生SDK、Steam上传或整套美术验收；七植物及旧环境PCK的既有通过记录保持独立。其他人物、场景、特效、UI和完整美术目标继续开放。
