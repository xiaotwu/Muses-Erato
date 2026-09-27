import Foundation

/// 具备 O(1) 探测性能与 LRU 容量配额管理的音频磁盘缓存。
enum MediaFileCache {
    /// 默认磁盘缓存上限：1 GB
    static let defaultMaxBytes: Int64 = 1024 * 1024 * 1024
    /// 触发清理后回落的目标水位：80% (800 MB)
    static let targetLowWatermarkBytes: Int64 = Int64(Double(defaultMaxBytes) * 0.8)

    static let supportedExtensions = ["m4a", "webm", "mp3", "opus", "aac", "mp4", "ogg"]

    /// 用于测试隔离的目录覆盖
    nonisolated(unsafe) static var directoryOverride: URL?

    static var directory: URL {
        if let override = directoryOverride {
            try? FileManager.default.createDirectory(at: override, withIntermediateDirectories: true)
            return override
        }
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        let dir = base.appendingPathComponent("Muses/streams", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func sanitizedQuality(_ quality: String) -> String {
        quality.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    static func file(videoId: String, quality: String, ext: String) -> URL {
        directory.appendingPathComponent("\(videoId)__\(sanitizedQuality(quality)).\(ext)")
    }

    /// O(1) 精准寻址：基于已知扩展名直接测试文件是否存在，彻底替代 O(N) 遍历目录
    static func existing(videoId: String, quality: String) -> URL? {
        let baseName = "\(videoId)__\(sanitizedQuality(quality))"
        let fm = FileManager.default

        for ext in supportedExtensions {
            let candidate = directory.appendingPathComponent("\(baseName).\(ext)")
            if let attrs = try? fm.attributesOfItem(atPath: candidate.path) {
                let size = (attrs[.size] as? NSNumber)?.int64Value ?? (attrs[.size] as? Int64 ?? 0)
                if size > 4096 {
                    // 更新访问时间以辅助 LRU 排序
                    try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: candidate.path)
                    return candidate
                }
            }
        }
        return nil
    }

    static func remove(videoId: String, quality: String) {
        let baseName = "\(videoId)__\(sanitizedQuality(quality))"
        let fm = FileManager.default
        for ext in supportedExtensions {
            let candidate = directory.appendingPathComponent("\(baseName).\(ext)")
            if fm.fileExists(atPath: candidate.path) {
                try? fm.removeItem(at: candidate)
            }
        }
    }

    static func totalBytes() -> Int64 {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return items.reduce(Int64(0)) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(size)
        }
    }

    /// LRU 容量淘汰检查：当超出 maxBytes 时，将缓存修剪至 target 水位（默认 80%）
    static func pruneIfNeeded(maxBytes: Int64 = defaultMaxBytes, targetWatermarkBytes: Int64? = nil) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }

        var fileInfos: [(url: URL, size: Int64, date: Date)] = []
        var total: Int64 = 0

        for url in items {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let date = values?.contentModificationDate ?? Date.distantPast
            total += size
            fileInfos.append((url, size, date))
        }

        guard total > maxBytes else { return }

        // 按最后修改/访问时间升序排序（最旧的排在前面）
        fileInfos.sort { $0.date < $1.date }

        let target = targetWatermarkBytes ?? Int64(Double(maxBytes) * 0.8)
        for file in fileInfos {
            if total <= target { break }
            do {
                try fm.removeItem(at: file.url)
                total -= file.size
            } catch {
                continue
            }
        }
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
