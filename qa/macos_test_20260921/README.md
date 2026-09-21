# macOS 本地试玩包 · 2026-09-21

用户要求把上一批 RTS 修复打成 Mac 包供启动试用，并列出改动。本轮没有正式发布授权：没有改生产版本，没有 tag、GitHub Release、Steam 或更新服务器操作。

## 交付身份与启动

- 冻结生产提交：`e3be6474690f438fdda3c63a45b8ccebbc485f09`，3062 份生产白名单文件。收尾逐份对照 Git 提交 blob 与构建 SHA，全部一致；副本除声明覆盖层外零漂移。
- 本机目录：`build/macos-test-20260921/`，内有 `水浒英雄传-TEST-20260921-e3be6474.app` 与同名 `.dmg`。双击 App 试玩；DMG 可用于拷贝。安装包被 Git 忽略，不随源码上传。
- 菜单左下角应显示 `TEST 0921-e3be6474`。生产版本仍为 1.8，此标记才是本次测试包身份。
- Universal 二进制含 `arm64` / `x86_64`；本机 Apple M4 Max 实测 ARM64，未验收 Intel Mac。
- 独立用户目录：`~/Library/Application Support/LSH-macos-test-20260921-e3be6474/`，不共享正式存档/设置。用户可从空进度开始试玩，不代表原进度丢失。
- 本地 ad-hoc 签名，未做 Apple 公证。没有修改 Gatekeeper 或系统安全设置；若另一台机器拦截，保留报错后再处理。

## 包内改动（来自 e3be6474）

1. 触屏六英雄的全部技能统一进右侧安全区，主动/被动均展示，学习按钮独立；底栏去掉重复技能和键盘提示，信息/物品向左展开。
2. 小米 12S Ultra、vivo X300 Ultra、联想 Y900 13（2026）及补充宽高比做过离屏布局矩阵；手机/平板真机手势和 DPI 仍待实测。Mac 使用桌面布局。
3. 新增血瓶：己方英雄出生一瓶，复活无瓶时补一瓶，恢复 `200 + 20% 当前最大生命`，满血不消耗；已有物品保留，满格不覆盖。尚无商店、掉落或 AI 自动喝药。
4. 修正低速行军重寻、不可达巡逻、据守友军绕行和镜头边界；手动施法不被托管抢走，Shift 移动在当前施法后接续，取消与目标失效交接更完整。
5. 英雄名册固定，阵亡留槽；邻近英雄可转交物品，禁止远程全图转交。资源栏补工人数/排队人口，工人显示携带量，生产按钮显示锁定原因。
6. 1v1 普通难度经济起点对齐；AI 真实付费生产/研究，难度补偿明示，训练情报归为自定义局；新增四语经营说明。

详细规则与前批验证见 [RTS 实现](../../docs/RTS_REFINEMENT_20260920.md) 及 [464 项功能检查、173 个原生尺寸图形状态](../rts_foundation_20260920/README.md)。本轮未重跑 60 波整场性能，不把小场景 FPS 当压力性能结论。

## 本次实际验证

| 层级 | 结果 | 边界 |
| --- | --- | --- |
| 构建/签名 | Godot 4.6.1 导入、macOS release 导出、PCK 排除清单、Universal 架构、ad-hoc 严格签名验证通过 | 不等于 Apple 公证 |
| DMG | `hdiutil verify` 通过；只读挂载后 App 严格验签，PCK SHA 与源 App 相同，已卸载镜像 | 未做下载隔离标记下的 Gatekeeper 验收 |
| 实际 App 主入口 | ARM64 + Metal，普通菜单 4 帧引擎录帧退出 0；测试标记完整可见 | 没有用源码菜单替代 App 菜单 |
| 实际 App 竞技场入口 | 原有 `ARENA=1` / `SCREENSHOT_DIR` 环境入口，360 帧退出 0，真实场景截图已目检 | 到达开场说明，不是完整玩家点击/对局验收 |
| 实际 PCK 逻辑 | 原生 Godot 宿主用 `--main-pack` 加载 App 内 PCK，39 项通过；出生血瓶一次性恢复 1→265（最大生命320），扣一瓶，空格再次使用不回血 | 宿主资源测试，**不是**实际 release 二进制执行外部脚本 |

截图：`native-menu.png`、`native-arena-entry.png` 是实际导出 App；`packed-host-potion.png` 是宿主加载实际 PCK 后的血瓶场景。没有绕过生产回血逻辑，只有扣到 1 血的夹具设置；场景暂停，不算自然战斗测试。

原生 App 的强制定帧退出有音频实例残留提示；竞技场截图协程尚未完成即退出时另有 `2 resources still in use at exit`。原始日志保留，不能写成“零警告/零错误”；这不是本轮发现的启动失败。宿主探针正常完成退出，无该资源错误。

## 未通过的诊断尝试与已知问题

- release 模板不支持 `--script`。第一次尝试没有执行探针，进程仍在正常渲染，随后由本轮终止；不计测试通过。之后改用实际 App 录帧/内置入口与独立 PCK 宿主探针两层验证。
- 第一版宿主探针误以为 `OS.get_cmdline_args()` 保留 `--main-pack`，来源门禁失败并退出 1，未运行场景。最终版由启动器显式提供 PCK 路径和 SHA，核验实际字节、二进制项目、无源码路径、专属 profile/feature/stamp，并保留实际启动命令；结果明确标记 `packed_resources_native_host`。失败 JSON 留作证据，不计入通过数。
- 桌面第二位起的英雄头像键帽仍顺排 F2/F3…，但实际英雄键为 F1、F3–F8，F2 默认全军。此包未暗改冻结生产来源；鼠标头像选择正常，文档已纠正，显示修复留后续。
- 首次构建工具记录了所有来源/覆盖层哈希，但版本元数据由本次 QA 补录；复制与源 SHA 记录不是一个原子快照。本批已用逐份 Git blob 和副本零漂移复核闭合，不宣称该工具能防御任意并发写入。构建期间仍须遵守不并改生产文件约定。

## 产物与工具链

- DMG：386,667,452 字节；SHA-256 `a5ed00af3f85f1d7e769a44b90324691ba2ce356252a412549dbe0d1c0025e3b`。
- PCK：315,922,824 字节、3286 项；SHA-256 `bee24558a2b38be9fe9651f1b31d7a56f5a7e28178931000907524ec70c54cc8`。
- Godot：`4.6.1.stable.official.14d19694e`，本机可执行文件 SHA-256 `ad304ee206ac9a0ab8407365e767ec33fe78d9455ff9dcace207c053e2651667`。
- `4.6.1.stable/macos.zip` 导出模板 SHA-256 `a6d51d2b650091ab7073c15e9e6faf01c0e972648edb2e99952735c6befae00e`。

`build-receipt.json` 是构建时原始收据，其中 `native_launch_tested=false` 表示**构建工具没有负责启动验收**，本节与 `handoff.json` 另记后续原生运行，不回写历史收据冒称同一流程完成。完整私有导入/导出与诊断目录为 `/tmp/lsh-macos-test-20260921-e3be6474/`。

## 复现

先确认受测提交与生产文件干净，配置本机 `GODOT_PATH`，不得重设 HOME。构建入口和独立 profile/私有四处覆盖层见 `tools/build_macos_test.py`：

```sh
python3 tools/build_macos_test.py --godot "$GODOT_PATH" \
  --out /absolute/new/directory/outside/checkout \
  --delivery-dir "$PWD/build/new-macos-test" --expected-commit "$(git rev-parse HEAD)"
```

实际 App 支持 `--write-movie /absolute/new/menu.png --quit-after 4` 录菜单。不能给 release App 传 `--script` 来假定测试执行。宿主探针用下列命令；`APP` / `PCK` 必须来自本次构建收据，输出目录每次使用新目录：

```sh
PCK="$APP/Contents/Resources/水浒英雄传：八幕战役.pck"
LSH_MAC_TEST_PACKED_HOST=1 LSH_MAC_TEST_PCK="$PCK" \
LSH_MAC_TEST_PCK_SHA256="$PCK_SHA256" \
LSH_MAC_TEST_PROFILE="$PROFILE" LSH_MAC_TEST_STAMP="$STAMP" \
LSH_MAC_TEST_QA_OUT="$OUT" STEAM_DISABLED=1 CAMPAIGN_QA=1 \
CONTENT_UPDATE_NO_AUTO=1 LSH_LANGUAGE=zh_CN \
"$GODOT_PATH" --main-pack "$PCK" \
  --script "$PWD/tools/macos_test_package_probe.gd" \
  --windowed --resolution 1280x720 --position 20000,20000
```

先清除 `SMOKE_TEST`、`SCREENSHOT_DIR`、`LEVEL`、`SKIRMISH`、`SKIRMISH_AI`、`SCENARIO`、`CUSTOM_DEFENSE`、`ARENA`、`PERF_BENCH`、`INFO_UI_TEST*` 等无关测试变量。本机 Git 如被完整 Xcode 许可挡住，只给本次命令设置现有 CommandLineTools 的 `DEVELOPER_DIR`；不更改系统开发工具选择或代为接受许可。
