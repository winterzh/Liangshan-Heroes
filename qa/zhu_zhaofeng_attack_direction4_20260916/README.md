# 祝朝奉四向攻击 QA · 2026-09-16

本批把同一人物的攻击状态补入水浒 RTS。网页端原图四行固定为 SE、SW、NE、NW，每行四格依次为收刀蓄势、起砍、刀锋伸展、收势回防；正面与真实背面独立绘制。人物保持祝朝奉的年长宽体、灰黑短须、栗色乡绅袍和黑色幞头，和陆谦的精瘦深青官服区分明确。

## 证据

- 网页会话：`https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c`
- 原始下载：`assets/characters/art_full_20260915/zhu_zhaofeng_attack_direction4_source.png`，1230×1278 RGBA，SHA 和原始画布尺寸见 `assets/direction4/zhu_zhaofeng_attack_20260915.json`。
- 生产图：`assets/characters/art_full_20260915/zhu_zhaofeng_attack_direction4.png`。网页画布先居中放入 1278×1278 透明画布，再确定性缩放到 2508×2508；原像素全部保留，没有镜像、抠像、重着色、补画或清除像素。
- 目检：四向背面语义成立，四格刀臂、刀身、衣摆和脚步有明显变化，人物与武器完整，无文字/网格/边框/地面/阴影；透明背景为真 alpha。

## 自动验证

- `py -3 -X utf8 -B tools/zhu_zhaofeng_attack_direction4_contract.py --output qa/zhu_zhaofeng_attack_direction4_20260916/contract.json`：125/125。
- `py -3 -X utf8 -B tools/art_full_source_contract.py --output qa/zhu_zhaofeng_attack_direction4_20260916/source_contract.json`：5 张原生来源、32 项资源的字节/alpha/区域/锚点契约通过。
- Godot 4.6.3 导入：退出 0，攻击原图与透明来源均成功导入。
- `STEAM_DISABLED=1` + `ZHU_ZHAOFENG_ATTACK_OUT=D:/CodexTemp/zhu_zhaofeng_attack_runtime_20260916_run1` 运行时：140/140，四向路由、4 帧、627 像素固定格、768 正方形虚拟帧、透明补边、`filter_clip` 和非镜像源均通过；hurt 仍按 idle 回退，death 仍为空。
- 全库回归：`D:/CodexTemp/art_full_continue_20260916_r10/20260916_000206_9483e6fc`，导入与库存 321 项通过，源文件与私有副本零漂移，共享锁已释放。原始回归摘录见 `full_qa_receipt_excerpt.json`。

本批只补齐祝朝奉 attack；hurt、death 仍开放，不能用 idle 或其他角色动作代替。陆谦 hurt/death、旧头像背景、地形细节和技能实战辨识也仍在总台账中。
