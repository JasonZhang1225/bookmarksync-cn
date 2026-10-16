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

## 2026-10-15 AI 协作规范、工作记忆与第一阶段计划（PR #2，`docs/ai-workflow-and-plan`）

- 改动：`AGENTS.md` 末尾新增第 3 节（中文）：文档分工、仓库事实、数据安全红线、工作方式、测试与交付；新增 `memory.md`、`history_full.md`、`docs/plan/2026-10-phase1-safety.md`（16 个问题条目、7 个批次）；`.gitignore` 忽略 `.artifacts/`。
- 原因/决策：参照 BJTUselfService-KMP-Refreshed 的协作体系；问题清单合并了 Claude Code 与 Codex 两份审阅。
- 验证：仅文档；合入前已在分支上合并 PR #1 后的 `main`。
- 未验证：计划中的问题均来自静态阅读。

## 2026-10-15 读取异常与大批量删除保护（PR #3，`fix/s1-s2-deletion-safety`，计划 S1、S2）

- 改动：新增 `BookmarkParseError`，Safari / Firefox 文件结构异常时抛错，不再返回空列表；新增 `DeletionGuard`，读到空结果而上次非空、删除 ≥10 个且 ≥20%、删除 ≥3 个且 ≥50% 时冻结该浏览器配置（不导入、不写入、不更新观察基线），每轮重新检查；菜单栏 `DeletionHoldBanner` 提供“确认删除 / 恢复书签”。
- 原因/决策：只冻结出问题的那一个配置，同组其他浏览器照常同步（中枢里书签还在，其他浏览器不受影响）。
- 验证：macOS CI（Xcode 27）79 个测试全部通过，其中新增 16 个（`DeletionGuardTests` 5、`ParserStructureTests` 7、`DeletionHoldIntegrationTests` 4）。
- 实机：用户试用 CI 包时触发了暂停提示，但提示只显示数量，并暴露出备份恢复错位的问题（B1），转入批次 1b。

## 2026-10-15 备份时间戳、准确恢复与逐条差异（PR #4，`fix/backup-restore-and-diff`，计划 B1–B3）

- 改动：新增 `BackupStore`：备份按时间戳命名、不再改名；最近 7 天全留、7–30 天每天一份、总数上限 200，旧版 `.backup.N` / `daily` 照常列出且不清理；恢复先另存当前文件、再整体替换为所选备份，Firefox 恢复后清理旧 WAL；目标浏览器运行时拒绝恢复；恢复后用应用自己的同步引擎。新增 `BookmarkDiff` / `BookmarkDiffList`（+ − ~）；暂停删除提示条可查看详情；备份管理改为先对比再恢复。
- 原因/决策：用户实机试用发现“恢复后提示删 83 个、确认后没变少”——旧轮换使恢复错位（B1），且恢复时 Chrome 开着、退出时覆盖了恢复结果；提示只显示数量，无法判断。
- 验证：macOS CI（Xcode 27）90 个测试全部通过，含新增 `BackupStoreTests`（含恢复准确性回归测试）、`BackupRetentionTests`、`BookmarkDiffTests`。
- 未验证：界面效果与真实恢复流程，留到实机验证第 1 轮。

## 2026-10-15 CI 固定签名（PR #5，`codex/persistent-ci-signing`，计划 E2，Codex 实施）

- 改动：CI 改用专用固定自签名证书签名（`scripts/sign_app.sh`，一次性钥匙串），公钥 `signing/BookmarkSync-Signing.crt` 进 Git，私钥 P12 与密码只在仓库 Secrets 和用户本机私有备份；`scripts/check_signing_identity.sh` 模拟更新后要求 designated requirement 不变；Fork PR 只编译测试，缺 Secrets 时打包失败、不退回 ad-hoc。说明见 `docs/ci-signing.md`。
- 原因/决策：ad-hoc 签名每次构建身份都变，用户每装一次都要重新授予完全磁盘访问权限。
- 验证：CI run `38757143393` 与合并 main 后的 `38758121528` 均通过；designated requirement 为 `identifier "app.xazi.BookmarkSync" and certificate root = H"c46362f9…"`。
- 未验证：两个固定签名版本之间 TCC 授权是否真的保留（实机验证第 1 轮第 1 项）；从 ad-hoc 版切换需最后授权一次。

## 2026-10-15 保留空文件夹与写入等待提示（PR #6，`fix/m3-u1-empty-folders-write-wait`，计划 M3、U1）

- 改动：中枢不再过滤空文件夹；旧中枢缺少的空文件夹在每个配置第一次同步时一次性补录（`EmptyFolderMigration`，`UserDefaults` 键 `emptyFolderMigratedConfigIds`），补录过的不再补。`WriteQueue` 发布因浏览器运行而等待写入的浏览器，菜单栏 `WriteWaitBanner` 提示“完全退出（⌘Q）后写入 N 项”；读取失败的配置显示提示图标（S1 遗留）。
- 原因/决策：空文件夹过滤来自上游最初实现、无记录原因，导致新建空文件夹在所有浏览器被删；用户反馈 Edge 的删除过一阵才出现，原因是写入在等 Edge 退出，但界面没说。
- 验证：CI run `38758660923` 93 个测试全部通过，含 `EmptyFolderMigrationTests`、`EmptyFolderSyncTests`。
- 未验证：界面效果，留到实机验证第 1 轮。
- 备注：分支上合并 PR #5 后的文档更新提交在 PR 合并之后才推送，没有进入 `main`，由后续文档 PR 补上。

## 2026-10-15 实机验证：备份对比与恢复（PR #4 的功能，用户在 Mac 上测试）

- 结果：用户反馈备份差异对比已在 Mac 上测试通过。
- 未测：实机验证第 1 轮其余项（固定签名跨版本授权、暂停删除与查看详情、空文件夹保留、写入等待提示）；用户决定先推进新功能，留到第 2 轮。
