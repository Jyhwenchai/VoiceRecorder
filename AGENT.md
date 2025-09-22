# 语音录制库实施方案 - 实现状态更新

## 项目概述
- **平台**: iOS 13+ (iOS 15+ 推荐，完整 Swift Concurrency 支持) ✅ **已实现**
- **开发语言**: Swift 5.5+ ✅ **已实现**
- **核心框架**: AVFoundation ✅ **已实现**
- **并发模型**: Swift Concurrency (async/await, Actor) ✅ **已实现**
- **包管理**: Swift Package Manager ✅ **已实现**

## 核心功能需求

### 1. 录音功能 ✅ **全部实现**
- 开始/停止连续录音 ✅
- 暂停/恢复录音 ✅
- 取消录音（不保存） ✅
- 保存到缓存或自定义目录 ✅
- **最短有效录制时长**（低于此时长自动取消） ✅
- 最大录音时长限制 ✅
- 实时录音时长跟踪 ✅

### 2. 回调机制（三种方案） ✅ **全部实现**
- **链式闭包方式**：现代化函数式编程风格（推荐） ✅
- **协议委托方式**：传统 iOS 开发模式（可选） ✅
- **AsyncStream**：Swift Concurrency 原生支持 ✅
- 录音状态变化回调 ✅
- 实时音频分贝级别 ✅
- 实时录音时长更新 ✅
- 文件保存完成回调 ✅
- 错误处理回调 ✅

### 3. 配置选项 ✅ **全部实现**
- 音频格式（m4a、wav、caf、mp3、aac） ✅
- 音频质量设置 ✅
- 采样率配置 ✅
- 声道数（单声道/立体声） ✅
- 比特率配置 ✅
- **最短有效录制时长** ✅
- 最大录音时长 ✅
- 自定义保存目录 ✅
- 文件命名规则 ✅ (支持5种模式：timestampSuffix、timestampPrefix、dateTimeSuffix、sequentialNumber、uuid)
- 音频级别更新频率 ✅
- 时长更新频率 ✅

## Swift Concurrency 架构设计

### 使用 Actor 保证线程安全
```swift
// 使用 Actor 管理录音状态，确保线程安全
actor VoiceRecorderActor {
    private var audioRecorder: AVAudioRecorder?
    private var recordingState: RecordingState = .idle
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0

    func startRecording(with settings: [String: Any], url: URL) async throws {
        // Actor 内部自动序列化访问
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()
        recordingState = .recording
        startTime = Date()
    }

    func stopRecording() async -> (URL?, TimeInterval) {
        let duration = calculateDuration()
        audioRecorder?.stop()
        recordingState = .idle
        return (audioRecorder?.url, duration)
    }

    nonisolated func calculateDuration() -> TimeInterval {
        // nonisolated 方法可以同步调用
        guard let startTime = startTime else { return 0 }
        return Date().timeIntervalSince(startTime) - pausedDuration
    }
}
```

### 使用 MainActor 处理 UI 更新
```swift
@MainActor
public class VoiceRecorder: ObservableObject {
    private let recorder = VoiceRecorderActor()
    private var meteringTask: Task<Void, Never>?
    private var durationTask: Task<Void, Never>?

    // 发布的属性自动在主线程更新
    @Published public private(set) var isRecording = false
    @Published public private(set) var isPaused = false
    @Published public private(set) var currentDuration: TimeInterval = 0
    @Published public private(set) var audioLevel: Float = 0
}
```

### AsyncStream 实时事件流
```swift
public struct RecordingEvent {
    public enum EventType {
        case started
        case paused
        case resumed
        case stopped(URL)
        case cancelled
        case audioLevel(Float)
        case duration(TimeInterval)
        case error(VoiceRecorderError)
        case reachedMaxDuration
        case belowMinDuration
    }

    public let type: EventType
    public let timestamp: Date
}

public class VoiceRecorder {
    // 提供 AsyncStream 供外部监听
    public var events: AsyncStream<RecordingEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
            continuation.onTermination = { _ in
                self.eventContinuation = nil
            }
        }
    }

    private var eventContinuation: AsyncStream<RecordingEvent>.Continuation?
}
```

## 技术架构设计

### 核心组件 ✅ **全部实现**
1. **VoiceRecorder** - 主接口类 ✅
2. **VoiceRecorderDelegate** - 协议回调（可选） ✅
3. **VoiceRecorderCallbacks** - 链式回调管理 ✅ (集成在主类中)
4. **VoiceRecorderConfiguration** - 配置结构体 ✅
5. **RecordingManager** - Actor 管理录音状态 ✅
6. **FileOperationsActor** - 文件操作管理 ✅
7. **AudioFormat** - 音频格式定义 ✅
8. **VoiceRecorderError** - 错误类型定义 ✅

### 文件结构 ✅ **已实现**
```
Sources/VoiceRecorder/
├── VoiceRecorder.swift              # 主类 ✅
├── VoiceRecorderConfiguration.swift # 配置 ✅
├── RecordingManager.swift           # Actor 录音管理 ✅
├── FileOperationsActor.swift        # 文件操作 ✅
├── AudioFormat.swift                # 格式定义 ✅
├── VoiceRecorderError.swift         # 错误定义 ✅
└── RecordingEvent.swift             # 事件定义 ✅
```

### 示例项目 ✅ **已实现**
- Example/Example/ - UIKit 示例 ✅
- SwiftUIExample/SwiftUIExample/ - SwiftUI 示例 ✅
  - ContentView.swift - 主录音界面 ✅
  - ConfigurationView.swift - 配置界面 ✅
  - RecordingListView.swift - 录音列表 ✅
  - AudioVisualizerView.swift - 音频可视化 ✅
  - PermissionRequestView.swift - 权限请求 ✅
  - RecordingViewModel.swift - 视图模型 ✅

## API 设计

### 主类接口
```swift
@MainActor
public class VoiceRecorder: ObservableObject {
    // 配置
    public var configuration: VoiceRecorderConfiguration

    // 状态属性（@Published 用于 SwiftUI）
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var currentDuration: TimeInterval = 0
    @Published public private(set) var audioLevel: Float = 0

    // 事件流
    public var events: AsyncStream<RecordingEvent> { get }

    // 初始化
    public init(configuration: VoiceRecorderConfiguration = .default)

    // 异步录音控制方法
    public func startRecording() async throws
    public func pauseRecording() async
    public func resumeRecording() async
    public func stopRecording() async throws -> URL
    public func cancelRecording() async

    // 带自动停止的录音方法
    public func recordFor(duration: TimeInterval) async throws -> URL

    // 带条件的录音方法
    public func recordUntil(_ condition: @escaping () async -> Bool) async throws -> URL

    // 链式回调方法（保留兼容性）
    @discardableResult
    public func onStart(_ handler: @escaping () -> Void) -> Self

    @discardableResult
    public func onStop(_ handler: @escaping (URL) -> Void) -> Self

    @discardableResult
    public func onAudioLevel(_ handler: @escaping (Float) -> Void) -> Self

    @discardableResult
    public func onDurationUpdate(_ handler: @escaping (TimeInterval) -> Void) -> Self

    @discardableResult
    public func onError(_ handler: @escaping (VoiceRecorderError) -> Void) -> Self
}
```

### 配置结构体
```swift
public struct VoiceRecorderConfiguration: Sendable {
    // 音频设置
    public var audioFormat: AudioFormat = .m4a
    public var audioQuality: AudioQuality = .high
    public var numberOfChannels: Int = 2
    public var bitRate: Int = 128000

    // 录音时长设置
    public var minimumDuration: TimeInterval = 0.5  // 最短有效录制时长
    public var maximumDuration: TimeInterval? = nil // 最大录音时长
    public var autoStopBelowMinimum: Bool = true   // 低于最短时长自动取消

    // 文件设置
    public var saveDirectory: URL? = nil
    public var fileNamePrefix: String = "recording"
    public var autoGenerateFileName: Bool = true
    public var overwriteExisting: Bool = false

    // 实时监控
    public var enableMetering: Bool = true
    public var meteringUpdateInterval: TimeInterval = 0.1
    public var enableDurationUpdates: Bool = true
    public var durationUpdateInterval: TimeInterval = 0.1

    // 高级设置
    public var enableEchoCancellation: Bool = false
    public var enableNoiseSuppression: Bool = false

    // 并发设置
    public var maxConcurrentOperations: Int = 1
    public var updatePriority: TaskPriority = .userInitiated
}
```

## 使用示例

### 现代 async/await 方式
```swift
// 基础用法
@MainActor
class ViewController: UIViewController {
    let recorder = VoiceRecorder()

    func startRecording() {
        Task {
            do {
                try await recorder.startRecording()

                // 监听事件流
                for await event in recorder.events {
                    switch event.type {
                    case .duration(let duration):
                        updateTimeLabel(duration)
                    case .audioLevel(let level):
                        updateLevelMeter(level)
                    case .stopped(let url):
                        await saveRecording(url)
                    case .belowMinDuration:
                        showAlert("录音时长过短")
                    default:
                        break
                    }
                }
            } catch {
                showAlert(error.localizedDescription)
            }
        }
    }

    func stopRecording() {
        Task {
            do {
                let url = try await recorder.stopRecording()
                print("录音保存至: \(url)")
            } catch VoiceRecorderError.recordingTooShort(let duration) {
                showAlert("录音时长 \(duration) 秒，低于最短要求")
            } catch {
                showAlert(error.localizedDescription)
            }
        }
    }
}
```

### SwiftUI 集成
```swift
struct RecordingView: View {
    @StateObject private var recorder = VoiceRecorder()
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("时长: \(recorder.currentDuration.formatted())")
            ProgressView(value: recorder.audioLevel)

            HStack {
                Button(recorder.isRecording ? "停止" : "开始") {
                    Task { await toggleRecording() }
                }

                if recorder.isRecording {
                    Button(recorder.isPaused ? "恢复" : "暂停") {
                        Task {
                            if recorder.isPaused {
                                await recorder.resumeRecording()
                            } else {
                                await recorder.pauseRecording()
                            }
                        }
                    }
                }
            }
        }
        .task {
            for await event in recorder.events {
                handleEvent(event)
            }
        }
    }
}
```

### 链式调用兼容
```swift
let recorder = VoiceRecorder()
    .configure { config in
        config.minimumDuration = 1.0  // 最短1秒
        config.maximumDuration = 300  // 最长5分钟
        config.autoStopBelowMinimum = true
    }
    .onStart {
        print("录音开始")
    }
    .onDurationUpdate { duration in
        if duration < 1.0 {
            self.showHint("继续录音...")
        }
    }
    .onStop { url in
        print("录音完成: \(url)")
    }
    .onError { error in
        if case .recordingTooShort(let duration) = error {
            self.showAlert("录音仅 \(duration) 秒，太短了")
        }
    }
```

## 实现步骤 ✅ **全部完成**

1. **基础结构搭建** ✅ **已完成**
   - 创建错误类型枚举 ✅
   - 实现音频格式和质量枚举 ✅
   - 实现配置结构体 ✅

2. **Actor 系统实现** ✅ **已完成**
   - 实现 RecordingManager Actor ✅
   - 实现 FileOperationsActor ✅
   - 添加线程安全保证 ✅

3. **核心录音功能** ✅ **已完成**
   - 实现主 VoiceRecorder 类 ✅
   - AVAudioSession 配置 ✅
   - 录音控制方法实现 ✅

4. **回调系统** ✅ **已完成**
   - 实现链式闭包回调 ✅
   - 实现协议委托模式 ✅
   - 实现 AsyncStream 事件流 ✅

5. **实时监控功能** ✅ **已完成**
   - 录音时长跟踪 ✅
   - 音频分贝监控 ✅
   - 使用 Task 管理 ✅

6. **最短录音时长验证** ✅ **已完成**
   - 实现时长检查逻辑 ✅
   - 自动取消短录音 ✅
   - 错误处理 ✅

7. **权限和错误处理** ✅ **已完成**
   - 麦克风权限检查 ✅
   - 异步权限请求 ✅
   - 完善错误处理 ✅

8. **测试和示例** ✅ **已完成**
   - 单元测试 ✅
   - SwiftUI 示例 ✅
   - UIKit 示例 ✅
   - 使用文档 ✅

## 额外实现的功能 🎉 **超出原计划**

### 高级文件管理功能
- getRecordingFiles() - 获取录音文件列表 ✅
- deleteRecording(at:) - 删除指定录音 ✅
- exportRecording(from:to:) - 导出录音到指定位置 ✅
- cleanupOldRecordings() - 清理旧录音文件 ✅
- getStorageStats() - 获取存储统计信息 ✅

### 便利录音方法
- recordFor(duration:) - 录制指定时长 ✅
- recordUntil(_:) - 录制直到满足条件 ✅

### 预设配置
- .longRecording - 长时间录音配置 ✅
- .voiceMemo - 语音备忘录配置 ✅
- .podcast - 播客录制配置 ✅
- .music - 音乐录制配置 ✅
- .spaceEfficient - 节省空间配置 ✅

### 完整的示例应用
- SwiftUI 完整示例应用，包含：
  - 权限请求界面 ✅
  - 录音主界面 ✅
  - 配置界面 ✅
  - 录音文件列表 ✅
  - 音频可视化 ✅

## 技术实现细节

### 最短录音时长验证
- 在停止录音时检查时长
- 支持自动取消或警告模式
- 提供详细的错误信息

### Swift Concurrency 优势
- Actor 模型保证线程安全
- async/await 简化异步操作
- 结构化并发管理任务
- MainActor 保证 UI 更新
- 自动任务取消传播

### 性能优化
- 使用 Actor 避免数据竞争
- Task 优先级管理
- 取消未完成的任务
- AsyncStream 缓冲区管理

### 向后兼容性
- iOS 13-14: 提供基于 Combine 的回退
- 保留传统回调接口
- 使用 @available 标记新 API

## 权限要求
```xml
<!-- Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>需要使用麦克风来录制音频</string>
```

## 测试策略
- 异步测试用例
- 并发录音测试
- 最短时长验证测试
- 内存泄漏检测
- 性能基准测试

## 错误处理
- 权限错误优雅处理
- 存储空间检查
- 音频会话冲突处理
- 格式兼容性验证
- 用户友好的错误信息

## 未来扩展
- 后台录音支持
- 音频效果处理
- 波形可视化
- 云端上传集成
- 语音转文字
- 多录音并发