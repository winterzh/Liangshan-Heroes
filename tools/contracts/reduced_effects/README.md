# 标准 / 精简特效 QA 合约

公共入口直接验证当前源码，不生成或应用生产补丁。行为、GUI、旧 Settings 启动各自记录来源、用户目录、进程退出和结果；这里的源码迁移不是公共入口已经运行通过的证明。

## 命令

从工程根目录运行；Godot 由 `--godot`、`GODOT_PATH` 或被忽略的 `godot.local.txt` 提供。

```powershell
python tools/run_reduced_effects_qa.py
python tools/run_reduced_effects_qa.py --run --suite behavior
python tools/run_reduced_effects_qa.py --run --suite gui --sizes 1440x900 1280x720
python tools/run_reduced_effects_qa.py --run --suite legacy
python tools/run_reduced_effects_qa.py --run --suite all
python tools/run_reduced_effects_qa.py --run --suite freed-target-boundary
```

无 `--run` 时只检查合约、当前源码枚举与项目路径规则，不启动 Godot、不创建副本、不写运行产物。`all` 包含 behavior、两分辨率 GUI 和 legacy；释放目标边界始终显式独立运行。每个进程默认超时 240 秒，可用 `--timeout` 在 30–900 秒内指定。结果放在 `.godot/reduced_effects_qa/<UTC>/`，失败日志也保留；不创建发布包、不运行 Git。

运行必须独占 Godot，并共用现有 `.godot/redraw_rejection_source.lock`。启动器持有准确 Popen 句柄，超时/中断后仅终止自己的 child 并有界等待；退出未确认、源/真实保存冲突或锁所有者不符时保留锁和证据，不杀其它进程、不覆盖未知 WIP。`SCRIPT ERROR`、`ERROR`、`WARNING`、`FAIL`、非零退出、缺失/错误阶段报告、空检查或不一致来源均失败。

## 用户目录与来源

当前启动隔离实现仅支持 Windows 默认项目 user data 规则；自定义 user-dir 或无法安全解析的项目名被拒绝。只给子进程设置本次新建的 APPDATA/LOCALAPPDATA，启动后核对实际 `user://` 与 manifest 的私有目录完全相同。真实 settings.cfg、campaign.cfg、screen.cfg 只读 SHA 校验，不复制、不删除、不自动恢复。不存在 Godot `--user-dir` 参数的替代用法。

行为测试的配置实例使用当前真实 Settings 原文，唯一修改是 PATH 常量指向本次配置 fixture；原文/副本哈希和替换位置写入报告。这不能代替 GUI：GUI 保留真实菜单按钮、滚轮、Esc、生产 pressed 信号和 SettingsPanel.close，清除 CAMPAIGN_QA 后在私有目录真正保存 Settings 与 Campaign。write/read 是两个已确认退出后重新创建的进程；PID 可被操作系统复用。

外部来源清单包含九类生产目录、root icon.*、project.godot、两 GD QA、runner、公共环境 helper 及本 contracts，包含隐藏文件并记录目录集合/根是否存在；拒绝 links/reparse 和扫描失败。每个阶段前后重新枚举路径并比较 raw SHA；GD 入口也在动作前与结束时核对 manifest 文件。当前源码不会固定为某次候选全文 SHA，未来修改照样可测试，但不同来源收据不能被说成同一版本的结果。

`manifest.json` 只固定旧 Settings 源字节与历史迁移出处。其 origin 路径仅为来源说明，没有运行时 scratchpad 依赖。普通/重击白色中心保留已经核对的半透明预乘 readback 判断；不要重新换成不适用的非预乘 RGB 阈值。

## 验证内容与边界

行为入口运行真实生产 Battle/Unit 及内部特效类，延迟到 Autoload 就绪后加载，校验实例化和脚本继承。保留非法/缺失/损坏配置、独立重启、护盾/地火 DOT/飞斧延迟伤害与只结算一次、地火真实 tree_exited 两轮预算释放、完整下游 RNG 哨兵，以及同实例标准→精简→恢复标准的实际像素比较。三处 SubViewport 都使用独立 World2D，飞斧保留实际纹理斧体和伤害对象。完整回调状态缺字段或为空会失败。

V2 起步版本的伤害源码中曾有释放目标类型转换问题；后续生产增加独立的有效性 guard。释放目标 QA 检查当前真实行为，历史失败应保留，不能声称 Battle 的所有非绘制代码始终没有变过。`freed-target-boundary` 运行结果单列，不默认忽略其错误，也不因为绘制 QA 通过而宣布该边界通过。

GUI 保留 1440×900 与 1280×720 的物理/逻辑尺寸、真实滚动、互斥高亮、关闭设置后仍暂停、继续同战斗及返回主菜单释放旧 Battle。截图使用整个 viewport，附面板/CanvasLayer/z 与 HUD toast/tip 的实际层级收据；不通过隐藏 HUD 或重排节点制造无遮挡图。当前设置面板层级修正后的截图必须实际审阅，`gui_valid` 不能代替 `visual_review`。根任务将需要的正确来源 PNG SHA 与审阅结论纳入正式 QA；原图存在本身不是视觉通过证据。

这些都是有限状态/像素/真实输入检查，不是完整战役玩法等价、30 FPS 或长期稳定性验收。全局音频 RNG、呈现帧飞斧伤害仍不构成确定性重放；性能使用独立的公共性能入口和其完整门槛。

## 旧 Settings 的真实启动

`settings_legacy.gd.txt` 是未增加 effects_quality 字段时的完整 Settings 原字节；原路径与 raw/LF SHA 见 manifest。正常编辑器将它当文本，legacy suite 才复制成 `.gd`。

legacy 只在本次输出目录内复制来源 manifest 的生产资源/脚本和必要 QA 文件，不复制玩家数据、Git、导出物或 Godot 缓存，不使用链接。副本保留当前 `scripts/settings.gd`；只把 project.godot 的一处 Settings Autoload 路径指向副本内的冻结旧 Settings。其它 Autoload、当前新面板/绘制源码保持相同原字节，差异必须准确列在 copy receipt。

副本先做一个独立、严格日志、有界的资源导入进程，再新进程运行 legacy_autoload。复制完毕时枚举每个已复制 `.gd`，仅把确定缺少同名 `.gd.uid` 的脚本列为可新增元数据集合，保存具体脚本/UID 路径。当前原始 2712 文件清单中有 73 个 `.gd`，仅两个新公共 QA 缺 UID；副本另有新建 legacy_settings.gd，因此本次允许集合准确为这三个文件各自的 `.uid`。公共 QA 已有的 UID 也纳入普通来源收据，不能被遗漏后误判为可新增。

导入后逐项核对新增内容符合 Godot 4.6 实际生成的规范 UID：`uid://` 加 a–y/0–8 的 34 进制，无多余前导零位，数值不超过有符号 64 位上限；依据 [ResourceUID 官方源码](https://raw.githubusercontent.com/godotengine/godot/4.6/core/io/resource_uid.cpp)。记录原字节 SHA 和对应原脚本 SHA，再冻结完整副本来源。已有 UID 的任何字节变化、新脚本、其它 UID 或路径变化均失败，绝不宽泛忽略所有 `.uid`。导入日志不是行为通过证据。实际检查 booted Settings 的脚本路径/字节、字段缺失、新选项隐藏、标准浮尘有实际像素；不在新 Settings 启动后换对象冒充旧启动，也不调用旧面板保存。该桌面组合不能替代历史 Android APK/PCK 挂载顺序和真机验证。

公共迁移完成后必须重新运行以上入口并审图，不能直接继承临时工具的已通过结论。运行目录中的私有用户文件、缓存和所有历史截图不可整包提交。
