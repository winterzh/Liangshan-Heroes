# Windows Steam 更新交接与四语公告草案

App `5088120`、Windows Depot `5088121` 本地候选来自 `455f2c623a17f582cae021a5e141676bec9e7d2b`。最近公开 Build `26719792`、Manifest `3426323641209633325`。[最近发布回执](STEAM_UPDATE_20261117.md)

Windows 本地候选 `455f2c62` 已封装，原生 EXE 离线启动及黄泥冈、快活林、大名府直达短测通过。同一个编译包运行七种菜单入口，八次开战及返回，点击至战场首帧 0.57–1.02 秒。交付目录 `D:/AI项目/水浒/Windows候选/2026-11-17-455f2c62/SteamDepot`。Steam 下载版前台操作和手动计时仍待验。[六文件收据](../qa/battle_entry_timing_20261116/windows_candidate_455f2c62.json) · [Steam 发布指南](STEAM_RELEASE_GUIDE.md)

## 简体中文

### 黄泥冈运货与快活林提示修正

- 智取生辰纲的顶栏会显示待接手的重车数。选中有资格接手的空手同伴后，「下一步」优先定位附近的待接重车。
- 修复接手旗标与重车叠在一起时，右键误判为攻击的问题。
- 醉打蒋门神的查看栏会显示鸳鸯脚是否就绪，并在冷却时显示剩余时间。

## 繁體中文

### 黃泥岡運貨與快活林提示修正

- 智取生辰綱的頂欄會顯示待接手的重車數。選中有資格接手的空手同伴後，「下一步」優先定位附近的待接重車。
- 修正接手旗標與重車重疊時，按右鍵卻發出攻擊指令的問題。
- 醉打蔣門神的查看欄會顯示鴛鴦腳是否就緒，並在冷卻時顯示剩餘時間。

## English

### Cart recovery and duel cooldown fixes

- The Birthday Tribute Heist shows how many loaded carts need recovery. Select an eligible companion with free hands, then use Next Step to locate a nearby loaded cart first.
- Right-clicking a recovery marker that overlaps its cart now issues a recovery order.
- In Drunken Duel with Jiang the Door God, the inspector shows whether Mandarin Duck Kick is ready and how much cooldown time remains.

## 日本語

### 荷車の回収と必殺技の表示を修正

- 「生辰綱を智取する」の画面上部に、引き継ぎ待ちの積載車の数を表示します。引き継げる手の空いた仲間を選ぶと、「次の手順」で近くの積載車を優先して探せます。
- 荷車と引き継ぎ標識が重なったとき、右クリックで攻撃してしまう問題を修正しました。
- 「酔って蒋門神を打つ」の情報欄に、鴛鴦脚が使用可能かどうかと、クールダウンの残り時間を表示します。
