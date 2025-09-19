//
//  AudioVisualizerView.swift
//  SwiftUIExample
//
//  Created by Claude on 2025/9/19.
//

import SwiftUI

/// 音频波形可视化视图
struct AudioVisualizerView: View {
    let audioLevels: [Float]
    let isRecording: Bool
    let animated: Bool

    @State private var animationOffset: CGFloat = 0

    init(audioLevels: [Float], isRecording: Bool = false, animated: Bool = true) {
        self.audioLevels = audioLevels
        self.isRecording = isRecording
        self.animated = animated
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(audioLevels.enumerated()), id: \.offset) { index, level in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor(for: level))
                        .frame(
                            width: barWidth(geometry: geometry),
                            height: barHeight(for: level, maxHeight: geometry.size.height)
                        )
                        .animation(
                            animated ? .easeInOut(duration: 0.1) : .none,
                            value: level
                        )
                        .scaleEffect(
                            isRecording ? 1.0 + sin((animationOffset + Double(index)) * 0.5) * 0.1 : 1.0
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if animated && isRecording {
                startAnimation()
            }
        }
        .onChange(of: isRecording) { recording in
            if recording && animated {
                startAnimation()
            } else {
                animationOffset = 0
            }
        }
    }

    private func barWidth(geometry: GeometryProxy) -> CGFloat {
        let totalSpacing = CGFloat(audioLevels.count - 1) * 2
        let availableWidth = geometry.size.width - totalSpacing
        return max(1, availableWidth / CGFloat(audioLevels.count))
    }

    private func barHeight(for level: Float, maxHeight: CGFloat) -> CGFloat {
        let minHeight: CGFloat = 2
        let normalizedLevel = CGFloat(max(0, min(1, level)))
        return max(minHeight, normalizedLevel * maxHeight)
    }

    private func barColor(for level: Float) -> Color {
        if level < 0.3 {
            return .green
        } else if level < 0.7 {
            return .yellow
        } else {
            return .red
        }
    }

    private func startAnimation() {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            animationOffset = .pi * 2
        }
    }
}

/// 圆形音频电平指示器
struct CircularAudioLevelView: View {
    let audioLevel: Float
    let isRecording: Bool

    private let gradient = LinearGradient(
        colors: [.green, .yellow, .red],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)

            // 音频电平圆环
            Circle()
                .trim(from: 0, to: CGFloat(audioLevel))
                .stroke(gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.1), value: audioLevel)

            // 中心文本
            VStack {
                Text("\(Int(audioLevel * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(isRecording ? "录音中" : "准备")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120, height: 120)
        .scaleEffect(isRecording ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isRecording)
    }
}

/// 简化的音频电平条
struct AudioLevelBarView: View {
    let audioLevel: Float
    let isRecording: Bool

    var body: some View {
        HStack {
            Text("音量")
                .font(.caption)
                .foregroundColor(.secondary)

            ProgressView(value: audioLevel, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: barColor))
                .frame(height: 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(3)

            Text("\(Int(audioLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .animation(.easeInOut(duration: 0.1), value: audioLevel)
    }

    private var barColor: Color {
        if audioLevel < 0.3 {
            return .green
        } else if audioLevel < 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
}

/// 音频电平历史图表
struct AudioLevelChartView: View {
    let audioLevelHistory: [Float]
    let isRecording: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("音频电平历史")
                .font(.caption)
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                Path { path in
                    guard !audioLevelHistory.isEmpty else { return }

                    let stepWidth = geometry.size.width / CGFloat(audioLevelHistory.count - 1)
                    let maxHeight = geometry.size.height

                    for (index, level) in audioLevelHistory.enumerated() {
                        let x = CGFloat(index) * stepWidth
                        let y = maxHeight - (CGFloat(level) * maxHeight)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .animation(.easeInOut(duration: 0.1), value: audioLevelHistory)
            }
            .frame(height: 60)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

/// 录音状态指示器
struct RecordingStatusIndicator: View {
    let isRecording: Bool
    let isPaused: Bool

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .scaleEffect(pulseScale)
                .animation(
                    isRecording && !isPaused ?
                        .easeInOut(duration: 1).repeatForever(autoreverses: true) :
                        .none,
                    value: pulseScale
                )

            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .onAppear {
            if isRecording && !isPaused {
                pulseScale = 1.3
            }
        }
        .onChange(of: isRecording) { recording in
            if recording && !isPaused {
                pulseScale = 1.3
            } else {
                pulseScale = 1.0
            }
        }
        .onChange(of: isPaused) { paused in
            if !paused && isRecording {
                pulseScale = 1.3
            } else {
                pulseScale = 1.0
            }
        }
    }

    private var statusColor: Color {
        if isRecording {
            return isPaused ? .orange : .red
        } else {
            return .gray
        }
    }

    private var statusText: String {
        if isRecording {
            return isPaused ? "已暂停" : "录音中"
        } else {
            return "准备就绪"
        }
    }
}

// MARK: - Previews

struct AudioVisualizerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AudioVisualizerView(
                audioLevels: Array(repeating: 0.5, count: 20),
                isRecording: true
            )
            .frame(height: 60)

            CircularAudioLevelView(audioLevel: 0.6, isRecording: true)

            AudioLevelBarView(audioLevel: 0.7, isRecording: true)

            AudioLevelChartView(
                audioLevelHistory: (0..<50).map { _ in Float.random(in: 0...1) },
                isRecording: true
            )

            RecordingStatusIndicator(isRecording: true, isPaused: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}