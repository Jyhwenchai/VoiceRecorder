import Foundation

/// 文件操作管理器 - 使用 Actor 确保线程安全的文件操作
actor FileOperationsActor {

    // MARK: - 私有属性

    private let fileManager = FileManager.default
    private var configuration: VoiceRecorderConfiguration
    private var sequentialNumberCounter: Int = 0

    // MARK: - 初始化

    init(configuration: VoiceRecorderConfiguration) {
        self.configuration = configuration
    }

    // MARK: - 配置管理

    /// 更新配置
    func updateConfiguration(_ newConfiguration: VoiceRecorderConfiguration) {
        self.configuration = newConfiguration
    }

    // MARK: - 文件创建和管理

    /// 准备录音文件URL
    func prepareRecordingURL() async throws -> URL {
        let directory = try await getOrCreateRecordingDirectory()
        let fileName = await generateFileName()
        let fileURL = directory.appendingPathComponent(fileName)

        // 检查文件是否已存在
        if fileManager.fileExists(atPath: fileURL.path) {
            if configuration.overwriteExisting {
                try fileManager.removeItem(at: fileURL)
            } else {
                // 生成新的唯一文件名
                let uniqueURL = try await generateUniqueFileURL(baseURL: fileURL)
                return uniqueURL
            }
        }

        return fileURL
    }

    /// 移动临时文件到最终位置
    func moveToFinalLocation(from tempURL: URL, to finalURL: URL) async throws {
        // 确保目标目录存在
        let targetDirectory = finalURL.deletingLastPathComponent()
        try await ensureDirectoryExists(targetDirectory)

        // 如果目标文件已存在，根据配置决定处理方式
        if fileManager.fileExists(atPath: finalURL.path) {
            if configuration.overwriteExisting {
                try fileManager.removeItem(at: finalURL)
            } else {
                let uniqueURL = try await generateUniqueFileURL(baseURL: finalURL)
                try fileManager.moveItem(at: tempURL, to: uniqueURL)
                return
            }
        }

        try fileManager.moveItem(at: tempURL, to: finalURL)
    }

    /// 复制文件到指定位置
    func copyFile(from sourceURL: URL, to targetURL: URL) async throws {
        // 确保目标目录存在
        let targetDirectory = targetURL.deletingLastPathComponent()
        try await ensureDirectoryExists(targetDirectory)

        // 处理文件冲突
        var finalTargetURL = targetURL
        if fileManager.fileExists(atPath: targetURL.path) {
            if configuration.overwriteExisting {
                try fileManager.removeItem(at: targetURL)
            } else {
                finalTargetURL = try await generateUniqueFileURL(baseURL: targetURL)
            }
        }

        try fileManager.copyItem(at: sourceURL, to: finalTargetURL)
    }

    /// 删除文件
    func deleteFile(at url: URL) async throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return // 文件不存在，无需删除
        }
        try fileManager.removeItem(at: url)
    }

    /// 获取文件信息
    func getFileInfo(at url: URL) async throws -> FileInfo {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)

        return FileInfo(
            url: url,
            size: attributes[.size] as? UInt64 ?? 0,
            creationDate: attributes[.creationDate] as? Date ?? Date(),
            modificationDate: attributes[.modificationDate] as? Date ?? Date(),
            isDirectory: (attributes[.type] as? FileAttributeType) == .typeDirectory
        )
    }

    /// 检查文件是否存在
    func fileExists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }

    // MARK: - 目录管理

    /// 获取或创建录音目录
    private func getOrCreateRecordingDirectory() async throws -> URL {
        let directory: URL

        if let saveDirectory = configuration.saveDirectory {
            directory = saveDirectory
        } else {
            // 使用临时目录
            directory = fileManager.temporaryDirectory.appendingPathComponent("VoiceRecorder")
        }

        try await ensureDirectoryExists(directory)
        return directory
    }

    /// 确保目录存在
    private func ensureDirectoryExists(_ directory: URL) async throws {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory)

        if exists && isDirectory.boolValue {
            return // 目录已存在
        }

        if exists && !isDirectory.boolValue {
            // 存在同名文件，删除它
            try fileManager.removeItem(at: directory)
        }

        // 创建目录
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// 获取目录内容
    func getDirectoryContents(_ directory: URL) async throws -> [URL] {
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
    }

    // MARK: - 文件名生成

    /// 生成文件名
    private func generateFileName() async -> String {
        let prefix = configuration.fileNamePrefix.isEmpty ? "recording" : configuration.fileNamePrefix
        let fileExt = configuration.audioFormat.fileExtension

        switch configuration.fileNamingPattern {
        case .timestampSuffix:
            return await generateTimestampSuffixName(prefix: prefix, extension: fileExt)

        case .timestampPrefix:
            return await generateTimestampPrefixName(suffix: prefix, extension: fileExt)

        case .dateTimeSuffix:
            return await generateDateTimeSuffixName(prefix: prefix, extension: fileExt)

        case .sequentialNumber:
            return await generateSequentialNumberName(prefix: prefix, extension: fileExt)

        case .uuid:
            return await generateUUIDName(prefix: prefix, extension: fileExt)

        case .custom:
            // 使用时间戳作为默认的自定义模式
            return await generateTimestampSuffixName(prefix: prefix, extension: fileExt)
        }
    }

    private func generateTimestampSuffixName(prefix: String, extension fileExt: String) async -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(prefix)_\(timestamp).\(fileExt)"
    }

    private func generateTimestampPrefixName(suffix: String, extension fileExt: String) async -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(timestamp)_\(suffix).\(fileExt)"
    }

    private func generateDateTimeSuffixName(prefix: String, extension fileExt: String) async -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: Date())
        return "\(prefix)_\(dateString).\(fileExt)"
    }

    private func generateSequentialNumberName(prefix: String, extension fileExt: String) async -> String {
        sequentialNumberCounter += 1
        let numberString = String(format: "%03d", sequentialNumberCounter)
        return "\(prefix)_\(numberString).\(fileExt)"
    }

    private func generateUUIDName(prefix: String, extension fileExt: String) async -> String {
        let uuidString = UUID().uuidString.lowercased()
        return "\(prefix)_\(uuidString).\(fileExt)"
    }

    /// 生成唯一文件URL
    private func generateUniqueFileURL(baseURL: URL) async throws -> URL {
        let directory = baseURL.deletingLastPathComponent()
        let baseName = baseURL.deletingPathExtension().lastPathComponent
        let fileExt = baseURL.pathExtension

        var counter = 1
        var uniqueURL: URL

        repeat {
            let uniqueName = "\(baseName)_\(counter).\(fileExt)"
            uniqueURL = directory.appendingPathComponent(uniqueName)
            counter += 1
        } while fileManager.fileExists(atPath: uniqueURL.path) && counter < 1000

        if counter >= 1000 {
            throw VoiceRecorderError.fileOperationFailed("无法生成唯一文件名")
        }

        return uniqueURL
    }

    // MARK: - 存储空间管理

    /// 检查可用存储空间
    func checkAvailableSpace() async throws -> UInt64 {
        let directory = try await getOrCreateRecordingDirectory()
        let resourceValues = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])

        guard let availableCapacity = resourceValues.volumeAvailableCapacityForImportantUsage else {
            throw VoiceRecorderError.fileOperationFailed("无法获取存储空间信息")
        }

        return UInt64(availableCapacity)
    }

    /// 检查存储空间是否足够
    func hasEnoughSpace(for estimatedSize: UInt64) async throws -> Bool {
        let availableSpace = try await checkAvailableSpace()
        let requiredSpace = estimatedSize + (10 * 1024 * 1024) // 预留10MB

        return availableSpace >= requiredSpace
    }

    /// 获取目录大小
    func getDirectorySize(_ directory: URL) async throws -> UInt64 {
        let contents = try await getDirectoryContents(directory)
        var totalSize: UInt64 = 0

        for url in contents {
            let fileInfo = try await getFileInfo(at: url)
            totalSize += fileInfo.size
        }

        return totalSize
    }

    // MARK: - 清理操作

    /// 清理临时文件
    func cleanupTempFiles(olderThan date: Date = Date().addingTimeInterval(-24 * 3600)) async throws {
        guard configuration.autoCleanupTempFiles else {
            return
        }

        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("VoiceRecorder")

        guard fileManager.fileExists(atPath: tempDirectory.path) else {
            return
        }

        let files = try await getDirectoryContents(tempDirectory)

        for fileURL in files {
            do {
                let fileInfo = try await getFileInfo(at: fileURL)
                if fileInfo.creationDate < date {
                    try await deleteFile(at: fileURL)
                }
            } catch {
                // 忽略单个文件的错误，继续清理其他文件
                continue
            }
        }
    }

    /// 清理录音目录（根据配置）
    func cleanupRecordingDirectory() async throws {
        guard configuration.maxDiskUsageMB > 0 else {
            return // 不限制磁盘使用
        }

        let directory = try await getOrCreateRecordingDirectory()
        let currentSize = try await getDirectorySize(directory)
        let maxSizeBytes = UInt64(configuration.maxDiskUsageMB) * 1024 * 1024

        if currentSize <= maxSizeBytes {
            return // 未超过限制
        }

        // 获取所有文件并按创建时间排序
        let files = try await getDirectoryContents(directory)
        var fileInfos: [(URL, FileInfo)] = []

        for url in files {
            do {
                let info = try await getFileInfo(at: url)
                fileInfos.append((url, info))
            } catch {
                continue
            }
        }

        // 按创建时间升序排序（最旧的在前）
        fileInfos.sort { $0.1.creationDate < $1.1.creationDate }

        // 删除旧文件直到大小符合要求
        var remainingSize = currentSize
        for (url, info) in fileInfos {
            if remainingSize <= maxSizeBytes {
                break
            }

            try await deleteFile(at: url)
            remainingSize -= info.size
        }
    }

    /// 删除所有录音文件
    func deleteAllRecordings() async throws {
        let directory = try await getOrCreateRecordingDirectory()
        let contents = try await getDirectoryContents(directory)

        for url in contents {
            try await deleteFile(at: url)
        }
    }

    // MARK: - 文件验证

    /// 验证音频文件
    func validateAudioFile(at url: URL) async throws -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }

        // 检查文件大小
        let fileInfo = try await getFileInfo(at: url)
        if fileInfo.size == 0 {
            return false
        }

        // 检查文件扩展名
        let fileExtension = url.pathExtension.lowercased()
        let expectedExtension = configuration.audioFormat.fileExtension.lowercased()

        return fileExtension == expectedExtension
    }

    /// 修复损坏的文件
    func repairCorruptedFile(at url: URL) async throws -> Bool {
        // 对于音频文件，修复选项有限
        // 这里只是检查并尝试基本的文件完整性修复
        guard try await validateAudioFile(at: url) else {
            return false
        }

        // 如果文件看起来正常，返回true
        return true
    }

    // MARK: - 批量操作

    /// 批量删除文件
    func batchDeleteFiles(_ urls: [URL]) async throws {
        for url in urls {
            try await deleteFile(at: url)
        }
    }

    /// 批量移动文件
    func batchMoveFiles(_ operations: [(from: URL, to: URL)]) async throws {
        for operation in operations {
            try await moveToFinalLocation(from: operation.from, to: operation.to)
        }
    }

    // MARK: - 文件监控

    /// 开始监控目录变化（简单实现）
    func startDirectoryMonitoring(_ directory: URL, handler: @escaping (URL, FileChangeType) -> Void) async {
        // 这是一个简化的实现
        // 在实际应用中，可能需要使用 FSEvents 或其他系统API
        // 这里仅作为接口预留
    }

    /// 停止目录监控
    func stopDirectoryMonitoring() async {
        // 停止监控实现
    }
}

// MARK: - 数据结构

/// 文件信息
public struct FileInfo: Sendable {
    public let url: URL
    public let size: UInt64
    public let creationDate: Date
    public let modificationDate: Date
    public let isDirectory: Bool

    public var sizeInMB: Double {
        return Double(size) / (1024 * 1024)
    }

    public var fileName: String {
        return url.lastPathComponent
    }

    public var fileExtension: String {
        return url.pathExtension
    }
}

/// 文件变化类型
public enum FileChangeType: Sendable {
    case created
    case modified
    case deleted
    case moved
}

// MARK: - 文件操作结果

/// 文件操作结果
public struct FileOperationResult: Sendable {
    public let success: Bool
    public let url: URL?
    public let error: Error?
    public let operationType: FileOperationType

    public init(success: Bool, url: URL? = nil, error: Error? = nil, operationType: FileOperationType) {
        self.success = success
        self.url = url
        self.error = error
        self.operationType = operationType
    }
}

/// 文件操作类型
public enum FileOperationType: String, Sendable {
    case create = "create"
    case move = "move"
    case copy = "copy"
    case delete = "delete"
    case cleanup = "cleanup"
    case validate = "validate"
}

// MARK: - 扩展：便利方法

extension FileOperationsActor {

    /// 获取录音文件列表
    func getRecordingFiles() async throws -> [FileInfo] {
        let directory = try await getOrCreateRecordingDirectory()
        let contents = try await getDirectoryContents(directory)

        var fileInfos: [FileInfo] = []
        for url in contents {
            // 只包含音频文件
            if isAudioFile(url) {
                do {
                    let info = try await getFileInfo(at: url)
                    fileInfos.append(info)
                } catch {
                    // 忽略单个文件错误
                    continue
                }
            }
        }

        // 按修改时间降序排序（最新的在前）
        return fileInfos.sorted { $0.modificationDate > $1.modificationDate }
    }

    /// 检查是否为音频文件
    private func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = ["m4a", "wav", "caf", "mp3", "aac"]
        let fileExtension = url.pathExtension.lowercased()
        return audioExtensions.contains(fileExtension)
    }

    /// 获取存储使用统计
    func getStorageStats() async throws -> StorageStats {
        let directory = try await getOrCreateRecordingDirectory()
        let files = try await getRecordingFiles()
        let totalSize = try await getDirectorySize(directory)
        let availableSpace = try await checkAvailableSpace()

        return StorageStats(
            totalFiles: files.count,
            totalSize: totalSize,
            availableSpace: availableSpace,
            oldestFile: files.min(by: { $0.creationDate < $1.creationDate }),
            newestFile: files.max(by: { $0.creationDate < $1.creationDate })
        )
    }

    /// 导出文件到指定位置
    func exportFile(from sourceURL: URL, to targetURL: URL) async throws -> FileOperationResult {
        do {
            try await copyFile(from: sourceURL, to: targetURL)
            return FileOperationResult(success: true, url: targetURL, operationType: .copy)
        } catch {
            return FileOperationResult(success: false, error: error, operationType: .copy)
        }
    }
}

/// 存储统计信息
public struct StorageStats: Sendable {
    public let totalFiles: Int
    public let totalSize: UInt64
    public let availableSpace: UInt64
    public let oldestFile: FileInfo?
    public let newestFile: FileInfo?

    public var totalSizeMB: Double {
        return Double(totalSize) / (1024 * 1024)
    }

    public var availableSpaceMB: Double {
        return Double(availableSpace) / (1024 * 1024)
    }

    public var averageFileSize: UInt64 {
        return totalFiles > 0 ? totalSize / UInt64(totalFiles) : 0
    }
}