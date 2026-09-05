# 田地接入 QA，2026-09-06

基线 `f0818c1`；新增田地源图与独立审核记录，运行逻辑/关卡/shader未修改。生产与原图为同一1254×1254 RGB PNG，源文件、提示词、实际生成记录见 [field来源](../../tools/contracts/environment/field_20260906/README.md)，实现与复现见 [说明](../../docs/ENVIRONMENT_FIELD_20260906.md)。

| 检查 | 结果 | 证据 |
|---|---|---|
| 静态路由 | 790项通过 | `router.json` |
| Godot运行路由 | 794项通过 | `runtime_routes.json`、`.log` |
| 真实画面对照 | 44项通过，Vulkan Forward+、RTX3070Ti、1280×720 | `render.json`、`render.log` |
| 错误注入与迁移 | 40项通过 | `selftest.json`、`selftest.log` |
| 生产与来源 | 37图匹配、32缺图、0错误、249缺口；退出1 | `audit.json` |
| 原36张生产图 | SHA全部保持原基线 | `receipt.json` |

`receipt.json` 固定27项测试输入和本批结果文件字节。`pixel_comparison.json` 对四组PNG进行只读像素比较；没有编辑截图。原历史inventory没有重新生成，独立审核增量只改变field一项。40项反例包括新审核文件丢失/漂移，原图、提示词、接入记录各自删除/漂移，其他新图仍拒绝无审核接入，以及新field不能被算作旧四张地表安装合同通过。

## 四组实机对照

`level3` 为当前祝家庄RTS，`level8` 为当前大名府RTS。每组 `before` 是同场景仅关闭field sampler的旧atlas，`after` 打开新图，`restored` 再关闭；每组恢复后的像素均与改前完全相同。场景/单位冻结，HUD与迷雾覆盖层隐藏，镜头固定；不是实战截图或性能测量。地形格、碰撞、动态占地、高度、自然地表mask及存档哈希均保持一致。

- [祝家庄100%改前](level3_100_before.png) · [改后](level3_100_after.png) · [恢复](level3_100_restored.png)
- [祝家庄150%改前](level3_150_before.png) · [改后](level3_150_after.png) · [恢复](level3_150_restored.png)
- [大名府100%改前](level8_100_before.png) · [改后](level8_100_after.png) · [恢复](level8_100_restored.png)
- [大名府150%改前](level8_150_before.png) · [改后](level8_150_after.png) · [恢复](level8_150_restored.png)

Codex查看生成原图和全部四组前后图：重复方块/稻茬纹样减少，改为连续收割后土质；人物、建筑、道路及标记保持可读。150%时纹理较柔和，现有地形网格细缝仍可见，地图边缘黑区及旧城墙画面也未纳入本批修复。未取得真人美术认可、实战或长期性能结论。

## 保留的失败尝试

- `attempts/render_attempt1_parse.log`：新夹具方法名与父类签名冲突，改为独立命名。
- `attempts/render_attempt2_compile.log`：启动前引用GameMap枚举触发依赖中的Art尚未可用，场景未建立；当次日志虽打印9项PASS，但含编译错误且没有两关截图，拒绝采用。改用已创建map实例的枚举，并增加“两关全部截图完成”断言，最终44项及无错误日志共同验收。
- `attempts/selftest_attempt1.log`：将无审核新图反例移到仍缺失的overlay时，夹具目录未建立；补建一次性目录后40项通过。失败不算正式通过项。

旧来源仍缺失，旧门禁继续明确阻塞，不以本批新图冒充恢复历史。源码与必要来源/QA同步到原开发分支；没有导出、Steam写入或发布。

## 干净检出与并行工作合入

`clean_checkout.json`：从田地提交 `591479d` 创建独立无缓存检出，27/27输入、24/24证据字节一致；三个Python入口从检出外目录运行，退出码0/1/0且隔离40项通过，执行前后工作区干净。该项没有在干净目录再做GPU测试。

`integration/`：收尾合入另一任务发布的野猪林 `fe70c4e`，五处冲突均为文档/换行规则新增内容，双方保留；33个非冲突远端文件保持原内容。合并后重跑田地44项、运行路由794、静态790、自测40，通过日志无脚本错误；37/32/249审计结果不变。`integration/receipt.json` 固定29项合并后输入及结果。每组改前与恢复仍逐像素一致；跨两次运行仅大名府100%图的右上边缘7像素不同，其余9张文件相同，两个批次分别保留，不宣称两次运行每像素完全相同。已查看合并后画面，田地、道路、人物与标记的结论一致。
