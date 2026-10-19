# 邹润SE撤刀下沉与SW四主姿势候选

本批含三份内置imagegen原PNG：[SE过渡v4](native_originals/transition_se_v4.png)、[SW首稿](native_originals/attack_sw_v1.png)、[SW方格v2](native_originals/attack_sw_v2.png)。[精确参数/父图集合](prompt_set.json)和原失败完整保存，无本地镜像、裁切、清洗或重编码。第49回人形/脑后肉瘤/短刀仍为书证，具体姿势、五官/衣甲/刀形及节奏为美术解释，不新增剧情事件或批准既有技能。

SE原稿更深屈膝，在[同一整组比例的新旧连播](browser/comparison.html)中减轻撤刀突然抬高的观感。两侧攻击/过渡同用0.9037146998419183，待机仍用原尺度，没有逐帧拟合。实际原alpha主分量上缘从674到722，下降48px，不是精确满足提示28—32px；这也不是头骨或重心测量。其他三格有小变化，鞋底也非逐像素固定，见[几何观察](geometry_observations.json)。

SE实际正式段8.4秒连播，十阶段截图和一张视频解码图已目检；预热后录像约10.57秒/299帧。[独立复核](playback_verification.json)仅覆盖来源/阶段、两侧共用比例、人工鞋点的Canvas float32舍入及媒体统计，不等于整鞋接地、握持连续性或自然攻击通过。

SW新增朝左预备/蓄势/前切/收招，保持一把短刀由同一条手臂持握，另一手空。首稿实际1388×1133，按本批方格规格失败；未本地改尺寸，另用内置工具生成v2方图。v2四格完整取图通过，但65px边缘留白请求并未全部实现；[各边实际余量](geometry_observations.json)保留，不能把完整采样当制作要求全部通过。打开[SW原稿/四姿势静态比较](sw_browser/sw.html)，实际解码3源PNG/SHA和11显示实例已核对并目检，只有静态来源资格，尚缺过渡、材质/体量对齐及方向连续，未验收自然动作/解剖或握持。

两份方图按原alpha>0检查四主分量归属与选定采样边缘alpha=0；极淡分量原样保留，数量/max alpha见[核验范围](verification.json)，不称全背景空。SW首稿失败不由v2补签。原始PNG和参数来源随库保存，工具未精确做到的请求在几何/目检记录中明示。

```powershell
python -X utf8 -B qa/zou_run_attack_recovery_20261019/record_and_check.py --set attack_sw --version v3 --original <新内置PNG>
# SE四过渡使用 --set transition_se，已有版本不得覆盖。
python -X utf8 -B qa/zou_run_attack_recovery_20261019/render_recovery.py --deps <既有私有Playwright依赖> --output <全新工程外目录> --browser-exe <既有Edge路径>
python -X utf8 -B qa/zou_run_attack_recovery_20261019/render_sw_intake.py --deps <既有私有Playwright依赖> --output <另一全新工程外目录> --browser-exe <既有Edge路径>
```

浏览器自己的profile进程已结束，依赖/profile/可执行文件不入Git，ffmpeg只解码QA录像、不改角色PNG。129生产/16贡车/81无关文件、HUD及26待验证文件保持原哈希；未启动Godot、修改租约或其他进程。生产采用0，完整四向/全动作、后脑、小尺寸身份、Unit/HUD、原生/包内/性能及全库人物/场景/船只/特效/UI继续，main/Steam未改。
