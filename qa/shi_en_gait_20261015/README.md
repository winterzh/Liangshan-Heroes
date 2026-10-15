# 施恩四向待机与行走：原Level7通过并接入

`native_pass/`完整保存实际通过批的原始日志、报告、65张PNG与SHA归档清单：冷导入/mipmap导入/导入探针/原Level7窗口均退出0、错误0，原生导入60项、场景372项全部通过。原Battle移动指令处理器驱动原施恩四向实际寻路；其余单位和Battle模拟明确冻结。三尺寸逐帧矩阵属于视觉采样，四向待机、实际NE移动和1920/960代表图已直接查看。

`runtime_adoption_receipt.json`记录34个生产运行文件与通过批字节完全一致、既有源保护和12个新导入UID无冲突；`runtime_visual_review.json`记录实际看过的画面。工程普通施恩已采用这批idle/walk，原头像和非战斗/技能定义不变，详见[接入说明](../../docs/SHI_EN_GAIT_RUNTIME_20261015.md)。

`native_failures/`保留五个旧失败批日志/报告及原测试脚本文字副本。失败分别涉及数值类型比较、隔离Pillow依赖、SceneTree取Art方式及屏幕外模拟鼠标位置。独立最小输入测试在`D:/CodexTemp/shi_en_input_probe_20261015/`确认后者限制；本轮不把移动指令验收写成鼠标点击通过。失败批PNG和全部冻结工程仍保留外部原目录，没有覆盖或删除。

`runtime_plan.json`和builder记录接入前几何，原始来源/生成清单的未接入字段保留阶段语境；后续接入事实以独立adoption收据为准。近距离头像一致、完整循环审美、攻击/受击/倒地接入、PCK/SDK/平台与整套美术仍开放。

以下为来源候选批的历史记录。

# 施恩待机/步态来源候选

12张原生RGBA、12份完整请求；4向待机共4姿势、4向步态共16关键姿势。`source_manifest.json`逐项绑定实际原PNG/请求SHA、原区域和RGBA SHA、明确弃用区域、透明度、候选脚点与来源统一比例。生产未接入，`.gdignore`隔离导入/导出；不作为完整人物动作、Godot、PCK、SDK或平台验收。

`prepare_shi_en_gait_candidates_20261015.py`只复制原生字节、读取RGBA、写JSON和HTML，不输出或修改PNG。校验原字节/请求、真实透明、区域完整、所有前景选择或明确弃用，以及四个不同关键姿势；不同像素不能单独证明步态质量。`candidate_preview.html`只以原生区域等比采样，脚点只是候选几何。静态HTTP服务的浏览器逐帧结果另保存五张`preview_*.png`。`before_source_scale_normalization_passing_b.png`保留首次独立来源比例不一致的画面；新预览没有覆盖它。

`visual_review.json`记载直接原图/逐帧检查、已排除姿势和仍需核对的项目。`source_verify_output.json`为本批CPU来源复核的实际输出，`verification_receipt.json`绑定工具、输入、预览与截图SHA。此检查没有启动Godot；共享引擎正在进行盲盒原生测试，后续水浒实景必须串行等待其自然结束。
