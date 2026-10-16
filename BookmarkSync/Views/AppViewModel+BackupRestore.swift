import Foundation
import SwiftData

extension AppViewModel {
    /// Puts one bookmark or folder from a backup back into the hub, with any
    /// enclosing folders the hub no longer has and, for a folder, the contents
    /// the backup has. The next sync writes it to every browser in the
    /// profile's set, as if it had just been added in one of them.
    ///
    /// - Parameters:
    ///   - id: the item's node id as read from the backup (no set prefix).
    ///   - backup: every node read from the backup, by id.
    /// - Returns: how many hub nodes were added or changed.
    @discardableResult
    func restoreFromBackup(id: String, backup: [String: ParsedBookmark], into config: BrowserConfig) -> Int {
        guard let context = modelContext,
              let setId = config.profileSetId, !setId.isEmpty,
              let target = backup[id],
              let hubNodes = try? context.fetch(FetchDescriptor<BookmarkNode>()) else { return 0 }

        var hubById = Dictionary(hubNodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func hubId(_ backupId: String) -> String { "\(setId):\(backupId)" }

        // Enclosing folders first (outermost first), then the item, then what
        // a folder contained.
        var chain: [ParsedBookmark] = []
        var visited = Set<String>()
        var parentId = target.parentId
        while let pid = parentId, visited.insert(pid).inserted, let parent = backup[pid] {
            chain.insert(parent, at: 0)
            parentId = parent.parentId
        }
        var contents: [ParsedBookmark] = []
        if target.type == .folder {
            var childrenByParent: [String: [ParsedBookmark]] = [:]
            for node in backup.values {
                if let pid = node.parentId { childrenByParent[pid, default: []].append(node) }
            }
            var stack = childrenByParent[target.id] ?? []
            while let node = stack.popLast() {
                contents.append(node)
                stack.append(contentsOf: childrenByParent[node.id] ?? [])
            }
            contents.sort { $0.id < $1.id }
        }

        var touched = 0
        for node in chain + [target] + contents {
            if let existing = hubById[hubId(node.id)] {
                // Only the chosen item takes the backup's title and URL;
                // folders around it and items inside it are left as they are.
                guard node.id == target.id,
                      existing.title != node.title || existing.url != node.url else { continue }
                existing.title = node.title
                existing.url = node.url
                existing.mtime = Date()
            } else {
                let restored = BookmarkNode(
                    id: hubId(node.id),
                    title: node.title,
                    url: node.url,
                    type: node.type,
                    parentId: node.parentId.map(hubId),
                    mtime: Date(),
                    profileSetId: setId,
                    index: node.index
                )
                context.insert(restored)
                hubById[restored.id] = restored
            }
            touched += 1
        }

        guard touched > 0 else { return 0 }
        try? context.save()
        noteBookmarkDataChanged()
        SyncLog.event("[Backup] Restored \(touched) node(s) for \(id) into the hub from a backup of \(config.browserName) (\(config.profileName))")
        syncEngine?.triggerSync(changedPaths: [], forceImmediate: true)
        return touched
    }
}
