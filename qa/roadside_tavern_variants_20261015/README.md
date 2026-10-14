# 快活林四间酒肆：2026-10-15

四处路边酒望此前统一绘制同一张备用 PNG；本批复用已验收网页原图 `assets/campaign/environment/art_full_20260915/taverns.png` 的四个既有 TRES 区域，固定裁切后确定性缩放为四张 512×512 透明 PNG。原图与 TRES 字节保持，未补画、镜像、抠像或修改玩法。

原有 PNG 优先路由自动选择各自建筑。Unit 持有实际绘制纹理，避免局部资源释放后 Canvas RID 显示白块；脚点及名称高度仅按已绑定 PNG SHA 的 alpha>=16 可见范围校准。名称高度新规则只显式用于这四项；头像沿各自世界纹理且查询不改变绘制元数据。

最终隔离批冷导入和 OpenGL 窗口化运行退出 0，错误 0，189/189 项通过。原生产 Level7/短决斗脚本生成四个原酒肆，检查原实例来源、alpha 全像素、opaque RGB、关卡限域、头像、脚点、名称、跨帧纹理引用和实际 framebuffer 屋顶白块守卫。1280×720、1920×1080、960×540 共 15 张局部/总览，另保留一张正常迷雾开局；HP、位置、半径、阵营、对象身份等绘制前后保持。源码与私有副本零漂移。

原16张截图和 SHA 全在 `native/report.json` 及原外部批中；仓库保留正常开局、总览、四间代表截图的原字节。`visual_review.json` 记录实际图像检查与仍开放事项，未生成或加工实景截图。

首次 `failure_load_order/` 在工具提前加载 GameMap 时缺少 Art 单例，未开始实景测试；改为延迟加载。第二次 `failure_unowned_texture/` 保留原白块总览，并因工具误调用 Unit 不存在的雾更新方法终止；已改用原 Battle._grid_build。随后生产 Unit 保留纹理引用，最终实际白块消失。失败收据没有改写为通过。

本批是四间酒肆的素材接入与显示验证；冻结演员/局部取消迷雾只用于明确的视觉夹具，不代表完整战斗、性能、整库美术、真人验收或平台发布。原平面摊位、其他建筑比例/地表接缝、人物身份与动作、特效和完整多尺寸 UI 继续开放。

复查来源：`python -B tools/prepare_roadside_tavern_variants_20261015.py --verify`。
复现原生：`python -B tools/run_roadside_tavern_art_qa_20261015.py --run`，须共享 Godot 空闲；使用新私有工程与 APPDATA，不读写玩家存档。初次准备工具不覆盖现有产物，已有批使用 --verify。
