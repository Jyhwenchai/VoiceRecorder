import Foundation

/// 语音录制库错误类型定义
public enum VoiceRecorderError: Error, LocalizedError, Sendable {
    /// 麦克风权限被拒绝
    case microphonePermissionDenied

    /// 音频会话设置失败
    case audioSessionSetupFailed(String)

    /// 录音失败
    case recordingFailed(String)

    /// 无效配置
    case invalidConfiguration(String)

    /// 存储空间不足
    case storageFull

    /// 文件写入失败
    case fileWriteFailed(String)

    /// 不支持的音频格式
    case formatNotSupported(String)

    /// 录音时长低于最短要求
    case recordingTooShort(TimeInterval)

    /// 正在录音中（不能重复开始）
    case recordingInProgress

    /// 没有活动的录音
    case noActiveRecording

    /// 用户主动取消
    case cancelled

    /// 达到最大录音时长
    case reachedMaximumDuration(TimeInterval)

    /// 文件操作失败
    case fileOperationFailed(String)

    /// 音频设备不可用
    case audioDeviceUnavailable

    /// 系统资源不足
    case systemResourcesUnavailable

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "麦克风权限被拒绝，请在设置中允许应用使用麦克风"

        case .audioSessionSetupFailed(let detail):
            return "音频会话设置失败: \(detail)"

        case .recordingFailed(let detail):
            return "录音失败: \(detail)"

        case .invalidConfiguration(let detail):
            return "无效配置: \(detail)"

        case .storageFull:
            return "存储空间不足，无法继续录音"

        case .fileWriteFailed(let detail):
            return "文件写入失败: \(detail)"

        case .formatNotSupported(let format):
            return "不支持的音频格式: \(format)"

        case .recordingTooShort(let duration):
            return "录音时长 \(String(format: "%.1f", duration)) 秒，低于最短要求"

        case .recordingInProgress:
            return "正在录音中，请先停止当前录音"

        case .noActiveRecording:
            return "没有正在进行的录音"

        case .cancelled:
            return "录音已被取消"

        case .reachedMaximumDuration(let duration):
            return "已达到最大录音时长 \(String(format: "%.0f", duration)) 秒"

        case .fileOperationFailed(let detail):
            return "文件操作失败: \(detail)"

        case .audioDeviceUnavailable:
            return "音频设备不可用"

        case .systemResourcesUnavailable:
            return "系统资源不足，无法录音"
        }
    }

    public var failureReason: String? {
        switch self {
        case .microphonePermissionDenied:
            return "应用没有麦克风使用权限"

        case .audioSessionSetupFailed:
            return "无法配置音频会话"

        case .recordingFailed:
            return "录音过程中发生错误"

        case .invalidConfiguration:
            return "录音配置参数无效"

        case .storageFull:
            return "设备存储空间不足"

        case .fileWriteFailed:
            return "无法写入录音文件"

        case .formatNotSupported:
            return "当前设备不支持指定的音频格式"

        case .recordingTooShort:
            return "录音时长未达到最短要求"

        case .recordingInProgress:
            return "已有录音在进行中"

        case .noActiveRecording:
            return "当前没有录音会话"

        case .cancelled:
            return "用户取消了录音操作"

        case .reachedMaximumDuration:
            return "录音时长达到上限"

        case .fileOperationFailed:
            return "文件系统操作失败"

        case .audioDeviceUnavailable:
            return "音频设备被其他应用占用或不可用"

        case .systemResourcesUnavailable:
            return "系统内存或CPU资源不足"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "请前往设置 > 隐私与安全性 > 麦克风，允许此应用使用麦克风"

        case .audioSessionSetupFailed:
            return "请关闭其他音频应用后重试"

        case .recordingFailed:
            return "请检查设备状态并重新开始录音"

        case .invalidConfiguration:
            return "请检查录音配置参数是否正确"

        case .storageFull:
            return "请清理设备存储空间后重试"

        case .fileWriteFailed:
            return "请检查存储空间和文件权限"

        case .formatNotSupported:
            return "请选择设备支持的音频格式"

        case .recordingTooShort:
            return "请录制更长时间的音频"

        case .recordingInProgress:
            return "请等待当前录音完成或手动停止"

        case .noActiveRecording:
            return "请先开始录音"

        case .cancelled:
            return "如需录音，请重新开始"

        case .reachedMaximumDuration:
            return "录音已自动停止，可以开始新的录音"

        case .fileOperationFailed:
            return "请检查文件权限和存储空间"

        case .audioDeviceUnavailable:
            return "请关闭其他音频应用或连接音频设备"

        case .systemResourcesUnavailable:
            return "请关闭其他应用释放系统资源"
        }
    }
}

// MARK: - 错误处理扩展

extension VoiceRecorderError {
    /// 是否是可恢复的错误
    public var isRecoverable: Bool {
        switch self {
        case .microphonePermissionDenied,
             .storageFull,
             .audioDeviceUnavailable,
             .systemResourcesUnavailable:
            return true

        case .invalidConfiguration,
             .formatNotSupported,
             .recordingTooShort,
             .cancelled:
            return false

        default:
            return true
        }
    }

    /// 是否需要用户操作
    public var requiresUserAction: Bool {
        switch self {
        case .microphonePermissionDenied,
             .storageFull,
             .audioDeviceUnavailable:
            return true

        default:
            return false
        }
    }

    /// 错误严重级别
    public var severity: ErrorSeverity {
        switch self {
        case .microphonePermissionDenied,
             .audioSessionSetupFailed,
             .storageFull,
             .systemResourcesUnavailable:
            return .critical

        case .recordingFailed,
             .fileWriteFailed,
             .fileOperationFailed,
             .audioDeviceUnavailable:
            return .high

        case .invalidConfiguration,
             .formatNotSupported,
             .reachedMaximumDuration:
            return .medium

        case .recordingTooShort,
             .recordingInProgress,
             .noActiveRecording,
             .cancelled:
            return .low
        }
    }
}

/// 错误严重级别
public enum ErrorSeverity: Int, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public var description: String {
        switch self {
        case .low:
            return "轻微"
        case .medium:
            return "中等"
        case .high:
            return "严重"
        case .critical:
            return "关键"
        }
    }
}

// MARK: - 错误处理助手

public struct ErrorHandler {
    /// 处理录音错误并提供用户友好的提示
    public static func handleRecordingError(_ error: VoiceRecorderError) -> (title: String, message: String, actionTitle: String?) {
        switch error {
        case .microphonePermissionDenied:
            return (
                title: "需要麦克风权限",
                message: error.errorDescription ?? "",
                actionTitle: "去设置"
            )

        case .storageFull:
            return (
                title: "存储空间不足",
                message: error.errorDescription ?? "",
                actionTitle: "清理空间"
            )

        case .recordingTooShort(let duration):
            return (
                title: "录音太短",
                message: "录音时长 \(String(format: "%.1f", duration)) 秒，请录制更长时间",
                actionTitle: "重新录音"
            )

        case .reachedMaximumDuration:
            return (
                title: "录音完成",
                message: "已达到最大录音时长，录音已自动停止",
                actionTitle: "查看录音"
            )

        default:
            return (
                title: "录音错误",
                message: error.errorDescription ?? "发生未知错误",
                actionTitle: "重试"
            )
        }
    }
}