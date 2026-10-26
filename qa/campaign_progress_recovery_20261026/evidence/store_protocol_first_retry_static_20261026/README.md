# 首次重试 CAS 冲突：静态缺陷记录

原 Store `199c4f92`；本目录保存修正前原始源码/清单/静态检查，未执行原生复现。准备冻结为 `20261026_210350_189c0290`，准备是否完成以其原收据为准。旧“静态检查通过”不证明该并发分支正确。

时序：A 读旧 head 后延迟；B 完成新提交并进入 unique cleanup/marker；A 随后创建自己的 writing，遇屏障返回 WRITER_BUSY。Ledger 将 phase 改为 commit，但 commit_attempted 仍 false。B 清完屏障后，A 第一次 retry 调 commit_locked(old CAS)，基类在写入前返回 CAS_CHANGED。Ledger 将它记为 unsafe，后续直接返回错误，A 的活 writing 残留。只有额外在屏障期间重试过，才会进入原 retry_owned_commit 的 stale-abort 分支。

修复目标：首次 commit_locked 的实际 CAS_CHANGED 同样冻结原 CAS/proposal，先释放本对象自己的锁，再明确要求重启；释放失败继续以同一 scope 重试。不能重算提案、覆盖 B 的 head、清除他人 writing 或把此静态推演写作已通过原生测试。独立的两进程 delayed-acquire 测试将分别覆盖两种重试时序。
