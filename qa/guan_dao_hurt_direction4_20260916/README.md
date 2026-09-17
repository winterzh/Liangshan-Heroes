# 官军刀盾兵受击四向美术 QA · 2026-09-16

本批补齐普通北宋官军刀盾兵 `guan_dao` 的受击动作。四行固定为 SE/SW/NE/NW，每行四帧是警戒、后仰、踉跄、回稳；保持现有深铁灰鳞甲、暗红棉袍、圆盾和弯刀识别点，背面单独绘制，不镜像陆谦、祝朝奉或其他单位。

- 原生网页 PNG：`assets/characters/art_full_20260916/guan_dao_hurt_direction4_source.png`
- 生产图：`assets/characters/art_full_20260916/guan_dao_hurt_direction4.png`（确定性整图 2× LANCZOS，2508×2508）
- 路由：`assets/anim/guan_dao_hurt_{se,sw,ne,nw}.tres`
- 清单：`assets/direction4/guan_dao_hurt_20260916.json`
- 提示词：`assets/direction4/web_prompts_20260916/guan_dao_hurt_direction4.txt`

验证结果：

- 静态契约 `128/128` 通过：原图/生产图 SHA、RGBA、alpha、四向区域、四帧差异、TRES 固定引用与 `filter_clip`。
- Godot 4.6.3 运行时 `128 checks; 0 failures`：四向精确路由、4 帧 AtlasTexture、627px 固定格、脚底留边、无镜像。
- 全库美术导入/库存回归：`complete=true`，输出见 `full_art_receipt.json`；本批没有改变玩法数值或 Steam 包。

复现：

```powershell
py -3 -X utf8 -B tools/guan_dao_hurt_direction4_contract.py --output qa/guan_dao_hurt_direction4_20260916/contract.json
$env:GUAN_DAO_HURT_OUT='D:\CodexTemp\guan_dao_hurt_runtime_20260916_r1'; $env:STEAM_DISABLED='1'; & 'C:\Users\rsb\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\AI项目\水浒\开发工程' --script res://tools/guan_dao_hurt_direction4_runtime_qa.gd
py -3 -X utf8 -B tools/run_art_full_qa.py --run --work-root D:\CodexTemp\art_full_guan_dao_hurt_20260916_r1
```
