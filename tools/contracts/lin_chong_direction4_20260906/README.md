# 林冲通用战斗四向来源

`generation.json` 保留实际内置 image_gen 提示词和被采用素材的完整引用链。7张生产PNG保存在 `assets/characters/lin_chong_direction4_20260906/`；其依赖的中间输出和两张Godot三维迈步参照保存在 `references/`。未被引用的候选只保留哈希和提示词，不作为生产资源。

`lc_two_step_guide.gd.txt` 与 `lc_pose_guide.gd.txt` 是两张原始三维参照的精确生成代码。它们是本次生成证据，包含当时忽略暂存区的路径，不是跨电脑启动入口。图像生成后的PNG没有在本地抠图、裁切、重画或重新编码。Godot的导入缩放、AtlasTexture采样与透明留边由资源元数据完成。

`pose_recipe.json` 保留原图区域、身体/地面锚点、虚拟方框尺寸，以及被替换格的具体原因。最终运行尺寸、采样区域、偏移与状态顺序以 `assets/direction4/lin_chong_20260906.json` 为准。普通拉取只需导入已提交素材，不需要重新生成。

复核或重建排帧：

```powershell
py -3 tools/build_directional_spriteframes.py assets/direction4/lin_chong_20260906.json
py -3 tools/build_directional_spriteframes.py assets/direction4/lin_chong_20260906.json --write
py -3 tools/directional_character_sources.py assets/direction4/lin_chong_20260906.json tools/contracts/lin_chong_direction4_20260906/generation.json
```

第一条只读比较20个资源，第二条只写该清单明确列出的20个TRES，第三条用Pillow只读审计原生字节、透明度、导入、参考链及串格。工具不会修改PNG。原项目林冲身份参考的更早来源没有被本记录补造；四向姿态和低帧数动作仍需真人观感反馈。实现与当前QA见 [林冲说明](../../../docs/LIN_CHONG_DIRECTION4_20260906.md)。
