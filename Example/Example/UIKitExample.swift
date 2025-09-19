import UIKit
import VoiceRecorder
import AVFoundation

/// UIKit 录音应用示例
class UIKitExampleViewController: UIViewController {

    // MARK: - UI 组件

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "准备就绪"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.textAlignment = .center
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var levelProgressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progress = 0
        progressView.progressTintColor = .systemBlue
        progressView.translatesAutoresizingMaskIntoConstraints = false
        return progressView
    }()

    private lazy var levelLabel: UILabel = {
        let label = UILabel()
        label.text = "0%"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var recordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("录音", for: .normal)
        button.setTitle("停止", for: .selected)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        button.layer.cornerRadius = 35
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var pauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("暂停", for: .normal)
        button.setTitle("继续", for: .selected)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消", for: .normal)
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - 属性

    private var recorder: VoiceRecorder!
    private var eventTask: Task<Void, Never>?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupRecorder()
    }

    deinit {
        eventTask?.cancel()
    }

    // MARK: - UI 设置

    private func setupUI() {
        title = "语音录制器"
        view.backgroundColor = .systemBackground

        setupViews()
        setupConstraints()
    }

    private func setupViews() {
        view.addSubview(statusLabel)
        view.addSubview(durationLabel)
        view.addSubview(levelProgressView)
        view.addSubview(levelLabel)
        view.addSubview(recordButton)
        view.addSubview(pauseButton)
        view.addSubview(cancelButton)
        view.addSubview(activityIndicator)
    }

    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 40),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Duration Label
            durationLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 30),
            durationLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            durationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Level Progress View
            levelProgressView.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 40),
            levelProgressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            levelProgressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            levelProgressView.heightAnchor.constraint(equalToConstant: 4),

            // Level Label
            levelLabel.topAnchor.constraint(equalTo: levelProgressView.bottomAnchor, constant: 8),
            levelLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            levelLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Record Button
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 60),
            recordButton.widthAnchor.constraint(equalToConstant: 70),
            recordButton.heightAnchor.constraint(equalToConstant: 70),

            // Pause Button
            pauseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            pauseButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -10),
            pauseButton.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 30),
            pauseButton.heightAnchor.constraint(equalToConstant: 44),

            // Cancel Button
            cancelButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            cancelButton.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 30),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),

            // Activity Indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 30)
        ])
    }

    private func setupRecorder() {
        var configuration = VoiceRecorderConfiguration.default
        configuration.enableMetering = true
        configuration.meteringUpdateInterval = 0.1
        configuration.maximumDuration = 300 // 5分钟

        recorder = VoiceRecorder(configuration: configuration)
        recorder.delegate = self

        // 监听事件流
        eventTask = Task {
            for await event in recorder.events {
                await handleRecordingEvent(event)
            }
        }
    }

    // MARK: - 按钮动作

    @objc private func recordButtonTapped() {
        Task {
            do {
                if recorder.isRecording {
                    let fileURL = try await recorder.stopRecording()
                    print("录音完成: \(fileURL)")
                } else {
                    // 检查权限
                    guard await checkMicrophonePermission() else {
                        showAlert(title: "需要麦克风权限", message: "请在设置中允许访问麦克风")
                        return
                    }

                    try await recorder.startRecording()
                }
            } catch {
                showError(error)
            }
        }
    }

    @objc private func pauseButtonTapped() {
        Task {
            if recorder.isPaused {
                await recorder.resumeRecording()
            } else {
                await recorder.pauseRecording()
            }
        }
    }

    @objc private func cancelButtonTapped() {
        Task {
            await recorder.cancelRecording()
        }
    }

    // MARK: - 辅助方法

    private func checkMicrophonePermission() async -> Bool {
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
    }

    private func getOutputURL() -> URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        return documentDirectory.appendingPathComponent(fileName)
    }

    private func updateUI() {
        statusLabel.text = getStatusText()
        durationLabel.text = formatDuration(recorder.currentDuration)
        levelLabel.text = "\(Int(recorder.audioLevel * 100))%"
        levelProgressView.progress = recorder.audioLevel

        recordButton.isSelected = recorder.isRecording
        pauseButton.isEnabled = recorder.isRecording || recorder.isPaused
        pauseButton.isSelected = recorder.isPaused
        cancelButton.isEnabled = recorder.isRecording || recorder.isPaused

        if recorder.isRecording {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    private func getStatusText() -> String {
        if recorder.isRecording {
            return recorder.isPaused ? "已暂停" : "录音中..."
        } else {
            return "准备就绪"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func showError(_ error: Error) {
        let recorderError = error as? VoiceRecorderError ?? VoiceRecorderError.recordingFailed(error.localizedDescription)
        let errorInfo = ErrorHandler.handleRecordingError(recorderError)
        showAlert(title: errorInfo.title, message: errorInfo.message)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 事件处理

    private func handleRecordingEvent(_ event: RecordingEvent) async {
        switch event.type {
        case .started:
            print("录音开始")
        case .paused:
            print("录音暂停")
        case .resumed:
            print("录音恢复")
        case .stopped(let fileURL):
            print("录音停止: \(fileURL)")
        case .cancelled:
            print("录音取消")
        case .audioLevel(let level):
            // 音频级别在 UI 更新中处理
          print("current level: \(level)")
        case .peakAudioLevel(let level):
          print("current peak: \(level)")
        case .duration(_):
            // 时长在 UI 更新中处理
            break
        case .error(let error):
            showError(error)
        case .reachedMaxDuration:
            showAlert(title: "录音完成", message: "已达到最大录音时长")
        default:
            break
        }

        updateUI()
    }
}

// MARK: - VoiceRecorderDelegate

extension UIKitExampleViewController: VoiceRecorderDelegate {
    func voiceRecorderDidStartRecording(_ recorder: VoiceRecorder) {
        updateUI()
    }

    func voiceRecorderDidPauseRecording(_ recorder: VoiceRecorder) {
        updateUI()
    }

    func voiceRecorderDidResumeRecording(_ recorder: VoiceRecorder) {
        updateUI()
    }

    func voiceRecorderDidStopRecording(_ recorder: VoiceRecorder, fileURL: URL) {
        updateUI()
        showAlert(title: "录音完成", message: "文件已保存到: \(fileURL.lastPathComponent)")
    }

    func voiceRecorderDidCancelRecording(_ recorder: VoiceRecorder) {
        updateUI()
    }

    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateAudioLevel level: Float) {
        // 由 updateUI 统一处理
    }

    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateDuration duration: TimeInterval) {
        // 由 updateUI 统一处理
    }

    func voiceRecorder(_ recorder: VoiceRecorder, didFailWithError error: VoiceRecorderError) {
        showError(error)
    }

    func voiceRecorderDidReachMaximumDuration(_ recorder: VoiceRecorder) {
        Task {
            do {
                _ = try await recorder.stopRecording()
            } catch {
                showError(error)
            }
        }
    }
}

// MARK: - 简化版录音示例

/// 最简化的录音示例类
@MainActor
class SimpleRecordingExample {
    private let recorder = VoiceRecorder()

    func startSimpleRecording() async throws {
        try await recorder.startRecording()
    }

    func stopSimpleRecording() async throws -> URL {
        return try await recorder.stopRecording()
    }

    private func getOutputURL() -> URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentDirectory.appendingPathComponent("simple_recording.m4a")
    }
}

// MARK: - 链式调用示例

/// 展示链式调用 API 的示例类
@MainActor
class ChainedCallExample {
    private let recorder = VoiceRecorder()

    func demonstrateChainedCalls() {
        // 链式调用示例已被移除，因为当前 API 不支持
        print("链式调用示例当前不可用")
    }
}
