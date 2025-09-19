import Foundation

/// 语音录制器配置
public struct VoiceRecorderConfiguration: Sendable {

    // MARK: - 音频设置

    /// 音频格式
    public var audioFormat: AudioFormat

    /// 音频质量
    public var audioQuality: AudioQuality

    /// 自定义音频质量（当audioQuality为custom时使用）
    public var customAudioQuality: CustomAudioQuality?

    /// 声道数（1=单声道，2=立体声）
    public var numberOfChannels: Int

    /// 比特率（kbps，用于压缩格式）
    public var bitRate: Int

    // MARK: - 录音时长设置

    /// 最短有效录制时长（秒）
    public var minimumDuration: TimeInterval

    /// 最大录音时长（秒，nil表示无限制）
    public var maximumDuration: TimeInterval?

    /// 低于最短时长时是否自动取消（true=自动取消，false=显示警告但保存）
    public var autoStopBelowMinimum: Bool

    /// 达到最大时长时是否自动停止
    public var autoStopAtMaximum: Bool

    // MARK: - 文件设置

    /// 保存目录（nil使用临时目录）
    public var saveDirectory: URL?

    /// 文件名前缀
    public var fileNamePrefix: String

    /// 自动生成唯一文件名
    public var autoGenerateFileName: Bool

    /// 覆盖已存在的文件
    public var overwriteExisting: Bool

    /// 文件名模式
    public var fileNamingPattern: FileNamingPattern

    // MARK: - 实时监控设置

    /// 启用音频级别监控
    public var enableMetering: Bool

    /// 音频级别更新间隔（秒）
    public var meteringUpdateInterval: TimeInterval

    /// 启用录音时长更新
    public var enableDurationUpdates: Bool

    /// 时长更新间隔（秒）
    public var durationUpdateInterval: TimeInterval

    // MARK: - 高级音频设置

    /// 启用回声消除
    public var enableEchoCancellation: Bool

    /// 启用噪音抑制
    public var enableNoiseSuppression: Bool

    /// 启用自动增益控制
    public var enableAutomaticGainControl: Bool

    /// 音频输入增益（0.0-1.0）
    public var inputGain: Float

    // MARK: - 性能和并发设置

    /// 最大并发操作数
    public var maxConcurrentOperations: Int

    /// 更新任务优先级
    public var updatePriority: VoiceRecorderTaskPriority

    /// 使用后台队列处理文件操作
    public var useBackgroundQueue: Bool

    // MARK: - 存储管理设置

    /// 自动清理临时文件
    public var autoCleanupTempFiles: Bool

    /// 临时文件保留时间（小时）
    public var tempFileRetentionHours: Int

    /// 最大磁盘使用量（MB，0表示不限制）
    public var maxDiskUsageMB: Int

    /// 磁盘空间不足时的处理策略
    public var lowDiskSpaceStrategy: LowDiskSpaceStrategy

    // MARK: - 调试和日志设置

    /// 启用详细日志
    public var enableVerboseLogging: Bool

    /// 启用性能监控
    public var enablePerformanceMonitoring: Bool

    /// 保存录音会话信息
    public var saveSessionInfo: Bool

    // MARK: - 初始化方法

    public init(
        audioFormat: AudioFormat = .m4a,
        audioQuality: AudioQuality = .high,
        customAudioQuality: CustomAudioQuality? = nil,
        numberOfChannels: Int = 2,
        bitRate: Int = 128,
        minimumDuration: TimeInterval = 0.5,
        maximumDuration: TimeInterval? = nil,
        autoStopBelowMinimum: Bool = true,
        autoStopAtMaximum: Bool = true,
        saveDirectory: URL? = nil,
        fileNamePrefix: String = "recording",
        autoGenerateFileName: Bool = true,
        overwriteExisting: Bool = false,
        fileNamingPattern: FileNamingPattern = .timestampSuffix,
        enableMetering: Bool = true,
        meteringUpdateInterval: TimeInterval = 0.1,
        enableDurationUpdates: Bool = true,
        durationUpdateInterval: TimeInterval = 0.1,
        enableEchoCancellation: Bool = false,
        enableNoiseSuppression: Bool = false,
        enableAutomaticGainControl: Bool = false,
        inputGain: Float = 1.0,
        maxConcurrentOperations: Int = 1,
        useBackgroundQueue: Bool = true,
        autoCleanupTempFiles: Bool = true,
        tempFileRetentionHours: Int = 24,
        maxDiskUsageMB: Int = 0,
        lowDiskSpaceStrategy: LowDiskSpaceStrategy = .stopRecording,
        enableVerboseLogging: Bool = false,
        enablePerformanceMonitoring: Bool = false,
        saveSessionInfo: Bool = false
    ) {
        self.audioFormat = audioFormat
        self.audioQuality = audioQuality
        self.customAudioQuality = customAudioQuality
        self.numberOfChannels = numberOfChannels
        self.bitRate = bitRate
        self.minimumDuration = minimumDuration
        self.maximumDuration = maximumDuration
        self.autoStopBelowMinimum = autoStopBelowMinimum
        self.autoStopAtMaximum = autoStopAtMaximum
        self.saveDirectory = saveDirectory
        self.fileNamePrefix = fileNamePrefix
        self.autoGenerateFileName = autoGenerateFileName
        self.overwriteExisting = overwriteExisting
        self.fileNamingPattern = fileNamingPattern
        self.enableMetering = enableMetering
        self.meteringUpdateInterval = meteringUpdateInterval
        self.enableDurationUpdates = enableDurationUpdates
        self.durationUpdateInterval = durationUpdateInterval
        self.enableEchoCancellation = enableEchoCancellation
        self.enableNoiseSuppression = enableNoiseSuppression
        self.enableAutomaticGainControl = enableAutomaticGainControl
        self.inputGain = inputGain
        self.maxConcurrentOperations = maxConcurrentOperations
        self.updatePriority = .userInitiated
        self.useBackgroundQueue = useBackgroundQueue
        self.autoCleanupTempFiles = autoCleanupTempFiles
        self.tempFileRetentionHours = tempFileRetentionHours
        self.maxDiskUsageMB = maxDiskUsageMB
        self.lowDiskSpaceStrategy = lowDiskSpaceStrategy
        self.enableVerboseLogging = enableVerboseLogging
        self.enablePerformanceMonitoring = enablePerformanceMonitoring
        self.saveSessionInfo = saveSessionInfo
    }
}

// MARK: - 预设配置

extension VoiceRecorderConfiguration {

    /// 默认配置
    public static var `default`: VoiceRecorderConfiguration {
        // 设置默认的保存目录为 Documents
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let defaultSaveDirectory = documentsDirectory.appendingPathComponent("VoiceRecorder")

        return VoiceRecorderConfiguration(
            saveDirectory: defaultSaveDirectory
        )
    }

    /// 高质量配置（适合音乐录制）
    public static var highQuality: VoiceRecorderConfiguration {
        return VoiceRecorderConfiguration(
            audioFormat: .wav,
            audioQuality: .max,
            numberOfChannels: 2,
            bitRate: 256,
            minimumDuration: 1.0,
            enableMetering: true,
            meteringUpdateInterval: 0.05, // 更频繁的更新
            enableNoiseSuppression: true
        )
    }

    /// 低延迟配置（适合实时应用）
    public static var lowLatency: VoiceRecorderConfiguration {
        var config = VoiceRecorderConfiguration(
            audioFormat: .caf,
            audioQuality: .medium,
            numberOfChannels: 1,
            meteringUpdateInterval: 0.05,
            durationUpdateInterval: 0.05,
            useBackgroundQueue: false
        )
        if #available(iOS 13.0, macOS 10.15, *) {
            config.updatePriority = .high
        }
        return config
    }

    /// 长时间录音配置（适合会议、讲座）
    public static var longRecording: VoiceRecorderConfiguration {
        return VoiceRecorderConfiguration(
            audioFormat: .m4a,
            audioQuality: .medium,
            numberOfChannels: 1,
            bitRate: 96,
            maximumDuration: 3600, // 1小时
            meteringUpdateInterval: 0.5, // 降低更新频率节省电量
            durationUpdateInterval: 1.0,
            enableNoiseSuppression: true,
            autoCleanupTempFiles: true
        )
    }

    /// 语音备忘录配置
    public static var voiceMemo: VoiceRecorderConfiguration {
        return VoiceRecorderConfiguration(
            audioFormat: .m4a,
            audioQuality: .medium,
            numberOfChannels: 1,
            bitRate: 64,
            minimumDuration: 0.3,
            maximumDuration: 180, // 3分钟
            meteringUpdateInterval: 0.2,
            enableNoiseSuppression: true,
            enableAutomaticGainControl: true
        )
    }

    /// 播客录制配置
    public static var podcast: VoiceRecorderConfiguration {
        return VoiceRecorderConfiguration(
            audioFormat: .m4a,
            audioQuality: .high,
            numberOfChannels: 1,
            bitRate: 128,
            minimumDuration: 2.0,
            enableMetering: true,
            enableEchoCancellation: true,
            enableNoiseSuppression: true,
            enableAutomaticGainControl: true
        )
    }

    /// 音乐录制配置
    public static var music: VoiceRecorderConfiguration {
        return VoiceRecorderConfiguration(
            audioFormat: .wav,
            audioQuality: .max,
            numberOfChannels: 2,
            minimumDuration: 1.0,
            meteringUpdateInterval: 0.02, // 高频更新用于音乐
            enableEchoCancellation: false, // 音乐录制不需要回声消除
            enableNoiseSuppression: false, // 保持原始音质
            enablePerformanceMonitoring: true
        )
    }

    /// 节省空间配置
    public static var spaceEfficient: VoiceRecorderConfiguration {
        return VoiceRecorderConfiguration(
            audioFormat: .mp3,
            audioQuality: .low,
            numberOfChannels: 1,
            bitRate: 32,
            meteringUpdateInterval: 0.3,
            durationUpdateInterval: 0.5,
            autoCleanupTempFiles: true,
            tempFileRetentionHours: 1,
            maxDiskUsageMB: 100
        )
    }
}

// MARK: - 辅助枚举

/// 文件命名模式
public enum FileNamingPattern: String, CaseIterable, Sendable {
    case timestampSuffix = "timestampSuffix"     // prefix_20231201_143022.ext
    case timestampPrefix = "timestampPrefix"     // 20231201_143022_prefix.ext
    case dateTimeSuffix = "dateTimeSuffix"       // prefix_2023-12-01_14-30-22.ext
    case sequentialNumber = "sequentialNumber"   // prefix_001.ext, prefix_002.ext
    case uuid = "uuid"                           // prefix_UUID.ext
    case custom = "custom"                       // 使用自定义生成器

    public var description: String {
        switch self {
        case .timestampSuffix:
            return "前缀_时间戳后缀"
        case .timestampPrefix:
            return "时间戳前缀_后缀"
        case .dateTimeSuffix:
            return "前缀_日期时间后缀"
        case .sequentialNumber:
            return "前缀_序号"
        case .uuid:
            return "前缀_UUID"
        case .custom:
            return "自定义模式"
        }
    }
}

/// 磁盘空间不足策略
public enum LowDiskSpaceStrategy: String, CaseIterable, Sendable {
    case stopRecording = "stopRecording"         // 停止录音
    case continueRecording = "continueRecording" // 继续录音（可能失败）
    case askUser = "askUser"                     // 询问用户
    case cleanupAndContinue = "cleanupAndContinue" // 清理临时文件后继续

    public var description: String {
        switch self {
        case .stopRecording:
            return "自动停止录音"
        case .continueRecording:
            return "继续录音"
        case .askUser:
            return "询问用户"
        case .cleanupAndContinue:
            return "清理后继续"
        }
    }
}

// MARK: - 配置验证

extension VoiceRecorderConfiguration {

    /// 验证配置的有效性
    public var isValid: Bool {
        return validationErrors.isEmpty
    }

    /// 获取配置验证错误
    public var validationErrors: [String] {
        var errors: [String] = []

        // 验证声道数
        if numberOfChannels < 1 || numberOfChannels > 2 {
            errors.append("声道数必须为1或2")
        }

        // 验证比特率
        if bitRate < 32 || bitRate > 512 {
            errors.append("比特率必须在32-512之间")
        }

        // 验证时长设置
        if minimumDuration < 0 {
            errors.append("最短录音时长不能小于0")
        }

        if let maxDuration = maximumDuration, maxDuration <= minimumDuration {
            errors.append("最大录音时长必须大于最短录音时长")
        }

        // 验证更新间隔
        if meteringUpdateInterval <= 0 {
            errors.append("音频级别更新间隔必须大于0")
        }

        if durationUpdateInterval <= 0 {
            errors.append("时长更新间隔必须大于0")
        }

        // 验证输入增益
        if inputGain < 0 || inputGain > 1 {
            errors.append("输入增益必须在0.0-1.0之间")
        }

        // 验证自定义音频质量
        if audioQuality == .custom {
            if let custom = customAudioQuality {
                if !custom.isValid {
                    errors.append("自定义音频质量参数无效")
                }
            } else {
                errors.append("使用自定义质量时必须提供customAudioQuality")
            }
        }

        // 验证存储设置
        if maxDiskUsageMB < 0 {
            errors.append("最大磁盘使用量不能小于0")
        }

        if tempFileRetentionHours < 0 {
            errors.append("临时文件保留时间不能小于0")
        }

        return errors
    }

    /// 获取有效的音频质量
    public var effectiveAudioQuality: AudioQuality {
        if audioQuality == .custom {
            return .high
        }
        return audioQuality
    }

    /// 获取有效的采样率
    public var effectiveSampleRate: Double {
        if audioQuality == .custom {
            return customAudioQuality?.sampleRate ?? audioQuality.sampleRate
        }
        return audioQuality.sampleRate
    }

    /// 获取有效的位深度
    public var effectiveBitDepth: Int {
        if audioQuality == .custom {
            return customAudioQuality?.bitDepth ?? audioQuality.bitDepth
        }
        return audioQuality.bitDepth
    }

    /// 获取有效的比特率
    public var effectiveBitRate: Int {
        if audioQuality == .custom,
           let customBitRate = customAudioQuality?.bitRate {
            return customBitRate
        }
        return bitRate
    }
}

// MARK: - 配置比较

extension VoiceRecorderConfiguration: Equatable {
    public static func == (lhs: VoiceRecorderConfiguration, rhs: VoiceRecorderConfiguration) -> Bool {
        return lhs.audioFormat == rhs.audioFormat &&
               lhs.audioQuality == rhs.audioQuality &&
               lhs.numberOfChannels == rhs.numberOfChannels &&
               lhs.bitRate == rhs.bitRate &&
               lhs.minimumDuration == rhs.minimumDuration &&
               lhs.maximumDuration == rhs.maximumDuration &&
               lhs.enableMetering == rhs.enableMetering
        // 为简化比较，只比较关键属性
    }
}

// MARK: - 配置描述

extension VoiceRecorderConfiguration: CustomStringConvertible {
    public var description: String {
        let format = audioFormat.description
        let quality = audioQuality == .custom ?
            (customAudioQuality?.description ?? "自定义") :
            audioQuality.description
        let channels = numberOfChannels == 1 ? "单声道" : "立体声"

        return """
        VoiceRecorderConfiguration:
        - 格式: \(format)
        - 质量: \(quality)
        - 声道: \(channels)
        - 比特率: \(bitRate)kbps
        - 最短时长: \(minimumDuration)秒
        - 最长时长: \(maximumDuration?.description ?? "无限制")
        """
    }
}

// MARK: - 任务优先级枚举

/// 任务优先级枚举（兼容版本）
public enum VoiceRecorderTaskPriority: String, CaseIterable, Sendable {
    case low = "low"
    case utility = "utility"
    case userInitiated = "userInitiated"
    case high = "high"

    @available(iOS 13.0, macOS 10.15, *)
    public var taskPriority: TaskPriority {
        switch self {
        case .low:
            return .low
        case .utility:
            return .utility
        case .userInitiated:
            return .userInitiated
        case .high:
            return .high
        }
    }
}