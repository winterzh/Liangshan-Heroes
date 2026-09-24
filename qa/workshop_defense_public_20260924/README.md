# 公开据守示例验收（2026-09-24）

作品：[示例据守 · 两波练兵](https://steamcommunity.com/sharedfiles/filedetails/?id=3807085508)。使用现有线上 Build 25476210 上传，无新构建切换。

- 编辑器内实战：两波共 13 名敌人全部击败，截图 `local_victory.jpg`。初始 250 金、150 木，首波准备 90 秒，第二波间隔 25 秒；无单位或技能数值覆盖。
- 为修正首波 10 秒来不及正常招募英雄的问题，单独创建公开配置，原本地副本保留。关闭倍率、速度 1.0、强英雄托管，以林冲与宋江完成；此前三次失败也记录在 `local_playtest.json`。
- 实机封面：`marketing/steam_workshop_20260923/sample_defense_cover.jpg`，浏览器已目视确认公开页面正确显示。上传自动生成的 `preview.jpg` 与订阅下载一致。
- 未登录凭据的公开 API 返回 result=1、visibility=0、banned=0、AppID=5088120、Defense 标签，见 `public_api.json`。
- 浏览器显示取消订阅及“已添加至订阅夹”；下载的 content.json、manifest.json、preview.jpg 三份 SHA-256 全部与上传目录一致，见 `subscription_hashes.json`。
- 游戏工坊列表显示可游玩，从该列表已启动本作品。订阅实战结算另见 `public_verification.json`，未结束前不标记胜利。

公开描述提供简体中文、英语，并提示关闭倍率、林冲东侧防守及英雄托管。工坊不计 Steam 成就。第二账号和跨设备未测试。

## 安装回调修复与未完成项

订阅时发现线上安装回调参数不匹配，详见 `installed_callback_failure.json`。GodotSteam 原生元数据声明两个参数，实际事件发出四个；修复兼容两种调用。`native_callback_fix/report.json` 219 项全通过。仅源码修复，线上构建未变。

桌面锁定前订阅关卡已进入第二波，最终结算未观察到；暂不记为订阅胜利。试玩设置恢复及独占图形性能仍待解锁后完成，详细恢复值记录在 `public_verification.json`。

新候选 `20260924_115136_3e79be81` 已完成 1136 项包检查、源工程/包内容身份验证，3048 项源文件 SHA-256 全部与当前工程匹配；实际鼠标续玩及新包下载回调复验仍待解锁。上一候选实机结果不自动计入本候选。包未上传 Steam。
