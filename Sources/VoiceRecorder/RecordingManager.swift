import Foundation
import AVFoundation

/// 录音管理器 - 使用 Actor 确保线程安全
actor RecordingManager {

    // MARK: - 录音状态

    /// 录音状态枚举
    enum State: Sendable {
        case idle
        case recording(startTime: Date)
        case paused(startTime: Date, pauseTime: Date)
        case stopping
    }

    // MARK: - 私有属性

    private var state: State = .idle
    private var audioRecorder: AVAudioRecorder?
    private var currentFileURL: URL?
    private var totalPausedDuration: TimeInterval = 0
    private var configuration: VoiceRecorderConfiguration

    // MARK: - 初始化

    init(configuration: VoiceRecorderConfiguration) {
        self.configuration = configuration
    }

    // MARK: - 配置管理

    /// 更新配置
    func updateConfiguration(_ newConfiguration: VoiceRecorderConfiguration) {
        self.configuration = newConfiguration
    }

    /// 获取当前配置
    func getCurrentConfiguration() -> VoiceRecorderConfiguration {
        return configuration
    }

    // MARK: - 录音控制

    /// 开始录音
    func startRecording(url: URL, settings: [String: Any]) async throws {
        guard case .idle = state else {
            throw VoiceRecorderError.recordingInProgress
        }

        // 验证文件URL和父目录
        let parentDirectory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDirectory.path) {
            throw VoiceRecorderError.fileOperationFailed("录音目录不存在: \(parentDirectory.path)")
        }

        // 设置音频会话
        try await setupAudioSession()

        // 创建音频录制器
        do {
            print("[RecordingManager] 创建录音器: \(url.path)")
            print("[RecordingManager] 录音设置: \(settings)")

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            guard let recorder = audioRecorder else {
                throw VoiceRecorderError.recordingFailed("无法创建音频录制器")
            }

            // 配置录制器
            recorder.isMeteringEnabled = configuration.enableMetering

            // 准备录音
            let prepareSuccess = recorder.prepareToRecord()
            print("[RecordingManager] 录音器准备结果: \(prepareSuccess)")

            if !prepareSuccess {
                throw VoiceRecorderError.recordingFailed("录音器准备失败")
            }

            // 开始录音
            let recordSuccess = recorder.record()
            print("[RecordingManager] 录音启动结果: \(recordSuccess)")

            guard recordSuccess else {
                // 获取更详细的错误信息
                print("[RecordingManager] 录音文件URL: \(recorder.url)")
                throw VoiceRecorderError.recordingFailed("录音启动失败")
            }

            // 更新状态
            state = .recording(startTime: Date())
            currentFileURL = url
            totalPausedDuration = 0

            print("[RecordingManager] 录音成功启动")

        } catch {
            // 清理资源
            audioRecorder = nil
            currentFileURL = nil
            print("[RecordingManager] 录音启动失败: \(error)")
            throw VoiceRecorderError.recordingFailed("录音初始化失败: \(error.localizedDescription)")
        }
    }

    /// 暂停录音
    func pauseRecording() async -> Bool {
        guard case .recording(let startTime) = state else {
            return false
        }

        audioRecorder?.pause()
        state = .paused(startTime: startTime, pauseTime: Date())
        return true
    }

    /// 恢复录音
    func resumeRecording() async -> Bool {
        guard case .paused(let startTime, let pauseTime) = state else {
            return false
        }

        // 累计暂停时间
        totalPausedDuration += Date().timeIntervalSince(pauseTime)

        // 恢复录音
        audioRecorder?.record()
        state = .recording(startTime: startTime)
        return true
    }

    /// 停止录音
    func stopRecording() async throws -> (URL, TimeInterval) {
        let duration = getCurrentDuration()

        // 检查最短录音时长
        if duration < configuration.minimumDuration {
            if configuration.autoStopBelowMinimum {
                // 自动取消录音
                await cancelRecording()
                throw VoiceRecorderError.recordingTooShort(duration)
            }
            // 否则继续保存但发出警告
        }

        state = .stopping
        audioRecorder?.stop()
        state = .idle

        guard let url = currentFileURL else {
            throw VoiceRecorderError.noActiveRecording
        }

        // 清理状态
        audioRecorder = nil
        currentFileURL = nil
        totalPausedDuration = 0

        return (url, duration)
    }

    /// 取消录音
    func cancelRecording() async {
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()

        // 手动删除文件（以防deleteRecording失败）
        if let url = currentFileURL {
            try? FileManager.default.removeItem(at: url)
        }

        // 重置状态
        state = .idle
        audioRecorder = nil
        currentFileURL = nil
        totalPausedDuration = 0
    }

    // MARK: - 状态查询

    /// 是否正在录音
    func isRecording() -> Bool {
        if case .recording = state {
            return true
        }
        return false
    }

    /// 是否已暂停
    func isPaused() -> Bool {
        if case .paused = state {
            return true
        }
        return false
    }

    /// 是否空闲状态
    func isIdle() -> Bool {
        if case .idle = state {
            return true
        }
        return false
    }

    /// 获取当前录音时长
    func getCurrentDuration() -> TimeInterval {
        switch state {
        case .idle, .stopping:
            return 0

        case .recording(let startTime):
            return Date().timeIntervalSince(startTime) - totalPausedDuration

        case .paused(let startTime, let pauseTime):
            return pauseTime.timeIntervalSince(startTime) - totalPausedDuration
        }
    }

    /// 获取音频级别（分贝）
    func getAudioLevel() -> Float {
        guard let recorder = audioRecorder,
              recorder.isRecording,
              configuration.enableMetering else {
            return 0.0
        }

        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)

        // 将分贝值转换为0-1范围的线性值
        // 分贝范围通常是 -160dB 到 0dB
        let minDecibels: Float = -80.0  // 实际可听范围
        let maxDecibels: Float = 0.0

        // 限制范围
        let clampedLevel = max(minDecibels, min(maxDecibels, level))

        // 转换为0-1范围
        let normalizedLevel = (clampedLevel - minDecibels) / (maxDecibels - minDecibels)

        return normalizedLevel
    }

    /// 获取峰值音频级别
    func getPeakAudioLevel() -> Float {
        guard let recorder = audioRecorder,
              recorder.isRecording,
              configuration.enableMetering else {
            return 0.0
        }

        recorder.updateMeters()
        let peakLevel = recorder.peakPower(forChannel: 0)

        // 同样转换为0-1范围
        let minDecibels: Float = -80.0
        let maxDecibels: Float = 0.0
        let clampedLevel = max(minDecibels, min(maxDecibels, peakLevel))
        let normalizedLevel = (clampedLevel - minDecibels) / (maxDecibels - minDecibels)

        return normalizedLevel
    }

    /// 获取当前录音文件URL
    func getCurrentFileURL() -> URL? {
        return currentFileURL
    }

    /// 检查是否达到最大录音时长
    func hasReachedMaximumDuration() -> Bool {
        guard let maxDuration = configuration.maximumDuration else {
            return false
        }
        return getCurrentDuration() >= maxDuration
    }

    // MARK: - 私有方法

    /// 设置音频会话
    private func setupAudioSession() async throws {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let audioSession = AVAudioSession.sharedInstance()

        do {
            print("[RecordingManager] 配置音频会话...")

            // 设置音频会话类别
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])

            // 根据配置设置音频处理选项
            if configuration.enableEchoCancellation || configuration.enableNoiseSuppression {
                try audioSession.setMode(.voiceChat)
            }

            // 激活音频会话
            try audioSession.setActive(true)
            print("[RecordingManager] 音频会话激活成功")

            // 设置音频输入增益（如果支持）
            if audioSession.isInputGainSettable {
                try audioSession.setInputGain(configuration.inputGain)
                print("[RecordingManager] 输入增益设置为: \(configuration.inputGain)")
            }

        } catch {
            print("[RecordingManager] 音频会话设置失败: \(error)")
            throw VoiceRecorderError.audioSessionSetupFailed("音频会话设置失败: \(error.localizedDescription)")
        }
        #else
        // macOS 不需要设置 AVAudioSession
        print("[RecordingManager] macOS 环境，跳过音频会话设置")
        #endif
    }

    /// 检查存储空间
    private func checkStorageSpace() async throws {
        guard configuration.maxDiskUsageMB > 0 else {
            return // 不限制磁盘使用
        }

        // 获取可用空间
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableCapacity = values.volumeAvailableCapacityForImportantUsage {
                let availableMB = Double(availableCapacity) / (1024 * 1024)
                let requiredMB = Double(configuration.maxDiskUsageMB)

                if availableMB < requiredMB {
                    switch configuration.lowDiskSpaceStrategy {
                    case .stopRecording:
                        throw VoiceRecorderError.storageFull
                    case .continueRecording:
                        break // 继续录音
                    case .askUser:
                        // 这里应该通过回调通知上层处理
                        break
                    case .cleanupAndContinue:
                        // 触发清理操作
                        break
                    }
                }
            }
        } catch {
            // 如果无法获取存储信息，继续录音
        }
    }

    /// 估算当前录音文件大小
    func getEstimatedFileSize() -> UInt64 {
        let duration = getCurrentDuration()
        return AudioFormatUtility.estimateFileSize(
            format: configuration.audioFormat,
            quality: configuration.effectiveAudioQuality,
            duration: duration,
            numberOfChannels: configuration.numberOfChannels
        )
    }

    /// 获取录音统计信息
    func getRecordingStats() -> RecordingStats {
        return RecordingStats(
            duration: getCurrentDuration(),
            pausedDuration: totalPausedDuration,
            fileSize: getEstimatedFileSize(),
            averageLevel: getAudioLevel(),
            peakLevel: getPeakAudioLevel(),
            isRecording: isRecording(),
            isPaused: isPaused()
        )
    }
}

// MARK: - 录音统计信息

/// 录音统计信息
public struct RecordingStats: Sendable {
    public let duration: TimeInterval
    public let pausedDuration: TimeInterval
    public let fileSize: UInt64
    public let averageLevel: Float
    public let peakLevel: Float
    public let isRecording: Bool
    public let isPaused: Bool

    public var effectiveDuration: TimeInterval {
        return duration
    }

    public var fileSizeMB: Double {
        return Double(fileSize) / (1024 * 1024)
    }

    public var averageLevelDB: Float {
        // 将0-1范围转换回分贝
        let minDecibels: Float = -80.0
        let maxDecibels: Float = 0.0
        return minDecibels + (averageLevel * (maxDecibels - minDecibels))
    }

    public var peakLevelDB: Float {
        // 将0-1范围转换回分贝
        let minDecibels: Float = -80.0
        let maxDecibels: Float = 0.0
        return minDecibels + (peakLevel * (maxDecibels - minDecibels))
    }
}

// MARK: - 扩展：便利方法

extension RecordingManager {

    /// 使用配置生成录音设置
    func generateRecordingSettings() -> [String: Any] {
        return configuration.audioFormat.getRecordingSettings(
            quality: configuration.effectiveAudioQuality,
            numberOfChannels: configuration.numberOfChannels,
            bitRate: configuration.effectiveBitRate
        )
    }

    /// 验证录音设置
    func validateRecordingSettings(_ settings: [String: Any]) -> Bool {
        // 检查必要的设置项
        guard settings[AVFormatIDKey] != nil,
              settings[AVSampleRateKey] != nil,
              settings[AVNumberOfChannelsKey] != nil else {
            return false
        }

        return true
    }

    /// 获取推荐的缓冲区大小
    func getRecommendedBufferSize() -> AVAudioFrameCount {
        let sampleRate = configuration.effectiveSampleRate
        let bufferDuration = configuration.meteringUpdateInterval

        // 计算缓冲区大小（以帧为单位）
        let bufferSize = AVAudioFrameCount(sampleRate * bufferDuration)

        // 限制在合理范围内
        return max(64, min(4096, bufferSize))
    }
}


// MARK: - 调试和监控

extension RecordingManager {

    /// 获取调试信息
    func getDebugInfo() -> [String: Any] {
        var info: [String: Any] = [:]

        info["state"] = String(describing: state)
        info["totalPausedDuration"] = totalPausedDuration
        info["currentDuration"] = getCurrentDuration()
        info["isRecording"] = isRecording()
        info["isPaused"] = isPaused()
        info["fileURL"] = currentFileURL?.absoluteString
        info["configuration"] = configuration.description

        if let recorder = audioRecorder {
            info["recorderIsRecording"] = recorder.isRecording
            info["recorderURL"] = recorder.url.absoluteString
            if configuration.enableMetering {
                info["averageLevel"] = getAudioLevel()
                info["peakLevel"] = getPeakAudioLevel()
            }
        }

        return info
    }

    /// 性能监控数据
    func getPerformanceMetrics() -> [String: Any] {
        guard configuration.enablePerformanceMonitoring else {
            return [:]
        }

        return [
            "memoryUsage": getMemoryUsage(),
            "cpuUsage": getCPUUsage(),
            "fileSize": getEstimatedFileSize(),
            "duration": getCurrentDuration(),
            "updateInterval": configuration.meteringUpdateInterval
        ]
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }

    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.user_time.seconds + info.system_time.seconds)
        }
        return 0
    }
}
