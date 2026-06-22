# 遭遇战模式 · 美术需求清单（边开发边攒，统一用 Safari→ChatGPT 管线出图）

出图流程见 `README.md` / `art-pipeline-chatgpt` 记忆：每张**新开一个 chat**，2×2 走循环用 `tools/cut_anim.gd` 切，
建筑/物件用 `tools/process_sheets.gd` 的等距物件流程切。占位图已就位，出图后替换即可，不阻塞开发。

## 单位（走循环，2×2 绿幕，4 帧）
- [x] `lou_luo` 喽啰（工人）：肩扛斧、短打粗布。→ `assets/anim/lou_luo_walk.png`（静/动同一套）。
- [x] `liang_ma` 梁山马军（骑兵）：着甲骑手 + 棕色战马 4 帧奔走循环。→ `assets/anim/liang_ma_walk.png`（无独立立绘，待机用走循环过渡帧，全程同一套）。

## 建筑（等距 3/4 俯视，绿幕，软投影；2×2 一张出 4 个 → `assets/buildings.png`）
- [x] `barracks` 兵营（寨栅校场+兵器架+杏黄旗）
- [x] `arrow_tower` 箭楼（两层木望楼）
- [x] `house` 民居（茅草顶小屋）
- [x] `depot` 仓库（囤粮木仓）
- [ ] （后续）`stable` 马厩：木栏马厩 + 草料。
  - 单张 2×2 prompt：「a 2x2 grid, isometric 3/4 top-down Song-dynasty Water-Margin buildings on flat light-gray bg, soft ground shadow, gongbi painted: (1) a stockade military training camp 'barracks' with weapon racks and a yellow banner; (2) a two-storey timber arrow watchtower 'arrow_tower' with railings and arrow slits; (3) a thatched rammed-earth peasant house 'house'; (4) a timber granary/storehouse 'depot'. thin black grid lines, no text.」

## 资源点（等距物件，2×2 绿幕一张出 4 个 → `assets/objects.png`，art_db `object_texture`）
- [x] `gold_mine` 金矿：裸露金脉的岩堆 + 矿洞口。
- [x] `tree` 林木：松/阔叶/垂柳三种，按节点坐标稳定取一种使林子有变化。

## 头像（自由模式练英雄花名册，缺的补）
- 现有头像已覆盖宋江/吴用/林冲/花荣/李逵/鲁智深/武松等；练英雄阶段缺谁再补。
