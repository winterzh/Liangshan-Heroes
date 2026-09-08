# CampaignMission 界面与地图标记适配器

2026-09-09。本批在 `scripts/campaign_mission.gd` 为任务、地图定位、人物定位、官方关卡控件登记明确描述；新增 `scripts/run_campaign_presentation_state.gd` 固定工厂及状态适配器。**最终批 `20260909_050932_4cb652ff` 已通过 348 项原生检查（218 组件＋130 独立重启）**，全新导入和行为进程退出 0、错误 0，私有 profile 保护预期退出 2、错误 0。2,954 个来源的当前/冻结 SHA 共 5,908 次检查通过，四个失败批次及前版通过批原样保留。Mission 顶层仍为原有 **44 项字段**，新增的是常量、固定方法及节点 metadata，没有扩展任务值 schema。本工厂尚未接入 WorldCore，不能将组件结果记为八关完整续玩。

正式祝家庄的救囚按钮由主任务迁移到 `add_level_button()`。该接口保留原有最小高度 32 与字号 15，ID 为 `zhu_select_shi_qian` 和 `zhu_select_rescued`。点击才调用已安装关卡的固定 `activate_mission_button(battle, button_id)`；恢复工厂不调用该方法。其他七关自建控件须分别迁移和验收，不因登记了 ID 就计为已接通。

## 固定工厂与实际保存范围

`Mission.PRESENTATION_META` 为 `campaign_presentation_v1`，描述只允许：

- `action`：action_id，回调固定为新 Mission 的 `focus_action`。
- `map`：原始 label 与 Vector2i cell，回调固定为 `_activate_map_locator`。
- `actor`：action_id 与独立 actor_key，回调和文字渲染固定为新 Mission 的对应方法；不能用可能变化的 actions.actors 猜人物。
- `level`：官方玩法白名单中的 button_id、原始 label/tooltip；不允许存脚本路径、方法名或 Callable。
- `marker`：action_id。地图标记仍由正式 `MissionMarker` 类创建。

捕获完整按钮顺序，恢复时先创建有序任务动作，再按保存顺序插入/重排所有定位和关卡按钮。工厂只调用正式 Mission 构造器、`add_action()`、`add_map_locator()`、`add_actor_locator()`、`add_level_button()`；不调用 `begin()`、`configure_campaign()`、`tick()`、关卡部署、任务完成或奖励方法。`add_action(show_button=false)` 自带的状态文字随后由原始规范绑定与 Mission 值覆盖，不重放任务事件。

每个实际 Control（包括滚动条内部控件）的显示、位置/尺寸/锚点/边距、最小尺寸、缩放/旋转、颜色、层级、输入模式、尺寸策略与文本按显式字段表保存；Button 另存隐藏、禁用、按下、字号覆盖等状态。字体、样式等固定工厂资源不从存档加载：捕获时对未保存的存储属性和样式资源逐项与私有正式模板比较，未知属性改动拒绝。未知 metadata、额外非固定信号及额外全局语言回调也拒绝，不能静默漏掉行为。

Godot 4.6.3 挂载生成的连接只按精确目标、方法、flags 和绑定参数接受：父 Control 到直接子控件的几何更新、固定容器到直接父控件的布局回调，以及当前实际 Viewport 的 ref-counted canvas 排序连接。官方 Mission 的 pressed/toggled 必须为同步 flags 0；同一 Callable 改为 deferred 也拒绝。内部提示 TextureRect 保存 `none/horizontal/vertical` 主题标识和翻转值，恢复只从固定父滚动容器取得对应主题图标；焦点框只接受同一固定主题的 focus 样式。实现依据同时核对了[官方 ScrollContainer 源码](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/scene/gui/scroll_container.cpp)，没有从存档加载纹理或任意 Resource。

Marker 保存完整二维变换基、平面位置、可见性、label、number、show_caption、颜色和层级，以及已知 render_height。恢复实际调用已准备地图的 `sync_render_position()` 并校验高程一致；挂载后再次同步。仅写平面坐标或 metadata 不能代替 RenderingServer 的高程投影。

Localize 保存规范 source、format 参数类型/顺序、translate_arguments、suffix，以及唯一受信 actor-render 描述。恢复直接重建规范 binding，不依赖 512 项格式历史，也不从已译文字逆向猜来源。未绑定的文字保留实际显示值；在不同语言下安装时，通过正式 Mission 的语言刷新重建源文驱动的标题、目标、任务文字和布局。

最终格式修复将保存模板限定为 `%s`、`%d`、`%f`、`%%`，允许不重复的 `+/-`、最大宽度 64、仅浮点可用且最大 6 位精度。宽度/精度按数字逐位限额，拒绝动态 `*`、`#`、空格修饰、`%i`、双小数点等；错误在 prepare 分配新 UI 之前返回，不实际格式化危险字符串。已核对当前官方 Mission/关卡及四语文本需求，并用 7 个合法格式渲染和 13 个坏档无分配反例验证。所支持语法以[Godot 4.6 格式说明](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_format_string.html)为依据；这是存档协议的明确子集，不声称支持引擎所有格式类型。

## API 与跨组件 token

上下文与 Mission 状态完全相同：`{level_id, content_version, mission_token, presentation_token}`，四项必须来自外层已验证的官方安装内容，两个记录必须完全一致。外层须为同一次捕获提供一致的 token，并保证 Mission/Level/Unit 与内容身份相符；不能重用不同战斗或不同时刻的 token 拼装记录。

局部 registry 保持原 Mission 协议：`node:_panel` 等主控件 token、按序的 `button:0` / `marker:0`。未被 Mission 字段直接持有的结构控件使用明确索引路径 `ui:...`；滚动别名仍指向同一 `node:_detail_scroll` / `node:_details`，不制造第二个对象。路径只用于匹配固定工厂生成的图，不用于加载 NodePath、Resource 或脚本。

1. `Presentation.new().capture(mission, context, held_ui=[])` 返回 `{ok, record, external_to_token, token_to_external}`。正常运行控件可直接读取标志；世界屏障已禁用控件时，应传 `barrier._saved_ui` 的 `{node, mode, blocked}` 行，保存冻结前的标志。已 disabled+blocked 的控件缺原标志会拒绝。
2. 将 `external_to_token` 交给原 `MissionState.capture()`，和同一暂停边界、时钟、稳定 Unit registry 一起捕获任务值。捕获调用者仍须真实完成 deferred drain；没有实际排空旧 `begin()` 的 queue_free 节点时会拒绝，不能只靠布尔声明代替世界屏障。
3. `adapter = Presentation.new()`；`adapter.prepare(owner, presentation_record, mission_record, context, ids, next_id, now)`。owner 必须离树、禁用处理、阻断信号，hud/fx_root/map/level 已由受信世界工厂准备且 mission 为空；Level 和 Unit 数据应由对应适配器与官方注册表核验。
4. 成功返回 `adapter=self`、新 mission、token_to_external、`level_buttons`（button_id→新 Button）、activation_plan、resume_eligible；同时将 `owner.mission` 指向新对象。LevelState 可使用这些引用完成其 mission、depart_button/end_button 等外部字段绑定。所有UI/marker仍禁用且阻断信号，未开启玩家操作。
5. 外层在暂停且禁用世界的状态下挂载 owner，再调用 `adapter.finish_layout()`。第一次调用安排原生容器布局并返回 `PRESENTATION_LAYOUT_PENDING`；后续帧等滚动范围可接受后写入精确横纵滚动值，再显式安排滚动内容布局并跨帧等其生效。被屏障阻断的滚动条不能靠 value_changed 自动布局。最后恢复会被原生容器重置的缩放、旋转和 pivot，才返回成功。同语言保留已保存的面板/滚动最小尺寸；新语言调用正式 Mission 刷新以重新排版，同时保留任务值和按钮显隐/禁用状态。若外层时限内不能完成布局，应取消安装并清理，不能继续开世界。
6. 等待布局跨帧之后，外层应建立当前帧的世界时钟/HUD激活边界。HUD自有激活表对Mission节点暂保留 disabled/blocked 值；完成HUD本体安装后，调用 `adapter.activate()` 才恢复此适配器记录的控件/marker标志。不要预先打开其输入再调用 activate；门禁改变会被拒绝。它不激活 Battle 游戏逻辑。
7. 任何失败或取消都调用 `adapter.dispose()`。只清理本工厂的新 Mission 语言连接、所有其节点的 Localize 属性绑定、面板和标记，并按身份清空 owner.mission；不会释放外层 owner/map/Unit、旧世界绑定或其他任务资源。dispose 可在离树失败时执行，不依赖未发生的 tree_exiting。

`complete_world=false`、`begin_called=false`、`events_replayed=0` 只是本适配器的范围结果。终局 resume_eligible=false 仍必须由外层槽、生命周期与收益门禁拒绝继续，不能因为UI可构造就开放继续按钮。

## 隔离验证

```powershell
py -3.14 -X utf8 -B tools/run_campaign_presentation_state_qa.py --run
```

由主任务独占引擎运行。runner 显式纳入新 `run_local_lifecycle.gd`、Mission/Presentation、ContinueFlow 及其本地化依赖，冻结来源、私有 profile、全新导入、错误 profile 保护与独立重启进程。测试采用生产 Mission、Marker、GameMap 投影、Unit 和真实祝家庄救囚控件方法；Battle为无部署的合成宿主。QA 包含真实原生UI状态、实际非零内容滚动位置、按钮非默认缩放/旋转、面板自定义尺寸、内部滚动提示、格式历史清空、四语及跨语言安装、完整按钮混排、真实新Level选择回调、额外信号/metadata/样式及错误回调flags拒绝，以及分配后失败的全局绑定清理。

结果、失败历史、SHA与实际检查数以 [QA目录](../qa/campaign_presentation_state_20260909/README.md) 的收据为准。目前不计为八关完整恢复、真实战斗跨进程续玩、真人视觉验收或Steam交付。
