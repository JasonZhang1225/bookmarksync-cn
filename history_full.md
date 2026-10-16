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

## 2026-10-16 网址匹配与书签 ID 迁移（PR #8，`fix/m1-url-matching`，计划 M1、E1；含 PR #7 的文档补记）

- 改动：`normalizeURL` 只忽略协议、主机大小写、开头的 `www.`、默认端口和末尾斜杠，保留路径 / 参数 / 片段的大小写和非默认端口；新增 `BookmarkIdMigration`（`UserDefaults` 键 `bookmarkIdSchemeVersion` = 2），第一次同步前把中枢节点和各配置 `observedStateData` 里的 ID 改成新规则（两阶段改名，`:dupN` 沿用原顺序）；`AGENTS.md` 2.E、README 两处说明随之修正。
- 原因/决策：旧规则把大小写不同的路径、不同端口当成同一个书签；改 ID 规则必须带迁移，否则下一轮会表现为“全部删除 + 全部新增”。
- 验证：PR CI 通过，含新增 `URLMatchingTests`（规范化与迁移）。
- 未验证：真实书签库升级后的第一次同步（最终实机验证清单第 2 项）。

## 2026-10-16 根目录映射（PR #9，`fix/m2-root-mapping`，计划 M2）

- 改动：新增 `BookmarkRoots`，定义各浏览器支持的根目录（Chrome 有 `synced`，Safari 默认配置只有书签栏和书签菜单，Safari 命名配置只有书签栏，Firefox 只有书签栏和其他书签）；导出阶段不再把目标浏览器没有的根目录算作“缺失”；书签详情对这类条目显示“此浏览器不同步”。
- 原因/决策：Chrome 的移动设备书签在 Safari 里无处可放，以前每轮都会对 Safari 重新排队写入。
- 验证：PR CI 通过，含新增 `RootMappingTests`。
- 未验证：清单第 6 项。

## 2026-10-16 Firefox 增量写入（PR #10，`fix/s3-firefox-incremental-write`，计划 S3、S4）

- 改动：Firefox 写入改为 `FirefoxIncrementalWriter`：和读取共用 `assignIds` 确定身份，只删除 / 更新 / 新增有变化的行，保留 GUID 和分隔线；删除时给 Firefox Sync 写 `moz_bookmarks_deleted`、维护 `syncChangeCounter`；书签菜单里的书签留在原处，不再复制到“其他书签”；写入未变化的书签树不产生任何改动。
- 附带修复：PR CI 曾崩溃（“model instance was destroyed by calling ModelContext.reset”）。原因是文件监视回调持有 `BrowserConfig` 模型对象，测试重建上下文后回调仍在访问；改为只保存文件路径字符串，被监视的文件列表变化时重建监视器（`SyncEngine.updateWatcher`）。
- 验证：PR CI 通过，含新增 `FirefoxWriteTests`（sqlite fixture：未变化不写、原地改名、删除留记录、分隔线位置、菜单不复制、标签不动）。
- 未验证：真实 Firefox 和 Firefox Sync 往返（清单第 7、8 项）。

## 2026-10-16 设计稿与最终实机验证清单（PR #11，`docs/phase1-designs`，计划批次 7）

- 改动：新增 `docs/design/d1-identity-model.md`（中枢自有 ID + 原生 ID 对照）、`docs/design/d2-browser-extension.md`（Chromium / Firefox 配套扩展）、`docs/design/u2-u3-m4-evaluation.md`（U2 归档方案选项、U3 不改、M4 交给 D1）；计划中合并出“最终实机验证清单”。
- 决策：U3 写入队列不持久化，不改；M4 不单独修。U2 默认方式、D1 / D2 是否进入第二阶段，待用户决定。
- 验证：仅文档。

## 2026-10-16 实机验证：固定签名跨版本保留授权（计划 E2）

- 结果：用户安装 PR #11 的 CI 包后，没有再被要求授予完全磁盘访问权限。2026-10-15 安装 PR #8 包时的那次授权，是从 ad-hoc 版切换到固定签名版的一次性授权。E2 验证通过。

## 2026-10-16 最终实机验证结果与用户决定

- 通过：E2（跨版本无需重新授权）、M1（升级后第一次同步无删除 / 暂停 / 大量更新）、B1/B2（浏览器运行时拒绝恢复，用户判断为通过）、M3（个人收藏里新建空文件夹被保留并同步）、U1（等待提示与 ⌘Q 后写入）、C1/C2（Chrome / Safari 云同步暂未发现异常，需长期观察）。
- M2：Chrome 移动设备书签对 Safari 显示“此浏览器不同步”，符合设计；用户以为是 Safari 结构问题，已解释。
- 未测：S1/S2/B3 批量删除（Chrome 其他配置读不到，未测）；S3/S4 Firefox（用户不用 Firefox）。
- 新发现：① 在 Safari 书签根目录新建文件夹会被识别成一个新的 Safari 配置；文件夹删除后，该配置一直显示“暂时无法访问”且无法移除。② Chrome 读不到其他配置（多个 Google 账号），原因待查。③ Safari 删除后 Chrome 显示已删但实际未删：Chrome 当时在运行，删除在排队等 ⌘Q，属预期，待用户退出 Chrome 后确认。
- 用户建议：写清自动备份的触发时机，增加手动备份按钮。
- 决定：U2 维持现状（选项 A）；D1、D2 暂时搁置；用户表示按最小化工程的标准，需求已基本满足。
