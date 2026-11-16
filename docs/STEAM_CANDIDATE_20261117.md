# Windows Steam 更新交接与四语公告草案

候选源码为 `7bd1f0e5c1aaaf25b80c30a151983a1e45cb6a12`，目标是 App `5088120` 的 Windows Depot `5088121`。本机 Steam 安装仍为 Build `26699320`，其发布回执对应 Manifest `3231099744923356430`。这组标识用于核对上线前基线及必要时回退。[上次发布回执](STEAM_UPDATE_20261116.md) · [Steam 发布指南](STEAM_RELEASE_GUIDE.md)

## 交付目录与验收状态

`D:/AI项目/水浒/Windows候选/2026-11-17-7bd1f0e5/SteamDepot` 含 EXE、三个原生 DLL 和两份许可证，共六个文件。文件的大小、SHA-1 和 SHA-256 已读回。原生 EXE 通过离线启动，成品包内含八章脚本以及四语进场文案。许可证字节与上次服务端清单一致。[Depot 六文件清单](../qa/battle_entry_timing_20261116/windows_steam_depot_7bd1f0e5.json) · [成品核对与启动记录](../qa/battle_entry_timing_20261116/README.md#windows-候选成品内容核对)

候选的菜单入口与 Steam 客户端实际点击仍待验。发布时从候选清单比对 SteamPipe 预览和服务端文件，确认新 Build 对应同一 Windows Depot，再核对正式分支、四语公告和客户端下载启动。备选回退目标为 Build `26699320`，实际操作前以 Steamworks 当时的 `default` 标记为准。[发布指南](STEAM_RELEASE_GUIDE.md)

高俅关 Windows 源码十分钟样本达到整段帧时门槛，六模式三十分钟样本已通过关键节点释放和内存回收检查，逐分钟 P95 仍有超限。当前候选与试玩、Android 实机及战役续玩的适用状态见路线图，公告草案只覆盖本轮玩家可见变化。[持续性能数据](../qa/campaign_sustained_performance_20261116/README.md#单位绘制优化后的十分钟复测) · [模式切换长测](../qa/battle_entry_timing_20261116/README.md#windows-主菜单模式切换三十分钟) · [八幕战役路线图](CAMPAIGN_ROADMAP_20261116.md)

## 简体中文

### 出征加载与战役提示优化

- Windows 点击出征或确认模式后，会显示对应关卡或模式的加载提示。提示支持简体中文、繁体中文、英语和日语。
- 三打祝家庄会按断援、破门和内应结果更新目标。大破连环马的军情会分两路显示剩余骑兵。
- 江州劫法场的码头会显示仍在岸上的好汉。智取大名府在牢院放行、开枷及撤离时会提供更清楚的下一步提示。
- 三败高太尉调整了内港举火判定和押俘进度提示。两艘接应船完成安全撤离后，后续失船仍保留已完成的火攻演义。
- 智取生辰纲中，载重枣车掉落后可从可通行的一侧接手。醉打蒋门神新增重拳和冲撞的起手倒计时及危险范围提示。

## 繁體中文

### 出征載入與戰役提示優化

- Windows 點擊出征或確認模式後，會顯示對應關卡或模式的載入提示。提示支援簡體中文、繁體中文、英語和日語。
- 三打祝家莊會依斷援、破門和內應結果更新目標。大破連環馬的軍情會分兩路顯示剩餘騎兵。
- 江州劫法場的碼頭會顯示仍在岸上的好漢。智取大名府在牢院放行、開枷及撤離時會提供更清楚的下一步提示。
- 三敗高太尉調整了內港舉火判定和押俘進度提示。兩艘接應船完成安全撤離後，後續失船仍保留已完成的火攻演義。
- 智取生辰綱中，重載棗車掉落後可從可通行的一側接手。醉打蔣門神新增重拳和衝撞的起手倒數及危險範圍提示。

## English

### Battle loading and campaign objectives

- On Windows, deploying or confirming a game mode now shows a loading message for the selected mission or mode in Simplified Chinese, Traditional Chinese, English, or Japanese.
- Three Assaults on Zhu Manor updates its objectives as you cut reinforcements, breach gates, or gain help from the inside. Breaking the Chained Cavalry reports how many riders remain on each route.
- In Rescue at Jiangzhou, the dock shows which allies are still ashore. The Daming Rescue gives clearer directions as you reach the prison yard, free the captives, and evacuate.
- Three Defeats for Marshal Gao adjusts when the inner-harbor fire can be lit and clarifies the prisoner escort’s progress. If both escort boats have reached safety, losing a boat later preserves the completed fire attack story objective.
- In The Birthday Tribute Heist, if a carrier drops a loaded cart, another character can take over from a side they can reach. Drunken Duel with Jiang the Door God shows windup countdowns and danger areas for heavy punches and charges.

## 日本語

### 戦闘のロード表示とキャンペーンの目標案内

- Windows では、出陣やモード選択を確定すると、選んだステージやモードに応じたロード案内を表示します。簡体字中国語、繁体字中国語、英語、日本語に対応しています。
- 「祝家荘を三度攻める」では、援軍の遮断、門の突破、内応の結果に応じて目標が更新されます。「連環馬を打ち破る」では、進軍ルートごとに残りの騎兵数を表示します。
- 「江州の刑場を襲う」では、船着き場でまだ岸にいる仲間を確認できます。「大名府を智取する」では、牢の中庭への進入、囚人の解放、撤退の各段階で次の行動が分かりやすくなります。
- 「高太尉を三たび破る」では、内港で火を放てる条件を調整し、捕虜の護送状況を明確にしました。援護船が二隻とも安全圏に入った後は、船を失っても達成済みの火攻めの物語目標は保持されます。
- 「生辰綱を智取する」では、落とした積荷付きの荷車を、通行できる側から引き継げます。「酔って蒋門神を打つ」では、強打と突進までのカウントダウンと危険範囲を表示します。
