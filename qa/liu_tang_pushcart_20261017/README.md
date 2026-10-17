# 刘唐推车接入验收（2026-10-17）

最终完整冷私有工程/PCK/实际OpenGL514项通过、79张截图；6602冻结来源在原工程和私有编译副本零漂移，28纹理像素/尺寸/mipmap保持，锁已释放。[原收据](receipt.json)、[原报告](report.json)、[39张直接目检](direct_review.json)、[车轮校准](wheel_calibration.json)均在本目录。PCK留工程外：1221623740字节，SHA-256 `c563677bdf851ec27c00914fcb14a8c1bea5e499f64131d35abc1a6b6c3f8cea`。

实际原短章mission取货回调设置货物元数据；三尺寸/四向所有推车帧及真正物理行走四阶段通过。受击改用原场景实际攻击者，触发现有受击机制；人物放手退缩/恢复，反击用原持刀动作，独立车不随之旋转或变红。原mission消费者驱动真实移动并交付一次，退出携货图；实际倒下触发原drop。未改关卡逻辑/地图/定义/伤害/订单或存档字段。CARRY/药倒前提与取货/采样位置、无关单位冻结和关雾是明确夹具，不是完整酒计或整关通关。

保留3次未进入Godot的暂存失败记录：来源身份目录保护、MSIX逻辑/实际位置差异、过长路径。其重复来源副本核对可重建后收回，Git原对象+198份差异ZIP及完整清单留工程外；实际原生工程/PCK/截图、失败收据/档案未移除，见[收回记录](reclaimed_unstarted_staging.json)。首个450项运行有4受击断言失败（无攻击者不能触发原退缩）；第二个450项自动通过，但目检发现按每帧鞋底对齐导致车轮跳动，拒绝当作美术通过。原证据分别在`rejected_native_hurt_sender/`和`rejected_visual_wheel_drift/`。

复现：只读`python -X utf8 -B tools/build_liu_tang_pushcart_20261017.py`；本机完整新批用`python -X utf8 -B tools/run_liu_tang_pushcart_20261017.py --run --checkout-staging --work-root C:/CodexQA/liu_cart`。无`--run`只预检28纹理。本机需显式短绝对工作路径，默认LocalAppData经MSIX映射后可能过长；目录/链接保护及identity规则均保持。

本批仅接入刘唐携货身体和中断停车。其他同伴、落地/交付货物仍旧担图，原三目标/肩挑文案与七车十一担对应仍需修正；轮转连续性、拥挤取货场景、完整UI/性能另验。没有Steam/main更新，不是完整原著剧情/战役/续玩或整库美术完成。[实现及原著边界](../../docs/LIU_TANG_PUSHCART_20261017.md)。
