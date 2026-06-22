# 美术资源生成提示词（Imagen 2）

共 3 张大图。生成参数：**1:1 比例，尽量 1024×1024 或更高**。
生成后按下面的文件名放进 `assets/` 目录即可（不必完美对齐网格，拿到图后我来校准切片和抠底）：

| 文件名 | 网格 | 用途 |
|---|---|---|
| `assets/units_sheet.png` | 4×4（每格 256px） | 单位精灵 |
| `assets/terrain_sheet.png` | 4×4（每格 256px） | 地形纹理 |
| `assets/portraits_sheet.png` | 3×3（每格 ~341px） | 剧情对话头像 |

游戏会自动检测这三个文件：存在就按网格切片使用，不存在就用代码占位图形。

---

## 提示词 1：单位图集（units_sheet.png）

> A sprite sheet for a 2D real-time strategy game: a strict 4x4 grid of 16 equal square cells separated by thin black lines, every cell filled with a plain solid light-gray background. Each cell contains ONE full-body character sprite, centered, same scale and same hand-painted historical game-art style throughout, three-quarter top-down view like a classic isometric RTS. Setting: Northern Song dynasty China, the "Water Margin" (Outlaws of the Marsh). No text, no watermark.
> Row 1, left to right: (1) Song Jiang, a stout charismatic outlaw chieftain in an apricot-yellow battle robe holding a sword; (2) Wu Yong, a thin strategist in a black scholar's robe and headscarf holding a bronze-feather fan; (3) Lin Chong, a fierce spear master in dark lamellar armor with a long spear; (4) Hua Rong, a handsome young archer in silver-white light armor drawing an ornate bow.
> Row 2: (5) Liangshan outlaw infantryman with a podao saber and straw rain-cape; (6) Liangshan spearman with a long bamboo pike and wide bamboo hat; (7) Liangshan archer wearing a reed-camouflage cloak with a short bow; (8) Liangshan flag bearer carrying a large apricot-yellow banner.
> Row 3: (9) Imperial Song soldier with sword and rectangular shield, red and black lamellar armor; (10) imperial spearman with halberd; (11) imperial crossbowman; (12) imperial heavy cavalryman on an armored brown horse.
> Row 4: (13) Gao Qiu, an arrogant imperial grand marshal in ornate gilded armor and red cape riding a white horse; (14) imperial flag bearer with a tall red banner; (15) a small wooden war boat with a single sail; (16) a war drummer beating a large drum.

**格子对照表**（列, 行，从 0 计）：

| | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| **行0** | 宋江 | 吴用 | 林冲 | 花荣 |
| **行1** | 梁山朴刀手 | 梁山长枪手 | 梁山弓手 | 梁山旗手(备用) |
| **行2** | 官军刀盾兵 | 官军长枪兵(备用) | 官军弓手 | 官军骑兵 |
| **行3** | 高俅 | 官军旗手(备用) | 战船(备用) | 鼓手(备用) |

---

## 提示词 2：地形图集（terrain_sheet.png）

> A 4x4 grid of 16 equal square top-down terrain texture tiles for a 2D strategy game, thin black lines separating cells, hand-painted style, consistent palette, each tile fills its whole cell edge to edge (seamless tileable texture), no text, no watermark. Setting: the vast Liangshan marsh of Song-dynasty China.
> Row 1: (1) deep lake water, dark blue-green with subtle ripples; (2) shallow shore water with mud showing through; (3) swampy marsh mud with puddles and sparse grass; (4) dense green reed beds seen from above.
> Row 2: (5) lush green grass; (6) green grass with small wildflowers; (7) packed earth dirt road on a raised dike with wooden edge reinforcements; (8) dense forest canopy seen from above.
> Row 3: (9) a large Song-dynasty timber great-hall with curved tile roof and a yellow banner, seen from a three-quarter top-down view, centered on plain light-gray background; (10) a wooden watchtower, three-quarter top-down view on plain background; (11) a wooden palisade wall section, top-down; (12) an apricot-yellow war banner on a pole, plain background.
> Row 4: (13) an imperial army tent, red fabric, three-quarter top-down view on plain background; (14) mossy rocks on grass; (15) a small wooden sampan boat seen from above on plain background; (16) a wooden plank bridge surface, top-down.

**格子对照表**：

| | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| **行0** | 深水 | 浅滩 | 沼泽 | 芦苇 |
| **行1** | 草地 | 草地变体 | 土堤道路 | 树林 |
| **行2** | 聚义厅 | 哨塔(备用) | 木栅(备用) | 杏黄旗(备用) |
| **行3** | 官军营帐(备用) | 岩石(备用) | 小船(备用) | 木桥(备用) |

---

## 提示词 3：头像图集（portraits_sheet.png）

> A 3x3 grid of 9 equal square character portrait busts for a Chinese historical strategy game, thin black lines separating cells, painted in a dramatic classical wuxia ink-and-color style, head and shoulders, consistent lighting, Song dynasty, characters from the novel "Water Margin". No text, no watermark.
> Row 1: (1) Song Jiang — a stout middle-aged outlaw leader with a short beard, warm commanding eyes, apricot-yellow robe; (2) Wu Yong — a thin clever strategist with a wispy goatee, black scholar's headscarf, holding a feather fan near his chin; (3) Gao Qiu — an arrogant sneering imperial grand marshal in gilded armor and an official's hat.
> Row 2: (4) Lin Chong — a stern leopard-headed warrior with round eyes and a bristling beard, dark armor; (5) Hua Rong — a handsome young archer in silver-white armor with a bow over his shoulder; (6) a wide misty landscape of the Liangshan marsh fortress at dawn, reeds and water, a yellow banner on the distant stronghold (used as the narrator portrait).
> Row 3: (7) Lu Zhishen — a burly tattooed monk with a staff; (8) Wu Song — a powerful tiger-slaying warrior; (9) Li Kui — a wild black-skinned brawler with two axes.

**格子对照表**：

| | 0 | 1 | 2 |
|---|---|---|---|
| **行0** | 宋江 | 吴用 | 高俅 |
| **行1** | 林冲 | 花荣 | 旁白(水泊远景) |
| **行2** | 鲁智深(备用) | 武松(备用) | 李逵(备用) |

---

## 提示词 2B：等距地形图 v2（terrain_sheet_raw_iso.png）

游戏转等距视角后的地形图精修版。**生成后保存为 `assets/terrain_sheet_raw_iso.png`**（不要覆盖旧图，
切图时会择优拼合：新图地面格 + 新旧之间更好的物件格）。格子布局与提示词 2 完全一致。

> A 4x4 sprite sheet grid of 16 equal square cells separated by thin black lines, for an isometric real-time strategy game in the style of a classic isometric RTS. Setting: the vast Liangshan marsh, Song dynasty China. Hand-painted, consistent muted natural palette, soft even overhead lighting, no text, no watermark.
> Cells 1 to 8 (rows 1-2) are SEAMLESS TILEABLE ground textures filling their whole cell edge to edge: perfectly uniform density, no borders, no vignette, no large objects, no directional pattern, so they tile invisibly in any direction.
> Row 1: (1) deep lake water, dark blue-green, calm with faint scattered ripples; (2) shallow marshy shore, wet mud and moss patches; (3) deep swamp mud, dark wet earth with small puddles; (4) dense green reed beds seen from above, even tufts.
> Row 2: (5) lush green grass; (6) slightly drier grass with tiny wildflowers; (7) packed bare earth road surface, trampled dirt with scattered pebbles and faint hoofprints, absolutely NO wooden planks, NO edges, NO ruts; (8) dense forest canopy from above.
> Cells 9 to 16 (rows 3-4) are isometric game sprites in three-quarter view, camera looking down at 45 degrees from the south-east exactly like a classic isometric RTS buildings, each centered on a plain solid light-gray background:
> (9) grand Song-dynasty timber great-hall with sweeping tiled roof and an apricot-yellow banner; (10) wooden watchtower with thatched top; (11) wooden palisade wall segment running diagonally; (12) tall apricot-yellow war banner on a pole; (13) imperial army command tent, red fabric with gold trim; (14) cluster of mossy rocks; (15) small flat-bottomed marsh sampan boat; (16) short wooden pier segment running diagonally.

要点：地面格"无方向性、无边框、无大物件"最关键——游戏里用连续取样跨格延展纹理，
任何边框或大物件都会变成显眼的周期图案。土路那格务必没有木桩和车辙（旧图的主要问题）。

## 生成小贴士

- 一次生成 2–4 张候选，挑网格最规整、风格最统一的一张。
- 如果整张图风格难以统一，可以退化为**逐格单独生成**：把上面对应格子的描述单独抽出来，加上前缀
  "A single game sprite, hand-painted style, three-quarter top-down view, full body, centered, plain solid light-gray background, Song dynasty Water Margin, no text —"。
  单独生成的图发我，我来拼图集。
- 单位图要求纯色浅灰背景是为了方便抠底；拿到图后我会做色键抠图并校准网格。

---

# 第二批美术：五幕战役新增（由设计 workflow 产出）

下面 4 张图集覆盖第1–4关的新角色/地形/头像。生成参数同前（1:1，1024²+，灰底，thin black grid lines，no text）。
生成后存为对应 `*_raw.png`，再跑切图脚本接入（切图脚本会扩展为支持多图集）。

## 4×4 单位图集（梁山新好汉）
**存为 `assets/units2_raw.png`** · 网格 4x4 · sheet_id `units_sheet_02_liangshan_heroes`

格子对照：
- 格0：晁盖(托塔天王)：魁梧主帅，络腮短须，皂巾或范阳毡笠，深褐皮甲外罩赭黄战袍，一手按朴刀一手叉腰（L1/L2复用，与宋江同尺度）
- 格1：公孙胜(入云龙)：清癯道人，道髻木簪，青灰道袍外罩八卦法衣，一手掐剑诀一手持桃木符/拂尘，隐有云气
- 格2：刘唐(赤发鬼)：亡命猛汉，赤红乱发，鬓边朱砂胎记，赤膊半披褐衣露虬结肌肉，双手握宽背朴刀作劈砍势
- 格3：阮氏三雄(渔家水军)：赤膊精瘦，青布渔巾，腰系水裈打绑腿赤足，手持渔叉或短朴刀（1款通用代表小二/小五/小七）
- 格4：白胜(白日鼠·挑酒汉)：瘦小灵巧，破凉笠敞怀短褐赤足，肩挑双酒桶酒担(担头插'酒'字小旗)，一手扶担一手摇蒲扇笑卖
- 格5：李逵(黑旋风)：黝黑壮硕满脸虬髯，赤膊上身，双手各执阔刃板斧，怒目张口怒吼作劈砍前冲，腰束布带短裤草鞋
- 格6：戴宗(神行太保)：清瘦干练面色微赤，皂色轻便短打，腿上绑四片画符篆的'甲马'布条，麻鞋疾走奔行态衣袂飘起
- 格7：张顺(浪里白条)：肤色雪白精壮水军，仅着短裤水裈赤足赤膊，水巾束发，手持渔叉/单刀半弯腰搏浪姿，身带水光
- 格8：燕顺(锦毛虎)：黄发赤须凶悍头目，披虎纹黄褐毛皮战袍内着皮甲，手执朴刀/单刀叉腿挺立冲阵
- 格9：石秀(拼命三郎)：精悍机敏青年好汉，短打劲装束腰，背缚行脚客斗笠小包袱，手持朴刀身形轻快前倾探步引路
- 格10：徐宁(金枪手)：英武教头，锃亮鱼鳞细甲披白银战袍，手持精钢钩镰长枪(枪尖带亮钩)挺拔如教武，腰悬佩刀
- 格11：汤隆(金钱豹子)：古铜肤色面带豹纹斑点，短打劲装袒臂露豹斑纹身，手持飞标/短戟腰挂铁锤，机敏狡黠
- 格12：钩镰枪手：梁山步兵手持钩镰枪(枪顶带内弯利钩、钩刃朝下专钩马腿)，压低枪头钩划马腿备战姿，轻皮甲短打缠腿
- 格13：祝家庄客(近战庄丁)：训练有素庄丁，短褐布衣外罩皮护甲扎头巾，手持单刀或哨棒，土黄褐配暗红束带结实剽悍
- 格14：祝家弓手(远程庄丁)：轻便短褐皮臂韝，半蹲开弓搭箭(伏兵冷箭姿)背负箭壶，土黄褐更轻装
- 格15：祝家马军(庄堡骑兵)：皮甲布面甲跨褐马，手持长枪/马刀，褐黄配深红旗号，较官军骑兵轻便显乡勇

> A 4x4 sprite atlas sheet, 16 cells in a strict 4-by-4 grid separated by thin black grid lines, flat neutral light-gray background for easy cutout, isometric 3/4 top-down view (Age-of-Empires-II angle), Song-dynasty Chinese Water-Margin (Shuihu) gongbi fine-brush painting style, consistent scale and lighting across all cells, each cell one full-body standing character, no text, no labels. Cells row by row: (1) Chao Gai 'Pagoda-bearing Heavenly King', burly broad-faced chieftain with short full beard, black headscarf or felt hat, dark-brown leather armor under an ochre-yellow battle robe, one hand on a saber the other on hip; (2) Gongsun Sheng 'Dragon-in-the-Clouds', gaunt Taoist priest, hair-bun with wooden pin, grey-blue Taoist robe with eight-trigram overcloak, one hand making a sword-finger gesture the other holding a peachwood talisman, faint cloud-qi; (3) Liu Tang 'Red-haired Devil', desperate fierce man with bright-red messy hair and a cinnabar birthmark by the temple, bare-chested showing knotted muscle, both hands gripping a broad-backed pudao mid-chop; (4) Ruan fisher-warrior, lean bare-chested fisherman with blue cloth fishing turban, water-loincloth and leg-wraps barefoot, holding a fish-spear or short pudao; (5) Bai Sheng wine-peddler, small nimble commoner in broken straw hat and open short jacket barefoot, shouldering a yoke of two wine barrels with a small wine-flag, one hand steadying the pole one waving a palm fan, sly grin; (6) Li Kui 'Black Whirlwind', dark muscular bearded man bare-chested, a broad axe in each hand, glaring open-mouthed roar lunging to chop, cloth belt and short pants straw sandals; (7) Dai Zong 'Magic Traveler', lean wiry runner with flushed face, black light travel garb, four paper-talisman 'spirit-horse' cloth bands strapped to his calves, hemp shoes, mid-stride dashing pose with flying sleeves; (8) Zhang Shun, snow-white-skinned muscular water-warrior in only shorts barefoot bare-chested, water cloth headband, holding a fish-fork or saber, half-crouched wave-fighting stance with watery sheen; (9) Yan Shun 'Brocade-furred Tiger', fierce bandit chief with yellow hair and red beard, draped in tiger-stripe tawny fur war-cloak over leather armor, holding a pudao, charging stance; (10) Shi Xiu, wiry nimble young hero in short fighting garb with waist sash, a traveler's bamboo hat and small bundle on his back, holding a pudao, light forward-leaning scouting step; (11) Xu Ning 'Golden-spear Drillmaster', valiant instructor in gleaming fish-scale armor and white war-cape, holding a fine-steel hook-sickle long spear with bright hooked tip, upright drilling posture; (12) Tang Long, bronze-skinned wiry blacksmith hero with leopard-spot markings, short garb bare arm showing leopard tattoo, holding a throwing-dart with a hammer at his belt; (13) hook-sickle spearman, Liangshan footsoldier holding a hook-sickle spear with an inward curved hook pointing down to slash horse legs, low hooking ready-stance, light leather armor with leg-wraps; (14) Zhu-manor melee retainer, well-drilled estate guard in short brown tunic over leather guard, head cloth, holding a saber or staff, earth-yellow-brown with dark-red sash; (15) Zhu-manor archer, light short tunic with leather arm-guard, half-kneeling drawing a bow (ambush pose), quiver on back; (16) Zhu-manor cavalry, rider in leather/cloth-faced armor on a brown horse holding a spear, brown-yellow with deep-red banners, rustic. Keep a clean thin black border between every cell.

## 4×4 单位图集（敌将/特殊/目标物）
**存为 `assets/units3_raw.png`** · 网格 4x4 · sheet_id `units_sheet_03_imperial_and_special`

格子对照：
- 格0：杨志(青面兽)：精悍刀客，面带青色胎记，范阳笠/抹额，磨亮暗色鱼鳞甲肩搭旧战袍，双手按家传宝刀，冷峻精英
- 格1：军汉(挑担押运厢军)：汗流浃背士卒，巾裹头短打皂衣草鞋，肩挑沉甸甸财货箱笼担子，一手扶担一手抹汗中暑疲态，腰挎朴刀
- 格2：军汉·瘫倒态(蒙汗药昏睡)：同军汉装束，瘫倒/昏睡姿，口角流涎四仰八叉躺地(备用药倒态)
- 格3：虞候(押运军官)：硬脚幞头/皮盔，半身皮甲外罩青色公服，手持朴刀/哨棒，比军汉齐整神气
- 格4：老都管(随行老管事)：白须老管事，软脚幞头绸面长衫拄拐杖，富态文弱一脸热昏窘相，无战力
- 格5：刽子手(行刑手)：赤膊壮汉头裹红巾面蒙黑布/狞笑，露肥硕肌肉束红腰布，双手高举宽大鬼头大刀作举刀欲斩凶态
- 格6：江州牢子(法场看守)：皂色软帽青灰公人短褂(比官军刀盾简朴)，手持水火棍或单刀小盾，腰悬铁链腰牌神情木然
- 格7：连环马(重甲连锁骑兵)：重甲骑兵骑披全套马甲褐马，黑铁扎甲兜鍪持长枪/铁锏，马身侧面挂出一截粗铁环锁链向左右延伸(连缀成排)，厚重肃杀正面冲锋姿
- 格8：呼延灼(双鞭重甲骑将)：威猛骑将骑披重甲玄黑战马，连环铁叶重铠凤翅兜鍪红玄战袍，双手各执一条钢鞭(双鞭对称)，满面虬髯气势凌人主将规格
- 格9：韩滔/彭玘(精英骑将通用)：官军精英骑将，较华丽红黑扎甲骑战马持长枪/方天画戟，介于普通骑兵与主将之间(以名牌区分二人)
- 格10：生辰纲宝车·完好态：木质货车(独轮/双轮)，车上堆满裹红布捆扎结实的箱笼财货隐露金珠绸缎，车辕搭地停放(建筑/目标)
- 格11：生辰纲宝车·被夺态：同货车，绳索解开箱笼敞口露宝(卸载态)
- 格12：官军精骑/铁浮屠(可选)：在官军骑兵基础上乌黑重甲、马披全身马铠，金属高光暗红披风，比普通骑兵更精锐沉重
- 格13：空格(留白·备用单位格)
- 格14：空格(留白·备用单位格)
- 格15：空格(留白·备用单位格)

> A 4x4 sprite atlas sheet, 16 cells in a strict 4-by-4 grid separated by thin black grid lines, flat neutral light-gray background for easy cutout, isometric 3/4 top-down view (Age-of-Empires-II angle), Song-dynasty Chinese Water-Margin gongbi fine-brush painting style, consistent scale and lighting, no text, no labels. Cells row by row: (1) Yang Zhi 'Blue-faced Beast', lean fierce swordsman with a blue birthmark across his cheek, brimmed hat or forehead-wrap, polished dark fish-scale armor with an old war robe over the shoulder, both hands on a heirloom saber, cold elite bearing; (2) escort soldier-laborer, sweat-soaked garrison conscript in head cloth and dark short tunic straw sandals, shouldering a carrying-pole with cloth-wrapped treasure crates, one hand steadying the pole one wiping sweat, heat-exhausted, a pudao at his waist; (3) the same conscript collapsed/asleep sprawled drooling (drugged knocked-out pose); (4) escort officer (yuhou), stiff-winged futou cap or leather helmet, half leather armor over a teal official tunic, holding a pudao or staff, neater than the conscript; (5) old steward, white-bearded elderly manor steward in soft futou cap and silk long gown leaning on a cane, plump and frail dazed from heat; (6) executioner, bare-chested burly headsman with red head-wrap and black face cloth, hefting a huge broad executioner's blade overhead in a beheading stance, red waist cloth; (7) Jiangzhou jailer-guard, black soft cap and grey-teal clerk's short jacket simpler than imperial soldiers, holding a fire-water staff or saber with small shield, iron chain and badge at waist, blank expression; (8) chained-cavalry 'lianhuan ma', heavily-armored rider on a fully horse-armored brown warhorse, black lamellar armor and helmet holding a spear/mace, a thick iron-ring chain visibly extending left and right from the horse's flank linking into a row, heavy grim frontal-charge pose; (9) Huyan Zhuo the double-mace general, mighty heavily-armored cavalry general on a black armored warhorse, layered iron-leaf heavy armor with phoenix-wing helmet and red-black war robe, a steel mace in each hand, full bristling beard, commanding boss scale; (10) elite imperial cavalry officer shared for Han Tao and Peng Qi, ornate red-black lamellar armor on a warhorse holding a spear or crescent-halberd, between common cavalry and the boss; (11) the Birthday-Convoy treasure cart intact, a wooden hand/two-wheeled cart piled with red-cloth-wrapped bound treasure crates faintly showing gold and silk, shafts resting on the ground (stationary objective); (12) the same treasure cart looted, ropes undone and crates burst open spilling treasure; (13) optional heavy elite 'iron-pagoda' cavalry, a darker recolor in jet-black heavy armor with full horse barding, metallic highlights and dark-red cape; (14) empty flat light-gray cell; (15) empty flat light-gray cell; (16) empty flat light-gray cell. Keep a clean thin black border between every cell; empty cells just flat light-gray.

## 4×4 地形图集（丘陵/城镇/村庄）
**存为 `assets/terrain2_raw.png`** · 网格 4x4 · sheet_id `terrain_sheet_02_hills_town_village`

格子对照：
- 格0：黄土坡地地块 dryhill(无缝平铺)：赭黄到土褐板结泥土，稀疏枯黄草茎与碎石，无方向无边框，黄泥冈主体地面
- 格1：丘陵岩坡地块 cliff(不可通行)：黄褐裸露岩坡/断崖断面，层叠风化砂岩陡峭石壁带阴影，视觉明确不可逾越
- 格2：法场夯土广场地块 plaza_ground(无缝)：夯实青灰色市集广场地面略带石板缝与踩踏痕，城镇硬地，色偏石灰青
- 格3：江州街道土路地块 street_tile(无缝)：踩实黄褐土街零星碎石车辙，无木板无边框，城镇主干道(加速同road)
- 格4：田埂农田地块 field_ridge(无缝)：宋代乡村农田垄沟田埂纹理，半黄半绿稻麦田与裸土埂，赭黄+草绿质朴
- 格5：开阔平原决战场地块 plain_battlefield(无缝)：被铁骑反复践踏的开阔旷野，夯实浅褐草甸散布枯草与马蹄印车辙压痕，平坦干硬
- 格6：空格(留白·备用地块格)
- 格7：空格(留白·备用地块格)
- 格8：松树/松林等距物件 pine：黄泥冈旱地油松/马尾松，虬曲苍劲松干伞状墨绿松冠三两成丛带落地阴影
- 格9：白杨树等距物件 white_poplar(盘陀路路标)：挺直主干银白树皮顶端纵向窄叶冠，比普通树林瘦高更亮醒目易辨
- 格10：法场刑台等距物件 scaffold(2x2建筑)：宋代市曹方形夯木台基四角立柱围低矮木栏，台上两根木桩与'斩'字招魂幡，阴森肃杀
- 格11：江州市井屋舍等距物件 town_house(2x2)：宋代江南市镇白墙黛瓦民居/店铺，临街木格窗门板挑出布幌酒旗，可重复铺设
- 格12：江边码头等距物件 dock：浔阳江边斜向木栈码头，栈桥尽头停泊位系缆绳(船体复用战船精灵)，登船撤退目标点
- 格13：祝家庄门等距物件 zhu_gate(目标建筑，约1x3横向)：厚重木质双扇大门嵌夯土木栅壁垒缺口，门楼覆瓦悬'祝'字匾额旗幡箭楼垛口，森严坚固
- 格14：祝家祠堂/内院主楼等距物件 zhu_hall：宋代乡绅祠堂青瓦歇山顶雕花门廊悬祖宗牌匾灯笼，殷实气派(比聚义厅更精致乡绅)
- 格15：夯土木栅壁垒段等距物件 village_palisade：下为夯土矮墙上为削尖木栅栏与了望垛口，可斜向平铺成连续庄墙

> A 4x4 terrain atlas sheet, 16 cells in a strict 4-by-4 grid separated by thin black grid lines, flat neutral light-gray background, Song-dynasty Chinese Water-Margin gongbi painting style, no text, no labels. The FIRST 8 cells (rows 1-2) are seamless tileable top-down ground textures with NO directional features, NO borders, NO large objects, sampleable continuously across adjacent tiles; the LAST 8 cells (rows 3-4) are centered isometric 3/4 top-down (isometric 45-degree) objects/buildings each with a soft ground shadow. Ground tiles: (1) dry loess hill ground 'dryhill', cracked ochre-to-tan packed earth with sparse withered grass tufts and pebbles, hot arid tone; (2) cliff rock-slope 'cliff', exposed yellow-brown weathered sandstone strata and steep shadowed rock face reading as impassable; (3) rammed-earth plaza ground 'plaza_ground', compacted grey-blue market square with faint flagstone seams and trampled wear, limestone-grey town paving; (4) town street dirt road 'street_tile', packed yellow-brown earthen street with gravel and cart ruts, no planks no border; (5) farm-field ridge 'field_ridge', rural furrow-and-ridge farmland, half-yellow half-green grain field with bare earth ridges; (6) trampled open battlefield plain 'plain_battlefield', wide flat sun-baked pale-brown meadow with sparse dry grass, hoof-prints and cart ruts, hard and level; (7) empty flat light-gray cell; (8) empty flat light-gray cell. Isometric objects: (9) dry-hill pine 'pine', gnarled rugged pine trunk with an umbrella of dark-green needle-canopy in small clusters, cast shadow; (10) white poplar landmark tree 'white_poplar', a single tall straight poplar with silvery-white bark and a slim vertical leaf-crown, taller and brighter than ordinary forest; (11) execution scaffold 'scaffold' about 2x2 footprint, a square rammed-timber platform with corner posts and low wood rail, two binding posts and a 'beheading' soul-banner on top, grim; (12) Jiangzhou townhouse 'town_house' about 2x2, Song Jiangnan whitewashed wall with dark tiled roof, street-facing lattice windows and a hanging cloth banner, tileable into streets; (13) riverside dock 'dock', a slanted timber plank pier with a mooring berth at its end and tied ropes, an embarkation point; (14) Zhu manor gate 'zhu_gate' about 1x3 wide, a heavy twin-leaf wooden gate set in a rammed-earth palisade gap, tiled gate-tower with a 'Zhu' plaque, banners and arrow-tower battlements, fortified; (15) Zhu ancestral hall 'zhu_hall', Song gentry shrine with grey-tiled hip-and-gable roof, carved porch, ancestral plaque and lanterns, refined; (16) rammed-earth palisade segment 'village_palisade', a low rammed-earth wall topped with sharpened wooden stakes and watch battlements, tileable diagonally. Keep a clean thin black border between every cell; empty cells flat light-gray.

## 3×3 头像图集（新登场人物）
**存为 `assets/portraits2_raw.png`** · 网格 3x3 · sheet_id `portraits_sheet_02_new_faces`

格子对照：
- 格0：晁盖头像：托塔天王，络腮短须浓眉阔脸目光豪迈仗义，皂巾，赭黄战袍露皮甲领，山东庄主豪气(L1/L2复用)
- 格1：杨志头像：青面兽，面颊标志性青色胎记，剑眉冷目郁郁刚硬，范阳笠/抹额，暗色鱼鳞甲领，落魄英武敌将
- 格2：白胜头像：白日鼠，市井闲汉尖脸细眼一脸机灵市侩的笑，破凉笠敞怀短褐，油滑促狭(卖酒下药桥段)
- 格3：蔡九知府头像：养尊处优面白微胖中年官僚，宋代展脚幞头绯色官袍补服，阴鸷倨傲冷笑，反派督战
- 格4：石秀头像：拼命三郎，精悍机敏青年浓眉锐目果决带江湖机警，束发布巾青灰短打肩露朴刀柄
- 格5：扈三娘头像：一丈青，英姿飒爽青年女将明眸英气，红缨束发长辫垂肩，青绿戎装软甲肩后双刀，柔美凛冽
- 格6：徐宁头像：金枪手，英武清俊中年教头刚毅专注，银白鱼鳞甲披白战袍，肩后露钩镰枪尖，教头宗师
- 格7：呼延灼头像：双鞭，满面虬髯剑眉怒目重甲悍将，凤翅兜鍪玄黑连环重铠，身侧隐现双钢鞭，傲然彪悍反派主将
- 格8：汤隆头像：金钱豹子，古铜肤色面带豹纹斑点精悍铁匠好汉，短须机敏带笑，袒臂露豹斑纹身劲装短打，献策狡黠

> A 3x3 portrait atlas sheet, 9 cells in a strict 3-by-3 grid separated by thin black grid lines, flat neutral light-gray background, classic Chinese wuxia gongbi ink-and-color painting style, dramatic head-and-shoulders bust portraits, consistent lighting and scale matching an existing Water-Margin portrait set, no text, no labels. Cells row by row: (1) Chao Gai 'Pagoda-bearing Heavenly King', broad-faced chieftain with short full beard and thick brows, righteous generous gaze, black headscarf, ochre-yellow war robe showing a leather armor collar, hearty Shandong-squire bearing; (2) Yang Zhi 'Blue-faced Beast', a blue birthmark across his cheek, sword-like brows and cold brooding hard eyes, brimmed hat or forehead-wrap, dark fish-scale armor collar, fallen-hero air; (3) Bai Sheng 'Daylight Rat', a street commoner with a narrow face and thin eyes wearing a sly merchant grin, broken straw hat and open short jacket, oily roguish look; (4) Prefect Cai Jiu, a pampered pale slightly plump middle-aged official, Song winged futou cap and crimson official robe with rank-badge, a sinister haughty cold smile; (5) Shi Xiu, a sharp alert young hero with thick brows and keen resolute eyes carrying jianghu wariness, hair-cloth headband and grey-blue short garb with a pudao hilt at the shoulder; (6) Hu Sanniang 'Ten-foot Green', a dashing spirited young woman general with bright heroic eyes, red-tassel-bound hair and a long braid over the shoulder, teal-green battle dress and soft armor with twin sabers behind, both delicate and fierce; (7) Xu Ning 'Golden-spear Drillmaster', a valiant handsome middle-aged instructor with firm focused features, silver-white fish-scale armor and white war cape, a hook-sickle spear-tip peeking over the shoulder; (8) Huyan Zhuo the double-mace general, a heavily-bearded fierce armored warrior with knit brows and glaring eyes, phoenix-wing helmet and jet-black layered iron armor, twin steel maces faintly at his side, proud ferocious villain boss; (9) Tang Long 'Money-leopard', a bronze-skinned wiry blacksmith hero with faint leopard-spot markings, short beard and a clever smiling look, bare arm showing a leopard tattoo, short fighting garb. Keep a clean thin black border between every cell.

---

## 3×3 头像图集（据守模式·地方英雄）— portraits4
**存为 `assets/portraits4_raw.png`** · 网格 3x3 · 补「原本没头像」的敌将
格子：0栾廷玉 1韩滔 2彭玘 · 3祝龙 4祝虎 5祝彪 · 6祝朝奉 7史文恭(新) 8空
> （见 /tmp/cg/prompt_portraits4.txt：gongbi 半身像九宫，淡灰底不抠，与既有头像同风格。）

## 2×2 走刀（绿幕）— 据守 boss 战场立绘
**生成 `/tmp/cg/walk_<key>.png`（绿底 RGB 0,177,64）→ `tools/cut_anim.gd` → `assets/anim/<key>_walk.png`**
已出：`shi_wengong`（史文恭·画戟）、`luan_tingyu`（栾廷玉·铁棒）。
模板：2×2 四帧走循环(TL右脚前/TR并腿抬/BL左脚前/BR过渡)、3/4 侧朝右、等距俯角、gongbi、纯绿底无影。
其余敌将（呼延灼/祝家三杰/扈三娘/张团练/龚旺/丁得孙/蔡九/陆谦/韩滔/彭玘）暂只有头像、战场仍程序化——可续出走刀。
