# 蔡九、史文恭头像校准 · 2026-09-27

## 本批变化

| 人物 | 原差异 | 新头像 |
| --- | --- | --- |
| 蔡九 | 旧图集中为红袍，实际行走/攻击是蓝色官袍 | 靛蓝袍、金色领缘与胸前鸟纹、黑色展脚帽；保留圆脸、细眼、小须及自得神态 |
| 史文恭 | 旧图集中为白缨、银甲和白披衣，实际动作是深色甲与暗红披风 | 黑金甲、红盔缨、暗红披风及较短尖须；保留长脸、颧骨和锐利眉眼 |

二者改为独立头像，在纸纹、勾线和材质画法上与现有画像统一，脸型与表情分别保留。`Art.STANDALONE_PORTRAITS` 新增两条路径，图鉴、战斗左下角和英雄栏共用同一人物资源。

## 来源

`assets/characters/officer_portraits_20260927/` 保存内置 image_gen 原生 PNG 与 Godot 导入配置；没有本地图片加工或 CLI 调用。完整编辑提示词、旧图集中的目标格、实际动作参考、输出哈希见 `tools/contracts/officer_portraits_20260927/`。

史文恭首版盔缨贴住上边缘，追加构图修订，留出完整盔缨轮廓和纸纹空白。中间图保存于 `qa/officer_portraits_20260927/sources/shi_wengong_initial.png`，在提示词记录中保留编辑链。蔡九直接采用首版。

## 验证与范围

复验：`python -X utf8 -B tools/run_hero_portraits_qa.py --work-root <工程外目录> --contract tools/contracts/officer_portraits_20260927 --ui --run`。

两人目前仍是旧方向回退动作，四个请求方向展示同一来源，本批不宣称独立四向完成。蔡九按实际行走源、史文恭按实际待机源并排核对，同时保留其他动作文件原字节。新的四向身体和动作仍列后续范围。

实际检查和目检结果见 [QA](../qa/officer_portraits_20260927/README.md)。本批仅头像素材和源码同步，未打包或发布 Steam/Android。
