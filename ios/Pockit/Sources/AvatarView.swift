import SwiftUI
import AVFoundation
import UIKit

/// Cara de Marisol en un círculo. Cuando cambia el mood, reproduce el clip actual→neutral
/// y luego neutral→nuevo, pegados en una sola composición pa' que no haya cortes.
struct AvatarView: View {
    let mood: Mood
    var size: CGFloat = 46
    var spoilerDot = false

    @StateObject private var player = AvatarPlayer()
    @State private var breathe = false

    /// Dónde queda la cara dentro del cuadro 9:16 (0 = arriba, 1 = abajo).
    private let faceCenterY: CGFloat = 0.41
    private let zoom: CGFloat = 2.3

    var body: some View {
        let videoW = size * zoom
        let videoH = videoW * 16 / 9
        let offsetY = size / 2 - faceCenterY * videoH

        ZStack {
            Image(uiImage: AvatarPlayer.still(player.stillMood))
                .resizable()
                .frame(width: videoW, height: videoH)
                .offset(y: offsetY + (videoH - size) / 2)
            PlayerLayerView(player: player.player)
                .frame(width: videoW, height: videoH)
                .offset(y: offsetY + (videoH - size) / 2)
                .opacity(player.isPlaying ? 1 : 0)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.hot, lineWidth: 2))
        .scaleEffect(breathe ? 1.025 : 1.0)
        .overlay(alignment: .bottomTrailing) {
            if spoilerDot {
                Circle().fill(Theme.sunset)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .overlay(Circle().stroke(Theme.night, lineWidth: 2))
            }
        }
        .onAppear {
            player.show(mood, animated: false)
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathe = true }
        }
        .onChange(of: mood) { _, newMood in player.show(newMood, animated: true) }
        .accessibilityLabel("Marisol, \(mood.rawValue)")
    }
}

@MainActor
final class AvatarPlayer: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var stillMood: Mood = .neutral
    @Published private(set) var isPlaying = false

    private var current: Mood = .neutral
    private var pending: Mood?
    private var endObserver: NSObjectProtocol?

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .pause
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    static func still(_ mood: Mood) -> UIImage {
        if let url = Bundle.main.url(forResource: "Face_\(mood.rawValue)", withExtension: "jpg"),
           let img = UIImage(contentsOfFile: url.path) { return img }
        return UIImage()
    }

    private static func clip(_ from: Mood, _ to: Mood) -> URL? {
        Bundle.main.url(forResource: "Marisol_\(from.rawValue)_a_\(to.rawValue)", withExtension: "mp4")
    }

    func show(_ mood: Mood, animated: Bool) {
        guard animated else {
            current = mood
            stillMood = mood
            return
        }
        if isPlaying { pending = mood; return }
        guard mood != current else { return }

        var urls: [URL] = []
        if current != .neutral, let u = Self.clip(current, .neutral) { urls.append(u) }
        if mood != .neutral, let u = Self.clip(.neutral, mood) { urls.append(u) }
        let target = mood
        guard !urls.isEmpty else { current = target; stillMood = target; return }

        isPlaying = true
        Task {
            guard let item = await Self.composedItem(urls) else {
                finish(target)
                return
            }
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.finish(target) }
            }
            player.replaceCurrentItem(with: item)
            player.playImmediately(atRate: 1.8)
        }
    }

    private func finish(_ mood: Mood) {
        current = mood
        stillMood = mood
        isPlaying = false
        if let next = pending {
            pending = nil
            show(next, animated: true)
        }
    }

    private static func composedItem(_ urls: [URL]) async -> AVPlayerItem? {
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video,
                                                      preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        var cursor = CMTime.zero
        for url in urls {
            let asset = AVURLAsset(url: url)
            guard let source = try? await asset.loadTracks(withMediaType: .video).first,
                  let duration = try? await asset.load(.duration) else { continue }
            do {
                try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: cursor)
                cursor = cursor + duration
            } catch { continue }
        }
        return cursor == .zero ? nil : AVPlayerItem(asset: composition)
    }
}

/// AVPlayerLayer dentro de SwiftUI.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let v = PlayerUIView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspectFill
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
