//
//  PermissionRequestView.swift
//  SwiftUIExample
//
//  Created by Claude on 2025/9/19.
//

import SwiftUI
import AVFoundation

/// 权限请求视图
struct PermissionRequestView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            permissionIcon

            permissionMessage

            actionButtons

            Spacer()

            additionalInfo
        }
        .padding(.horizontal, 30)
        .background(Color(UIColor.systemBackground))
    }

    private var permissionIcon: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
                .background(
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 140, height: 140)
                )

            Text("需要麦克风权限")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
    }

    private var permissionMessage: some View {
        VStack(spacing: 12) {
            Text("为了录制音频，我们需要访问您的麦克风")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)

            Text("您的隐私很重要，录音文件只会保存在您的设备上")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: requestPermission) {
                HStack {
                    Image(systemName: "mic")
                    Text("允许麦克风访问")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            if !viewModel.hasMicrophonePermission {
                Button(action: openSettings) {
                    HStack {
                        Image(systemName: "gear")
                        Text("打开设置")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
        }
    }

    private var additionalInfo: some View {
        VStack(spacing: 8) {
            Text("为什么需要麦克风权限？")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                PermissionReasonRow(
                    icon: "waveform",
                    text: "录制高质量音频"
                )

                PermissionReasonRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "实时显示音频电平"
                )

                PermissionReasonRow(
                    icon: "lock.shield",
                    text: "所有数据保存在本地"
                )
            }
        }
    }

    private func requestPermission() {
        Task {
            await viewModel.requestMicrophonePermission()
        }
    }

    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

/// 权限原因行
struct PermissionReasonRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

/// 权限状态指示器
struct PermissionStatusView: View {
    let hasPermission: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: hasPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(hasPermission ? .green : .orange)

            Text(hasPermission ? "麦克风权限已授予" : "需要麦克风权限")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(hasPermission ? .green : .orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            (hasPermission ? Color.green : Color.orange).opacity(0.1)
        )
        .cornerRadius(12)
    }
}

/// 权限检查助手
struct PermissionHelper {
    /// 检查麦克风权限状态
    static func checkMicrophonePermission() async -> AVAudioSession.RecordPermission {
        return AVAudioSession.sharedInstance().recordPermission
    }

    /// 请求麦克风权限
    static func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// 权限状态描述
    static func permissionDescription(for permission: AVAudioSession.RecordPermission) -> String {
        switch permission {
        case .granted:
            return "已授予"
        case .denied:
            return "已拒绝"
        case .undetermined:
            return "未确定"
        @unknown default:
            return "未知"
        }
    }

    /// 是否需要显示权限请求
    static func shouldShowPermissionRequest(for permission: AVAudioSession.RecordPermission) -> Bool {
        return permission != .granted
    }

    /// 是否可以打开设置
    @MainActor
    static func canOpenSettings() -> Bool {
        return UIApplication.shared.canOpenURL(URL(string: UIApplication.openSettingsURLString)!)
    }

    /// 打开设置
    @MainActor
    static func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

/// 权限教学视图
struct PermissionTutorialView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    tutorialHeader

                    tutorialSteps

                    tutorialFooter
                }
                .padding()
            }
            .navigationTitle("如何授予权限")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private var tutorialHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("权限设置指南")
                .font(.title2)
                .fontWeight(.bold)

            Text("按照以下步骤在设置中允许麦克风访问")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }

    private var tutorialSteps: some View {
        VStack(alignment: .leading, spacing: 16) {
            TutorialStepView(
                stepNumber: 1,
                title: "打开设置应用",
                description: "在主屏幕找到并点击\"设置\"应用"
            )

            TutorialStepView(
                stepNumber: 2,
                title: "找到隐私与安全性",
                description: "向下滚动找到\"隐私与安全性\"选项"
            )

            TutorialStepView(
                stepNumber: 3,
                title: "选择麦克风",
                description: "在隐私设置中点击\"麦克风\"选项"
            )

            TutorialStepView(
                stepNumber: 4,
                title: "启用应用权限",
                description: "找到本应用并打开麦克风权限开关"
            )
        }
    }

    private var tutorialFooter: some View {
        VStack(spacing: 12) {
            Button("直接打开设置") {
                PermissionHelper.openSettings()
                isPresented = false
            }
            .buttonStyle(.borderedProminent)

            Text("设置完成后返回应用即可开始录音")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

/// 教学步骤视图
struct TutorialStepView: View {
    let stepNumber: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(stepNumber)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

/// 权限状态监控视图
struct PermissionMonitorView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @State private var showTutorial = false

    var body: some View {
        if !viewModel.hasMicrophonePermission {
            VStack(spacing: 12) {
                PermissionStatusView(hasPermission: false)

                HStack(spacing: 8) {
                    Button("重新检查") {
                        viewModel.checkMicrophonePermission()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("查看教程") {
                        showTutorial = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .sheet(isPresented: $showTutorial) {
                PermissionTutorialView(isPresented: $showTutorial)
            }
        } else {
            PermissionStatusView(hasPermission: true)
        }
    }
}

// MARK: - Previews

struct PermissionRequestView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PermissionRequestView(viewModel: RecordingViewModel())

            PermissionTutorialView(isPresented: .constant(true))

            PermissionMonitorView(viewModel: RecordingViewModel())
                .padding()
        }
    }
}