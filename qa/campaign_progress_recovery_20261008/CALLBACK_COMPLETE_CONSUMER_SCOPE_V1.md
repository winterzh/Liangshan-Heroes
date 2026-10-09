# 自然回调完整消费者 V1 范围

这是源码候选，未运行完整validate，没有原生准入。

后继状态：V1 独立审查确认 CALLBACK-PACKET-ORDER-001，尾流顺序可漏解析一段受拒绝原 prefix；V1 来源和拒绝收据保留。V2 packet helper 仅修两处顺序/原字节重构 guard，完整消费者仅换 import。六项合成检查不能替代本说明要求的实际 Popen、完整物理记录与原生管线；V2 来源封存和有限差异复审单独记录。

完整消费者只验证 callback_sees_new_memory 的实际首次自然终局和同private profile的另一次普通restart。原始callback report按新schema直接读取；不转换成旧报告、不伪造旧字段。首次80项、终局前56项、重启21项有序检查均逐条核对，stage/public两个原件和原marker保持。普通父restart报告仍按父schema读取。

进入validate先要求当前batch持有实际subprocess.Popen、当前step对象、唯一PID/nonce、实际poll0/terminal0/零诊断。完整15字段native Provider响应必须对应封存host inventory。原life1/2/3、意图与ACK、CFG prepared/applied1/2全部14字段、candidate/public CFG原SHA、真实Mission/HUD/单局完整record和普通startup noReplay保持原核对。

原packet helper仅重放数据包和文件；返回native_ownership_proven=false，不能替代上述进程/source证明。完整event目录/path/原bytes/SHA必须闭合；adapter/controller对同frame的重复存档不等于两个输入。每个发送尝试必须紧接原成功标记，并按真实栈请求唯一snapshot后disable/continue。末尾普通EOF、退出竞争的adapter-only frame、受拒绝partial prefix及terminal tail须分别保留与重放，截断/未知/晚到控制拒绝。观察到的新内存须是同Campaign对象的原native seal record，不能dummy cloud或假回调。

15项伪造私有packet文件/metadata fixture和fake-child拒绝只验证primitive与局部边界；它们没有运行完整consumer、物理journal路径或真实Popen，也不证明当前Engine暂停capture兼容。独立预审同样只来源/API范围，所有执行批准阶段为空。

完整producer尚未实现。只有成功且闭合完整V12来源、精确新seal、独立阶段准入以及actual cold/callback/restart完整管线结果，才可声明这个单case和重启的有限资格；不能据此授其它原19、SDK奖励一次性、内容/性能/Android或整个目标通过。另两实际云端driver/故障与其它原要求继续保留。
