# 施恩技能图标原始验收记录

内置image_gen生成四份1254×1254 RGBA，生产PNG与原图字节一致。完整提示词：`assets/ui/shi_en_skills_sources_20261015/prompt_set.json`；本批实现及复现边界：`docs/SHI_EN_SKILL_ICONS_20261015.md`。

- `native_pass/`：同一真实完整PCK最终753项、102张原生截图，中文/英文960/1280/1920英雄HUD、真实界面事件和既有五类动作；原PNG在运行目录及PCK中不可读，29张实际纹理像素/mipmap与导入参考相等。
- `pack_export/`：冷导入/解析/纹理参考/完整导出原收据及初次752项报告，四张初次叠层截图保留。最终仅排除QA脚本改变，添加真实鼠标移出悬停卡，游戏生产输入及894405808字节包SHA不变。
- `provenance/`：实际执行过的导出脚本与最终探针原文；`production_binding.json`和`visual_review.json`分别保存来源绑定及直接目检范围。
- `native_import_prior/`、`disk_full_prior/`、`preflight_driver_v1.py`：新导入配置换行归一化、D盘导出失败和中断工程身份不匹配的旧记录。旧零字节receipt原样保留，不能当有效收据。
- `import_cache_duplicates.csv`、`disk_recovery.json`：仅本轮失败工程3851个重复可再生成缓存逐项SHA与保留位置；自动审批拒绝的较宽删除未执行。最终新工程的缓存和包位于C盘。

已学习/冷却展示直接设置测试rank/cd_t，不代表真实技能全链施放；Q真实学习和原其他GUI回归独立检查。编辑器加载实际资源PCK，不是正式EXE、live SDK、Steam、全战役、稳定性能或完整美术验收。其余人物、头像、场景、特效及多语言/多设备UI继续。
