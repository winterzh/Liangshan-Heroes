# 韩滔四向生擒姿态

`captured.png` 是内置 imagegen 生成并逐字节复制的原生透明 RGBA；不进行裁切、缩放、镜像或像素编辑。参考为既有 `assets/portraits4.png` 顶行中格，完整实际请求在 `generation_request.json`，来源和 SHA 在 `generation.json`。

使用 Python 与 Pillow 运行本目录 `prepare.py` 重建清单与采样元数据，再运行 `tools/build_directional_spriteframes.py assets/direction4/han_tao_captured_20261005.json --write` 重建四个资源。去掉 `--write` 可核对资源。这里只选取图集区域、补虚拟方形边距和地面锚点，原图保持不变。实际 Godot 导入尺寸必须与清单一致。

仅用于通用韩滔 `captured` 状态；他保持存活敌军，不转为死亡、不换阵营。其他人物、剧情换装以及 unconscious/subdued/retreated/embarked 不借用此图。骑乘五状态及跨状态服装不一致仍待下一批处理。
