# BookmarkSync 中文分支工作日志

只在一项工作合入 `main` 或发版时，在**末尾**追加条目；不改写旧条目（事实错误时追加更正条目）。格式见 `AGENTS.md` 3.1 节。

## 2026-10-15 基线：fork 自上游 Xazzzi/bookmarksync

- 基线：`main` 指向上游 `13485d1`（“Usability improvements”）。代码约 3.3k 行 Swift，`BookmarkSyncTests` 57 个 XCTest。
- 架构：中枢（SwiftData `BookmarkNode`）+ 每个浏览器配置的 `observedStateData`（上次从磁盘读到的状态）；导入阶段（浏览器 → 中枢）、导出阶段（中枢 → 浏览器）；`WriteQueue` 在目标浏览器退出后写入；写入前做每日/轮换备份；删除以“移入 `Deleted by BookmarkSync` 文件夹”的方式软删除。
- 代码评估结论（Claude Code 与 Codex 各自审阅，结论一致的部分）：架构方向正确，但防丢数据保护不足、网址匹配过于激进、Firefox 写入方式粗糙、浏览器根目录映射不完整。问题清单与修复安排见 `docs/plan/2026-10-phase1-safety.md`。
- 未验证：以上结论均来自静态阅读，未在真实 macOS 和浏览器云同步上复现。

## 2026-10-15 中英文本地化与 macOS CI（PR #1，`feat/simplified-chinese-i18n`）

- 改动：加入原生英文 / 简体中文本地化（`BookmarkSync/Localization/{en,zh-Hans}.lproj`，95 组文案 + 搜索数量复数资源），动态文案走 `L10n`；书签标题、配置名、磁盘上的 `Set N`、`Deleted by BookmarkSync` 不翻译。新增 `README.zh-CN.md`、`scripts/check_localizations.py`、`LocalizationTests`。新增 `.github/workflows/macos.yml`：PR 上 `xcodegen generate` + `xcodebuild test`，打包 ad-hoc 签名的 Debug 应用。菜单栏面板加宽到 320。
- 附带的同步行为改动（commit `1cdd347`）：浏览器配置扫描不到时（例如完全磁盘访问权限失效），不再删除该配置及其中枢书签，而是标记为“暂时不可用”（`AppViewModel.unavailableProfileIds`），同步时跳过；菜单栏新增“重新扫描浏览器配置”按钮和不可用提示；新增 `ProfileDiscoveryTests`。这与计划 S1“不确定就不写”的方向一致。
- 验证：GitHub Actions（Xcode 27）编译通过，XCTest 全部通过；`python3 scripts/check_localizations.py` 通过（合入后在 Linux 上复跑：95 组文案、69 个界面字面量）。
- 未验证：真实 macOS 上的中文界面（截断、换行）、“暂时不可用”状态的实机表现、与浏览器云同步的联调。
