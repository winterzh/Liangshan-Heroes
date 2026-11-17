# Windows Steam 更新交接与四语公告草案

使用 `d645e44fb391546bdcdc1a872ba9d433fa049054` 构建 App `5088120` 的 Windows Depot `5088121` 本地候选。上一正式回执为 Build `26699320`、Manifest `3231099744923356430`。[上次发布回执](STEAM_UPDATE_20261116.md)

## 交付目录与验收状态

`D:/AI项目/水浒/Windows候选/2026-11-17-d645e44f/SteamDepot` 含 EXE、三份 DLL 和两份许可证，逐项核对了长度、SHA-1 和 SHA-256。Windows 原生 EXE 离线启动通过。编译包实际运行六种入口、四语和六次正常返回，祝家庄可定位可采矿点，黄泥冈原存档文字可按当前语言显示接力报告。Steam 客户端的实际下载和前台操作仍待验。结算恢复仍在独立私有候选。[六文件收据](../qa/battle_entry_timing_20261116/windows_candidate_d645e44f.json) · [结算恢复记录](../qa/campaign_siege_20261116/README.md#终局恢复候选)

此前 `88e03a75` 的 Vulkan 源码长测覆盖 109 次切换，逐分钟帧时达到门槛。预热基线复核的内存增长在容差内，原始失败回执保留。上线时按 SteamPipe 预览、服务端 Build、分支及客户端下载回读核对。[长测与预热复核](../qa/battle_entry_timing_20261116/README.md#windows-72-fps-模式切换三十分钟) · [Steam 发布指南](STEAM_RELEASE_GUIDE.md)

## 简体中文

### 出征加载与战役提示优化

- Windows 点击出征或确认模式后，会显示对应关卡或模式的加载提示。提示支持简体中文、繁体中文、英语和日语。
- 智取生辰纲的七名好汉会在 Windows 加载画面期间提前准备开场动作，减少战场刚出现时的停顿。
- 三打祝家庄新增侦察查看提示。外营、北矿守军和庄门会给出断援、占矿与攻门建议。偏门提示随孙立的状态更新。
- 三败高太尉的三批出击各有开战前预警，任务栏可快速定位东山关和内港。
- 三打祝家庄会按断援、破门和内应结果更新目标。大破连环马的军情会分两路显示剩余骑兵。
- 江州劫法场的码头会显示仍在岸上的好汉。智取大名府在牢院放行、开枷及撤离时会提供更清楚的下一步提示。
- 三败高太尉调整了内港举火判定和押俘进度提示。两艘接应船完成安全撤离后，后续失船仍保留已完成的火攻演义。
- 智取生辰纲中，载重枣车掉落后可从可通行的一侧接手。醉打蒋门神新增重拳和冲撞的起手倒计时及危险范围提示。
- 三打祝家庄任务栏可查看可采的前营金矿及剩余金量。智取生辰纲的伤亡接力报告会按当前界面语言显示。

## 繁體中文

### 出征載入與戰役提示優化

- Windows 點擊出征或確認模式後，會顯示對應關卡或模式的載入提示。提示支援簡體中文、繁體中文、英語和日語。
- 智取生辰綱的七名好漢會在 Windows 載入畫面期間預先準備開場動作，減少戰場剛出現時的停頓。
- 三打祝家莊新增偵察查看提示。外營、北礦守軍和莊門會提供斷援、占礦與攻門建議。偏門提示隨孫立的狀態更新。
- 三敗高太尉的三批出擊各有開戰前預警，任務欄可快速定位東山關和內港。
- 三打祝家莊會依斷援、破門和內應結果更新目標。大破連環馬的軍情會分兩路顯示剩餘騎兵。
- 江州劫法場的碼頭會顯示仍在岸上的好漢。智取大名府在牢院放行、開枷及撤離時會提供更清楚的下一步提示。
- 三敗高太尉調整了內港舉火判定和押俘進度提示。兩艘接應船完成安全撤離後，後續失船仍保留已完成的火攻演義。
- 智取生辰綱中，重載棗車掉落後可從可通行的一側接手。醉打蔣門神新增重拳和衝撞的起手倒數及危險範圍提示。
- 三打祝家莊任務欄可查看可採的前營金礦及剩餘金量。智取生辰綱的傷亡接力報告會依目前介面語言顯示。

## English

### Battle loading and campaign objectives

- On Windows, deploying or confirming a game mode now shows a loading message for the selected mission or mode in Simplified Chinese, Traditional Chinese, English, or Japanese.
- On Windows, The Birthday Tribute Heist prepares the seven merchants’ opening animations during loading to reduce the pause as the battlefield appears.
- In Three Assaults on Zhu Manor, inspect the outpost, mine guards, or gates for tactics. Side-gate advice updates based on Sun Li's availability.
- Three Defeats for Marshal Gao gives a distinct advance warning for each wave and adds camera shortcuts to East Gate and the inner harbor.
- Three Assaults on Zhu Manor updates its objectives as you cut reinforcements, breach gates, or gain help from the inside. Breaking the Chained Cavalry reports how many riders remain on each route.
- In Rescue at Jiangzhou, the dock shows which allies are still ashore. The Daming Rescue gives clearer directions as you reach the prison yard, free the captives, and evacuate.
- Three Defeats for Marshal Gao adjusts when the inner-harbor fire can be lit and clarifies the prisoner escort’s progress. If both escort boats have reached safety, losing a boat later preserves the completed fire attack story objective.
- In The Birthday Tribute Heist, if a carrier drops a loaded cart, another character can take over from a side they can reach. Drunken Duel with Jiang the Door God shows windup countdowns and danger areas for heavy punches and charges.
- In Three Assaults on Zhu Manor, the objective panel can locate a mine at your camp and show how much gold remains. Cart relay reports in The Birthday Tribute Heist follow the current language.

## 日本語

### 戦闘のロード表示とキャンペーンの目標案内

- Windows では、出陣やモード選択を確定すると、選んだステージやモードに応じたロード案内を表示します。簡体字中国語、繁体字中国語、英語、日本語に対応しています。
- Windows 版の「生辰綱を智取する」では、ロード中に七人の商人の開幕アニメーションを準備し、戦場が表示されるときの引っかかりを軽減しました。
- 「祝家荘を三度攻める」では、外営、金鉱の守備隊、門の情報欄で攻略の手掛かりを確認できます。脇門の案内は孫立の状況に応じて変わります。
- 「高太尉を三たび破る」では、出撃前の警告が各陣で変わり、目標欄から東山関と内港へカメラを移動できます。
- 「祝家荘を三度攻める」では、援軍の遮断、門の突破、内応の結果に応じて目標が更新されます。「連環馬を打ち破る」では、進軍ルートごとに残りの騎兵数を表示します。
- 「江州の刑場を襲う」では、船着き場でまだ岸にいる仲間を確認できます。「大名府を智取する」では、牢の中庭への進入、囚人の解放、撤退の各段階で次の行動が分かりやすくなります。
- 「高太尉を三たび破る」では、内港で火を放てる条件を調整し、捕虜の護送状況を明確にしました。援護船が二隻とも安全圏に入った後は、船を失っても達成済みの火攻めの物語目標は保持されます。
- 「生辰綱を智取する」では、落とした積荷付きの荷車を、通行できる側から引き継げます。「酔って蒋門神を打つ」では、強打と突進までのカウントダウンと危険範囲を表示します。
- 「祝家荘を三度攻める」では、目標欄から前営の採掘可能な金鉱と残量を確認できます。「生辰綱を智取する」の荷車引き継ぎ報告は現在の言語で表示されます。
