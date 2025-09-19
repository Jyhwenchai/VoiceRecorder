import Foundation

/// 录音事件
public struct RecordingEvent: Sendable {

    /// 事件类型
    public enum EventType: Sendable {
        /// 录音开始
        case started

        /// 录音暂停
        case paused

        /// 录音恢复
        case resumed

        /// 录音停止（包含保存的文件URL）
        case stopped(URL)

        /// 录音取消
        case cancelled

        /// 音频级别更新（0.0-1.0范围）
        case audioLevel(Float)

        /// 峰值音频级别更新
        case peakAudioLevel(Float)

        /// 录音时长更新（秒）
        case duration(TimeInterval)

        /// 发生错误
        case error(VoiceRecorderError)

        /// 达到最大录音时长
        case reachedMaxDuration

        /// 录音时长低于最短要求
        case belowMinDuration

        /// 存储空间不足警告
        case lowStorageWarning(UInt64)

        /// 录音统计更新
        case statsUpdate(RecordingStats)

        /// 权限状态变化
        case permissionChanged(Bool)

        /// 音频会话中断
        case audioSessionInterrupted

        /// 音频会话恢复
        case audioSessionResumed

        /// 文件操作完成
        case fileOperationCompleted(FileOperationResult)
    }

    /// 事件类型
    public let type: EventType

    /// 事件时间戳
    public let timestamp: Date

    /// 事件来源
    public let source: EventSource

    /// 事件优先级
    public let priority: EventPriority

    /// 附加信息
    public let metadata: [String: String]?

    public init(
        type: EventType,
        timestamp: Date = Date(),
        source: EventSource = .recorder,
        priority: EventPriority = .normal,
        metadata: [String: String]? = nil
    ) {
        self.type = type
        self.timestamp = timestamp
        self.source = source
        self.priority = priority
        self.metadata = metadata
    }
}

/// 事件来源
public enum EventSource: String, Sendable {
    case recorder = "recorder"
    case fileSystem = "fileSystem"
    case audioSession = "audioSession"
    case system = "system"
    case user = "user"
}

/// 事件优先级
public enum EventPriority: Int, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    public static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 事件过滤器

/// 事件过滤器
public struct EventFilter: Sendable {
    public let types: Set<EventTypeCategory>?
    public let sources: Set<EventSource>?
    public let minimumPriority: EventPriority?
    public let timeRange: (start: Date, end: Date)?

    public init(
        types: Set<EventTypeCategory>? = nil,
        sources: Set<EventSource>? = nil,
        minimumPriority: EventPriority? = nil,
        timeRange: (start: Date, end: Date)? = nil
    ) {
        self.types = types
        self.sources = sources
        self.minimumPriority = minimumPriority
        self.timeRange = timeRange
    }

    /// 检查事件是否匹配过滤条件
    public func matches(_ event: RecordingEvent) -> Bool {
        // 检查事件类型
        if let types = types {
            let eventCategory = event.type.category
            if !types.contains(eventCategory) {
                return false
            }
        }

        // 检查事件来源
        if let sources = sources, !sources.contains(event.source) {
            return false
        }

        // 检查优先级
        if let minimumPriority = minimumPriority, event.priority < minimumPriority {
            return false
        }

        // 检查时间范围
        if let timeRange = timeRange {
            if event.timestamp < timeRange.start || event.timestamp > timeRange.end {
                return false
            }
        }

        return true
    }
}

/// 事件类型分类
public enum EventTypeCategory: String, CaseIterable, Sendable {
    case recording = "recording"        // 录音控制相关
    case monitoring = "monitoring"      // 实时监控相关
    case error = "error"               // 错误相关
    case fileOperation = "fileOperation" // 文件操作相关
    case system = "system"             // 系统事件相关
}

// MARK: - 事件类型扩展

extension RecordingEvent.EventType {
    /// 获取事件分类
    public var category: EventTypeCategory {
        switch self {
        case .started, .paused, .resumed, .stopped, .cancelled:
            return .recording

        case .audioLevel, .peakAudioLevel, .duration, .statsUpdate:
            return .monitoring

        case .error, .lowStorageWarning:
            return .error

        case .fileOperationCompleted:
            return .fileOperation

        case .reachedMaxDuration, .belowMinDuration, .permissionChanged,
             .audioSessionInterrupted, .audioSessionResumed:
            return .system
        }
    }

    /// 获取事件描述
    public var description: String {
        switch self {
        case .started:
            return "录音开始"
        case .paused:
            return "录音暂停"
        case .resumed:
            return "录音恢复"
        case .stopped(let url):
            return "录音停止，文件保存至: \(url.lastPathComponent)"
        case .cancelled:
            return "录音取消"
        case .audioLevel(let level):
            return "音频级别: \(String(format: "%.2f", level))"
        case .peakAudioLevel(let level):
            return "峰值音频级别: \(String(format: "%.2f", level))"
        case .duration(let duration):
            return "录音时长: \(String(format: "%.1f", duration))秒"
        case .error(let error):
            return "错误: \(error.localizedDescription)"
        case .reachedMaxDuration:
            return "达到最大录音时长"
        case .belowMinDuration:
            return "录音时长低于最短要求"
        case .lowStorageWarning(let available):
            return "存储空间不足，剩余: \(available / (1024*1024))MB"
        case .statsUpdate:
            return "录音统计更新"
        case .permissionChanged(let granted):
            return "录音权限\(granted ? "已授予" : "被拒绝")"
        case .audioSessionInterrupted:
            return "音频会话中断"
        case .audioSessionResumed:
            return "音频会话恢复"
        case .fileOperationCompleted(let result):
            return "文件操作完成: \(result.operationType.rawValue)"
        }
    }

    /// 获取建议的优先级
    public var suggestedPriority: EventPriority {
        switch self {
        case .error:
            return .critical
        case .lowStorageWarning, .reachedMaxDuration, .belowMinDuration:
            return .high
        case .started, .stopped, .cancelled, .permissionChanged:
            return .high
        case .paused, .resumed:
            return .normal
        case .audioLevel, .peakAudioLevel, .duration, .statsUpdate:
            return .low
        case .audioSessionInterrupted, .audioSessionResumed:
            return .high
        case .fileOperationCompleted:
            return .normal
        }
    }
}

// MARK: - 事件处理器

/// 事件处理器协议
public protocol EventHandler: Sendable {
    func handle(_ event: RecordingEvent) async
}

/// 简单的闭包事件处理器
public struct ClosureEventHandler: EventHandler {
    private let handler: @Sendable (RecordingEvent) async -> Void

    public init(_ handler: @escaping @Sendable (RecordingEvent) async -> Void) {
        self.handler = handler
    }

    public func handle(_ event: RecordingEvent) async {
        await handler(event)
    }
}

/// 过滤事件处理器
public struct FilteredEventHandler: EventHandler {
    private let filter: EventFilter
    private let handler: any EventHandler

    public init(filter: EventFilter, handler: any EventHandler) {
        self.filter = filter
        self.handler = handler
    }

    public func handle(_ event: RecordingEvent) async {
        if filter.matches(event) {
            await handler.handle(event)
        }
    }
}

// MARK: - 事件统计

/// 事件统计信息
public struct EventStatistics: Sendable {
    public let totalEvents: Int
    public let eventsByType: [EventTypeCategory: Int]
    public let eventsBySource: [EventSource: Int]
    public let eventsByPriority: [EventPriority: Int]
    public let timeRange: (start: Date, end: Date)?
    public let averageEventsPerMinute: Double

    public init(events: [RecordingEvent]) {
        self.totalEvents = events.count

        // 按类型统计
        var typeStats: [EventTypeCategory: Int] = [:]
        for event in events {
            let category = event.type.category
            typeStats[category, default: 0] += 1
        }
        self.eventsByType = typeStats

        // 按来源统计
        var sourceStats: [EventSource: Int] = [:]
        for event in events {
            sourceStats[event.source, default: 0] += 1
        }
        self.eventsBySource = sourceStats

        // 按优先级统计
        var priorityStats: [EventPriority: Int] = [:]
        for event in events {
            priorityStats[event.priority, default: 0] += 1
        }
        self.eventsByPriority = priorityStats

        // 时间范围
        if !events.isEmpty {
            let timestamps = events.map { $0.timestamp }
            let start = timestamps.min()!
            let end = timestamps.max()!
            self.timeRange = (start: start, end: end)

            // 计算平均每分钟事件数
            let duration = end.timeIntervalSince(start)
            self.averageEventsPerMinute = duration > 0 ? Double(events.count) / (duration / 60.0) : 0
        } else {
            self.timeRange = nil
            self.averageEventsPerMinute = 0
        }
    }
}

// MARK: - 便利扩展

extension RecordingEvent {
    /// 创建录音开始事件
    public static func started() -> RecordingEvent {
        return RecordingEvent(
            type: .started,
            priority: .high
        )
    }

    /// 创建录音停止事件
    public static func stopped(url: URL) -> RecordingEvent {
        return RecordingEvent(
            type: .stopped(url),
            priority: .high
        )
    }

    /// 创建音频级别事件
    public static func audioLevel(_ level: Float) -> RecordingEvent {
        return RecordingEvent(
            type: .audioLevel(level),
            priority: .low
        )
    }

    /// 创建时长更新事件
    public static func duration(_ duration: TimeInterval) -> RecordingEvent {
        return RecordingEvent(
            type: .duration(duration),
            priority: .low
        )
    }

    /// 创建错误事件
    public static func error(_ error: VoiceRecorderError) -> RecordingEvent {
        return RecordingEvent(
            type: .error(error),
            priority: .critical,
            metadata: [
                "errorType": String(describing: Swift.type(of: error)),
                "errorCode": error.localizedDescription
            ]
        )
    }
}

// MARK: - 调试支持

extension RecordingEvent: CustomStringConvertible {
    public var description: String {
        let timeString = DateFormatter.eventTimestamp.string(from: timestamp)
        return "[\(timeString)] \(source.rawValue.uppercased()): \(type.description)"
    }
}

extension DateFormatter {
    static let eventTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}