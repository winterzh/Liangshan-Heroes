# 吴用推车四阶段：新原稿与真实单位候选

内置imagegen新增6份1254方形原字节RGBA PNG，完整实际工具参数/提示/输入SHA见prompt_set.json及tool_prompt_*.json。选用native_originals/contact_a_v2.png、passing_a_v1.png、contact_b_v2.png、passing_b_v1.png；复用上一批idle_rear_grip_v2.png作待机。contact_a_v1因上身/手距/体量漂移退回，contact_b_v1因重复A的支撑腿退回，原图保留。没有本地绘画、镜像或PNG像素修改。

四向固定体量原生比较68项通过：12张纹理各5项尺寸/原PNG SHA/RGBA格式/原生像素/角点检查，加8项截图保存，不是68个游戏场景。actual_preview/原收据、日志、驱动、报告、8张图全部原样保存；直接查看4张compare，grid四图未逐张查看。新四帧均可辨别A/B相反支撑腿及过渡阶段，背面远拳不再露在腰后。背面远手遮挡不冒称已测接触；整循环自然步态、脚底滑动与实际单位仍未接受。

registration_inputs.json固定每方向一个来自已采用空载吴用的人物reference，五阶段仅按掌心平移；原车在各阶段的变换完全相同，未用逐帧缩放掩盖差异。手点人工估计约5原像素误差。build_candidate.py建立未接线的5人物PNG、共享原车、12个SpriteFrames/24姿势，默认只读校验。新资源原PNG与内置来源逐字节一致，资源文本校验完成；新12资源的实际Unit加载尚未执行。

真实游戏候选只在candidate_unit.gd.txt和candidate_campaign_art.gd.txt增加吴用独立人物/车接线，保留已采用晁盖和阮小七所属路径；Root两段代码未修改。unit_driver.gd.txt使用当前短章、明确药酒后携货QA阶段、真实拾取回调、四向普通移动、停止/受击恢复/卸货，并检查晁盖和阮小七自己的帧仍有效且拒绝吴用帧；不是完整酒计或存读档验收。

已新复制7016个当前规范文件，私有路径和SHA见unit_preparation/。原共享引擎正在运行其他项目全套测试，首次准入在原生启动前拒绝，不是游戏测试失败。wait_then_run_unit.py只启动了一个排队进程：等实际Godot进程和共享lease同时消失再启动run_unit_native.py，保留独立profile、冷导入、源码身份、命令/日志/报告。续作须先查看工程外unit/queue/state.json并核实实际进程/已有会话，不能因观察超时重复开队列或删外来锁。排队不算已执行、通过或生产接入。

当前106运行、16保护/81外来文件和HUD保持。Root新增23个未接线候选资源，使旧晁盖完整包不能代表当前完整来源或吴用验收；旧包的共同输入零差异，新输入及私有UID等差别见相邻chao_gai_layered_full_pack_20261018/source_identity_drift_after_wu_preparation.json，原通过记录不改写。

第16回赤膊贩枣客/朴刀，第14回清秀面白须长，第15回草鞋为依据；黑头巾/灰裤、推车时收置朴刀、具体动作和时序是游戏美术解释，无新兵器/法术/剧情/正史伤亡。普通及受击状态的既有朴刀必须保留。全库人物、场景、战船、特效、UI、性能和其余车轮仍继续，main/Steam不变。
