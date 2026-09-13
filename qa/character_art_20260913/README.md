# 孙立、扈三娘四向基础美术验收

最终批为 [20260913_180852_fc6b5bef](native/20260913_180852_fc6b5bef/receipt.json)：扈三娘609项、孙立651项，共1260项通过；共享取图合同8项通过。两人分别27张、25张原生渲染PNG。联合核验确认3054份冻结来源与当前checkout一致，64份归档文件SHA全部一致，锁释放且无遗留引擎。[联合结果](validation_summary.json) · [实现和限制](../../docs/CHARACTER_ART_20260913.md)。

该批显式复用174530批的`.godot/imported`缓存，`fresh_import=false`；源码、类缓存和玩家profile独立新建。首次全新导入来自165022批，但该批角色脚本失败，不能把它称为最终全新验收。Godot为4.6.3.stable.official.7d41c59c4，正常模拟速度；默认图形窗口位于20000,20000且不可聚焦，无桌面输入注入。没有改玩家目录或控制其他程序。

## 覆盖与目检

原生覆盖精确TRES/方向/裁框/补边/锚点、四向普通移动与实际近战伤害、命中帧、受击、死亡释放，孙立真实R三分身和到位接应的中断/续令，扈三娘实际普通攻击触发生擒、原活体保留及无死亡图借用。非参与者和攻击靶冻结、六级施法条件及姿态总览均为明确测试夹具，不冒充完整章节通关。

人工目检最终批13张：两人`unit_pose_matrix_1/2/3.png`共六张；孙立`walk_sw.png`、`terminal_sw.png`、`sun_real_riders.png`、`sun_actual_contact.png`；扈三娘`walk_sw.png`、`melee_ne.png`、`hu_captured_se.png`。总览覆盖全部独立姿态，确认四向前后视、动作身份、留边、落地和血条。实机场景中旗帜/树木仍会遮挡部分视线，因此使用无遮挡总览补查本体；不宣称每张实机PNG均完成人工审查。

孙立旧全局1.35倍率导致血条压脸，最终除去该全局倍率，保留大画布相对补偿；扈三娘SW walkA的region/margin分数尺寸会使引擎拒绝整个资源，最终只增加无前景透明边带并改为整数尺寸，原53157个alpha>15前景完整保留。构建器新增对应拒绝守卫。剧情生擒沿用现有整图休止表现，本批没有新做单独下马或束缚动画。

这是低帧基础动作；孙立SW/NW两步前腿变化较弱，扈三娘部分方向为支撑/收腿两相。没有高帧完整马步、连续转身、全库质量、完整30波、保存恢复、长时间性能或Steam发行验收结论。

## 来源、盘点与失败历史

标准来源审计：[孙立380项](static/sun_li_sources_final.json)、[扈三娘259项](static/hu_sanniang_sources_final.json)。20张原生RGBA共32219245字节，PNG逐字节复制，未做程序抠图、镜像或重编码；Godot标准导入与AtlasTexture元数据负责尺寸和排帧。40个TRES可重建且无差异。六个[导入探针](import_probes/)保留实际纹理尺寸与来源回读，未归档缓存或profile。

[当前全库清单](native/20260913_180852_fc6b5bef/inventory/inventory.json)：164移动定义、159参考，四向idle/walk/attack/death文件齐全数28/11/11/9，驻守idle710/778。[共享合同](native/20260913_180852_fc6b5bef/routing/report.json)的“完整动作”还要求hurt/down，与这里death口径不同；其未完成覆盖门槛仍为false，合同通过不能解读成全库完成。下批按出场频率优先官军斩字军54实例、跨7波。

- `165022_41b552b8`：全新导入成功，QA类型推断失败。
- `170642_5b254bf8`：JSON数字数组与Vector2精度断言错误，仅修QA。
- `171444_232f1905`：孙立旧倍率无画面626项通过，仅历史诊断。
- `174530_a644ec8d`：孙立旧倍率图形650项通过；扈三娘SW资源回退导致失败，目检另发现孙立血条问题。
- `180852_fc6b5bef`：两处修正后最终同版1260项及共享8项通过。不得累计上述历史批数字作为本批计数。

## 复现

在项目根目录执行；工作目录占位须替换为工程外本机绝对路径，Godot由`godot.local.txt`、`GODOT_PATH`或`--godot`提供。

```powershell
py -3 -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/sun_li_20260913.json
py -3 -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/hu_sanniang_20260913.json
py -3 -X utf8 -B tools/directional_character_sources.py assets/direction4/sun_li_20260913.json tools/contracts/sun_li_direction4_20260913/generation.json --out "X:/QA/sun_sources.json"
py -3 -X utf8 -B tools/directional_character_sources.py assets/direction4/hu_sanniang_20260913.json tools/contracts/hu_sanniang_direction4_20260913/generation.json --out "X:/QA/hu_sources.json"
py -3 -X utf8 -B tools/run_character_art_qa.py --repo . --manifest hu_sanniang=assets/direction4/hu_sanniang_20260913.json --manifest sun_li=assets/direction4/sun_li_20260913.json --work-root "X:/QA/character_art" --shared-checks --run
py -3 -X utf8 -B qa/character_art_20260913/verify_evidence.py --run 20260913_180852_fc6b5bef
```

不传`--cache-from`时重新完整导入；复用时传带来源收据的私有运行目录，并保留缓存标记。最终联合核验只比较已归档证据，不启动游戏。普通玩家仍用`Play.cmd`；本批没有打包、Steam上传或发布。
