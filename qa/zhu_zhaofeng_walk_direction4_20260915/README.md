# 祝朝奉四向行走 QA · 2026-09-15

本批将网页端生成并人工目检通过的 4×4 原始 PNG 接入祝朝奉行走状态。四行固定为 SE、SW、NE、NW；每行四格是左脚着地、经过、右脚着地、经过的连续步态。原图保持年长宽体、灰黑短须、栗色乡绅袍和黑色幞头，正面与真实背面均独立绘制，和陆谦的精瘦深青官服身份可区分。

## 证据

- 网页会话：`https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c`
- 原始下载：`assets/characters/art_full_20260915/zhu_zhaofeng_walk_direction4_source.png`，1254×1254 RGBA，SHA 见 `assets/direction4/zhu_zhaofeng_walk_20260915.json`。
- 生产图：`assets/characters/art_full_20260915/zhu_zhaofeng_walk_direction4.png`，仅做确定性整图 2 倍 LANCZOS 缩放；不镜像、不抠像、不补画、不清除像素。
- 目检：原始 PNG 四行方向成立，四格脚步和衣摆有明显变化，人物完整、脚底未截断、背景为真透明，无文字/网格/边框/地面/阴影。

## 自动验证

- `py -3 -X utf8 -B tools/zhu_zhaofeng_walk_direction4_contract.py --output qa/zhu_zhaofeng_walk_direction4_20260915/contract.json`：125/125。
- `py -3 -X utf8 -B tools/art_full_source_contract.py --output qa/zhu_zhaofeng_walk_direction4_20260915/source_contract.json`：5 张原生来源、32 项资源的字节/alpha/区域/锚点契约通过。
- Godot 4.6.3 导入：退出 0，生产图和原始图均成功导入。
- `STEAM_DISABLED=1` + `ZHU_ZHAOFENG_WALK_OUT=D:/CodexTemp/zhu_zhaofeng_walk_runtime_20260915_run1` 运行时：132/132，四向路由、4 帧、627 像素固定格、768 正方形虚拟帧、透明补边、`filter_clip` 和非镜像源均通过；death 仍为空，不以 walk 冒充。
- 全库回归：`D:/CodexTemp/art_full_continue_20260915_r9/20260915_234846_9c838752`，导入与库存 321 项通过，源文件与私有副本零漂移，共享锁已释放。原始回归摘录见 `full_qa_receipt_excerpt.json`。

本批只补齐祝朝奉 walk；attack、hurt、death 仍开放，不能用 idle 或其他角色动作代替。
