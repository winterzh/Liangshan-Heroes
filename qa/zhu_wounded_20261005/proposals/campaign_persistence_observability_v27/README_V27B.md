# 当前提案 v27b（外部未执行）

当前源码是proposed_b/scripts/campaign.gd与battle.gd。原ff819候选及全部v27文档保留历史；SOURCE_PINS_V27B/INTERFACE_V27B/FAULT_MATRIX_V27B/STATIC_REVIEW_V27B/proposal_b.diff对应本版本。

本版只将_cfg_value_supported的非容器默认允许改为33个固定内建leaf名单：基础值、全部math/Color/StringName/NodePath、10个Packed类型（含Vector4）。Dictionary/Array沿用原递归；Object/RID/Callable/Signal、脚本/对象typed容器、循环与未来类型默认拒绝。depth检查是root0下所有递归value node（包含key/leaf）≤128，不是仅容器计数；TYPE_MAX无法构造为真实Variant，不伪造native例。

其余v27语义原样：QA内存结果和旧_save bool=true，persisted=false/suppressed=true；真实失败保旧records/unlocked，accepted逻辑与memory/durable区分。save成功而回读失败时磁盘可能已有candidate，disk_state_unconfirmed=true；没有磁盘rollback、安全重试、pending写入锁或完整gen2→cfg→ack crash恢复。Cloud请求须在candidate内存安装之后，callback不等于实际dirty或上传。

完整section/key比较加每个值的ConfigFile规范文本和typeof，以ConfigFile序列化语义保留合法未知数据Variant，遵循引擎-0/NaN规范化，不宣称IEEE位或Object身份。坏既有cfg不覆盖，不支持值写前拒绝。官方API/4.6.3源码证据由FX独立提供。

Battle仅新增8行receipt传播；原victory/SteamService.settle与其余字节完全保留。当前HUD不消费失败receipt；玩家错误可见性、重试UI、Cloud apply既有pre-save内存替换边界均未完整修复。19条fault矩阵均未执行，harness/fault race injector未实现，GDScript parser/native/disk验证未运行。新候选仍不得作为已应用/已native/已计划完工发布。
