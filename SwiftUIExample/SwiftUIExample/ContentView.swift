//
//  ContentView.swift
//  SwiftUIExample
//
//  Created by didong on 2025/9/19.
//

import SwiftUI
import VoiceRecorder

struct ContentView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @State private var selectedTab: Tab = .recorder
    @State private var showConfiguration = false

    enum Tab: String, CaseIterable {
        case recorder = "录音器"
        case files = "文件"

        var icon: String {
            switch self {
            case .recorder:
                return "mic"
            case .files:
                return "folder"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 录音器标签
            NavigationView {
                recorderView
            }
            .tabItem {
                Image(systemName: Tab.recorder.icon)
                Text(Tab.recorder.rawValue)
            }
            .tag(Tab.recorder)

            // 文件列表标签
            RecordingListView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: Tab.files.icon)
                    Text(Tab.files.rawValue)
                }
                .tag(Tab.files)
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("成功", isPresented: $viewModel.showSuccess) {
            Button("确定") { }
        } message: {
            Text(viewModel.successMessage)
        }
        .sheet(isPresented: $showConfiguration) {
            ConfigurationView(viewModel: viewModel)
        }
    }

    private var recorderView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 权限检查
                if !viewModel.hasMicrophonePermission {
                    PermissionRequestView(viewModel: viewModel)
                        .frame(maxHeight: .infinity)
                } else {
                    // 主录音界面
                    mainRecordingInterface
                }
            }
            .padding()
        }
        .navigationTitle("语音录制器")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showConfiguration = true }) {
                    Image(systemName: "gear")
                }
            }
        }
        .onAppear {
            viewModel.checkMicrophonePermission()
        }
    }

    private var mainRecordingInterface: some View {
        VStack(spacing: 24) {
            // 权限状态监控
            PermissionMonitorView(viewModel: viewModel)

            // 录音状态和时长
            recordingStatusSection

            // 音频可视化
            audioVisualizationSection

            // 录音控制按钮
            recordingControlsSection

            // 配置快速预设
            configurationPresetSection

            Spacer(minLength: 20)
        }
    }

    private var recordingStatusSection: some View {
        VStack(spacing: 16) {
            // 录音状态指示器
            RecordingStatusIndicator(
                isRecording: viewModel.isRecording,
                isPaused: viewModel.isPaused
            )

            // 录音时长显示
            Text(viewModel.formatDuration(viewModel.currentDuration))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentDuration)

            // 音频格式信息
            HStack(spacing: 12) {
                Label(
                    viewModel.currentConfiguration.audioFormat.description,
                    systemImage: "waveform"
                )

                Label(
                    viewModel.currentConfiguration.audioQuality.description,
                    systemImage: "quality.high"
                )
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var audioVisualizationSection: some View {
        VStack(spacing: 16) {
            // 圆形音频电平
            CircularAudioLevelView(
                audioLevel: viewModel.audioLevel,
                isRecording: viewModel.isRecording
            )

            // 波形显示
            AudioVisualizerView(
                audioLevels: viewModel.audioLevelHistory,
                isRecording: viewModel.isRecording
            )
            .frame(height: 80)
            .background(Color.black.opacity(0.05))
            .cornerRadius(12)

            // 音频电平条
            AudioLevelBarView(
                audioLevel: viewModel.audioLevel,
                isRecording: viewModel.isRecording
            )

            // 音频电平历史图表
            if viewModel.isRecording {
                AudioLevelChartView(
                    audioLevelHistory: viewModel.audioLevelHistory,
                    isRecording: viewModel.isRecording
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var recordingControlsSection: some View {
        VStack(spacing: 16) {
            // 主录音按钮
            HStack(spacing: 20) {
                // 取消按钮
                Button(action: cancelRecording) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.gray)
                        .clipShape(Circle())
                }
                .disabled(!viewModel.isRecording)
                .opacity(viewModel.isRecording ? 1.0 : 0.5)

                // 暂停/恢复按钮
                Button(action: togglePauseResume) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .disabled(!viewModel.isRecording)
                .opacity(viewModel.isRecording ? 1.0 : 0.5)

                // 录音/停止按钮
                Button(action: toggleRecording) {
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(viewModel.isRecording ? Color.red : Color.red)
                        .clipShape(Circle())
                        .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
                }
                .disabled(!viewModel.hasMicrophonePermission)
            }

            // 快捷操作
            if !viewModel.isRecording {
                HStack(spacing: 16) {
                    Button("快速录音 30秒") {
                        quickRecording(duration: 30)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("快速录音 60秒") {
                        quickRecording(duration: 60)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var configurationPresetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速配置")
                .font(.headline)
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ConfigurationPreset.allCases, id: \.self) { preset in
                    Button(action: {
                        viewModel.usePresetConfiguration(preset)
                    }) {
                        VStack(spacing: 8) {
                            Text(preset.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            Text(preset.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isRecording)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Actions

    private func toggleRecording() {
        Task {
            if viewModel.isRecording {
                await viewModel.stopRecording()
            } else {
                await viewModel.startRecording()
            }
        }
    }

    private func togglePauseResume() {
        Task {
            if viewModel.isPaused {
                await viewModel.resumeRecording()
            } else {
                await viewModel.pauseRecording()
            }
        }
    }

    private func cancelRecording() {
        Task {
            await viewModel.cancelRecording()
        }
    }

    private func quickRecording(duration: TimeInterval) {
        Task {
            do {
                try await viewModel.startRecording()

                // 等待指定时间后自动停止
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    Task {
                        await viewModel.stopRecording()
                    }
                }
            } catch {
                // 错误会通过 viewModel 的错误处理机制显示
            }
        }
    }
}

// MARK: - Previews

#Preview {
    ContentView()
}
