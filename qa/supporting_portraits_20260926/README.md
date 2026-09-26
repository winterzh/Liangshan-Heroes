# 陆谦与祝朝奉头像 QA · 2026-09-26

私有冻结批 `20260926_163954_72a7e503`，**336/336 检查通过**，3385 个冻结输入在工作区与副本均零漂移。Godot 4.6.3 Compatibility：导入 106.343 秒、头像/模型对照 9.524 秒、实际 HUD 40.052 秒。保留已知 GLES3 2D MSAA 警告，无脚本或资源错误。

## 改动与来源

两幅 1254×1254 原生 PNG 由内置 `image_gen` 编辑生成，原字节复制到 `assets/characters/supporting_portraits_20260926/`。完整提示词、原立绘编辑目标、生产四向参考、风格参考及哈希见 `tools/contracts/supporting_portraits_20260926/`。

两人旧头像使用全身立绘。新头像为近景半身构图，陆谦保持蓝灰袍、帽上铜饰、瘦脸短须；祝朝奉保持褐袍、灰白长须、年长宽脸。仅共享笔触和纸纹，服色、年龄和脸型均保留独立特征。现有身体及动作资源通过清单逐文件哈希锁定，没有修改。

## 验证与目检

- `report.json`：来源哈希、导入尺寸、标准头像与真实图鉴路由、两人四方向实际模型来源。
- `ui_report.json`：八名原核心英雄加本批两人，共十人的实际 Battle/HUD 头像，以及既有剧情身份、防串脸检查。
- `model_alignment.json`：两人四向的真实加载来源与独立方向标志。
- 共保存 20 张引擎截图。本轮逐张目检其中七张：两幅 `*_model_alignment`、两幅 `*_codex`、`hud_lu_qian`、`hud_zhu_zhaofeng` 和 `portrait_sizes`；脸部、帽型、服色和四向造型对应，32px 以色块和轮廓区分。
- UI 夹具会顺序创建和移除人物；左侧阵亡栏与加载时 FPS 不是正常战斗或性能验收。未验收手机、全部动作帧或发布包。

## 复现

```powershell
python -X utf8 -B tools/run_hero_portraits_qa.py --work-root <工程外目录> --contract tools/contracts/supporting_portraits_20260926 --ui --run
```

`--ui` 现将指定清单传入 HUD 检查，自动纳入本批人物，同时保留八名核心英雄的回归。正常游戏启动入口不变。源码同步不代表 Steam 或 Android 已发布。
