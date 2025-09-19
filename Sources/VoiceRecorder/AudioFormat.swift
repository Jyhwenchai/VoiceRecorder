import Foundation
import AVFoundation

// MARK: - 音频格式定义

/// 支持的音频格式
public enum AudioFormat: String, CaseIterable, Sendable {
    case m4a = "m4a"
    case wav = "wav"
    case caf = "caf"
    case mp3 = "mp3"
    case aac = "aac"

    /// 文件扩展名
    public var fileExtension: String {
        return rawValue
    }

    /// AVFoundation 格式ID
    public var formatID: AudioFormatID {
        switch self {
        case .m4a:
            return kAudioFormatMPEG4AAC
        case .wav:
            return kAudioFormatLinearPCM
        case .caf:
            return kAudioFormatAppleLossless
        case .mp3:
            return kAudioFormatMPEGLayer3
        case .aac:
            return kAudioFormatMPEG4AAC
        }
    }

    /// MIME 类型
    public var mimeType: String {
        switch self {
        case .m4a:
            return "audio/mp4"
        case .wav:
            return "audio/wav"
        case .caf:
            return "audio/x-caf"
        case .mp3:
            return "audio/mpeg"
        case .aac:
            return "audio/aac"
        }
    }

    /// 是否为压缩格式
    public var isCompressed: Bool {
        switch self {
        case .m4a, .mp3, .aac:
            return true
        case .wav, .caf:
            return false
        }
    }

    /// 是否为无损格式
    public var isLossless: Bool {
        switch self {
        case .wav, .caf:
            return true
        case .m4a, .mp3, .aac:
            return false
        }
    }

    /// 格式描述
    public var description: String {
        switch self {
        case .m4a:
            return "M4A (AAC压缩)"
        case .wav:
            return "WAV (无压缩)"
        case .caf:
            return "CAF (苹果无损)"
        case .mp3:
            return "MP3 (压缩)"
        case .aac:
            return "AAC (压缩)"
        }
    }

    /// 建议的使用场景
    public var recommendedUseCase: String {
        switch self {
        case .m4a:
            return "默认选择，兼容性和质量平衡"
        case .wav:
            return "专业录音，最高质量"
        case .caf:
            return "苹果生态，高质量"
        case .mp3:
            return "广泛兼容，较小文件"
        case .aac:
            return "现代压缩，高效率"
        }
    }

    /// 平均文件大小（每分钟MB，立体声44.1kHz）
    public var approximateFileSizePerMinute: Double {
        switch self {
        case .m4a, .aac:
            return 1.0  // ~1MB/分钟
        case .wav:
            return 10.0 // ~10MB/分钟
        case .caf:
            return 5.0  // ~5MB/分钟
        case .mp3:
            return 0.9  // ~0.9MB/分钟
        }
    }

    /// 获取录音设置字典
    public func getRecordingSettings(quality: AudioQuality, numberOfChannels: Int, bitRate: Int? = nil) -> [String: Any] {
        var settings: [String: Any] = [
            AVFormatIDKey: formatID,
            AVSampleRateKey: quality.sampleRate,
            AVNumberOfChannelsKey: numberOfChannels
        ]

        switch self {
        case .wav:
            // 无压缩PCM设置
            settings[AVLinearPCMBitDepthKey] = quality.bitDepth
            settings[AVLinearPCMIsBigEndianKey] = false
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsNonInterleaved] = false

        case .m4a, .aac:
            // AAC压缩设置
            settings[AVEncoderAudioQualityKey] = quality.avAudioQuality.rawValue
//            if let bitRate = bitRate {
//                settings[AVEncoderBitRateKey] = bitRate
//            }

        case .mp3:
            // MP3压缩设置
            settings[AVEncoderAudioQualityKey] = quality.avAudioQuality.rawValue
            if let bitRate = bitRate {
                settings[AVEncoderBitRateKey] = bitRate
            }

        case .caf:
            // Apple Lossless设置
            settings[AVEncoderAudioQualityKey] = AVAudioQuality.max.rawValue
        }

        return settings
    }
}

// MARK: - 音频质量定义

/// 音频质量等级
public enum AudioQuality: String, CaseIterable, Sendable {
    case min = "min"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case max = "max"
    case custom = "custom"

    /// 采样率 (Hz)
    public var sampleRate: Double {
        switch self {
        case .min:
            return 8000.0
        case .low:
            return 16000.0
        case .medium:
            return 22050.0
        case .high:
            return 44100.0
        case .max:
            return 48000.0
        case .custom:
            return 44100.0 // 默认值，应该通过customSampleRate指定
        }
    }

    /// 位深度 (bit)
    public var bitDepth: Int {
        switch self {
        case .min:
            return 8
        case .low:
            return 16
        case .medium:
            return 16
        case .high:
            return 24
        case .max:
            return 32
        case .custom:
            return 24 // 默认值，应该通过customBitDepth指定
        }
    }

    /// AVAudioQuality 对应值
    public var avAudioQuality: AVAudioQuality {
        switch self {
        case .min:
            return .min
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        case .max, .custom:
            return .max
        }
    }

    /// 质量描述
    public var description: String {
        switch self {
        case .min:
            return "最低质量 (8kHz, 8bit)"
        case .low:
            return "低质量 (16kHz, 16bit)"
        case .medium:
            return "中等质量 (22kHz, 16bit)"
        case .high:
            return "高质量 (44kHz, 24bit)"
        case .max:
            return "最高质量 (48kHz, 32bit)"
        case .custom:
            return "自定义质量"
        }
    }

    /// 建议的使用场景
    public var recommendedUseCase: String {
        switch self {
        case .min:
            return "语音备忘，节省空间"
        case .low:
            return "电话质量，语音清晰"
        case .medium:
            return "一般录音，平衡质量和大小"
        case .high:
            return "高质量录音，推荐设置"
        case .max:
            return "专业录音，最佳质量"
        case .custom:
            return "特殊需求，自定义参数"
        }
    }

    /// 预估比特率（kbps）
    public var estimatedBitRate: Int {
        switch self {
        case .min:
            return 32
        case .low:
            return 64
        case .medium:
            return 96
        case .high:
            return 128
        case .max:
            return 256
        case .custom:
            return 128
        }
    }
}

// MARK: - 自定义音频质量

/// 自定义音频质量配置
public struct CustomAudioQuality: Sendable {
    public let sampleRate: Double
    public let bitDepth: Int
    public let bitRate: Int?

    public init(sampleRate: Double, bitDepth: Int, bitRate: Int? = nil) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.bitRate = bitRate
    }

    /// 验证参数有效性
    public var isValid: Bool {
        return sampleRate > 0 &&
               bitDepth > 0 &&
               [8, 16, 24, 32].contains(bitDepth) &&
               sampleRate >= 8000 &&
               sampleRate <= 192000
    }

    /// 获取对应的AVAudioQuality
    public var avAudioQuality: AVAudioQuality {
        switch sampleRate {
        case ...16000:
            return .low
        case ...22050:
            return .medium
        case ...44100:
            return .high
        default:
            return .max
        }
    }

    public var description: String {
        let bitRateText = bitRate.map { "\($0)kbps" } ?? "自适应"
        return "自定义 (\(Int(sampleRate))Hz, \(bitDepth)bit, \(bitRateText))"
    }
}

// MARK: - 音频格式工具

public struct AudioFormatUtility {
    /// 检查设备是否支持指定格式
    public static func isFormatSupported(_ format: AudioFormat) -> Bool {
        // 所有iOS设备都支持这些基本格式
        return true
    }

    /// 获取推荐的音频格式
    public static func recommendedFormat(for useCase: AudioUseCase) -> AudioFormat {
        switch useCase {
        case .voiceMemo:
            return .m4a
        case .musicRecording:
            return .wav
        case .podcast:
            return .m4a
        case .interview:
            return .m4a
        case .professional:
            return .wav
        case .sharing:
            return .mp3
        }
    }

    /// 获取推荐的音频质量
    public static func recommendedQuality(for useCase: AudioUseCase) -> AudioQuality {
        switch useCase {
        case .voiceMemo:
            return .medium
        case .musicRecording:
            return .max
        case .podcast:
            return .high
        case .interview:
            return .high
        case .professional:
            return .max
        case .sharing:
            return .medium
        }
    }

    /// 估算文件大小（字节）
    public static func estimateFileSize(
        format: AudioFormat,
        quality: AudioQuality,
        duration: TimeInterval,
        numberOfChannels: Int = 2
    ) -> UInt64 {
        let sampleRate = quality.sampleRate
        let bitDepth = quality.bitDepth

        let bytesPerSecond: Double

        if format.isCompressed {
            // 压缩格式按比特率计算
            let bitRate = Double(quality.estimatedBitRate * 1000) // 转换为bps
            bytesPerSecond = bitRate / 8.0
        } else {
            // 无压缩格式按采样率和位深度计算
            bytesPerSecond = sampleRate * Double(bitDepth) / 8.0 * Double(numberOfChannels)
        }

        return UInt64(bytesPerSecond * duration)
    }

    /// 格式转换兼容性检查
    public static func canConvert(from: AudioFormat, to: AudioFormat) -> Bool {
        // 所有格式之间理论上都可以转换
        return true
    }
}

// MARK: - 音频使用场景

/// 音频录制使用场景
public enum AudioUseCase: String, CaseIterable, Sendable {
    case voiceMemo = "voiceMemo"
    case musicRecording = "musicRecording"
    case podcast = "podcast"
    case interview = "interview"
    case professional = "professional"
    case sharing = "sharing"

    public var description: String {
        switch self {
        case .voiceMemo:
            return "语音备忘录"
        case .musicRecording:
            return "音乐录制"
        case .podcast:
            return "播客录制"
        case .interview:
            return "采访录音"
        case .professional:
            return "专业录音"
        case .sharing:
            return "分享录音"
        }
    }

    /// 推荐配置
    public var recommendedConfiguration: (format: AudioFormat, quality: AudioQuality, channels: Int) {
        switch self {
        case .voiceMemo:
            return (.m4a, .medium, 1)
        case .musicRecording:
            return (.wav, .max, 2)
        case .podcast:
            return (.m4a, .high, 1)
        case .interview:
            return (.m4a, .high, 1)
        case .professional:
            return (.wav, .max, 2)
        case .sharing:
            return (.mp3, .medium, 2)
        }
    }
}
