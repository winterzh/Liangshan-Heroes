# 战役死亡残留补画与接入

2026-09-01，本批补齐最初玩家截图中“人物死亡后缺少血迹、骨片等战场痕迹”的美术缺口。素材由主任务在网页版 ChatGPT 实际生成并下载，生产画面只使用克制的血迹、断兵器、旧旗布和散落装备；普通新死亡不随机使用两格骨片图，避免人物刚倒下便像陈年战场。

## 素材来源与处理

- 网页对话：<https://chatgpt.com/c/6a968371-24a0-83ea-8e33-d5fe2a8b56b2>
- 完整提示词：`assets/campaign/web_prompts_20260901/01_death_remains.txt`
- 网页原图：`assets/campaign/source/web_death_remains_v1.png`，1774×887、RGBA，SHA-256 `5ce342aedc2cdb0e2cbcdc60368ded7eeaa0aebee4ed355970bc9222076247a0`
- 实机图集：`assets/campaign/objects/death_remains_default.png`，1024×512、4列×2行、每格256×256，SHA-256 `1480d0d047cd4ae1bcbcb3ec63e272120f44dae9ba535bbc3bb1ccc08f64ca98`
- 处理工具：`tools/campaign_death_remains_prepare.py`。只补透明边、在预乘透明色空间等比缩放并检查八格边界；没有重画、补画或修复生成内容。逐格透明边界与哈希见`qa/death_remains_20260901/art_prepare.json`。

## 游戏规则

- 普通陆地人物真实死亡后留下残留45秒，最后8秒淡出；最多保留48处，超限先清最旧一处。
- 残留按死亡顺序与位置稳定选取血迹、断兵器、破布、草鞋、盾片或倒旗六类图格，并贴合当前地面坡度与高度。
- 昏迷、制服、被擒、撤离和登船属于剧情非致死结算，不生成死亡残留。建筑、资源点、召唤物、水上单位和玩家主动删除也不生成这类人物痕迹。
- 同一人物重复受击不会重复生成；跨日转场、重开和重新进入战役会清空旧残留。贴图缺失时使用无白底的克制程序标记，但正式测试要求生产图集必须实际加载。

## 验证

- Godot 4.6.3编辑器导入与脚本注册退出码0。
- `campaign_core_test.gd`为68项通过、0项失败：实际读取1024×512生产图集，覆盖剧情终态、真实死亡、同帧重复伤害、45秒生命周期、末8秒淡出、真实非零坡面与渲染高度、48处上限、跨日清理与重开。
- 黄泥冈纲担测试在本批前后均保持4例通过；日志与最终JSON继续由`qa/campaign_huangnigang/cargo_v1.json`记录。
- 1280×720图形夹具为7项通过：六名普通单位经真实`take_damage → died`死亡，1.4秒尸体动画结束并释放后仍有六处残留；一名“被擒”人物作为反例不留痕。截图为`qa/death_remains_20260901/visual/death_remains_real_deaths_1280.png`，报告为同目录`report.json`。
- `campaign_regression_edges.gd`仍为9/11；失败的是既有`fleet_killed_before_lure`和`dead_hull_cannot_lure`水战事件预期。生产逻辑与核心测试均排除水上单位，不能把这两项写成死亡残留通过，也不能把整套边缘测试写成全绿。
- 图形进程退出仍出现既有Texture RID与RenderingServer销毁顺序告警；核心测试仍有ObjectDB退出告警。本批没有做真人试玩、长时间性能或兵海帧时验收。

## 发布边界

本批完成时改动只在本地源码。Steam default 的 BuildID `25051529` 早于本批，不包含死亡残留图集和代码；该批当时没有重新导出、改 Steam 发布目录或上传。其后死亡残留源码与资源已随 `2026-09-04` Windows 测试构建进入 default BuildID `25121101`。
