# 李云帽型、邹润脑后轮廓返修

本批用内置imagegen分别编辑既有首稿，生成两份新原PNG；源文件按原字节保存，没有本地绘画、抠背景、镜像或重编码。编辑器并不保证未请求区域逐像素不变，本批独立目检两份结果，不把“只改帽型/轮廓”的请求当作其他像素完全相同的证明。

| 人物 | 新原稿 / 精确编辑参数 | 实际四列对照 |
|---|---|---|
| 李云 | [v2原PNG](native_originals/li_yun_v2.png) / [提示](tool_prompt_li_yun_v2.json) | [HTML](comparison/li_yun/review.html) / [截图](comparison/li_yun/review.png) |
| 邹润 | [v2原PNG](native_originals/zou_run_v2.png) / [提示](tool_prompt_zou_run_v2.json) | [HTML](comparison/zou_run/review.html) / [截图](comparison/zou_run/review.png) |

## 返修结论

李云将首稿的大块包巾后鼓、长布尾改为较直立的折冠和短系带，外轮廓更接近现用走图黑色官帽；自然绿眼与赤褐须鬓保留。精确帽构、衣甲、须长、五官是美术解释，并未据此取得与游戏身体完全同一造型或64/32像素绿眼可靠识别资格。

邹润将附近红布结/尾上移、脑后隆起周围的头发让开，大图中肉色后脑轮廓较清楚，额前保持无角。64像素下仍可能与发饰/布结混淆，不接受该尺寸的可靠解剖特征识别。具体隆起大小与发式是解释，现用身体的额前尖角、兵器和技能保持待修，不能把这张头像说成已修复游戏角色。

两份原稿及两张1800×1450实际截图均已直接目检。每页四列为生产现用区域、首稿、返修稿、生产走图首帧；另各有256/128/96/64/32像素首稿/返修比较。每次浏览器实际解码4源图并以WebCrypto核对SHA，DOM实际计数14显示实例，页面错误0，独立已有Edge/工程外profile进程已退出。依赖/profile不进Git，未修改用户登录profile或系统配置。

## 原著与范围

沿用上批实际取得的第43/49回文本和精确引文，当前重新核对源SHA/所在行，不是重新联网抓取。李云“面阔眉浓须鬓赤，双睛碧绿”和邹润“脑后一个肉瘤”、同龄叔侄/长大身材的事实保持；不添加兽化、鬼怪、额前龙角或新剧情。详细书证链接见`canon_basis.json`及[首稿来源](../li_yun_zou_run_portraits_20261019/README.md)。

本批生产采用0，首稿与旧报告不覆盖。没有Godot/真实图鉴/HUD/Unit、包内、性能、多语言/多分辨率或全角色识别资格。129/16/81和HUD、26份其他待验证文件保持；原Godot单一等待队列及外来占用标记未动。全库人物动作、场景、船只、特效、UI与性能继续，main/Steam未操作。

```text
python -X utf8 -B qa/li_yun_zou_run_portrait_refine_20261019/render_comparison.py --hero li_yun --deps <私有Playwright目录> --output <全新工程外目录> --browser-exe <已有Edge路径>
python -X utf8 -B qa/li_yun_zou_run_portrait_refine_20261019/render_comparison.py --hero zou_run --deps <私有Playwright目录> --output <另一个全新工程外目录> --browser-exe <已有Edge路径>
```

需要已有Pillow与Playwright 1.64.0，输出目录不得覆盖。归档包含实际HTML/截图/执行器/收据，原始素材/引用和字节摘要均保留。
