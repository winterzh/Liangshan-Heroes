# 李云、邹润原著特征头像候选

内置imagegen分别生成两份独立原PNG，按原字节复制，没有本地绘画、镜像、抠背景或重编码。

| 人物 | 原稿与精确提示 | 实际静态对照 |
|---|---|---|
| 李云 | [原PNG](native_originals/li_yun_v1.png) / [提示](tool_prompt_li_yun_v1.json) | [可打开HTML](readability/li_yun/review.html) / [截图](readability/li_yun/review.png) |
| 邹润 | [原PNG](native_originals/zou_run_v1.png) / [提示](tool_prompt_zou_run_v1.json) | [可打开HTML](readability/zou_run/review.html) / [截图](readability/zou_run/review.png) |

本批实际抓取维基文库120回本第43/49回，完整文本、原始公开HTML、精确引文行号与SHA均保留。

## 李云

第43回第59—60行“面阔眉浓须鬓赤，双睛碧绿似番人”“沂水县中青眼虎，豪杰都头是李云”，第66行有李云挺朴刀赶来。候选表现自然绿眼、赤褐须鬓与宽脸浓眉，不以“青眼虎”添加兽化或神通。具体五官、肤色、须长、黑色软帽/甲饰与纸纹为美术解释。

原稿及对照已目检：512/256/128显示可见绿色眼睛和赤须，64像素主要保留赤须/脸部轮廓，绿眼在64/32像素的可靠可读性未接受。新软帽/巾的折叠轮廓与当前走图官帽并不完全相同，必须继续对齐，不能称头像身体全部统一。现用黑雨/暗术技能、服装与兵器细节另待原著/行为核对。

## 邹润

第49回第39行明确侄儿邹润与叔叔年纪相仿、身材长大、**脑后**有肉瘤，因而称“独角龙”；第52行叔侄拔短刀。候选在侧向人形头像里画脑后圆润肉色隆起，额前没有尖角，不把绰号画成龙角。具体隆起大小、面貌、短须、红巾与甲衣均属美术设计；无兵器近景不代表角色一直空手。

原稿及对照已目检：大图可见脑后隆起，缩小后仍可能与发髻/布结混淆，64/32像素的该特征辨识未通过。现用旧头像与走图额前突出、长柄刀及技能均未被本批批准，也未修改。角色身高/动作不从头像推断为已验证。

## 实际检查与范围

每人一个独立已有Edge/工程外profile静态运行，实际解码3源图、WebCrypto核对源SHA，DOM计数13显示实例，比较256/128/96/64/32像素及现用头像/走图首帧。两张1800×1450截图均直接目检；页面错误0，本次profile进程均已退出。每张原图仅嵌入一次，私有Playwright 1.64.0/profile不进入Git，不修改用户登录profile或系统配置。

没有Godot/真实图鉴/HUD/Unit、四语言/多分辨率、包内、性能或全角色辨识资格，生产采用0。129/16/81与HUD、26份其他待验证本地文件保持；原Godot单一等待队列及外来占用标记未动。全库人物动作、场景、船只、特效、UI和性能继续，main/Steam未操作。

```text
python -X utf8 -B qa/li_yun_zou_run_portraits_20261019/render_readability.py --hero li_yun --deps <私有SDK目录> --output <全新工程外目录> --browser-exe <已有Edge路径>
python -X utf8 -B qa/li_yun_zou_run_portraits_20261019/render_readability.py --hero zou_run --deps <私有SDK目录> --output <另一个全新工程外目录> --browser-exe <已有Edge路径>
```

需要已有Pillow/Playwright，原文抓取另需BeautifulSoup。自动输出不覆盖旧目录，归档包括实际HTML/截图/执行器/收据和原始书证，逐文件索引见`archive_index.json`。
