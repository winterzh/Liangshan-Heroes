# 将领头像与战斗/图鉴统一验收 · 2026-09-26

## 结果

本地源码与生产素材完成：27 项新图/实际图鉴/尺寸渲染检查、229 项实际 Battle/HUD 与人物归属检查，共 **256/256 通过**。冻结批 `20260926_132556_cd4ede0f`，3363 个输入在源码与私有副本中均零漂移。使用官方 Godot 4.6.3 Compatibility；导入 223.580 秒、图鉴 12.045 秒、HUD 47.098 秒，三个步骤退出码均为 0，无脚本/资源错误。保留引擎现有 GLES3 不支持 2D MSAA 的警告。

- `receipt.json`：逐文件冻结清单、引擎哈希、运行步骤和零漂移结果。
- `report.json`、`ui_report.json`：全部逐项断言。
- `import.log`、`portraits.log`、`ui_portraits.log`：原始日志字节。
- `import_sidecars.json`：四份新 PNG 导入侧车的来源及哈希，原样从本次成功导入副本同步。
- `independent_readback.json`：归档、来源、生成原图与侧车的独立回读结果。

## 覆盖与目检

39 个人物剧情变体均验证标准身份、拒绝错误人物配对，并在实际 `Battle/HUD._port_tex` 检查显示结果。覆盖林冲、宋江、戴宗被缚，黄泥冈八人，江州李逵，大名府卢俊义/石秀等。另检查四名新增将领的标准战斗头像，八位本日补图人物的实际图鉴和八个不同的源图哈希，建筑/刑台/四类路人及三组剧情原图和 idle 动作保留。

已逐张目检 14 份引擎原生截图：四张 `*_codex.png`、九张 `hud_*.png`、一张 `portrait_sizes.png`。四位将领的白、绿、红、深铁色服装，长脸/宽圆脸/方脸及不同胡须可辨；256/96/64px 可读，32px 以服色和轮廓辨识为主。HUD 的剧情状态头像与对应标准图一致，没有裁掉面部或换成其他人物。

HUD 截图使用冻结黄泥冈战场逐一生成和选中人物的专项夹具；旁侧增加的阵亡英雄项来自夹具清理，截图中的 FPS 包含同步加载及截图开销。它们不代表正常战斗阵容、实战帧率、逐关通关或手机验收。身体/动作本轮未重绘，仍有历史美术待补。

## 复现与交付范围

```powershell
python -X utf8 -B tools/run_hero_portraits_qa.py --work-root <工程外QA目录> --contract tools/contracts/hero_portraits_commanders_20260926 --ui --run
```

使用现有本机 Godot 配置，共享引擎锁、独立用户目录、关闭 Steam；没有访问或改写玩家存档。生成工具为内置 `image_gen`，完整提示词、身份参考与原生字节哈希见 `tools/contracts/hero_portraits_commanders_20260926/`。文件名称遵循项目约定，旧来源与历史 QA 保留。

本批只同步 stable 分支的源码、生产资源、工具和文档；未打包、上传或发布 Steam/Android，也未合并 main。[实现说明](../../docs/HERO_PORTRAITS_COMMANDERS_20260926.md)。
