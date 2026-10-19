# 杨林四向连续步态浏览器候选

双击 [viewer.html](viewer.html) 可查看，原PNG已内嵌，无需安装工具或启动服务。可以停走、暂停、切换半速/正常/1.5倍速度；每格右上为现用普通角色高度参考，主图放大6倍。页面不是游戏入口。

本批只复用上一批固定上身、左右大腿/小腿和低靴原稿，没有新画或清洗PNG。四向固定，按累计位移推进双腿循环；停步时摆腿收落，支撑参照点保持地图位置。人物/兵器依据第44回，豹纹衣、头巾、须形和步态仍是美术解释，不能用“九尾龟”等绰号反推原著服装。获救/被缚状态与现有技能没有改变，技能的跨章原著核对仍未完成。

## 实际执行

[actual/run_v3/browser_report.json](actual/run_v3/browser_report.json) 记录12.4秒、774次画布绘制、四原图哈希一致。正常、半速、停止、恢复、加速、再次停止与恢复之后落脚，保存8张关键PNG和 [连续视频](actual/run_v3/continuous_canvas.webm)。8张PNG及完整页面截图均已目检；没有完成人工连续视频验收。

[独立复核](actual/run_v3/independent_verification.json) 对1544条实际绘制矩阵/三维关节记录重新计算，核对196组支撑参照、骨长、相机与位移积分，并由ffprobe解码356帧VP8视频，时间戳跨度12.313秒、无音频。数学容差1e-6只判断实现计算，不是游戏接地标准。单一靴底参照点稳定，不证明整片鞋底、脚掌滚动、碰撞或坡面接触。

来源透明边缘仍失败；膝踝接缝、快步节奏、站定后宽步姿势仍需返修。自然步态、Godot/Unit接入、方向切换、地形、普通与获救状态回归、包内与性能均未通过，本批生产采用0。当前画面不能当作全角色美术完成。

## 原始尝试与复现

- `actual/run_v1_failed/`：CLI无头捕获未取得连续报告，只推进约0.30秒；步幅/抬膝也过大。其原始receipt的wall_seconds是启动器等待，不是页面运行时长。
- `actual/run_v2_failed/`：缩短步幅后CLI捕获仍仅约0.24秒，没有连续资格。
- `actual/run_v3/`：Playwright驱动已有Edge，用独立临时profile、真实墙钟、DOM及仅本机POST双通道取证。页面自录画布，没有桌面或音频采集。服务器与本次浏览器进程已退出。

失败批次均保留执行时的HTML/JS/参数和原始结果，后继结果不补签旧批次。`archive_index.json`核对归档原文件。依赖安装目录及profile不进入Git。

`viewer.html`是已验证的冻结构建，`runtime_receipt.json`存在时`build_preview.py`拒绝重建。开发改动另建后继版本，不覆盖本批。已执行自动入口为：

```text
python -X utf8 -B qa/yang_lin_continuous_preview_20261019/run_playwright.py --deps <私有Playwright目录> --output <全新工程外证据目录> --browser-exe <已有Edge可执行文件>
python -X utf8 -B qa/yang_lin_continuous_preview_20261019/verify_runtime.py <该全新证据目录>
```

Pillow与ffprobe需已可用；Playwright精确版本见`requirements.preview.txt`。不修改系统浏览器配置，不使用用户登录profile，不下载新浏览器。`run_preview.py`为失败CLI入口留档，后继使用`run_playwright.py`。原生Godot仍由原公孙胜单一等待队列处理，未动外来占用声明。
