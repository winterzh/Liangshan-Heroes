# 阮小七推车分层人物原稿与原生美术预览

本批把人物与车体分开制作，解决整图反复重画时人物变大、车轮罩布也随稿变化的问题。12份原PNG（9四向+3单向）共39视图，全部直接查看；原字节、完整内置绘图请求、31引用绑定/10独立引用SHA及逐方向几何见素材prompt_set.json与source_geometry.json。包含未采用稿，不能称12份合格成品。`.gdignore`隔离，生产路由/资源未改。

两次实际Godot4.6.3/OpenGL美术预览成功，4张原PNG全部直接看过并原字节留存native_preview/01、02。真实加载3份冻结原图和固定渲染配置，用同一车体分别与新待机人物、旧持刀身体对照；preview.gd/project.godot/config.json/日志/收据完整保留，外部冻结输入SHA保持。第二批仅改后视固定位置和预览排版。首次体量对照支持分层方案，但高度由配置校准，不能当最终人物体量/握把/全部步态验收。

这是原生CanvasItem美术预览，未运行正式游戏Battle、未导出或挂载游戏PCK；原PNG直接创建ImageTexture，未验证Godot导入mipmap。既有运行版8a95f674的1417项不能转记给本稿。两次预检遇共享忙均在创建工程/启动引擎前退出；自然空闲后复核再运行，未终止对方或清理其锁。

未完成：完整对侧支撑腿/摆腿循环，西南单图头顶边界与握指，后视过渡步上肢位置，四方向一致体量/接触遮挡。native_preview_review.json与direct_review.json逐项保留；新SW交叉步是腿姿参考，头顶贴边未纳入候选采样。NW单图保留近左腿后撤抬跟/远右腿前伸，仍待游戏实景验证。姿势名不是生理步态资格，拒收稿不能凑入四相位。

只读检查：`python -X utf8 -B tools/inspect_ruan_xiaoqi_pushcart_layers_20261018.py`，核对12图/39格、仓库内引用SHA、尺寸/alpha与候选不截强内容，不写像素或给予运行资格。latest_external_preview_helper.py是本机第二批实际助手原文，包含本机路径，仅作来源记录；跨电脑重现应在新工程外目录复制原3图（路径/SHA见收据）、对应config/preview.gd/project.godot，再以本机Godot运行`--path <新目录> --script res://preview.gd --rendering-method gl_compatibility --audio-driver Dummy`，先串行取得共享引擎空闲。不能直接对旧冻结工程运行或改写原记录。

原著仍按第15/16回既有身份/黄泥冈依据，确切服色/发髻/裸足/车构/姿势为美术解释；未新增情节或改阮小七结局。七车十一担、文案、其他人物/场景/特效/UI等整体美术仍在后续范围。本轮只同步stable，未合并main或更新Steam。
