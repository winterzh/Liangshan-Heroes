# 阮小二推车原稿来源检查

6份内置imagegen原PNG，5候选/20选用视图，1份重复腿型退稿。完整提示词、22份引用SHA、原始生成路径和真实选格见`assets/characters/ruan_xiaoer_pushcart_sources_20261017/prompt_set.json`。主代理直接查看6张原始图谱，未称独立审查。

`report.json`为只读185项来源检查，核对原PNG/引用字节、RGBA尺寸、20格强alpha内容完整保留、选格角点/分隔轴及已记录的目检。三张整图左下alpha1如实记录，`full_selected_atlases_zero_corner_alpha_passed=false`；Atlas边界只略去原画布最外1像素的留白，不改PNG。过渡A强alpha竖间隔仅3列，后继必须实机查过滤/串色，不将空轴等同于所有背景alpha0。

`direct_review.json`保留每稿观察：第一次B重复A腿型退回；修正版前向迈足及后视轮廓改变，但后视支撑/摆腿时机、四相位连续性、人物/车深和罩布/轮纹仍未得到原生资格。未启动Godot、未修改生产路由，`.gdignore`隔离原稿；没有从公孙胜1107项结果借用通过结论。

14个生产/来源保护文件和81个无关未跟踪文件基线在独立JSON，收尾SHA核对见`closeout.json`。不包含SDK、私有档案、Steam缓存或导出包。[原著依据、说明和下一步](../../docs/RUAN_XIAOER_PUSHCART_SOURCES_20261017.md)。
