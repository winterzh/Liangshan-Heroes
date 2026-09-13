# 首批四人肖像与图鉴 QA

本批为宋江、林冲、孙立、扈三娘的独立肖像、常规HUD同源头像，以及实际图鉴四方向预览。采用 Godot 4.6.3、工程外冻结源码、独立APPDATA/LOCALAPPDATA/TEMP与Steam禁用环境；原生窗口不可聚焦且位于20000,20000，没有Computer Use输入，也没有修改玩家存档。

## 批次历史

- `20260913_210847_995b9bc2`：导入成功，QA静态引用Defs引发Localize编译依赖；改为autoload初始化后的延迟加载。属于QA初始化问题。
- `20260913_223741_8f75f659`：1784项诊断中2项失败。单次0.34秒时钟采样不可靠、聚义厅本来合法为空却被要求非空；分别改为实际帧有界采样与原链精确比较。
- `20260913_234839_467a69f5`：自动检查3689项通过且13张原生PNG完成，人工目检发现新动作只约60–90像素高，未接受为最终画面。固定脚下18像素过度限制缩放，改为整组内容与地面锚共同取景。
- `20260914_000243_5729cec4`：最终同版批，具体通过数见[联合核验](validation_summary.json)和[原始收据](native/20260914_000243_5729cec4/receipt.json)。明确复用上一个成功导入的资源缓存；新的源码、类缓存与三个profile独立新建，fresh_import=false。

最终QA实际打开codex.tscn，经真实角色按钮与方向选择信号检查4人×4方向×2动作的32组精确资源、帧顺序和元数据。全帧保持公用尺度/地面锚、图像内容在框内；新增取景空间利用率与每个移动姿态至少半框高度守卫。四人的最小移动内容高分别约150.1、122.5、164.6、149.4像素（232像素预览框），没有通过裁掉兵器换取放大。

常规 Art.avatar_texture 与肖像使用同一真实Texture；明确指定的剧情variant优先，不把同源断言扩到囚徒等造型。旧安道全、聚义厅合法空框及箭楼八向循环保留。简中、繁中、英语、日语均用真实新场景检查，新增五个词条经严格本地化构建，现有生平被检查翻译路由与换行，不据此声称全库原著生平审查完成。

## 肖像与人工目检

四张PNG由内置imagegen生成，原生1254×1254 RGB，标准导入探针实际读到1024×1024；源字节未改。独立原著/候选审查与精确来源见[static](static/)和[生成契约](../../tools/contracts/codex_identity_20260913/README.md)。肖像SHA不同只证明文件身份，逐人面貌结论来自人工目检。

最终共13张原生PNG，人工目检范围记录在[manual_review.json](manual_review.json)：四人对照、四位图鉴、孙立四朝向、三张其他语言页面、旧安道全与箭楼。截图只代表所摄帧；其他帧的边界/取图由自动检查覆盖，不能据此宣称高帧动作质量或完整战斗验收。

宋江战斗肤色、孙立战斗头饰和须式仍开放；本批未改战斗资源、游戏数值、保存入口或Steam包。源码使用既定stable分支同步，最终提交SHA由Git记录及交付回复给出。

## 复现与证据

工程外路径占位替换为本机可写目录，引擎通过现有godot.local.txt/GODOT_PATH/--godot配置：

```powershell
py -3 -X utf8 -B tools/run_codex_identity_qa.py --repo . --work-root "X:/QA/codex_identity" --timeout 240 --run
py -3 -X utf8 -B qa/codex_identity_20260913/verify_evidence.py 20260914_000243_5729cec4
```

默认导入+headless+visual串行，--headless-only仅诊断；--cache-from须明确指定可回读先前成功导入批。归档仅证据、源清单和实际QA脚本，不含私有profile、Godot缓存或整份冻结工程。只读verify_evidence核对所有归档artifact SHA、最终当前生产来源、四肖像、精确提示词及生成prior链，人工目检另记录。scripts/codex.gd与scripts/art_db.gd本批保留CRLF，冻结/提交字节一致；仅查逻辑差异可用git diff --ignore-space-at-eol。
