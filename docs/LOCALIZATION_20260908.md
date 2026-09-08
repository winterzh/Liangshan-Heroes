# 四语文字本地化

本批范围为简体中文、繁体中文、英语和日语。主菜单左上角和设置页提供语言选择，当前界面立即更新；语言偏好单独存入 `user://language.cfg`。首次启动按系统语言选择，未支持的系统语言回退英语。`zh-Hans` 选择简体，`zh-Hant`、台湾/香港/澳门选择繁体。

## 文本与数据

原简体中文字符串作为查询键，译文集中在 `assets/localization/`。`catalog.json` 是运行时唯一词库；其他 JSON 是可维护的分片，`glossary.json` 解决跨分片名称和术语差异。英文与日文按当前校订源文翻译。108 人生平已于后续批次按一百二十回本重写并附回目，详见 [文本校订](TEXT_REVIEW_20260908.md)。繁体使用 OpenCC `s2twp` 转换，并沿用专名；此转换不能替代区域用语和母语审校。

四语首批完成 4,350 个玩家显示源字符串及108篇传记（后续校订为 4,358 个显示源字符串，见 `qa/text_review_20260908/README.md`），完整性检查缺失0、格式错误0。另有120个精确列明的内部/美术字符串不计入显示覆盖率；该计数不替代交互和母语质量验收。

`Localize` 在其他 autoload 之前注册四种 Godot Translation。简体也注册原文恒等表，以免英语回退替换原文。动态文本先翻译模板，再插入原数值；`{v}`、printf 参数顺序和换行由构建检查验证。需要即时刷新的文本使用 `bind_text`、`bind_format` 或只读的 `bind_render`。绑定随控件离开场景释放；动态单位状态由 HUD 刷新，不保存捕获已释放单位的闭包。

本地化位于显示边界：单位键、技能键、阵营、关卡 ID、成就 ID、数值、存档内容和场景胜负规则继续使用原始数据。场景编辑器选项保留原值，名称和对白输入控件禁用自动翻译。Steam 成就导出仍返回原始定义，游戏内视图另行展开译文。玩家创作内容不纳入内置词库覆盖率。

## 界面与字体

使用 Noto Sans CJK Regular 字体集合；简体、繁体和日文选择对应字形，英语使用该集合的拉丁字形。字体与 OFL 许可证随导出包分发，下载来源及 SHA-256 见 `assets/fonts/provenance.json`。

战役卡片支持标题换行并在列表内滚动。任务框仍默认收起，展开详情在战场与指挥区之间滚动。顶部军情避开实际资源栏宽度，英文允许两行；即时消息向上扩展。技能和命令卡保持原操作面积，长名称明确显示省略号，悬浮或长按说明卡展示完整名称与说明。

## 维护与复现

修改分片或术语后重建词库；Python 仅在构建时使用，游戏不依赖 Python。构建依赖 `opencc-python-reimplemented==0.1.7`：

```powershell
py -3.14 -m pip install --target scratchpad/localization/deps opencc-python-reimplemented==0.1.7
py -3.14 -X utf8 -B tools/build_localization.py --opencc-path scratchpad/localization/deps --strict --report scratchpad/localization/merge.json
py -3.14 -X utf8 -B tools/localization_catalog.py --validate assets/localization/catalog.json --require-complete --report scratchpad/localization/coverage.json
py -3.14 -X utf8 -B tools/run_localization_qa.py --godot "$env:GODOT_PATH" --out scratchpad/localization/runtime
```

`run_localization_qa.py` 为每次检查设置独立 APPDATA、LOCALAPPDATA 和 XDG 目录。`--mode visual` 生成主菜单、关卡、设置、图鉴及传记画面；`--mode battle --level 1..8` 按内部关卡编号检查开场、开战、暂停、切换和恢复；`battle-headless` 检查相同行为而不生成画面。`--mode preference` 可在共享的隔离 `--profile` 中检查跨进程保存、回读及环境覆盖。

`run_localization_package_qa.py --godot "$env:GODOT_PATH"` 导出 Windows PCK，核对四语词库哈希、实际翻译、字体/许可文件，再启动包内真实主菜单。测试探针由外部命令加载，`tools/` 仍不进入发布包。

开发诊断可通过 `LSH_LANGUAGE=zh_CN|zh_TW|en|ja` 临时指定语言，该覆盖下的选择不写回语言偏好。正常玩家操作不要设置此变量。

## 验证边界

检查结果与逐项覆盖清单见 `qa/localization_20260908/`。自动检查覆盖脚本解析、模板参数、字形存在、语言偏好保存、界面切换保持场景/单位/数值，以及自定义规则和保存回读。截图检查不替代完整八关通关、移动设备实机测试或英文/日文母语编辑审校。场景牌匾、旗面等美术内的书法保留；诊断字符串和基于原文的内部分类不作为玩家界面译文计数。

本批为源码与本地包验证，Steam 上传和语言支持选项的发布需另行明确授权。
