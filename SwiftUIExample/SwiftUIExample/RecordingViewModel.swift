//
//  RecordingViewModel.swift
//  SwiftUIExample
//
//  Created by Claude on 2025/9/19.
//

import SwiftUI
import Combine
import VoiceRecorder
import AVFoundation

@MainActor
class RecordingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 是否正在录音
    @Published var isRecording = false

    /// 是否已暂停
    @Published var isPaused = false

    /// 当前录音时长
    @Published var currentDuration: TimeInterval = 0

    /// 音频电平 (0.0-1.0)
    @Published var audioLevel: Float = 0

    /// 峰值音频电平 (0.0-1.0)
    @Published var peakAudioLevel: Float = 0

    /// 是否有麦克风权限
    @Published var hasMicrophonePermission = false

    /// 当前配置
    @Published var currentConfiguration: VoiceRecorderConfiguration = .default

    /// 录音文件列表
    @Published var recordingFiles: [RecordingFile] = []

    /// 是否显示错误提示
    @Published var showError = false

    /// 错误信息
    @Published var errorMessage = ""

    /// 是否显示成功提示
    @Published var showSuccess = false

    /// 成功信息
    @Published var successMessage = ""

    /// 音频电平历史（用于波形显示）
    @Published var audioLevelHistory: [Float] = Array(repeating: 0, count: 50)

    // MARK: - Private Properties

    var recorder: VoiceRecorder
    private var eventTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Initialize recorder first
        let defaultConfig = VoiceRecorderConfiguration.default
        self.recorder = VoiceRecorder(configuration: defaultConfig)

        // Set current configuration after recorder is initialized
        self.currentConfiguration = defaultConfig

        setupRecorder()
        checkMicrophonePermission()

        // Load files asynchronously after initialization
        Task {
            await loadRecordingFiles()
        }
    }

    deinit {
        eventTask?.cancel()
    }

    // MARK: - Setup

    private func setupRecorder() {
        // 监听录音器的状态变化
        recorder.$isRecording
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)

        recorder.$isPaused
            .assign(to: \.isPaused, on: self)
            .store(in: &cancellables)

        recorder.$currentDuration
            .assign(to: \.currentDuration, on: self)
            .store(in: &cancellables)

        recorder.$audioLevel
            .sink { [weak self] level in
                self?.updateAudioLevel(level)
            }
            .store(in: &cancellables)

        recorder.$peakAudioLevel
            .assign(to: \.peakAudioLevel, on: self)
            .store(in: &cancellables)

        // 监听事件流
        eventTask = Task {
            for await event in recorder.events {
                await handleRecordingEvent(event)
            }
        }
    }

    private func updateAudioLevel(_ level: Float) {
        audioLevel = level

        // 更新音频电平历史
        audioLevelHistory.removeFirst()
        audioLevelHistory.append(level)
    }

    // MARK: - Recording Control

    func startRecording() async {
        do {
            try await recorder.startRecording()
        } catch {
            handleError(error)
        }
    }

    func stopRecording() async {
        do {
            let fileURL = try await recorder.stopRecording()
            showSuccessMessage("录音已保存到: \(fileURL.lastPathComponent)")
            await loadRecordingFiles()
        } catch {
            handleError(error)
        }
    }

    func pauseRecording() async {
        await recorder.pauseRecording()
    }

    func resumeRecording() async {
        await recorder.resumeRecording()
    }

    func cancelRecording() async {
        await recorder.cancelRecording()
        resetAudioLevel()
    }

    private func resetAudioLevel() {
        audioLevel = 0
        peakAudioLevel = 0
        audioLevelHistory = Array(repeating: 0, count: 50)
    }

    // MARK: - Configuration

    func updateConfiguration(_ config: VoiceRecorderConfiguration) {
        currentConfiguration = config
        recorder.configuration = config
    }

    func usePresetConfiguration(_ preset: ConfigurationPreset) {
        let config: VoiceRecorderConfiguration

        switch preset {
        case .default:
            config = .default
        case .highQuality:
            config = .highQuality
        case .voiceMemo:
            config = .voiceMemo
        case .podcast:
            config = .podcast
        case .music:
            config = .music
        }

        updateConfiguration(config)
    }

    // MARK: - File Management

    func loadRecordingFiles() async {
        do {
            let files = try await recorder.getRecordingFiles()
            recordingFiles = files.map { fileInfo in
                RecordingFile(
                    id: fileInfo.url.lastPathComponent,
                    name: fileInfo.url.lastPathComponent,
                    url: fileInfo.url,
                    createdAt: fileInfo.creationDate,
                    size: fileInfo.size,
                    duration: nil // Duration will need to be calculated separately
                )
            }.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("加载录音文件失败: \(error)")
        }
    }

    func deleteRecording(_ file: RecordingFile) async {
        do {
            try await recorder.deleteRecording(at: file.url)
            await loadRecordingFiles()
            showSuccessMessage("录音文件已删除")
        } catch {
            handleError(error)
        }
    }

    func exportRecording(_ file: RecordingFile, to targetURL: URL) async {
        do {
            try await recorder.exportRecording(from: file.url, to: targetURL)
            showSuccessMessage("录音文件已导出")
        } catch {
            handleError(error)
        }
    }

    func shareRecording(_ file: RecordingFile) -> URL {
        return file.url
    }

    // MARK: - Permissions

    func checkMicrophonePermission() {
        Task {
            let granted = await recorder.checkMicrophonePermission()
            hasMicrophonePermission = granted
        }
    }

    func requestMicrophonePermission() async {
        let granted = await recorder.requestMicrophonePermission()
        hasMicrophonePermission = granted

        if !granted {
            showErrorMessage("需要麦克风权限才能录音，请在设置中允许应用使用麦克风")
        }
    }

    // MARK: - Event Handling

    private func handleRecordingEvent(_ event: RecordingEvent) async {
        switch event.type {
        case .started:
            print("录音开始")

        case .stopped(let url):
            print("录音停止: \(url)")

        case .paused:
            print("录音暂停")

        case .resumed:
            print("录音恢复")

        case .cancelled:
            print("录音取消")
            resetAudioLevel()

        case .error(let error):
            handleError(error)

        case .reachedMaxDuration:
            showSuccessMessage("已达到最大录音时长，录音已自动停止")
            await loadRecordingFiles()

        case .audioLevel(_), .peakAudioLevel(_), .duration(_):
            // 这些事件通过 Combine 处理
            break

        default:
            break
        }
    }

    // MARK: - Utility Methods

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func handleError(_ error: Error) {
        if let recorderError = error as? VoiceRecorderError {
            let errorInfo = ErrorHandler.handleRecordingError(recorderError)
            showErrorMessage(errorInfo.message)
        } else {
            showErrorMessage(error.localizedDescription)
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }
}

// MARK: - Supporting Types

/// 录音文件模型
struct RecordingFile: Identifiable, Equatable {
    let id: String
    let name: String
    let url: URL
    let createdAt: Date
    let size: UInt64
    let duration: TimeInterval?
}

/// 配置预设
enum ConfigurationPreset: String, CaseIterable {
    case `default` = "default"
    case highQuality = "highQuality"
    case voiceMemo = "voiceMemo"
    case podcast = "podcast"
    case music = "music"

    var displayName: String {
        switch self {
        case .default:
            return "默认"
        case .highQuality:
            return "高质量"
        case .voiceMemo:
            return "语音备忘"
        case .podcast:
            return "播客"
        case .music:
            return "音乐"
        }
    }

    var description: String {
        switch self {
        case .default:
            return "平衡质量和文件大小"
        case .highQuality:
            return "专业录音质量"
        case .voiceMemo:
            return "适合语音备忘录"
        case .podcast:
            return "适合播客录制"
        case .music:
            return "音乐录制专用"
        }
    }
}