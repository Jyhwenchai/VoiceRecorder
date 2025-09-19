import XCTest
@testable import VoiceRecorder

/// 语音录制器单元测试
final class VoiceRecorderTests: XCTestCase {

    var recorder: VoiceRecorder!
    var testConfiguration: VoiceRecorderConfiguration!

    override func setUp() async throws {
        try await super.setUp()

        // 创建测试配置
        testConfiguration = VoiceRecorderConfiguration()
        testConfiguration.audioFormat = .wav
        testConfiguration.audioQuality = .medium
        testConfiguration.minimumDuration = 0.1
        testConfiguration.maximumDuration = 5.0
        testConfiguration.numberOfChannels = 1
        testConfiguration.enableMetering = true
        testConfiguration.meteringUpdateInterval = 0.1

        recorder = VoiceRecorder(configuration: testConfiguration)
    }

    override func tearDown() async throws {
        // 清理录音状态
        if recorder.isRecording {
            await recorder.cancelRecording()
        }

        recorder = nil
        testConfiguration = nil

        try await super.tearDown()
    }

    // MARK: - 基础功能测试

    func testRecorderInitialization() {
        XCTAssertNotNil(recorder)
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(recorder.isPaused)
        XCTAssertEqual(recorder.currentDuration, 0)
        XCTAssertEqual(recorder.audioLevel, 0)
    }

    func testConfigurationUpdate() {
        var newConfig = VoiceRecorderConfiguration()
        newConfig.audioFormat = .m4a
        newConfig.minimumDuration = 2.0

        recorder.configuration = newConfig

        XCTAssertEqual(recorder.configuration.audioFormat, .m4a)
        XCTAssertEqual(recorder.configuration.minimumDuration, 2.0)
    }

    // MARK: - 录音控制测试

    func testStartAndStopRecording() async throws {
        // 开始录音
        try await recorder.startRecording()
        XCTAssertTrue(recorder.isRecording)
        XCTAssertFalse(recorder.isPaused)

        // 等待一段时间
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

        // 停止录音
        let url = try await recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(recorder.isPaused)
        XCTAssertNotNil(url)

        // 验证文件存在
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        // 清理测试文件
        try? FileManager.default.removeItem(at: url)
    }

    func testPauseAndResumeRecording() async throws {
        // 开始录音
        try await recorder.startRecording()
        XCTAssertTrue(recorder.isRecording)

        // 暂停录音
        await recorder.pauseRecording()
        XCTAssertTrue(recorder.isPaused)

        // 恢复录音
        await recorder.resumeRecording()
        XCTAssertFalse(recorder.isPaused)
        XCTAssertTrue(recorder.isRecording)

        // 停止录音
        let url = try await recorder.stopRecording()
        XCTAssertNotNil(url)

        // 清理测试文件
        try? FileManager.default.removeItem(at: url)
    }

    func testCancelRecording() async throws {
        // 开始录音
        try await recorder.startRecording()
        XCTAssertTrue(recorder.isRecording)

        // 取消录音
        await recorder.cancelRecording()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(recorder.isPaused)
    }

    // MARK: - 最短录音时长测试

    func testMinimumDurationValidation() async throws {
        // 设置较长的最短时长
        var config = testConfiguration!
        config.minimumDuration = 2.0
        config.autoStopBelowMinimum = true
        recorder.configuration = config

        // 开始录音
        try await recorder.startRecording()

        // 很快停止录音（低于最短时长）
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

        // 应该抛出 recordingTooShort 错误
        do {
            _ = try await recorder.stopRecording()
            XCTFail("应该抛出 recordingTooShort 错误")
        } catch VoiceRecorderError.recordingTooShort(let duration) {
            XCTAssertLessThan(duration, 2.0)
        } catch {
            XCTFail("错误类型不正确: \(error)")
        }
    }

    // MARK: - 录音时长测试

    func testRecordForDuration() async throws {
        let targetDuration: TimeInterval = 1.0

        let url = try await recorder.recordFor(duration: targetDuration)
        XCTAssertNotNil(url)

        // 验证录音时长接近目标时长（允许误差）
        let actualDuration = await recorder.getCurrentStats().duration
        XCTAssertEqual(actualDuration, targetDuration, accuracy: 0.2)

        // 清理测试文件
        try? FileManager.default.removeItem(at: url)
    }

    func testRecordUntilCondition() async throws {
        var shouldStop = false

        // 1秒后设置停止条件
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            shouldStop = true
        }

        let url = try await recorder.recordUntil {
            return shouldStop
        }

        XCTAssertNotNil(url)

        // 清理测试文件
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 事件流测试

    func testEventStream() async throws {
        var events: [RecordingEvent] = []
        let eventExpectation = expectation(description: "接收到录音事件")

        // 监听事件流
        let eventTask = Task {
            var eventCount = 0
            for await event in recorder.events {
                events.append(event)
                eventCount += 1

                // 收到足够的事件后完成测试
                if eventCount >= 3 {
                    eventExpectation.fulfill()
                    break
                }
            }
        }

        // 开始录音
        try await recorder.startRecording()

        // 等待事件
        try await Task.sleep(nanoseconds: 500_000_000)

        // 停止录音
        let url = try await recorder.stopRecording()

        // 等待事件处理完成
        await fulfillment(of: [eventExpectation], timeout: 2.0)

        eventTask.cancel()

        // 验证事件
        XCTAssertFalse(events.isEmpty)
        let hasStartEvent = events.contains { event in
            if case .started = event.type { return true }
            return false
        }
        XCTAssertTrue(hasStartEvent)

        // 清理测试文件
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 链式回调测试

    func testChainedCallbacks() async throws {
        var startCalled = false
        var stopCalled = false
        var durationCalled = false

        let stopExpectation = expectation(description: "停止回调被调用")

        recorder = recorder
            .onStart {
                startCalled = true
            }
            .onDurationUpdate { _ in
                durationCalled = true
            }
            .onStop { _ in
                stopCalled = true
                stopExpectation.fulfill()
            }

        // 开始录音
        try await recorder.startRecording()
        XCTAssertTrue(startCalled)

        // 等待一段时间
        try await Task.sleep(nanoseconds: 300_000_000)

        // 停止录音
        let url = try await recorder.stopRecording()

        // 等待回调完成
        await fulfillment(of: [stopExpectation], timeout: 1.0)

        XCTAssertTrue(stopCalled)
        XCTAssertTrue(durationCalled)

        // 清理测试文件
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 错误处理测试

    func testRecordingInProgressError() async throws {
        // 开始第一个录音
        try await recorder.startRecording()

        // 尝试开始第二个录音，应该失败
        do {
            try await recorder.startRecording()
            XCTFail("应该抛出 recordingInProgress 错误")
        } catch VoiceRecorderError.recordingInProgress {
            // 预期的错误
        } catch {
            XCTFail("错误类型不正确: \(error)")
        }

        // 清理
        await recorder.cancelRecording()
    }

    func testNoActiveRecordingError() async throws {
        // 在没有录音时尝试停止
        do {
            _ = try await recorder.stopRecording()
            XCTFail("应该抛出 noActiveRecording 错误")
        } catch VoiceRecorderError.noActiveRecording {
            // 预期的错误
        } catch {
            XCTFail("错误类型不正确: \(error)")
        }
    }

    // MARK: - 配置验证测试

    func testConfigurationValidation() {
        var config = VoiceRecorderConfiguration()

        // 有效配置
        XCTAssertTrue(config.isValid)
        XCTAssertTrue(config.validationErrors.isEmpty)

        // 无效配置 - 声道数
        config.numberOfChannels = 0
        XCTAssertFalse(config.isValid)
        XCTAssertFalse(config.validationErrors.isEmpty)

        // 修复配置
        config.numberOfChannels = 1
        XCTAssertTrue(config.isValid)

        // 无效配置 - 时长设置
        config.minimumDuration = 10.0
        config.maximumDuration = 5.0 // 最大时长小于最小时长
        XCTAssertFalse(config.isValid)
    }

    // MARK: - 音频格式测试

    func testAudioFormatSupport() {
        let formats: [AudioFormat] = [.m4a, .wav, .caf, .mp3, .aac]

        for format in formats {
            XCTAssertTrue(AudioFormatUtility.isFormatSupported(format))
            XCTAssertFalse(format.fileExtension.isEmpty)
            XCTAssertNotEqual(format.formatID, 0)
        }
    }

    func testAudioQualitySettings() {
        let qualities: [AudioQuality] = [.min, .low, .medium, .high, .max]

        for quality in qualities {
            XCTAssertGreaterThan(quality.sampleRate, 0)
            XCTAssertGreaterThan(quality.bitDepth, 0)
        }
    }

    // MARK: - 文件大小估算测试

    func testFileSizeEstimation() {
        let duration: TimeInterval = 60 // 1分钟
        let format = AudioFormat.wav
        let quality = AudioQuality.high

        let estimatedSize = AudioFormatUtility.estimateFileSize(
            format: format,
            quality: quality,
            duration: duration,
            numberOfChannels: 2
        )

        XCTAssertGreaterThan(estimatedSize, 0)

        // WAV 文件应该比压缩格式大
        let compressedSize = AudioFormatUtility.estimateFileSize(
            format: .m4a,
            quality: quality,
            duration: duration,
            numberOfChannels: 2
        )

        XCTAssertGreaterThan(estimatedSize, compressedSize)
    }

    // MARK: - 性能测试

    func testRecordingPerformance() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 执行录音操作
        try await recorder.startRecording()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        let url = try await recorder.stopRecording()

        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime

        // 录音操作应该在合理时间内完成
        XCTAssertLessThan(executionTime, 2.0) // 2秒内完成

        // 清理测试文件
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 并发测试

    func testConcurrentOperations() async throws {
        // 测试并发录音操作不会导致竞态条件
        await withTaskGroup(of: Void.self) { group in
            // 添加多个并发任务
            for _ in 0..<10 {
                group.addTask {
                    do {
                        try await self.recorder.startRecording()
                        try await Task.sleep(nanoseconds: 50_000_000) // 0.05秒
                        _ = try await self.recorder.stopRecording()
                    } catch {
                        // 大部分操作会因为录音正在进行而失败，这是预期的
                    }
                }
            }
        }

        // 确保最终状态正确
        XCTAssertFalse(recorder.isRecording)
    }

    // MARK: - 内存泄漏测试

    func testMemoryLeaks() async throws {
        weak var weakRecorder: VoiceRecorder?

        autoreleasepool {
            let testRecorder = VoiceRecorder(configuration: testConfiguration)
            weakRecorder = testRecorder

            Task {
                try? await testRecorder.startRecording()
                try? await Task.sleep(nanoseconds: 100_000_000)
                await testRecorder.cancelRecording()
            }
        }

        // 给一点时间让对象释放
        try await Task.sleep(nanoseconds: 100_000_000)

        // 录音器应该被释放
        XCTAssertNil(weakRecorder, "VoiceRecorder 应该被释放，检查是否有内存泄漏")
    }
}

// MARK: - 文件操作测试

final class FileOperationsTests: XCTestCase {

    var fileOperations: FileOperationsActor!
    var testConfig: VoiceRecorderConfiguration!

    override func setUp() async throws {
        testConfig = VoiceRecorderConfiguration()
        testConfig.fileNamePrefix = "test_recording"
        testConfig.autoGenerateFileName = true
        fileOperations = FileOperationsActor(configuration: testConfig)
    }

    override func tearDown() async throws {
        fileOperations = nil
        testConfig = nil
    }

    func testPrepareRecordingURL() async throws {
        let url = try await fileOperations.prepareRecordingURL()

        XCTAssertNotNil(url)
        XCTAssertTrue(url.lastPathComponent.hasPrefix("test_recording"))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".m4a"))
    }

    func testFileExistence() async throws {
        let url = try await fileOperations.prepareRecordingURL()

        // 文件应该不存在
        let exists = await fileOperations.fileExists(at: url)
        XCTAssertFalse(exists)

        // 创建文件
        try "test content".write(to: url, atomically: true, encoding: .utf8)

        // 现在文件应该存在
        let existsNow = await fileOperations.fileExists(at: url)
        XCTAssertTrue(existsNow)

        // 清理
        try await fileOperations.deleteFile(at: url)
    }

    func testFileInfo() async throws {
        let url = try await fileOperations.prepareRecordingURL()
        let testContent = "test content for file info"

        // 创建测试文件
        try testContent.write(to: url, atomically: true, encoding: .utf8)

        // 获取文件信息
        let fileInfo = try await fileOperations.getFileInfo(at: url)

        XCTAssertEqual(fileInfo.url, url)
        XCTAssertGreaterThan(fileInfo.size, 0)
        XCTAssertEqual(fileInfo.fileName, url.lastPathComponent)

        // 清理
        try await fileOperations.deleteFile(at: url)
    }
}

// MARK: - 错误处理测试

final class ErrorHandlingTests: XCTestCase {

    func testVoiceRecorderError() {
        let error = VoiceRecorderError.recordingTooShort(1.5)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.failureReason)
        XCTAssertNotNil(error.recoverySuggestion)

        // 测试错误严重级别
        XCTAssertEqual(error.severity, .low)
        XCTAssertFalse(error.requiresUserAction)
    }

    func testErrorHandler() {
        let error = VoiceRecorderError.microphonePermissionDenied
        let result = ErrorHandler.handleRecordingError(error)

        XCTAssertEqual(result.title, "需要麦克风权限")
        XCTAssertNotNil(result.message)
        XCTAssertEqual(result.actionTitle, "去设置")
    }
}

// MARK: - 事件系统测试

final class EventSystemTests: XCTestCase {

    func testRecordingEvent() {
        let event = RecordingEvent.started()

        XCTAssertEqual(event.source, .recorder)
        XCTAssertEqual(event.priority, .high)
        XCTAssertNotNil(event.timestamp)

        if case .started = event.type {
            // 正确的事件类型
        } else {
            XCTFail("事件类型不正确")
        }
    }

    func testEventFilter() {
        let filter = EventFilter(
            types: [.recording],
            minimumPriority: .normal
        )

        let startEvent = RecordingEvent.started() // high priority, recording type
        let levelEvent = RecordingEvent.audioLevel(0.5) // low priority, monitoring type

        XCTAssertTrue(filter.matches(startEvent))
        XCTAssertFalse(filter.matches(levelEvent)) // 优先级太低
    }

    func testEventStatistics() {
        let events = [
            RecordingEvent.started(),
            RecordingEvent.audioLevel(0.5),
            RecordingEvent.duration(1.0),
            RecordingEvent.stopped(url: URL(fileURLWithPath: "/test.m4a"))
        ]

        let stats = EventStatistics(events: events)

        XCTAssertEqual(stats.totalEvents, 4)
        XCTAssertGreaterThan(stats.eventsByType.count, 0)
        XCTAssertGreaterThan(stats.averageEventsPerMinute, 0)
    }
}

// MARK: - 配置测试

final class ConfigurationTests: XCTestCase {

    func testPresetConfigurations() {
        let configs = [
            VoiceRecorderConfiguration.default,
            VoiceRecorderConfiguration.highQuality,
            VoiceRecorderConfiguration.lowLatency,
            VoiceRecorderConfiguration.longRecording,
            VoiceRecorderConfiguration.voiceMemo,
            VoiceRecorderConfiguration.podcast,
            VoiceRecorderConfiguration.music,
            VoiceRecorderConfiguration.spaceEfficient
        ]

        for config in configs {
            XCTAssertTrue(config.isValid, "配置 \(config) 应该是有效的")
        }
    }

    func testConfigurationEquality() {
        let config1 = VoiceRecorderConfiguration.default
        let config2 = VoiceRecorderConfiguration.default

        XCTAssertEqual(config1, config2)

        var config3 = config1
        config3.audioFormat = .wav

        XCTAssertNotEqual(config1, config3)
    }

    func testCustomAudioQuality() {
        let customQuality = CustomAudioQuality(
            sampleRate: 48000,
            bitDepth: 24,
            bitRate: 192
        )

        XCTAssertTrue(customQuality.isValid)
        XCTAssertEqual(customQuality.sampleRate, 48000)
        XCTAssertEqual(customQuality.bitDepth, 24)
        XCTAssertEqual(customQuality.bitRate, 192)
    }
}
