import SwiftUI
import AVFoundation
import UIKit

/// Cara de Marisol en un círculo. Al cambiar de mood: clip actual→neutral y, mientras ella
/// está en neutral, un fundido suave al clip neutral→nuevo (dos reproductores), sin cortes.
struct AvatarView: View {
    let mood: Mood
    var size: CGFloat = 52
    var spoilerDot = false
    var typing = false

    @StateObject private var player = AvatarPlayer()
    @State private var breathe = false

    /// Encuadre dentro del cuadro 9:16: centro de la cabeza y cuánto se agranda.
    static let faceCenterY: CGFloat = 0.38
    static let zoom: CGFloat = 1.0

    var body: some View {
        let videoW = size * Self.zoom
        let videoH = videoW * 16 / 9
        let offsetY = videoH * (0.5 - Self.faceCenterY)

        ZStack {
            Image(uiImage: AvatarPlayer.still(player.stillMood))
                .resizable()
                .frame(width: videoW, height: videoH)
            PlayerLayerView(player: player.playerA)
                .frame(width: videoW, height: videoH)
                .opacity(player.opacityA)
            PlayerLayerView(player: player.playerB)
                .frame(width: videoW, height: videoH)
                .opacity(player.opacityB)
        }
        .offset(y: offsetY)
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.hot, lineWidth: 2))
        .scaleEffect(breathe ? 1.02 : 1.0)
        .overlay(alignment: .bottomTrailing) {
            if spoilerDot {
                Circle().fill(Theme.sunset)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .overlay(Circle().stroke(Theme.night, lineWidth: 2))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if typing {
                TypingBadge()
                    .offset(x: 30, y: 4)
                    .transition(.scale(scale: 0.4, anchor: .topLeading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: typing)
        .onAppear {
            player.show(mood, animated: false)
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { breathe = true }
        }
        .onChange(of: mood) { _, newMood in player.show(newMood, animated: true) }
        .accessibilityLabel("Marisol, \(mood.rawValue)")
    }
}

@MainActor
final class AvatarPlayer: ObservableObject {
    let playerA = AVPlayer()
    let playerB = AVPlayer()
    @Published private(set) var stillMood: Mood = .neutral
    @Published private(set) var opacityA: Double = 0
    @Published private(set) var opacityB: Double = 0

    /// Velocidad de los clips (1 = normal).
    private let rate: Float = 1.25
    /// Punto del primer clip donde ella ya quedó en neutral y arranca el segundo.
    private let handoff = 0.74
    private let fade = 0.45

    private var busy = false
    private var current: Mood = .neutral
    private var pending: Mood?
    private var timeObservers: [(AVPlayer, Any)] = []
    private var endObservers: [NSObjectProtocol] = []

    init() {
        for p in [playerA, playerB] {
            p.isMuted = true
            p.actionAtItemEnd = .pause
            p.preventsDisplaySleepDuringVideoPlayback = false
        }
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
        if busy { pending = mood; return }
        guard mood != current else { return }

        let first = current != .neutral ? Self.clip(current, .neutral) : nil
        let second = mood != .neutral ? Self.clip(.neutral, mood) : nil
        let target = mood
        busy = true

        switch (first, second) {
        case let (a?, b?):
            play(a, on: playerA, crossfade: false, handoffEarly: true) { [weak self] in
                guard let self else { return }
                self.play(b, on: self.playerB, crossfade: true, handoffEarly: false) { [weak self] in
                    self?.finish(target)
                }
            }
        case let (a?, nil):
            play(a, on: playerA, crossfade: false, handoffEarly: false) { [weak self] in self?.finish(target) }
        case let (nil, b?):
            play(b, on: playerB, crossfade: false, handoffEarly: false) { [weak self] in self?.finish(target) }
        default:
            finish(target)
        }
    }

    /// Reproduce un clip. `then` se llama en el punto de relevo (o casi al final) pa' encadenar lo siguiente.
    private func play(_ url: URL, on player: AVPlayer, crossfade: Bool, handoffEarly: Bool,
                      then: @escaping @MainActor () -> Void) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        var fired = false
        let fire: @MainActor () -> Void = {
            guard !fired else { return }
            fired = true
            then()
        }

        Task {
            let duration = (try? await item.asset.load(.duration)) ?? CMTime(seconds: 2.8, preferredTimescale: 600)
            let cut = CMTimeMultiplyByFloat64(duration, multiplier: handoffEarly ? handoff : 0.97)
            let boundary = player.addBoundaryTimeObserver(forTimes: [NSValue(time: cut)], queue: .main) {
                Task { @MainActor in fire() }
            }
            timeObservers.append((player, boundary))
            let end = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
                Task { @MainActor in fire() }
            }
            endObservers.append(end)

            player.playImmediately(atRate: rate)
            let isA = player === playerA
            if crossfade {
                // Fundido del clip anterior al nuevo mientras los dos están en neutral.
                withAnimation(.easeInOut(duration: fade)) {
                    if isA { opacityA = 1; opacityB = 0 } else { opacityB = 1; opacityA = 0 }
                }
            } else {
                // El primer cuadro es igual a la foto fija: aparece sin que se note.
                if isA { opacityA = 1 } else { opacityB = 1 }
            }
        }
    }

    private func finish(_ mood: Mood) {
        current = mood
        stillMood = mood
        Task {
            // Espera a que termine el clip: el último cuadro es igual a la foto fija.
            try? await Task.sleep(for: .seconds(0.6))
            opacityA = 0
            opacityB = 0
            clearObservers()
            busy = false
            if let next = pending {
                pending = nil
                show(next, animated: true)
            }
        }
    }

    private func clearObservers() {
        for (player, token) in timeObservers { player.removeTimeObserver(token) }
        for token in endObservers { NotificationCenter.default.removeObserver(token) }
        timeObservers.removeAll()
        endObservers.removeAll()
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


/// Los tres puntitos de "Marisol está escribiendo", pegados a su retrato cuando la caja de escribir
/// ocupa todo el chat y ya no hay dónde mostrarlos abajo.
struct TypingBadge: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.32, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle().fill(Color.white)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1 : 0.45)
                    .offset(y: phase == i ? -1.5 : 0)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(Capsule().fill(.ultraThinMaterial))
        .background(Capsule().fill(Theme.nightDeep.opacity(0.55)))
        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .onReceive(timer) { _ in withAnimation(.easeInOut(duration: 0.25)) { phase = (phase + 1) % 3 } }
        .accessibilityLabel("Marisol está escribiendo")
    }
}
