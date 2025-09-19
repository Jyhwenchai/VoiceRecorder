# VoiceRecorder

一个现代化的 iOS 语音录制库，采用 Swift Concurrency (async/await) 和 Actor 模型设计，提供线程安全的录音功能。

## ✨ 特性

### 🎯 核心功能
- ✅ **完整录音控制**: 开始/停止/暂停/恢复/取消录音
- ✅ **最短录音时长验证**: 可配置最短有效录音时长
- ✅ **最大录音时长限制**: 自动或手动停止超长录音
- ✅ **实时音频监控**: 音频级别和录音时长实时更新
- ✅ **多种音频格式**: 支持 M4A、WAV、CAF、MP3、AAC
- ✅ **灵活配置**: 音频质量、采样率、声道等完全可配置

### 🚀 现代化设计
- ✅ **Swift Concurrency**: 全面采用 async/await 和 Actor 模式
- ✅ **线程安全**: Actor 确保并发安全，MainActor 保证 UI 更新
- ✅ **三种回调方式**:
  - AsyncStream 事件流（推荐）
  - 链式闭包回调（现代化）
  - 协议委托模式（传统）
- ✅ **SwiftUI 集成**: 原生支持 @Published 属性和 ObservableObject
- ✅ **结构化并发**: TaskGroup 和 withThrowingTaskGroup 支持

### 📁 文件管理
- ✅ **智能文件管理**: 自动生成唯一文件名
- ✅ **多种命名模式**: 时间戳、UUID、序号等
- ✅ **存储优化**: 自动清理、磁盘空间监控
- ✅ **批量操作**: 导出、删除、移动文件

### 🛡️ 错误处理
- ✅ **完整错误类型**: 详细的错误信息和恢复建议
- ✅ **权限处理**: 麦克风权限检查和请求
- ✅ **优雅降级**: 错误时的状态恢复
- ✅ **用户友好**: 本地化错误信息

## 📋 系统要求

- iOS 13.0+
- Swift 5.5+
- Xcode 13.0+

> **注意**: iOS 15.0+ 获得完整 Swift Concurrency 支持，推荐使用

## 📦 安装

### Swift Package Manager

在 Xcode 中：
1. File → Add Package Dependencies
2. 输入仓库 URL
3. 选择版本并添加到项目

或在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/Jyhwenchai/VoiceRecorder.git", from: "1.0.0")
]
```

## 🚀 快速开始

### 基础使用

```swift
import VoiceRecorder

class ViewController: UIViewController {
    let recorder = VoiceRecorder()

    func startRecording() {
        Task {
            do {
                try await recorder.startRecording()
                print("录音开始")
            } catch {
                print("录音失败: \(error)")
            }
        }
    }

    func stopRecording() {
        Task {
            do {
                let url = try await recorder.stopRecording()
                print("录音保存至: \(url)")
            } catch {
                print("停止录音失败: \(error)")
            }
        }
    }
}
```

### 链式配置（推荐）

```swift
let recorder = VoiceRecorder()
    .configure { config in
        config.audioFormat = .m4a
        config.audioQuality = .high
        config.minimumDuration = 1.0
        config.maximumDuration = 300
        config.numberOfChannels = 1
    }
    .onStart {
        print("录音开始")
    }
    .onDurationUpdate { duration in
        print("录音时长: \(duration)秒")
    }
    .onAudioLevel { level in
        print("音频级别: \(level)")
    }
    .onStop { url in
        print("录音完成: \(url)")
    }
    .onError { error in
        print("录音错误: \(error)")
    }
```

### SwiftUI 集成

```swift
import SwiftUI
import VoiceRecorder

struct RecordingView: View {
    @StateObject private var recorder = VoiceRecorder()

    var body: some View {
        VStack {
            Text("录音时长: \(recorder.currentDuration.formatted())")
            ProgressView(value: recorder.audioLevel)

            Button(recorder.isRecording ? "停止" : "开始") {
                Task {
                    if recorder.isRecording {
                        _ = try? await recorder.stopRecording()
                    } else {
                        try? await recorder.startRecording()
                    }
                }
            }
        }
        .task {
            // 监听事件流
            for await event in recorder.events {
                handleEvent(event)
            }
        }
    }

    func handleEvent(_ event: RecordingEvent) {
        switch event.type {
        case .error(let error):
            print("录音错误: \(error)")
        case .reachedMaxDuration:
            print("达到最大录音时长")
        default:
            break
        }
    }
}
```

### 事件流监听

```swift
// 使用 AsyncStream 监听所有事件
Task {
    for await event in recorder.events {
        switch event.type {
        case .started:
            updateUI(recording: true)
        case .stopped(let url):
            saveRecording(url)
        case .duration(let duration):
            updateDurationLabel(duration)
        case .audioLevel(let level):
            updateLevelMeter(level)
        case .error(let error):
            showError(error)
        default:
            break
        }
    }
}
```

## 🎛️ 高级用法

### 自定义配置

```swift
var config = VoiceRecorderConfiguration()

// 音频设置
config.audioFormat = .wav
config.audioQuality = .max
config.numberOfChannels = 2
config.bitRate = 256

// 录音时长
config.minimumDuration = 2.0
config.maximumDuration = 1800 // 30分钟
config.autoStopBelowMinimum = true

// 文件管理
config.fileNamePrefix = "interview"
config.fileNamingPattern = .dateTimeSuffix
config.saveDirectory = documentsURL

// 实时监控
config.enableMetering = true
config.meteringUpdateInterval = 0.05 // 20Hz 更新

let recorder = VoiceRecorder(configuration: config)
```

### 预设配置

```swift
// 高质量音乐录制
let musicRecorder = VoiceRecorder(configuration: .music)

// 播客录制
let podcastRecorder = VoiceRecorder(configuration: .podcast)

// 语音备忘录
let memoRecorder = VoiceRecorder(configuration: .voiceMemo)

// 长时间录音
let longRecorder = VoiceRecorder(configuration: .longRecording)

// 节省空间
let compactRecorder = VoiceRecorder(configuration: .spaceEfficient)
```

### 便利录音方法

```swift
// 录制指定时长
let url = try await recorder.recordFor(duration: 30) // 30秒

// 录制直到满足条件
let url = try await recorder.recordUntil {
    // 检测静音
    await recorder.audioLevel < 0.1
}

// 录制直到用户操作
let url = try await recorder.recordUntil {
    await userWantsToStop
}
```

### 文件管理

```swift
// 获取录音列表
let recordings = try await recorder.getRecordingFiles()

// 删除录音
try await recorder.deleteRecording(at: url)

// 导出录音
try await recorder.exportRecording(from: sourceURL, to: targetURL)

// 清理旧录音
try await recorder.cleanupOldRecordings()

// 获取存储统计
let stats = try await recorder.getStorageStats()
print("总文件数: \(stats.totalFiles), 总大小: \(stats.totalSizeMB)MB")
```

### 委托模式（传统方式）

```swift
class RecordingManager: VoiceRecorderDelegate {
    let recorder = VoiceRecorder()

    init() {
        recorder.delegate = self
    }

    func voiceRecorderDidStartRecording(_ recorder: VoiceRecorder) {
        updateUI(recording: true)
    }

    func voiceRecorderDidStopRecording(_ recorder: VoiceRecorder, fileURL: URL) {
        saveRecording(fileURL)
    }

    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateDuration duration: TimeInterval) {
        updateDurationLabel(duration)
    }

    func voiceRecorder(_ recorder: VoiceRecorder, didFailWithError error: VoiceRecorderError) {
        showError(error.localizedDescription)
    }
}
```

## 🎵 音频格式支持

| 格式 | 扩展名 | 压缩 | 质量 | 兼容性 | 推荐用途 |
|------|--------|------|------|--------|----------|
| M4A  | .m4a   | ✅   | 高   | 好     | 默认选择 |
| WAV  | .wav   | ❌   | 最高 | 优秀   | 专业录音 |
| CAF  | .caf   | ❌   | 高   | 苹果   | 苹果生态 |
| MP3  | .mp3   | ✅   | 中   | 优秀   | 广泛兼容 |
| AAC  | .aac   | ✅   | 高   | 好     | 现代压缩 |

## 🎚️ 音频质量等级

| 等级 | 采样率 | 位深度 | 用途 |
|------|--------|--------|------|
| min  | 8kHz   | 8bit   | 语音备忘 |
| low  | 16kHz  | 16bit  | 电话质量 |
| medium | 22kHz | 16bit  | 一般录音 |
| high | 44kHz  | 24bit  | 高质量录音 |
| max  | 48kHz  | 32bit  | 专业录音 |

## 🔧 权限配置

在 `Info.plist` 中添加麦克风权限描述：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要使用麦克风来录制音频</string>
```

代码中检查权限：

```swift
let hasPermission = await recorder.checkMicrophonePermission()
if !hasPermission {
    let granted = await recorder.requestMicrophonePermission()
    if !granted {
        // 处理权限被拒绝的情况
    }
}
```

## 🐛 错误处理

```swift
do {
    try await recorder.startRecording()
} catch VoiceRecorderError.microphonePermissionDenied {
    showPermissionAlert()
} catch VoiceRecorderError.recordingTooShort(let duration) {
    showAlert("录音时长 \(duration) 秒，太短了")
} catch VoiceRecorderError.storageFull {
    showAlert("存储空间不足")
} catch {
    showAlert("录音失败: \(error.localizedDescription)")
}
```

## 📊 性能和并发

### Actor 模型确保线程安全

```swift
// RecordingManager 是 Actor，自动序列化访问
actor RecordingManager {
    func startRecording() async throws { ... }
    func stopRecording() async throws -> URL { ... }
}

// VoiceRecorder 使用 @MainActor，UI 更新自动在主线程
@MainActor
class VoiceRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var currentDuration: TimeInterval = 0
}
```

### 结构化并发

```swift
// 使用 TaskGroup 进行并发监控
private func startMonitoring() {
    Task {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.monitorAudioLevel() }
            group.addTask { await self.monitorDuration() }
            group.addTask { await self.monitorStorage() }
        }
    }
}
```

## 🧪 测试

运行测试：

```bash
swift test
```

测试覆盖包括：
- ✅ 基础录音功能测试
- ✅ 配置验证测试
- ✅ 错误处理测试
- ✅ 并发安全测试
- ✅ 内存泄漏测试
- ✅ 性能基准测试

## 📁 项目结构

```
VoiceRecorder/
├── Sources/VoiceRecorder/
│   ├── VoiceRecorder.swift              # 主类
│   ├── VoiceRecorderConfiguration.swift # 配置
│   ├── RecordingManager.swift           # Actor 录音管理
│   ├── FileOperationsActor.swift        # 文件操作
│   ├── AudioFormat.swift                # 音频格式
│   ├── VoiceRecorderError.swift         # 错误定义
│   └── RecordingEvent.swift             # 事件系统
├── Tests/VoiceRecorderTests/
│   └── VoiceRecorderTests.swift         # 测试用例
├── Example/
│   ├── SwiftUIExample.swift             # SwiftUI 示例
│   └── UIKitExample.swift               # UIKit 示例
├── Package.swift                        # SPM 配置
└── README.md                           # 说明文档
```

## 🤝 贡献

欢迎贡献代码！请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详细信息。

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- Swift Concurrency 设计灵感
- AVFoundation 框架
- 社区反馈和建议

## 📞 支持

- 📖 [文档](https://docs.example.com/voicerecorder)
- 🐛 [问题反馈](https://github.com/your-repo/VoiceRecorder/issues)
- 💬 [讨论区](https://github.com/your-repo/VoiceRecorder/discussions)

---

**🎤 开始你的录音之旅吧！**
