# Windows Steam 更新交接与四语公告草案

候选使用 `7341bd27fb3cb1db94ea905c25d72e298695b53e` 构建，运行输入与 `88e03a754decc812901fdc8eaf51ead5fe14113d` 相同。目标是 App `5088120` 的 Windows Depot `5088121`。上一正式回执为 Build `26699320`、Manifest `3231099744923356430`。上线前对照 Steamworks 当前的 default 分支。[上次发布回执](STEAM_UPDATE_20261116.md) · [Steam 发布指南](STEAM_RELEASE_GUIDE.md)

## 交付目录与验收状态

`D:/AI项目/水浒/Windows候选/2026-11-17-88e03a75/SteamDepot` 含 EXE、三份 DLL 和两份许可证，逐项核对长度、SHA-1 和 SHA-256。使用 `7341bd27` 封装，实际运行输入与长测的 `88e03a75` 相同。离线原生启动通过，四语、四入口及高俅重进由同一编译包验证。默认加载上限 72 FPS，既有 45 FPS 上限保留。五次正常返回。Steam 客户端前台仍待实际验证。[六文件清单与实测](../qa/battle_entry_timing_20261116/windows_candidate_88e03a75.json)

最新 Vulkan 源码长测覆盖 109 次切换，逐分钟帧时达到门槛。旧工具的私有内存项失败回执保留，按预热基线复核原数据的增长在容差内。用 SteamPipe 预览逐项比对本地六文件，再核对服务端 Build、正式分支、四语公告和客户端下载启动。[长测与预热复核](../qa/battle_entry_timing_20261116/README.md#windows-72-fps-模式切换三十分钟) · [八幕战役路线图](CAMPAIGN_ROADMAP_20261116.md)

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
