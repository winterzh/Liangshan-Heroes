# 施恩待机/步态来源候选

12张原生RGBA、12份完整请求；4向待机共4姿势、4向步态共16关键姿势。`source_manifest.json`逐项绑定实际原PNG/请求SHA、原区域和RGBA SHA、明确弃用区域、透明度、候选脚点与来源统一比例。生产未接入，`.gdignore`隔离导入/导出；不作为完整人物动作、Godot、PCK、SDK或平台验收。

`prepare_shi_en_gait_candidates_20261015.py`只复制原生字节、读取RGBA、写JSON和HTML，不输出或修改PNG。校验原字节/请求、真实透明、区域完整、所有前景选择或明确弃用，以及四个不同关键姿势；不同像素不能单独证明步态质量。`candidate_preview.html`只以原生区域等比采样，脚点只是候选几何。静态HTTP服务的浏览器逐帧结果另保存五张`preview_*.png`。`before_source_scale_normalization_passing_b.png`保留首次独立来源比例不一致的画面；新预览没有覆盖它。

`visual_review.json`记载直接原图/逐帧检查、已排除姿势和仍需核对的项目。`source_verify_output.json`为本批CPU来源复核的实际输出，`verification_receipt.json`绑定工具、输入、预览与截图SHA。此检查没有启动Godot；共享引擎正在进行盲盒原生测试，后续水浒实景必须串行等待其自然结束。
