# BookmarkSync 中文分支工作日志

只在一项工作合入 `main` 或发版时，在**末尾**追加条目；不改写旧条目（事实错误时追加更正条目）。格式见 `AGENTS.md` 3.1 节。

## 2026-10-15 基线：fork 自上游 Xazzzi/bookmarksync

- 基线：`main` 指向上游 `13485d1`（“Usability improvements”）。代码约 3.3k 行 Swift，`BookmarkSyncTests` 57 个 XCTest。
- 架构：中枢（SwiftData `BookmarkNode`）+ 每个浏览器配置的 `observedStateData`（上次从磁盘读到的状态）；导入阶段（浏览器 → 中枢）、导出阶段（中枢 → 浏览器）；`WriteQueue` 在目标浏览器退出后写入；写入前做每日/轮换备份；删除以“移入 `Deleted by BookmarkSync` 文件夹”的方式软删除。
- 代码评估结论（Claude Code 与 Codex 各自审阅，结论一致的部分）：架构方向正确，但防丢数据保护不足、网址匹配过于激进、Firefox 写入方式粗糙、浏览器根目录映射不完整。问题清单与修复安排见 `docs/plan/2026-10-phase1-safety.md`。
- 未验证：以上结论均来自静态阅读，未在真实 macOS 和浏览器云同步上复现。
