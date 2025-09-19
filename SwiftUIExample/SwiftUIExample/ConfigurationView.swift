//
//  ConfigurationView.swift
//  SwiftUIExample
//
//  Created by Claude on 2025/9/19.
//

import SwiftUI
import VoiceRecorder

/// 录音配置设置视图
struct ConfigurationView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedPreset: ConfigurationPreset = .default
    @State private var customConfiguration: VoiceRecorderConfiguration
    @State private var showAdvancedSettings = false

    init(viewModel: RecordingViewModel) {
        self.viewModel = viewModel
        self._customConfiguration = State(initialValue: viewModel.currentConfiguration)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    presetSection
                    basicSettingsSection
                    audioQualitySection
                    durationSection

                    if showAdvancedSettings {
                        advancedSection
                        performanceSection
                    }
                }

                bottomButtons
            }
            .navigationTitle("录音设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveConfiguration()
                    }
                }
            }
        }
    }

    private var presetSection: some View {
        Section("预设配置") {
            Picker("选择预设", selection: $selectedPreset) {
                ForEach(ConfigurationPreset.allCases, id: \.self) { preset in
                    VStack(alignment: .leading) {
                        Text(preset.displayName)
                            .font(.headline)
                        Text(preset.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(preset)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedPreset) { preset in
                applyPreset(preset)
            }

            Button("应用预设") {
                applyPreset(selectedPreset)
            }
            .foregroundColor(.blue)
        }
    }

    private var basicSettingsSection: some View {
        Section("基本设置") {
            HStack {
                Text("音频格式")
                Spacer()
                Picker("格式", selection: $customConfiguration.audioFormat) {
                    ForEach(AudioFormat.allCases, id: \.self) { format in
                        Text(format.description).tag(format)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }

            HStack {
                Text("声道数")
                Spacer()
                Picker("声道", selection: $customConfiguration.numberOfChannels) {
                    Text("单声道").tag(1)
                    Text("立体声").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 150)
            }

            HStack {
                Text("比特率")
                Spacer()
                Text("\(customConfiguration.bitRate) kbps")
                    .foregroundColor(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(customConfiguration.bitRate) },
                    set: { customConfiguration.bitRate = Int($0) }
                ),
                in: 32...320,
                step: 32
            )
        }
    }

    private var audioQualitySection: some View {
        Section("音频质量") {
            Picker("质量等级", selection: $customConfiguration.audioQuality) {
                ForEach(AudioQuality.allCases.filter { $0 != .custom }, id: \.self) { quality in
                    VStack(alignment: .leading) {
                        Text(quality.description)
                        Text("采样率: \(Int(quality.sampleRate))Hz, 位深度: \(quality.bitDepth)bit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(quality)
                }
            }
            .pickerStyle(MenuPickerStyle())

            if customConfiguration.audioQuality != .custom {
                VStack(alignment: .leading, spacing: 8) {
                    Text("质量预览")
                        .font(.headline)

                    QualityPreviewRow(
                        title: "采样率",
                        value: "\(Int(customConfiguration.audioQuality.sampleRate)) Hz"
                    )

                    QualityPreviewRow(
                        title: "位深度",
                        value: "\(customConfiguration.audioQuality.bitDepth) bit"
                    )

                    QualityPreviewRow(
                        title: "预估文件大小",
                        value: "\(Int(customConfiguration.audioFormat.approximateFileSizePerMinute)) MB/分钟"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private var durationSection: some View {
        Section("录音时长") {
            HStack {
                Text("最短时长")
                Spacer()
                Text("\(customConfiguration.minimumDuration, specifier: "%.1f") 秒")
                    .foregroundColor(.secondary)
            }

            Slider(
                value: $customConfiguration.minimumDuration,
                in: 0.1...10.0,
                step: 0.1
            )

            Toggle("设置最大时长", isOn: Binding(
                get: { customConfiguration.maximumDuration != nil },
                set: { enabled in
                    customConfiguration.maximumDuration = enabled ? 300 : nil
                }
            ))

            if customConfiguration.maximumDuration != nil {
                HStack {
                    Text("最大时长")
                    Spacer()
                    Text("\(Int(customConfiguration.maximumDuration ?? 0 / 60)) 分钟")
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { customConfiguration.maximumDuration ?? 300 },
                        set: { customConfiguration.maximumDuration = $0 }
                    ),
                    in: 60...3600,
                    step: 60
                )
            }

            Toggle("达到最大时长自动停止", isOn: $customConfiguration.autoStopAtMaximum)
        }
    }

    private var advancedSection: some View {
        Section("高级设置") {
            Toggle("启用音频级别监控", isOn: $customConfiguration.enableMetering)

            if customConfiguration.enableMetering {
                HStack {
                    Text("级别更新间隔")
                    Spacer()
                    Text("\(customConfiguration.meteringUpdateInterval, specifier: "%.2f") 秒")
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: $customConfiguration.meteringUpdateInterval,
                    in: 0.05...1.0,
                    step: 0.05
                )
            }

            Toggle("启用时长更新", isOn: $customConfiguration.enableDurationUpdates)

            if customConfiguration.enableDurationUpdates {
                HStack {
                    Text("时长更新间隔")
                    Spacer()
                    Text("\(customConfiguration.durationUpdateInterval, specifier: "%.2f") 秒")
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: $customConfiguration.durationUpdateInterval,
                    in: 0.1...2.0,
                    step: 0.1
                )
            }

            Toggle("噪音抑制", isOn: $customConfiguration.enableNoiseSuppression)
            Toggle("自动增益控制", isOn: $customConfiguration.enableAutomaticGainControl)
            Toggle("回声消除", isOn: $customConfiguration.enableEchoCancellation)
        }
    }

    private var performanceSection: some View {
        Section("性能设置") {
            HStack {
                Text("输入增益")
                Spacer()
                Text("\(Int(customConfiguration.inputGain * 100))%")
                    .foregroundColor(.secondary)
            }

            Slider(
                value: $customConfiguration.inputGain,
                in: 0.0...1.0,
                step: 0.1
            )

            Toggle("使用后台队列", isOn: $customConfiguration.useBackgroundQueue)
            Toggle("自动清理临时文件", isOn: $customConfiguration.autoCleanupTempFiles)

            if customConfiguration.autoCleanupTempFiles {
                HStack {
                    Text("临时文件保留时间")
                    Spacer()
                    Text("\(customConfiguration.tempFileRetentionHours) 小时")
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(customConfiguration.tempFileRetentionHours) },
                        set: { customConfiguration.tempFileRetentionHours = Int($0) }
                    ),
                    in: 1...72,
                    step: 1
                )
            }
        }
    }

    private var bottomButtons: some View {
        VStack(spacing: 12) {
            Button(action: toggleAdvancedSettings) {
                HStack {
                    Text(showAdvancedSettings ? "隐藏高级设置" : "显示高级设置")
                    Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button("重置为默认") {
                resetToDefault()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }

    private func applyPreset(_ preset: ConfigurationPreset) {
        switch preset {
        case .default:
            customConfiguration = .default
        case .highQuality:
            customConfiguration = .highQuality
        case .voiceMemo:
            customConfiguration = .voiceMemo
        case .podcast:
            customConfiguration = .podcast
        case .music:
            customConfiguration = .music
        }
    }

    private func saveConfiguration() {
        viewModel.updateConfiguration(customConfiguration)
        presentationMode.wrappedValue.dismiss()
    }

    private func resetToDefault() {
        customConfiguration = .default
        selectedPreset = .default
    }

    private func toggleAdvancedSettings() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showAdvancedSettings.toggle()
        }
    }
}

/// 质量预览行
struct QualityPreviewRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

/// 配置验证视图
struct ConfigurationValidationView: View {
    let configuration: VoiceRecorderConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: configuration.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(configuration.isValid ? .green : .orange)
                Text("配置验证")
                    .font(.headline)
            }

            if configuration.isValid {
                Text("配置有效")
                    .foregroundColor(.green)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("配置问题:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(configuration.validationErrors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(configuration.isValid ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

/// 存储使用情况视图
struct StorageUsageView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @State private var storageStats: StorageStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("存储使用情况")
                .font(.headline)

            if let stats = storageStats {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("录音文件数量:")
                        Spacer()
                        Text("\(stats.totalFiles)")
                    }

                    HStack {
                        Text("总占用空间:")
                        Spacer()
                        Text(viewModel.formatFileSize(stats.totalSize))
                    }

                    if stats.availableSpace > 0 {
                        HStack {
                            Text("可用空间:")
                            Spacer()
                            Text(viewModel.formatFileSize(stats.availableSpace))
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("正在加载...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            loadStorageStats()
        }
    }

    private func loadStorageStats() {
        Task {
            do {
                let stats = try await viewModel.recorder.getStorageStats()
                await MainActor.run {
                    storageStats = stats
                }
            } catch {
                print("Failed to load storage stats: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

// Remove the conflicting StorageStats definition since we're using the one from VoiceRecorder

// MARK: - Previews

struct ConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationView(viewModel: RecordingViewModel())
    }
}