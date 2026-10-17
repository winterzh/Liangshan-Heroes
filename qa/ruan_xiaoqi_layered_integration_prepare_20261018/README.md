# 阮小七分层接入补丁准备（尚未应用/运行）

candidate/中2份生产脚本候选、4份全链验收候选已准备，根生产脚本保持。campaign_art.gd.patch和unit.gd.patch已实际执行git apply --check，不应用文件；候选Python通过AST，实际执行候选全链入口的只读预检：声明180纹理、当前route=false/engine_busy=true/lock=true/native_launched=false。这个180是输入数，不是180项原生通过；GDScript尚未原生解析。

拟改行为：仅精确阮小七/hn_ruan_xiaoqi在level1携货时，且真实Atlas来自新家族并有bool型independent_cart元数据，才在原人物层前/后画同一独立车；空手、其他人、受击/挥刀旧身体、退场不额外请求该层。已有受击/攻击停车逻辑保留。新源图严格路径和显式AtlasTexture转换避免通用元数据借用。

静态原图几何还发现NE固定车顶部约-0.9632个body_size，人物约-0.7389，旧只看人物的标签可能与更高车体相交；候选标签取人物与独立车顶部的最小值再留原8单位间距。label_geometry.json是原图alpha>=64只读测量，不是实际头标遮挡验收。

4份候选验收保留真实私有来源归档、不可变owner/identity助手、实际新PCK差分导出与SHA包链/原生packed身份、纹理像素/mipmap/真实Battle机制验证；新检查覆盖严格层资格、固定车、原角色/兄弟隔离、头标与受击停车。只准备了代码，尚未执行这些检查，也未新增包；旧1417项和上一轮预览绝不转记。本机实际源路径和候选SHA在candidate_manifest.json。

下一步先在原prepared工程完成14纹理/24姿势导入与四向画面对照，处理体量/脚点/手把问题；通过后核对生产before SHA才复制这2份脚本及4份工具到真实位置，再新冻结/导出/运行完整接入验收。不要把candidate/当生产工程或现在启动全链，不能跳过未完成的画面对照。原prepared路径见shared_lane_snapshot.json，未重建、未清别人的锁；Win32_Process已确认盲盒完整测试控制进程及Godot实际存活，进度快照不是锁释放。

本轮无新人物/装备/剧情原著变更；原有第15/16回依据和美术解释保持。七车十一担、旧文案及整体人物/场景/战船/特效/UI目标不缩减。只同步stable，不合并main或更新Steam。
