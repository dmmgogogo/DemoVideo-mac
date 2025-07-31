//
//  ContentView.swift
//  DemoVideo
//
//  Created by mmx on 2025/7/30.
//

import SwiftUI
import AVKit
import AVFoundation
import AppKit

struct ContentView: View {
    @State private var urlText: String = ""
    @State private var player: AVPlayer?
    @State private var showingPlayer = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var loadingMessage = "准备播放..."
    
    var body: some View {
        VStack(spacing: 16) {
            Text("M3U8 视频播放器")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            // URL输入框和复制按钮
            TextEditor(text: $urlText)
                .frame(height: 300)
                .frame(maxWidth: 600)
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .font(.system(size: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if urlText.isEmpty {
                        Text("请输入或粘贴M3U8链接")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
            
            VStack(spacing: 12) {
                Button(action: copyFromClipboard) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("从剪切板粘贴")
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
                    .frame(maxWidth: 200)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    print("🎯 播放按钮被点击")
                    print("🎯 点击前isLoading状态: \(isLoading)")
                    playVideo()
                    print("🎯 点击后isLoading状态: \(isLoading)")
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text(loadingMessage)
                                .fontWeight(.medium)
                        } else {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                            Text("播放视频")
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .frame(maxWidth: 200)
                    .background(isLoading ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .opacity(isLoading ? 0.8 : 1.0)
                }
                .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                .onChange(of: isLoading) { oldValue, newValue in
                    print("🎯 isLoading状态变化: \(newValue)")
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(minWidth: 400, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .multilineTextAlignment(.leading)
        .sheet(isPresented: $showingPlayer) {
            if let player = player {
                VideoPlayerView(player: player, isPresented: $showingPlayer)
                    .frame(width: 800, height: 500)
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
                .font(.system(size: 14))
        }
        .onAppear {
            // configureAVAudioSession() // macOS 不需要
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    private func configureAVAudioSession() {
        // macOS 不支持 AVAudioSession，故此处注释或移除
        /*
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
            print("音频会话配置成功")
        } catch {
            print("音频会话配置失败: \(error.localizedDescription)")
        }
        */
    }
    
    private func copyFromClipboard() {
        if let clipboardString = NSPasteboard.general.string(forType: .string) {
            urlText = clipboardString
            // showAlert(message: "已从剪切板复制内容")
        } else {
            // showAlert(message: "剪切板中没有文本内容")
        }
    }
    
    private func playVideo() {
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            showAlert(message: "请输入视频链接")
            return
        }
        
        guard let url = URL(string: trimmedURL) else {
            showAlert(message: "无效的URL链接")
            return
        }
        
        // 立即设置loading状态 - 确保UI立即更新
        print("🔄 设置loading状态为true")
        isLoading = true
        loadingMessage = "正在加载..."
        
        print("准备播放URL: \(trimmedURL)")
        print("🔄 当前isLoading状态: \(isLoading)")
        
        // 重新配置音频会话
        // configureAVAudioSession() // macOS 不需要
        
        // 清理之前的播放器 - 但不重置loading状态
        cleanupPlayerOnly()
        
        print("🔄 清理完成后isLoading状态: \(isLoading)")
        
        // 使用 AVPlayerItem(url:) 替代 AVURLAsset(url:)
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 5.0
        
        player = AVPlayer(playerItem: playerItem)
        
        // 配置播放器，尽可能与 iOS 一致
        player?.allowsExternalPlayback = true
        player?.automaticallyWaitsToMinimizeStalling = false
        
        print("🔄 播放器创建完成，isLoading: \(isLoading)")
        
        // 简化的状态监控
        setupSimpleObservers()
        
        // 设置超时保护
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            if self.isLoading {
                print("播放超时")
                self.isLoading = false // 超时时重新启用按钮
                self.showAlert(message: "播放超时，请检查网络连接或尝试其他链接")
                self.cleanupPlayer()
            }
        }
        
        // 延迟检查状态并播放
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🔄 准备检查播放状态，当前isLoading: \(self.isLoading)")
            self.checkAndPlay()
        }
    }
    
    private func setupSimpleObservers() {
        guard let player = player else { return }
        
        // 播放失败
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { notification in
            print("播放失败通知")
            self.isLoading = false
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                let errorMessage = self.formatError(error)
                print("播放失败详细信息: \(errorMessage)")
                self.showAlert(message: "播放失败:\n\(errorMessage)")
            } else {
                self.showAlert(message: "播放失败，请检查网络或重试")
            }
        }
        
        // 播放完毕
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            print("播放完毕")
        }
    }
    
    private func formatError(_ error: Error) -> String {
        let nsError = error as NSError
        var errorMessage = "错误域: \(nsError.domain)\n"
        errorMessage += "错误代码: \(nsError.code)\n"
        
        // 特殊处理常见的错误代码
        switch nsError.code {
        case -12642:
            errorMessage += "描述: 网络连接问题或媒体格式不支持\n"
            errorMessage += "建议: 检查网络连接，尝试使用其他网络或稍后重试"
        case -11800:
            errorMessage += "描述: 媒体文件损坏或无法解码\n"
            errorMessage += "建议: 检查视频链接是否有效"
        case -12645:
            errorMessage += "描述: 网络超时\n"
            errorMessage += "建议: 检查网络连接速度，尝试稍后重试"
        case -12660:
            errorMessage += "描述: 无法连接到服务器\n"
            errorMessage += "建议: 服务器可能暂时不可用，请稍后重试"
        case -12938:
            errorMessage += "描述: 播放被中断\n"
            errorMessage += "建议: 重新尝试播放"
        default:
            if !nsError.localizedDescription.isEmpty {
                errorMessage += "描述: \(nsError.localizedDescription)"
            } else {
                errorMessage += "描述: 未知错误"
            }
        }
        
        return errorMessage
    }
    
    private func checkAndPlay() {
        guard let player = player, let currentItem = player.currentItem else {
            print("播放器或播放项为空")
            isLoading = false // 确保重新启用按钮
            showAlert(message: "播放器初始化失败")
            return
        }
        
        print("当前播放项状态: \(currentItem.status.rawValue)")
        if let error = currentItem.error {
            let errorMessage = formatError(error)
            print("播放项错误详细信息: \(errorMessage)")
        }
        
        switch currentItem.status {
        case .readyToPlay:
            print("播放项已准备好")
            isLoading = false // 播放成功，重新启用按钮
            showingPlayer = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                player.play()
                print("开始播放，播放速率: \(player.rate)")
                
                // 检查播放是否真正开始
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if player.rate == 0.0 {
                        print("播放可能未成功启动，尝试再次播放")
                        player.play()
                        
                        // 如果还是不能播放，显示错误
                        // DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        //     if player.rate == 0.0 {
                        //         print("播放启动失败")
                        //         self.showAlert(message: "播放启动失败，请重试或检查网络连接")
                        //     }
                        // }
                    }
                }
            }
            
        case .failed:
            print("播放项加载失败")
            isLoading = false // 播放失败，重新启用按钮
            if let error = currentItem.error {
                let errorMessage = formatError(error)
                print("播放失败详细信息: \(errorMessage)")
                showAlert(message: "视频加载失败:\n\(errorMessage)")
            } else {
                showAlert(message: "视频加载失败，请检查链接或网络")
            }
            
        case .unknown:
            print("播放项状态未知，继续等待...")
            loadingMessage = "正在解析视频..."
            
            // 继续等待，但不重新启用按钮
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.isLoading {
                    self.checkAndPlay()
                }
            }
            
        @unknown default:
            print("未知的播放项状态")
            isLoading = false // 异常情况，重新启用按钮
            showAlert(message: "播放器状态异常")
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    // 只清理播放器，不影响loading状态
    private func cleanupPlayerOnly() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        NotificationCenter.default.removeObserver(self)
        player = nil
        print("播放器已清理（保持loading状态）")
    }
    
    // 完全清理，包括重置loading状态
    private func cleanupPlayer() {
        isLoading = false // 清理时确保重新启用按钮
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        NotificationCenter.default.removeObserver(self)
        player = nil
        print("播放器已清理，按钮已重新启用")
    }
}

// 自定义视频播放器视图
struct VideoPlayerView: View {
    let player: AVPlayer
    @Binding var isPresented: Bool
    @State private var showControls = true
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VideoPlayer(player: player)
                .ignoresSafeArea()
            
            if showControls {
                VStack {
                    HStack {
                        Spacer()
                        Button("完成") {
                            cleanup()
                            isPresented = false
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .onTapGesture {
            showControls.toggle()
        }
        .onAppear {
            // 控制栏3秒后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showControls = false
            }
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func cleanup() {
        print("清理视频播放器")
        player.pause()
        NotificationCenter.default.removeObserver(self)
    }
}

#Preview {
    ContentView()
}
