import XCTest
import SwiftData
@testable import BookmarkSync

@MainActor
final class BackupItemRestoreTests: XCTestCase {
    private func makeContext() throws -> (ModelContext, AppViewModel, BrowserConfig, ModelContainer) {
        let schema = Schema([BookmarkNode.self, BrowserConfig.self, ProfileSet.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let config = BrowserConfig(id: "com.google.Chrome:Default", bundleId: "com.google.Chrome", browserName: "Google Chrome",
                                   profileName: "Default", bookmarkFilePath: "/dev/null", isEnabled: true, profileSetId: "S")
        context.insert(config)
        try context.save()
        let viewModel = AppViewModel()
        viewModel.modelContext = context
        return (context, viewModel, config, container)
    }

    private let backup: [String: ParsedBookmark] = {
        let nodes = [
            ParsedBookmark(id: "bookmark_bar:F", title: "F", url: nil, type: .folder, mtime: Date(), index: 0),
            ParsedBookmark(id: "bookmark_bar:F:a.com", title: "A", url: "https://a.com/", type: .leaf,
                           parentId: "bookmark_bar:F", mtime: Date(), index: 0),
            ParsedBookmark(id: "bookmark_bar:F:c.com", title: "C", url: "https://c.com/", type: .leaf,
                           parentId: "bookmark_bar:F", mtime: Date(), index: 1),
            ParsedBookmark(id: "bookmark_bar:b.com", title: "B", url: "https://b.com/", type: .leaf, mtime: Date(), index: 1),
        ]
        return Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    }()

    private func hub(_ context: ModelContext) throws -> [String: BookmarkNode] {
        Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<BookmarkNode>()).map { ($0.id, $0) })
    }

    func testRestoringABookmarkBringsBackItsFolder() throws {
        let (context, viewModel, config, container) = try makeContext()
        _ = container

        XCTAssertEqual(viewModel.restoreFromBackup(id: "bookmark_bar:F:a.com", backup: backup, into: config), 2)
        let nodes = try hub(context)
        XCTAssertEqual(Set(nodes.keys), ["S:bookmark_bar:F", "S:bookmark_bar:F:a.com"])
        XCTAssertEqual(nodes["S:bookmark_bar:F:a.com"]?.parentId, "S:bookmark_bar:F")
        XCTAssertEqual(nodes["S:bookmark_bar:F:a.com"]?.profileSetId, "S")

        // Already there: nothing to do.
        XCTAssertEqual(viewModel.restoreFromBackup(id: "bookmark_bar:F:a.com", backup: backup, into: config), 0)
    }

    func testRestoringAFolderBringsBackItsContents() throws {
        let (context, viewModel, config, container) = try makeContext()
        _ = container

        XCTAssertEqual(viewModel.restoreFromBackup(id: "bookmark_bar:F", backup: backup, into: config), 3)
        XCTAssertEqual(Set(try hub(context).keys), ["S:bookmark_bar:F", "S:bookmark_bar:F:a.com", "S:bookmark_bar:F:c.com"])
    }

    func testRestoringAChangedBookmarkTakesTheBackupTitle() throws {
        let (context, viewModel, config, container) = try makeContext()
        _ = container
        context.insert(BookmarkNode(id: "S:bookmark_bar:b.com", title: "Renamed", url: "https://b.com/", type: .leaf,
                                    mtime: Date(), profileSetId: "S", index: 1))
        try context.save()

        XCTAssertEqual(viewModel.restoreFromBackup(id: "bookmark_bar:b.com", backup: backup, into: config), 1)
        XCTAssertEqual(try hub(context)["S:bookmark_bar:b.com"]?.title, "B")
    }

    func testAProfileOutsideASetCannotRestoreItems() throws {
        let (context, viewModel, config, container) = try makeContext()
        _ = container
        config.profileSetId = nil
        XCTAssertEqual(viewModel.restoreFromBackup(id: "bookmark_bar:b.com", backup: backup, into: config), 0)
        XCTAssertTrue(try hub(context).isEmpty)
    }
}

final class BackupDeleteTests: XCTestCase {
    func testDeletingABackupLeavesTheLiveFile() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("BackupDelete_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let live = dir.appendingPathComponent("Bookmarks")
        try Data("v1".utf8).write(to: live)
        try BackupStore.createBackup(of: live)

        let backup = try XCTUnwrap(BackupStore.listBackups(for: live).first)
        try BackupStore.delete(backup)
        XCTAssertTrue(BackupStore.listBackups(for: live).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: live.path))

        // An entry that is not a backup is refused.
        XCTAssertThrowsError(try BackupStore.delete(BackupEntry(url: live, kind: .timestamped, date: Date())))
        XCTAssertTrue(FileManager.default.fileExists(atPath: live.path))
    }
}
