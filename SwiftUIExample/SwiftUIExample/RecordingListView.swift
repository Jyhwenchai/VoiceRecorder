//
//  RecordingListView.swift
//  SwiftUIExample
//
//  Created by Claude on 2025/9/19.
//

import SwiftUI
import AVFoundation

/// 录音文件列表视图
struct RecordingListView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @State private var selectedFile: RecordingFile? {
      didSet {
        print("update selected file: \(selectedFile)")
      }
    }
    @State private var showDeleteAlert = false
    @State private var fileToDelete: RecordingFile?
    @State private var showShareSheet = false
    @State private var fileToShare: RecordingFile?
    @StateObject private var audioPlayerManager = AudioPlayerManager()

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.recordingFiles.isEmpty {
                    emptyStateView
                } else {
                    recordingListContent
                }
            }
            .navigationTitle("录音文件")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("刷新") {
                        Task {
                            await viewModel.loadRecordingFiles()
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadRecordingFiles()
            }
            .alert("删除录音", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let file = fileToDelete {
                        Task {
                            await viewModel.deleteRecording(file)
                        }
                    }
                }
            } message: {
                Text("确定要删除这个录音文件吗？此操作无法撤销。")
            }
            .sheet(isPresented: $showShareSheet) {
                if let file = fileToShare {
                    ShareSheet(activityItems: [file.url])
                }
            }
            .sheet(item: $selectedFile) { file in
                AudioPlayerSheet(
                    file: file,
                    audioPlayerManager: audioPlayerManager,
                    isPresented: .constant(true)
                )
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("暂无录音文件")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("开始录音后，文件将出现在这里")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recordingListContent: some View {
        List {
            ForEach(viewModel.recordingFiles) { file in
                RecordingFileRow(
                    file: file,
                    audioPlayerManager: audioPlayerManager,
                    onPlay: { playFile(file) },
                    onShare: { shareFile(file) },
                    onDelete: { deleteFile(file) }
                )
            }
        }
        .listStyle(PlainListStyle())
    }

    private func playFile(_ file: RecordingFile) {
        selectedFile = file
    }

    private func shareFile(_ file: RecordingFile) {
        fileToShare = file
        showShareSheet = true
    }

    private func deleteFile(_ file: RecordingFile) {
        fileToDelete = file
        showDeleteAlert = true
    }
}

/// 录音文件行视图
struct RecordingFileRow: View {
    let file: RecordingFile
    let audioPlayerManager: AudioPlayerManager
    let onPlay: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    @State private var isPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                fileIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.headline)
                        .lineLimit(1)

                    HStack {
                        Text(formatDate(file.createdAt))
                        Spacer()
                        Text(formatFileSize(file.size))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    if let duration = file.duration {
                        Text("时长: \(formatDuration(duration))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                actionButtons
            }
            .padding(.vertical, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
        .onReceive(audioPlayerManager.$currentPlayingFile) { currentFile in
            isPlaying = currentFile?.url == file.url
        }
    }

    private var fileIcon: some View {
        Image(systemName: "waveform")
            .font(.title2)
            .foregroundColor(.blue)
            .frame(width: 40, height: 40)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            Menu {
                Button(action: onShare) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }

                Button(action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// 音频播放器视图
struct AudioPlayerView: View {
    let file: RecordingFile
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0

    var body: some View {
        VStack(spacing: 16) {
            Text(file.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                Button(action: rewind) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }

                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }

                Button(action: fastForward) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
        }
        .padding()
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            stopPlayer()
        }
    }

    private func setupPlayer() {
        do {
            player = try AVAudioPlayer(contentsOf: file.url)
            player?.prepareToPlay()
        } catch {
            print("Failed to setup player: \(error)")
        }
    }

    private func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }

        isPlaying.toggle()
    }

    private func rewind() {
        guard let player = player else { return }
        player.currentTime = max(0, player.currentTime - 15)
    }

    private func fastForward() {
        guard let player = player else { return }
        player.currentTime = min(player.duration, player.currentTime + 15)
    }

    private func stopPlayer() {
        player?.stop()
        isPlaying = false
    }
}

/// 分享表单
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 录音文件详情视图
struct RecordingFileDetailView: View {
    let file: RecordingFile
    @ObservedObject var viewModel: RecordingViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 文件信息
                VStack(alignment: .leading, spacing: 12) {
                    Label("文件名", systemImage: "doc")
                    Text(file.name)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                    Label("创建时间", systemImage: "calendar")
                    Text(formatDate(file.createdAt))
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                    Label("文件大小", systemImage: "archivebox")
                    Text(viewModel.formatFileSize(file.size))
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                    if let duration = file.duration {
                        Label("录音时长", systemImage: "clock")
                        Text(viewModel.formatDuration(duration))
                            .font(.body)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 播放器
                AudioPlayerView(file: file)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)

                Spacer()

                // 操作按钮
                VStack(spacing: 12) {
                    Button(action: shareFile) {
                        Label("分享文件", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: deleteFile) {
                        Label("删除文件", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .navigationTitle("录音详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func shareFile() {
        // 实现分享功能
    }

    private func deleteFile() {
        Task {
            await viewModel.deleteRecording(file)
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Audio Player Manager

/// 音频播放管理器
@MainActor
class AudioPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentPlayingFile: RecordingFile?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func loadFile(_ file: RecordingFile) {
        stop()

        do {
            player = try AVAudioPlayer(contentsOf: file.url)
            player?.prepareToPlay()
            currentPlayingFile = file
            duration = player?.duration ?? 0
            currentTime = 0
        } catch {
            print("Failed to load audio file: \(error)")
        }
    }

    func play() {
        guard let player = player else { return }

        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        isPlaying = false
        currentTime = 0
        stopTimer()
        currentPlayingFile = nil
    }

    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        player.currentTime = min(max(0, time), duration)
        currentTime = player.currentTime
    }

    func skipForward(_ seconds: TimeInterval = 15) {
        guard let player = player else { return }
        let newTime = min(player.currentTime + seconds, duration)
        player.currentTime = newTime
        currentTime = newTime
    }

    func skipBackward(_ seconds: TimeInterval = 15) {
        guard let player = player else { return }
        let newTime = max(player.currentTime - seconds, 0)
        player.currentTime = newTime
        currentTime = newTime
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.player else { return }

                self.currentTime = player.currentTime

                if !player.isPlaying && self.isPlaying {
                    // 播放结束
                    self.isPlaying = false
                    self.currentTime = 0
                    self.stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func cleanup() {
        stop()
    }
}

// MARK: - Audio Player Sheet

/// 音频播放器弹窗
struct AudioPlayerSheet: View {
    let file: RecordingFile
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 文件信息
                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text(file.name)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    VStack(spacing: 4) {
                        Text("文件大小: \(formatFileSize(file.size))")
                        Text("创建时间: \(formatDate(file.createdAt))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                // 进度条
                VStack(spacing: 8) {
                    HStack {
                        Text(formatTime(audioPlayerManager.currentTime))
                            .font(.caption)
                            .monospacedDigit()

                        Spacer()

                        Text(formatTime(audioPlayerManager.duration))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)

                    Slider(
                        value: Binding(
                            get: { audioPlayerManager.currentTime },
                            set: { audioPlayerManager.seek(to: $0) }
                        ),
                        in: 0...max(audioPlayerManager.duration, 1)
                    )
                    .accentColor(.blue)
                }

                // 播放控制
                HStack(spacing: 40) {
                    Button(action: { audioPlayerManager.skipBackward() }) {
                        Image(systemName: "gobackward.15")
                            .font(.title)
                            .foregroundColor(.primary)
                    }

                    Button(action: togglePlayPause) {
                        Image(systemName: audioPlayerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                    }

                    Button(action: { audioPlayerManager.skipForward() }) {
                        Image(systemName: "goforward.15")
                            .font(.title)
                            .foregroundColor(.primary)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("播放器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        audioPlayerManager.stop()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            audioPlayerManager.loadFile(file)
        }
        .onDisappear {
            audioPlayerManager.stop()
        }
    }

    private func togglePlayPause() {
        if audioPlayerManager.isPlaying {
            audioPlayerManager.pause()
        } else {
            audioPlayerManager.play()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
