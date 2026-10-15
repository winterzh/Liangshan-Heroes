# 七种植物的原图可见范围与落地校准

现有Level5的四种芦苇、老柳、阔叶树和幼树，声明的可见范围与原512 PNG的实质alpha范围不一致，部分脚点跟随旧范围漂移。本轮只更新`CampaignEnvironmentArt.VISUAL_CALIBRATIONS`的七条`visible_bbox_xywh`，脚点沿现有源SHA绑定逻辑由新可见底部计算。原PNG、摆放位置、原地图、单位、玩法和角色属性不变；没有重绘、缩放源图或更换素材。

`qa/plant_bounds_20261015/source_calibration.json`保留初始/实测范围和原PNG SHA，初始`native_qualified=false`是准备时快照，不改写成结果。`native/`保存实际原Level5私有运行的原始导入/窗口日志、309项检查、22张三尺寸截图和收据，原字节回核归档。原图来源核对、七种原摆件的实际纹理/脚点、错误关卡拒绝、绘制底部对原逻辑锚点、地形/原单位不变均通过；1280/1920/960窗口分别采样，不是CPU或浏览器模拟。

直接查看七种1280实景及另两尺寸代表截图，未见植物底部脱离地面、白框或源图截断；小尺寸仍有原任务说明覆盖部分地图、顶部目标文字省略等UI问题，保持开放。三尺寸原图及每个原实例检查在报告，代表截图检查不扩大为全地图逐像素验收。测试显式冻结Battle/单位及摄影状态，不把截图FPS计数当性能通过，不代表整章玩法或真人验收。

实际批：`D:/CodexTemp/plant_bounds_art_20261015/20261015_080657_4be47fa6`。导入与窗口均退出0，错误0，冻结输入与当前生产输入零漂移，独立档案与共享锁正常释放。来源复核`python -B tools/calibrate_plant_bounds_20261015.py --verify`；原生复现`python -B tools/run_plant_bounds_art_qa_20261015.py --run`，先等共享引擎空闲，绝不抢占他人进程。

同轮完整资源PCK的原Level7六摊/四酒肆通过209项原生检查，22截图；该结果单列在`qa/packed_environment_art_20261015/full_world_pass/`与环境PCK说明。它不将本Level5植物的源码窗口资格扩大为PCK中七植物全部实景，也不将任何结果扩大为发布EXE/SDK/Steam或全美术完成。
