# 非长传原著文本审查

日期：2026-09-08。依据一百二十回袁无涯本《忠义水浒全传》，以维基文库原文为第一手文本；不以影视、评书、续书及人物百科替代原著。本文为改动方案与核查记录，源代码、词库集成及 Godot 验证由主任务完成。

## 覆盖范围与结果

- `scripts/bios.gd`：162 条 BIOS、108 条 STAR、28 条备用 LORE 全部审读。提出 39 条 BIOS、15 条备用 LORE 修订；STAR 座次、姓名、星号、绰号逐项对照第 71 回，保留版本字形差异。
- `scripts/defs.gd`：完整审读 663 个 name 字段和 473 个 desc 字段，范围包括单位、技能、陷阱、科技。只提出单廷珪显示名及技能说明姓名修订；游戏法术、分身、召唤、投射物、数值和专属兵种保留为游戏设计，不冒充原著人物武器或职司。
- 8 幕战役及兼容旧版本：15 个 `level*.gd` 中的 1,624 个含汉字字符串，含剧情对白、任务目标、交互记录、章回目标、胜败旁白、当前脚本及继承关系；逐幕对照原著节点。关卡流程和操作说明按游戏实现区分，未把每个游戏机制强改为原著叙事。
- `scripts/campaign.gd`：8 个关卡标题、副题、入口及 `STORY_ORDER`；当前顺序野猪林→黄泥冈→快活林→江州→祝家庄→连环马→大名府→三败高俅符合原著事件先后，无需调换入口。
- 额外对照 `skirmish.gd` 全部 30 波文字、竞技场实际刷兵和等级函数、菜单 1v1 胜利条件及驻守建筑称谓。
- 共 77 条方案，11 个源文件，77 个精确 GDScript 字符串 token 命中。`old_source/source/en/ja` 均为运行时解码值；唯一多行技能说明含真实换行。中文与英日的 printf、花括号变量及换行数量一致。

## 主要校正与原著证据

每项完整中英日文、章目与 URL 见 `story_changes.json`。以下为证据摘要，非原文长摘录。

| 项目 | 原著核查结果 |
|---|---|
| 杨志经历 | 第 12–13 回卖刀杀牛二、刺配大名府；第 16 回押生辰纲失陷；第 17 回上二龙山。原短传先押纲后卖刀倒置。 |
| 石秀 | 第 44 回自述金陵建康府人，蓟州为流落卖柴之地；第 118 回昱岭关随史进等中伏战死，非常州。 |
| 栾廷玉师门 | 第 49–50 回明确孙立与栾廷玉同师，孙立凭此入庄；不支持史文恭与栾廷玉同门，更不支持共同师从周侗。 |
| 晁盖与史文恭 | 第 60 回正面描写为乱箭中毒箭、箭有史文恭姓名，未直接描写发箭动作；晁盖回梁山后身亡。第 68 回史文恭刺伤秦明、被卢俊义生擒。保留箭上署名，不作阴谋推断。 |
| 闻达 | 第 12、66 回称闻大刀；李天王属于李成。短传与驻守波次均纠正。 |
| 梁山职司 | 第 71 回钱粮为柴进、李应；乐和为军中走报机密；朱富监造供应酒醋；王定六与李立掌北山酒店；段景住为军中走报机密。燕顺、杨林、欧鹏列马军小彪将；龚旺、丁得孙列步军将校。 |
| 外貌与号义 | 第 49 回孙立淡黄面皮；第 70 回皇甫端碧眼黄须，幽州人氏属实；第 67 回焦挺的没面目来自到处投人不着；第 41 回侯健黑瘦轻捷，不能仅从通臂猿反推臂长。 |
| 武松与花荣 | 第 31 回在十字坡由孙二娘助扮行者，之后过蜈蚣岭。第 35 回花荣在对影山断绒绦，第 47 回祝家庄射灭号灯。 |
| 刘唐、李逵 | 第 14 回刘唐久闻晁盖声名，先报信投奔再蒙救助，非报一饭旧恩。第 115 回刘唐死于杭州候潮门闸板。第 120 回宋江先让李逵喝毒酒，再告知实情，不能写知情含笑饮毒。 |
| 妇人与结局 | 第 50 回宋江给扈三娘王英配婚，先于第 55 回擒彭玘；第 117 回扈三娘被郑彪镀金铜砖打死。第 113 回施恩在常熟、孔亮在昆山落水溺亡。 |
| 其他结局 | 第 114 回徐宁杭州中箭后送秀州治疗、半月死，郝思文杭州被擒遇害；第 115 回鲍旭杭州被石宝斩杀、龚旺德清陷溪被刺；第 118 回丁得孙在昱岭关后山路中蛇毒身亡。 |
| 姓名正字 | 第 67、71 回为单廷珪；STAR 已用珪。Defs 两处、BIOS 两处及驻守波次统一，内部 `shan_tinggui` 不变。 |

## 十节度使：完整名单核对

依据第 78 回列名，第 79 回交锋补足兵器。原著只列官职或战例时，不从游戏武器、外部话本补造绰号。

| 人物 | 第 78 回官职 | 核实事项 |
|---|---|---|
| 王焕 | 河南河北节度使 | 名单之首，长枪与林冲交战；原短传可保留。 |
| 徐京 | 上党太原节度使 | 第 79 回使枪卖药的早年经历，举荐闻焕章。 |
| 王文德 | 京北弘农节度使 | 第 78 回挺枪战董平，张清飞石打中盔顶。 |
| 梅展 | 颍州汝南节度使 | 第 79 回三尖两刃刀，救韩存保时受石；无急先锋绰号。 |
| 张开 | 中山安平节度使 | 第 79 回射张清马眼、使枪救梅展；无督炮专长。 |
| 杨温 | 江夏零陵节度使 | 第 78 回接应王文德；此本不支持病大虫、流星锤设定。 |
| 韩存保 | 云中雁门节度使 | 第 79 回使方天画戟战呼延灼，后被擒；当前未收录的真正第十人。 |
| 李从吉 | 陇西汉阳节度使 | 与韩存保为右军；蕃将身份无此本依据。 |
| 项元镇 | 琅琊彭城节度使 | 使枪，回身箭射中董平右臂。 |
| 荆忠 | 清河天水节度使 | 瓜黄马、大杆刀，被呼延灼钢鞭打死。 |

段鹏举确有其人：第 76–77 回为睢州兵马都监、童贯的正先锋。应保留 ID 和现有玩法，将人物说明归官军将领，不能算高俅十节度。增设韩存保单位涉及内容范围和素材，不是本次纠正事实的必要前提；建议本轮先避免以“十节度全员”称呼现有组合。

## 保留与游戏改编边界

- 第 37 回确有张顺水中七昼夜的叙述；第 55 回确有凌振炮打十四五里。保留小说奇异夸张，不以现代可行性删改。凌振官职改为甲仗库副炮手。
- 第 67 回鲍旭持阔剑，第 112 回也写大阔板刀；不能把所有刀字判为错误。本次短传采用首次登场阔剑，主要纠正死地和死因。第 55 回彭玘初登场三尖两刃刀有明确依据，保留。
- 皇甫端幽州籍贯第 70 回明确，保留；只改误从紫髯伯之号推成紫须的外貌。
- 第 40 回众人确实先退入白龙庙，遇张顺等乘船到来，再登船。现有关卡白龙庙在登船之前正确，未误改顺序。
- 第 47 回钟离老人指点遇白杨转弯；第 49–50 回孙立内应及救囚破庄；第 56–57 回时迁盗甲、汤隆荐徐宁、徐宁传枪；第 66 回宋江留山调养、吴用代领、蔡福给柴进乐和换公人衣、时迁火烧翠云楼、鲁智深武松接南门，均有正文对应。
- 十一担缩为三担、三千甲马缩为十二骑、十二三家酒店缩为四酒望、三次攻庄合并为连续 RTS 战斗、鲁智深跟随阶段作为可玩关卡，均明确加进各关旁白为游戏压缩。原著关键事件和操作目标仍保留。
- 驻守战的跨章将领、战象、驼骑、火枪、投弹兵组合保留游戏玩法，初始旁白补说明。Defs 幻术与 Q/W/E/R 是游戏技能；不从其数值反证人物原著事迹。
- 第 71 回星号及绰号存在祐/佑、嵇/稽/羁、那/哪、旛/幡、白跳/白条等传本和常见用字差异，未将字形差异误标为独立人物错误。

## 需主任务决定的显示结构

1. `ruan_brother` 运行单位叫“阮氏好汉”，而 STAR 此键为阮小二、长传也是阮小二。保留运行合并单位是游戏适配；图鉴人物页建议按 STAR 显示阮小二，并加一条合并单位说明，避免阮氏三人短传和阮小二个人长传混读。本方案未擅自把全战场名称重命名。
2. 十节度栏目若有显式全员集合，应改为官军诸将或注明当前选录；不将段鹏举重命名成韩存保，不借换名字改变已有兵器、图像与玩法。

## 校验边界

该批只写 QA 方案，没有改共享脚本或词库，没有提交。已复用主任务 `localization_catalog.strings` tokenizer 检查 77 条旧值全部精确命中，每条命中一次；三语 printf、`{v}` 和换行校验通过。主任务需在集成后重建词库、跑解析、场景和视觉检查。长期人物传记 108 篇由另两位代理负责，本记录不将其算作本代理已完成工作。

下方哈希只记录本次查证使用的本地原文缓存；完整公版原文放在被忽略的 `scratchpad/shuihu_120_primary`，不纳入 QA 提交。

## 原文来源 SHA-256 索引

| 回次 | 来源 | 缓存文件 | SHA-256 |
|---|---|---|---|
| 8 | [袁本第8回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC008%E5%9B%9E) | `008.txt` | `39f816a8084767d4fbfccf22e5563e7e0fa6af286616a5e1cef2e05d53101790` |
| 9 | [袁本第9回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC009%E5%9B%9E) | `009.txt` | `3f8ddd1ce8dec85ddccb9e3aaf45a8560803822944c52659795e0c975cd60b24` |
| 11 | [袁本第11回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC011%E5%9B%9E) | `011.txt` | `98d04d510dfc9486e70d84da685cbf65619caed53a5b568d87bc844050bf7408` |
| 12 | [袁本第12回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC012%E5%9B%9E) | `012.txt` | `1acf7d492a4d5234a3e4c7597a52f90b54f039149f0b57d2eb07b3caff96e75d` |
| 13 | [袁本第13回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC013%E5%9B%9E) | `013.txt` | `765bb1ef9266275de93e46fcd5ee99500a9696842662640f1a2939bd91965a86` |
| 14 | [袁本第14回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC014%E5%9B%9E) | `014.txt` | `64fd485acd0ee2a5d40fd21d0166e70eef5b45e32b21defae8b51f5a9b31eac1` |
| 16 | [袁本第16回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC016%E5%9B%9E) | `016.txt` | `3a8391cdd3f0ce853ac65de2648fc9f692bdfcc91cf01e6d145facfcec6f2324` |
| 17 | [袁本第17回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC017%E5%9B%9E) | `017.txt` | `a7e87ce5c3742ab0d7896f813e79a90225af338f201b7104cf400d9d3cf34320` |
| 23 | [袁本第23回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC023%E5%9B%9E) | `023.txt` | `06be3da8b4a5afe9ce1f5b65c953d7edc02a0af692774b51fd9c03c776437db3` |
| 26 | [袁本第26回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC026%E5%9B%9E) | `026.txt` | `b8d12b754170d22d541577a819294093d0b3ce02e7e70039a88d48f8ccc8f2b8` |
| 28 | [袁本第28回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC028%E5%9B%9E) | `028.txt` | `e79ee81ae9d6a49cd1bb770fc28bf17ce1067490c815b263ed7267ed43a9659e` |
| 29 | [袁本第29回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC029%E5%9B%9E) | `029.txt` | `67314b2f5d1a25d927474e02df798c685e441dfbff8640fde11c7ea861b03829` |
| 31 | [袁本第31回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC031%E5%9B%9E) | `031.txt` | `7886993a8eac0b482dca016f1ea3660f592451f7070ca66ac36992806cdd56a0` |
| 32 | [袁本第32回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC032%E5%9B%9E) | `032.txt` | `56fa4650cc47c94f23abdc01e24bc18cf8eadb3849fa3905fd25abfa66f81188` |
| 35 | [袁本第35回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC035%E5%9B%9E) | `035.txt` | `c13cbf0bba98a01635d42fe8a752aaa17e1bda26f08b047339e773f2ecdbdac6` |
| 37 | [袁本第37回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC037%E5%9B%9E) | `037.txt` | `a80ad3ca3bd84af839195577e93a37f76d22d3d35d7dd86e0ad42c0c2acfcd91` |
| 38 | [袁本第38回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC038%E5%9B%9E) | `038.txt` | `cca673daad25dc35eb76627f5639b91afc703eb40a72d9733a7091e45db01ede` |
| 40 | [袁本第40回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC040%E5%9B%9E) | `040.txt` | `80981cbc4ad56cdb128ad74f52dc363b2ee368a0e05badeda5394a8bab719de0` |
| 41 | [袁本第41回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC041%E5%9B%9E) | `041.txt` | `8cfb5e9659efd20982ae1c8c6f7f8acba6ced034862c217805fed0bc682a98d2` |
| 43 | [袁本第43回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC043%E5%9B%9E) | `043.txt` | `de9ef389b059b24fd46ceeeb9bf3dd7a72856b7035cd64aacc3602b9a19e0b65` |
| 44 | [袁本第44回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC044%E5%9B%9E) | `044.txt` | `d7a11e1c4f7f6c7007eb90556436e5c3b71e8b9304acf6541572d99afc65885c` |
| 46 | [袁本第46回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC046%E5%9B%9E) | `046.txt` | `7126e50104d3fa1c65b54f841c5bd0df2159d62de7ec3861a32a07e9f763b550` |
| 47 | [袁本第47回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC047%E5%9B%9E) | `047.txt` | `f655ae40c8b1c3e83759b3fcac401dd2961678ac4abc3a567583d57f61ac2554` |
| 48 | [袁本第48回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC048%E5%9B%9E) | `048.txt` | `b003a375660f5e5ba3e24fee5de46149e6990ca9680613e59bd9322b19050b80` |
| 49 | [袁本第49回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC049%E5%9B%9E) | `049.txt` | `dd82a6e8a5edb489e1387e80591a9dda02b1c107800f34dabd71aaedd8df4431` |
| 50 | [袁本第50回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC050%E5%9B%9E) | `050.txt` | `06e6a5dbfa437633a2a4261c27ba4cc84d4c53ec50745cfe82ce5958d5881e15` |
| 54 | [袁本第54回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC054%E5%9B%9E) | `054.txt` | `c6682a97f5ead2c5033a4b7f0944c32f2759f9087e4b6663457182b9fe24c50e` |
| 55 | [袁本第55回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC055%E5%9B%9E) | `055.txt` | `22e6601f2b607a7567349bb40b8da2888a4d46754d0902998e5fe36c0b7c3dd4` |
| 56 | [袁本第56回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC056%E5%9B%9E) | `056.txt` | `2122583fd1579f7d0b000fc4fca93a0ab08b2ed350a7c6c9e846fb9752798705` |
| 57 | [袁本第57回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC057%E5%9B%9E) | `057.txt` | `a27a42204d91bc93d090b9c5f0421ec5e613bb6e14f5d5b553f83d4a92cc2881` |
| 58 | [袁本第58回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC058%E5%9B%9E) | `058.txt` | `38a0913eee7f15ee7639d1d094149d591503c3e3b8a83e9ab80c67f605bc7824` |
| 59 | [袁本第59回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC059%E5%9B%9E) | `059.txt` | `95aa4f7f7a99d7064bc7f35f1ed83bcb31b72adf0a3277241d07f2dc8a650e2c` |
| 60 | [袁本第60回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC060%E5%9B%9E) | `060.txt` | `25529c73088cc09d2453c193fb6229d2cc6fb984d6352c2f314a97f759e50bd7` |
| 61 | [袁本第61回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC061%E5%9B%9E) | `061.txt` | `694c87a7b93679e652870aa9d8eb439a4a2394da7389ac88071d77c21faf2fda` |
| 62 | [袁本第62回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC062%E5%9B%9E) | `062.txt` | `aad3bcdae78bc91fd94363299ae49bd85fd24c76e344aa1367aab57b6125d151` |
| 63 | [袁本第63回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC063%E5%9B%9E) | `063.txt` | `08546ad5277ac3123be2684ad762ab58bf3e02ff4b2d6aadf433c2afd54402cb` |
| 64 | [袁本第64回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC064%E5%9B%9E) | `064.txt` | `91a3ec7e82618bf9149ed1caf4e7f90e679a7b6021f082584a0eb20c3893c45e` |
| 65 | [袁本第65回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC065%E5%9B%9E) | `065.txt` | `e3e8f2c7425c50ed872e68826bb43c926f326522a8ae4ef80fc14983586604ab` |
| 66 | [袁本第66回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC066%E5%9B%9E) | `066.txt` | `9cdbc718fd996bf8ded60ae25c618881f085722689be61bc0c60cc54a3d60daa` |
| 67 | [袁本第67回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC067%E5%9B%9E) | `067.txt` | `defd6a217f5e6d3a567a2a4ad8cdb7e6f025f7b4beb3396dc24b09c72afc7c4a` |
| 68 | [袁本第68回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC068%E5%9B%9E) | `068.txt` | `9a5223c0895b261bd9ac8a3957fce878f069ac8833799ec3ae4c2b183aa0105e` |
| 70 | [袁本第70回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC070%E5%9B%9E) | `070.txt` | `c3cfdf4a4ac9352ade6b72a72bd3cdd1ca9006538fa8a24642d30ad4185463b8` |
| 71 | [袁本第71回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC071%E5%9B%9E) | `071.txt` | `bdb8784050d6369327b14090131a06a87a0c03ce0ef68d7bc2630b5141744b06` |
| 76 | [袁本第76回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC076%E5%9B%9E) | `076.txt` | `69cc48384846f87d8da470bc90e0033ea1e38cbcd1a4c67a4e32979133bccf0b` |
| 77 | [袁本第77回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC077%E5%9B%9E) | `077.txt` | `7f36dcfd8e98b0ecf4dd8dcc00b40c56a175b06f46f7ff6ca863928b6a324de5` |
| 78 | [袁本第78回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC078%E5%9B%9E) | `078.txt` | `2f24cf102f484208baec7b4c44b62aa87706cdd0a3d09d501dad34efc1beaeac` |
| 79 | [袁本第79回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC079%E5%9B%9E) | `079.txt` | `ffd7e3683ce8e30480f8f398fe58ba4cef5bd0723fa6fb462905e4d490344a9b` |
| 80 | [袁本第80回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC080%E5%9B%9E) | `080.txt` | `7a8a8128b4f3b74045ba427d08f2124f15d19467d69e7837488f285fb4962e1d` |
| 112 | [袁本第112回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC112%E5%9B%9E) | `112.txt` | `3e9b2a248fe793da10354e0762967046bc2f7cd3bdc48dfc184f334ab13ddc65` |
| 113 | [袁本第113回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC113%E5%9B%9E) | `113.txt` | `4d156fbe01798abea441aa6ffffa1f70b69abeea89b255e2150bc8870d1bf011` |
| 114 | [袁本第114回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC114%E5%9B%9E) | `114.txt` | `7f81a3af28520371b687a6f63ab2c925c84a666efde38995d5d09762dda11cd7` |
| 115 | [袁本第115回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC115%E5%9B%9E) | `115.txt` | `5e4cefbe65abd78d55a54e690eb63527a1400b7fa3dd80fcf528a63bc5337559` |
| 116 | [袁本第116回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC116%E5%9B%9E) | `116.txt` | `3124c686bbd08f8261fc9a52abab82a38fbce2f25692b21e09ce897c2af87017` |
| 117 | [袁本第117回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC117%E5%9B%9E) | `117.txt` | `2613061e06f34109eced16a91209411bf00229610d789955753ad01121f4544c` |
| 118 | [袁本第118回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC118%E5%9B%9E) | `118.txt` | `2d6a93f12966c560a0b3836ac6fb1208f0a2749049b4d4e45810742a1bd977b7` |
| 119 | [袁本第119回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC119%E5%9B%9E) | `119.txt` | `70d8dccf4c5b9887d7d6536d69cd8ff8a7af742f74cf2e38202ae81cb4755746` |
| 120 | [袁本第120回](https://zh.wikisource.org/zh-hans/%E6%B0%B4%E6%BB%B8%E5%82%B3_%28120%E5%9B%9E%E6%9C%AC%29/%E7%AC%AC120%E5%9B%9E) | `120.txt` | `d15af4308ef4daa42c05c81aa7353e1e0e470a365ea69ae697088858e2546679` |
