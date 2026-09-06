# 大名府 RTS 与共享接近寻路回归

基线 `11d620aae83aee0c5c550ac1cc80da7a616c9ec8`，分支 `codex/sync-20260905-stable`，Godot 4.6.3。新入口及玩法见 [大名府说明](../../docs/DAMING_RTS_20260905.md)。旧QA目录不覆盖，本目录保存本轮结果和源码/资源输入哈希。

## 最终检查

| 范围 | 通过项 | 证据 |
|---|---:|---|
| 经营、成本、门与牢区导航、敌方付费补军及失败条件 | 37 | `contracts.json`、`contracts_console.log` |
| 乔装暴露/恢复、取消重试、纯定位、入牢/开枷/两人实际撤离 | 29 | `infiltration.json`、`infiltration_console.log` |
| 合法远程接近、陆水边界、动态门、单次实际攻击、H不动 | 23 | `ranged.json`、`ranged_console.log` |
| 强攻真实经营战斗路线 | 6 | `assault.json`、`assault_console.log` |
| 内应真实经营战斗路线（Vulkan图形运行） | 8 | `signal.json`、`signal_console.log` |
| 祝家庄与跨模式经济/其他七关启动 | 39 | `shared/contracts.json`、`shared_console.log` |
| 孙立33人群选右键接应/取消/边界/门脚 | 22 | `contact/report.json`、`contact_console.log` |
| 守军近战接敌、回防、重复接敌与敌将施法 | 19 | `guards/guards.json`、`guards_console.log` |
| 连环马经营、钩镰与战斗合同 | 43 | `lianhuanma/contracts.json`、`lianhuanma_console.log` |
| 共享核心：导航、结果原子性、死亡、交互、隔离 | 68 | `core_console.log` |
| 合计 | **294** | 每份日志核对PASS数量，无FAIL/脚本错误；另有执行完整性检查 |

强攻203.75游戏秒、5座建筑开工、22次真实排队，其中2辆投石车、1辆撞车；敌营实际补3兵，原前营存活，两名原囚徒实际撤离，演义0/3不妨碍核心胜利。内应225.00游戏秒、4座建筑、21次排队，其中2辆投石车；敌营实际补2兵，完整南门按火号打开，两名原囚徒撤离，演义3/3。准确细项见JSON。

两条回放使用实际采集、扣费、生产计时、战斗伤害、死亡和普通玩家命令；没有注入金木、免费兵、冻结敌人、瞬杀目标或写入胜利。内应死亡仍可能发生，并不会撤销已经完成的火号；没有宣称三名内应全员生还。回放不是逐帧确定性测试，开战与渲染时序会改变耗时、伤亡和排队数，不能把这些秒数当作真人关卡时长。

其他合同/输入工具明确使用位置、暂停敌人物理帧和边界伤害等隔离夹具，不能作为难度证据。远程专项在真实大名府地图放置一辆投石车与一名枪兵，暂停其他单位，给一次实际右键攻击：投石车合法前进并造成真实伤害，枪兵未穿墙。20次部分路径查询均值在 `ranged.json`，只代表本机该查询，不能当作全局性能验收。

## 发现过的问题与判退记录

`attempts/` 保留以下尝试，**均不计入最终通过结果**：

- 初次声明不存在的 `guan_qiang` 导致解析失败，改用实际已有官军刀兵。
- 牢内等待点太近开枷标记，普通群体移动误触救人，伤员随即遭箭楼射击；集合点与开枷标记已分开。
- 军队点城内箭楼却停在城外：先修复远程仅查找完整路径的问题；之后又发现回放把迷雾中的建筑记忆当当前视野，右键实际上解析成了移动。回放改为先侦察，未放松生产迷雾交互限制。
- 专项工具曾调用错误H命令名、将22项写成23项预期；图形回放日志访问已释放的时迁实例。这些工具错误均保留日志并修正后重跑，不将提前退出或零检查当通过。
- 门体初版高度不足、牌子压门，后续按墙脚与墙高校准，并补关闭门扇。旧闲置偏门改为封墙。

## 图形与使用

七张1440×900实机图已检查：`camp.png` 使用正常迷雾；`city_gate.png`、`overview.png` 明确关闭迷雾并隐藏HUD，仅供几何与布局检查。`fire_signal.png`、`gate_open.png`、`prisoners_freed.png`、`signal_result.png` 来自最终内应真实回放，保留实际战果和正常迷雾。

实战截图在4倍游戏时间生成，画面FPS不是正常1倍性能测量；普通视觉工具为1倍。没有制作/安装新角色位图，门扇为门体局部代码绘制。全库四向、真人首通与趣味、长时性能、门楼完整开扇动画和发行候选仍未验收。

```powershell
$godotExe=(Get-Content godot.local.txt -Raw).Trim()
$env:DAMING_TEST='contracts' # 或 assault、signal
& $godotExe --headless --path . --script res://tools/daming_rts_test.gd
& $godotExe --headless --path . --script res://tools/daming_infiltration_test.gd
& $godotExe --headless --path . --script res://tools/ranged_firing_path_test.gd
# 图形窗口自动截图并退出；回放截图另设 DAMING_TEST=signal 和 DAMING_VISUAL=1。
& $godotExe --path . --script res://tools/daming_rts_visual.gd
```

`receipt.json` 记录源码与依赖的归一化LF哈希、QA文件原始字节哈希、预期检查数。跨模式/旧关工具通过 `RTS_TEST_OUT` 写入本目录的独立子目录。本轮未导出、未合并main、未操作Steam，沿用PR #1。
