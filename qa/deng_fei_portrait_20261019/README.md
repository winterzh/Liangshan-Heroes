# 邓飞独立头像来源，2026-10-19

三份1254×1254 RGB内置imagegen原稿保留原始字节；`portrait_v3`仅选为后继Godot比较候选，尚未接入生产。暖纸背景为有意设计，不要求透明。没有本地绘画或重采样修改原PNG。

第44回公开文本、取证来源及精确引文在`chapter44.txt`、`chapter44_source.json`、`canon_basis.json`。原著明确“双睛赤”“能使一条铁链”；脸型、卷发束发、胡须、褐色布甲沿用当前身体参考，纸纹沿既有头像风格，均标为美术解释。不得推演为魔眼、狻猊变身、火焰技能、新剧情或死亡；普通头像里的链条也不改变获救/被缚角色的武装状态。

`prompt_set_v3.json`记录三份精确提示和输入角色。v1由身体身份和施恩头像风格参考生成，v2/v3分别编辑上一版；v1脸部偏小，v2顶部发髻裁切，v3恢复细纸边并保留近景。实际对比图为`readability.png`、`readability_portrait_v3.png`，均已目检。64px面部/胡须较v1清楚；32px不能声称红眼细节可辨。

现用路由仍是`portrait_atlas_regions.gd`的`deng_fei → assets/portraits13.png [0,0,410,400]`。没有修改ArtDB、图鉴、HUD、人物动作、关卡、编译包或Steam。原生验证被共享占用声明挡住，本批只有来源与浏览器静态阅读检查。公孙胜原有等待队列保持，不新增并行Godot任务。

复现近景静态对比（需要Pillow和本机Edge，输出目录必须不存在）：

```powershell
python -X utf8 -B qa/deng_fei_portrait_20261019/render_portrait_variant.py portrait_v3 D:/CodexEvidence/shuihu/deng_fei_portrait_20261019/readability_replay
```

工具按原字节复制来源，SVG只负责显示图集区域和256/128/96/64/32px大小，浏览器输出截图；不是修改美术PNG。已执行SVG中的`images/`相对引用由工具在私有输出目录创建；工程内副本是原始归档，独立打开时应通过上述工具重建引用。浏览器profile保留工程外，不进入Git。

`record_portrait.py`、`record_portrait_variant.py`、`closeout.py`是仅执行一次的来源/收尾记录器；旧证据禁止覆盖或补签。`preservation.json`记录129运行文件、16保护文件、81外来文件及HUD原SHA不变。人物/场景/战船/特效/UI/性能完整美术目标仍未完成。
