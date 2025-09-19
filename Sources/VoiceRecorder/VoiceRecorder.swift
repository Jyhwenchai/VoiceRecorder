import Foundation
import AVFoundation
import Combine

/// 语音录制器主类 - 使用 Swift Concurrency 和 MainActor 确保线程安全
@MainActor
@available(iOS 13.0, macOS 10.15, *)
public class VoiceRecorder: ObservableObject {

    // MARK: - 发布的状态属性（用于SwiftUI）

    /// 是否正在录音
    @Published public private(set) var isRecording: Bool = false

    /// 是否已暂停
    @Published public private(set) var isPaused: Bool = false

    /// 当前录音时长（秒）
    @Published public private(set) var currentDuration: TimeInterval = 0

    /// 当前音频级别（0.0-1.0）
    @Published public private(set) var audioLevel: Float = 0

    /// 峰值音频级别（0.0-1.0）
    @Published public private(set) var peakAudioLevel: Float = 0

    /// 录音统计信息
    @Published public private(set) var stats: RecordingStats?

    /// 最后的错误信息
    @Published public private(set) var lastError: VoiceRecorderError?

    // MARK: - 配置和依赖

    /// 录音配置
    public var configuration: VoiceRecorderConfiguration {
        didSet {
            Task {
                await recordingManager.updateConfiguration(configuration)
                await fileOperations.updateConfiguration(configuration)
            }
        }
    }

    /// 可选的委托（传统回调方式）
    public weak var delegate: VoiceRecorderDelegate?

    // MARK: - 私有属性

    /// 录音管理器Actor
    private let recordingManager: RecordingManager

    /// 文件操作Actor
    private let fileOperations: FileOperationsActor

    /// 链式回调存储
    private var callbacks = VoiceRecorderCallbacks()

    /// 事件流延续
    private var eventContinuation: AsyncStream<RecordingEvent>.Continuation?

    /// 监控任务
    private var meteringTask: Task<Void, Never>?
    private var durationTask: Task<Void, Never>?
    private var maxDurationTask: Task<Void, Never>?

    /// 权限检查任务
    private var permissionTask: Task<Bool, Never>?

    // MARK: - 初始化

    public init(configuration: VoiceRecorderConfiguration = .default) {
        self.configuration = configuration
        self.recordingManager = RecordingManager(configuration: configuration)
        self.fileOperations = FileOperationsActor(configuration: configuration)
    }

    deinit {
        // 清理任务
        meteringTask?.cancel()
        durationTask?.cancel()
        maxDurationTask?.cancel()
        permissionTask?.cancel()
        eventContinuation?.finish()
    }

    // MARK: - 事件流（AsyncStream）

    /// 事件流，用于监听所有录音相关事件
    public var events: AsyncStream<RecordingEvent> {
        AsyncStream { continuation in
            Task { @MainActor in
                self.eventContinuation = continuation
                continuation.onTermination = { @Sendable _ in
                    Task { @MainActor in
                        self.eventContinuation = nil
                    }
                }
            }
        }
    }

    // MARK: - 录音控制方法（Swift Concurrency）

    /// 开始录音
    public func startRecording() async throws {
        // 检查当前状态
        guard !isRecording else {
            throw VoiceRecorderError.recordingInProgress
        }

        // 检查权限
        let hasPermission = await checkMicrophonePermission()
        guard hasPermission else {
            let error = VoiceRecorderError.microphonePermissionDenied
            await sendEvent(.error(error))
            throw error
        }

        do {
            // 准备录音文件
            let fileURL = try await fileOperations.prepareRecordingURL()

            // 生成录音设置
            let settings = configuration.audioFormat.getRecordingSettings(
                quality: configuration.effectiveAudioQuality,
                numberOfChannels: configuration.numberOfChannels,
                bitRate: configuration.effectiveBitRate
            )

            // 开始录音
            try await recordingManager.startRecording(url: fileURL, settings: settings)

            // 更新状态
            isRecording = true
            isPaused = false
            lastError = nil

            // 开始监控
            startMonitoring()

            // 发送事件和回调
            let startEvent = RecordingEvent.started()
            await sendEvent(startEvent)
            callbacks.onStart?()
            delegate?.voiceRecorderDidStartRecording(self)

        } catch let error as VoiceRecorderError {
            await sendEvent(.error(error))
            throw error
        } catch {
            let recorderError = VoiceRecorderError.recordingFailed(error.localizedDescription)
            await sendEvent(.error(recorderError))
            throw recorderError
        }
    }

    /// 暂停录音
    public func pauseRecording() async {
        guard isRecording && !isPaused else { return }

        let success = await recordingManager.pauseRecording()
        if success {
            isPaused = true

            let event = RecordingEvent(type: .paused, priority: .normal)
            await sendEvent(event)
            callbacks.onPause?()
            delegate?.voiceRecorderDidPauseRecording(self)
        }
    }

    /// 恢复录音
    public func resumeRecording() async {
        guard isRecording && isPaused else { return }

        let success = await recordingManager.resumeRecording()
        if success {
            isPaused = false

            let event = RecordingEvent(type: .resumed, priority: .normal)
            await sendEvent(event)
            callbacks.onResume?()
            delegate?.voiceRecorderDidResumeRecording(self)
        }
    }

    /// 停止录音
    public func stopRecording() async throws -> URL {
        guard isRecording else {
            throw VoiceRecorderError.noActiveRecording
        }

        do {
            // 停止录音并获取文件信息
            let (fileURL, _) = try await recordingManager.stopRecording()

            // 更新状态
            isRecording = false
            isPaused = false
            stopMonitoring()

            // 发送事件和回调
            let stopEvent = RecordingEvent.stopped(url: fileURL)
            await sendEvent(stopEvent)
            callbacks.onStop?(fileURL)
            delegate?.voiceRecorderDidStopRecording(self, fileURL: fileURL)

            return fileURL

        } catch let error as VoiceRecorderError {
            // 处理特殊错误（如录音时长过短）
            if case .recordingTooShort(_) = error {
                isRecording = false
                isPaused = false
                stopMonitoring()

                let belowMinEvent = RecordingEvent(type: .belowMinDuration, priority: .high)
                await sendEvent(belowMinEvent)
                callbacks.onError?(error)
                delegate?.voiceRecorder(self, didFailWithError: error)
            }

            await sendEvent(.error(error))
            throw error
        } catch {
            let recorderError = VoiceRecorderError.recordingFailed(error.localizedDescription)
            await sendEvent(.error(recorderError))
            throw recorderError
        }
    }

    /// 取消录音
    public func cancelRecording() async {
        guard isRecording else { return }

        await recordingManager.cancelRecording()

        // 更新状态
        isRecording = false
        isPaused = false
        stopMonitoring()

        // 发送事件和回调
        let cancelEvent = RecordingEvent(type: .cancelled, priority: .normal)
        await sendEvent(cancelEvent)
        callbacks.onCancel?()
        delegate?.voiceRecorderDidCancelRecording(self)
    }

    // MARK: - 便利录音方法

    /// 录音指定时长后自动停止
    public func recordFor(duration: TimeInterval) async throws -> URL {
        try await startRecording()

        return try await withThrowingTaskGroup(of: URL.self) { group in
            // 添加定时停止任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                return try await self.stopRecording()
            }

            // 添加错误监听任务
            group.addTask {
                for await event in await self.events {
                    if case .error(let error) = event.type {
                        throw error
                    }
                }
                throw VoiceRecorderError.cancelled
            }

            // 返回第一个完成的结果
            return try await group.next()!
        }
    }

    /// 录音直到满足指定条件
    public func recordUntil(_ condition: @escaping @Sendable () async -> Bool) async throws -> URL {
        try await startRecording()

        return try await withThrowingTaskGroup(of: URL.self) { group in
            // 添加条件检查任务
            group.addTask {
                while await !condition() {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms检查间隔
                }
                return try await self.stopRecording()
            }

            // 添加错误监听任务
            group.addTask {
                for await event in await self.events {
                    if case .error(let error) = event.type {
                        throw error
                    }
                }
                throw VoiceRecorderError.cancelled
            }

            // 返回第一个完成的结果
            return try await group.next()!
        }
    }

    // MARK: - 链式配置方法

    /// 配置录音器
    @discardableResult
    public func configure(_ block: (inout VoiceRecorderConfiguration) -> Void) -> Self {
        var config = configuration
        block(&config)
        configuration = config
        return self
    }

    // MARK: - 链式回调方法

    @discardableResult
    public func onStart(_ handler: @escaping () -> Void) -> Self {
        callbacks.onStart = handler
        return self
    }

    @discardableResult
    public func onPause(_ handler: @escaping () -> Void) -> Self {
        callbacks.onPause = handler
        return self
    }

    @discardableResult
    public func onResume(_ handler: @escaping () -> Void) -> Self {
        callbacks.onResume = handler
        return self
    }

    @discardableResult
    public func onStop(_ handler: @escaping (URL) -> Void) -> Self {
        callbacks.onStop = handler
        return self
    }

    @discardableResult
    public func onCancel(_ handler: @escaping () -> Void) -> Self {
        callbacks.onCancel = handler
        return self
    }

    @discardableResult
    public func onAudioLevel(_ handler: @escaping (Float) -> Void) -> Self {
        callbacks.onAudioLevel = handler
        return self
    }

    @discardableResult
    public func onDurationUpdate(_ handler: @escaping (TimeInterval) -> Void) -> Self {
        callbacks.onDurationUpdate = handler
        return self
    }

    @discardableResult
    public func onError(_ handler: @escaping (VoiceRecorderError) -> Void) -> Self {
        callbacks.onError = handler
        return self
    }

    @discardableResult
    public func onReachMaxDuration(_ handler: @escaping () -> Void) -> Self {
        callbacks.onReachMaxDuration = handler
        return self
    }

    // MARK: - 实时监控

    /// 开始监控
    private func startMonitoring() {
        startMeteringMonitoring()
        startDurationMonitoring()
        startMaxDurationMonitoring()
    }

    /// 停止监控
    private func stopMonitoring() {
        meteringTask?.cancel()
        durationTask?.cancel()
        maxDurationTask?.cancel()
        meteringTask = nil
        durationTask = nil
        maxDurationTask = nil
    }

    /// 开始音频级别监控
    private func startMeteringMonitoring() {
        guard configuration.enableMetering else { return }

        meteringTask = Task(priority: configuration.updatePriority.taskPriority) {
            while !Task.isCancelled && isRecording {
                let level = await recordingManager.getAudioLevel()
                let peak = await recordingManager.getPeakAudioLevel()

                audioLevel = level
                peakAudioLevel = peak

                // 发送事件和回调
                await sendEvent(.audioLevel(level))
                let peakEvent = RecordingEvent(type: .peakAudioLevel(peak), priority: .low)
                await sendEvent(peakEvent)
                callbacks.onAudioLevel?(level)
                delegate?.voiceRecorder(self, didUpdateAudioLevel: level)

                // 等待下一次更新
                try? await Task.sleep(nanoseconds: UInt64(configuration.meteringUpdateInterval * 1_000_000_000))
            }
        }
    }

    /// 开始时长监控
    private func startDurationMonitoring() {
        guard configuration.enableDurationUpdates else { return }

        durationTask = Task(priority: configuration.updatePriority.taskPriority) {
            while !Task.isCancelled && isRecording {
                let duration = await recordingManager.getCurrentDuration()
                currentDuration = duration

                // 更新统计信息
                stats = await recordingManager.getRecordingStats()

                // 发送事件和回调
                await sendEvent(.duration(duration))
                if let stats = stats {
                    let statsEvent = RecordingEvent(type: .statsUpdate(stats), priority: .low)
                    await sendEvent(statsEvent)
                }
                callbacks.onDurationUpdate?(duration)
                delegate?.voiceRecorder(self, didUpdateDuration: duration)

                // 等待下一次更新
                try? await Task.sleep(nanoseconds: UInt64(configuration.durationUpdateInterval * 1_000_000_000))
            }
        }
    }

    /// 开始最大时长监控
    private func startMaxDurationMonitoring() {
        guard let maxDuration = configuration.maximumDuration else { return }

        maxDurationTask = Task(priority: .high) {
            // 等待达到最大时长
            try? await Task.sleep(nanoseconds: UInt64(maxDuration * 1_000_000_000))

            // 检查是否仍在录音
            if isRecording && !Task.isCancelled {
                let maxDurationEvent = RecordingEvent(type: .reachedMaxDuration, priority: .high)
                await sendEvent(maxDurationEvent)
                callbacks.onReachMaxDuration?()
                delegate?.voiceRecorderDidReachMaximumDuration(self)

                if configuration.autoStopAtMaximum {
                    do {
                        _ = try await stopRecording()
                    } catch {
                        await sendEvent(.error(VoiceRecorderError.recordingFailed("自动停止失败")))
                    }
                }
            }
        }
    }

    // MARK: - 权限检查

    /// 检查麦克风权限
    public func checkMicrophonePermission() async -> Bool {
        #if os(iOS) || os(tvOS) || os(watchOS)
        return await withCheckedContinuation { continuation in
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                continuation.resume(returning: true)
            case .denied:
                continuation.resume(returning: false)
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            @unknown default:
                continuation.resume(returning: false)
            }
        }
        #else
        // macOS always return true for now
        return true
        #endif
    }

    /// 请求麦克风权限
    public func requestMicrophonePermission() async -> Bool {
        let granted = await checkMicrophonePermission()
        let permissionEvent = RecordingEvent(type: .permissionChanged(granted), priority: .high)
        await sendEvent(permissionEvent)
        return granted
    }

    // MARK: - 事件发送

    /// 发送事件
    private func sendEvent(_ event: RecordingEvent) async {
        eventContinuation?.yield(event)

        // 记录错误
        if case .error(let error) = event.type {
            lastError = error
        }
    }

    // MARK: - 状态查询

    /// 获取当前录音文件URL
    public func getCurrentFileURL() async -> URL? {
        return await recordingManager.getCurrentFileURL()
    }

    /// 获取当前录音统计
    public func getCurrentStats() async -> RecordingStats {
        return await recordingManager.getRecordingStats()
    }

    /// 获取存储统计
    public func getStorageStats() async throws -> StorageStats {
        return try await fileOperations.getStorageStats()
    }

    /// 获取录音文件列表
    public func getRecordingFiles() async throws -> [FileInfo] {
        return try await fileOperations.getRecordingFiles()
    }

    // MARK: - 文件操作

    /// 删除录音文件
    public func deleteRecording(at url: URL) async throws {
        try await fileOperations.deleteFile(at: url)

        let result = FileOperationResult(success: true, url: url, operationType: .delete)
        let event = RecordingEvent(type: .fileOperationCompleted(result), priority: .normal)
        await sendEvent(event)
    }

    /// 导出录音文件
    public func exportRecording(from sourceURL: URL, to targetURL: URL) async throws {
        let result = try await fileOperations.exportFile(from: sourceURL, to: targetURL)
        let event = RecordingEvent(type: .fileOperationCompleted(result), priority: .normal)
        await sendEvent(event)

        if !result.success, let error = result.error {
            throw error
        }
    }

    /// 清理旧录音文件
    public func cleanupOldRecordings() async throws {
        try await fileOperations.cleanupRecordingDirectory()

        let result = FileOperationResult(success: true, operationType: .cleanup)
        let event = RecordingEvent(type: .fileOperationCompleted(result), priority: .normal)
        await sendEvent(event)
    }

    // MARK: - 调试和监控

    /// 获取调试信息
    public func getDebugInfo() async -> [String: String] {
        var info: [String: String] = [:]
        info["configuration"] = configuration.description
        info["isRecording"] = String(isRecording)
        info["isPaused"] = String(isPaused)
        info["currentDuration"] = String(currentDuration)
        info["audioLevel"] = String(audioLevel)
        return info
    }

    /// 获取性能指标
    public func getPerformanceMetrics() async -> [String: String] {
        return [
            "memoryUsage": "0",
            "cpuUsage": "0.0",
            "updateInterval": String(configuration.meteringUpdateInterval)
        ]
    }
}

// MARK: - 链式回调存储

/// 链式回调存储结构
struct VoiceRecorderCallbacks {
    var onStart: (() -> Void)?
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    var onStop: ((URL) -> Void)?
    var onCancel: (() -> Void)?
    var onAudioLevel: ((Float) -> Void)?
    var onDurationUpdate: ((TimeInterval) -> Void)?
    var onError: ((VoiceRecorderError) -> Void)?
    var onReachMaxDuration: (() -> Void)?
}

// MARK: - 委托协议

/// 语音录制器委托协议
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public protocol VoiceRecorderDelegate: AnyObject {
    /// 录音开始
    func voiceRecorderDidStartRecording(_ recorder: VoiceRecorder)

    /// 录音暂停
    func voiceRecorderDidPauseRecording(_ recorder: VoiceRecorder)

    /// 录音恢复
    func voiceRecorderDidResumeRecording(_ recorder: VoiceRecorder)

    /// 录音停止
    func voiceRecorderDidStopRecording(_ recorder: VoiceRecorder, fileURL: URL)

    /// 录音取消
    func voiceRecorderDidCancelRecording(_ recorder: VoiceRecorder)

    /// 音频级别更新
    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateAudioLevel level: Float)

    /// 录音时长更新
    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateDuration duration: TimeInterval)

    /// 发生错误
    func voiceRecorder(_ recorder: VoiceRecorder, didFailWithError error: VoiceRecorderError)

    /// 达到最大录音时长
    func voiceRecorderDidReachMaximumDuration(_ recorder: VoiceRecorder)
}

// MARK: - 委托协议默认实现

@available(iOS 13.0, macOS 10.15, *)
public extension VoiceRecorderDelegate {
    func voiceRecorderDidStartRecording(_ recorder: VoiceRecorder) {}
    func voiceRecorderDidPauseRecording(_ recorder: VoiceRecorder) {}
    func voiceRecorderDidResumeRecording(_ recorder: VoiceRecorder) {}
    func voiceRecorderDidStopRecording(_ recorder: VoiceRecorder, fileURL: URL) {}
    func voiceRecorderDidCancelRecording(_ recorder: VoiceRecorder) {}
    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateAudioLevel level: Float) {}
    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateDuration duration: TimeInterval) {}
    func voiceRecorder(_ recorder: VoiceRecorder, didFailWithError error: VoiceRecorderError) {}
    func voiceRecorderDidReachMaximumDuration(_ recorder: VoiceRecorder) {}
}
