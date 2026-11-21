import SwiftUI

/// Pantalla de carga: silueta de Marisol con el sol y las palmeras mientras abre claude.ai.
struct LoadingView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @State private var breathe = false

    var body: some View {
        GeometryReader { geo in
            let artSide = min(geo.size.width * 1.35, geo.size.height * 0.72)
            ZStack(alignment: .bottom) {
                Color(hex: 0x4A1B63).ignoresSafeArea()

                VStack(spacing: 0) {
                    Image("LoadingArt")
                        .resizable()
                        .scaledToFill()
                        .frame(width: artSide, height: artSide)
                        .frame(width: geo.size.width, height: artSide)
                        .clipped()
                        .scaleEffect(breathe ? 1.02 : 1.0)
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea(edges: .top)

                // Fundido del arte hacia el panel de abajo.
                LinearGradient(colors: [.clear, Theme.night], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                    .offset(y: -bottomHeight + 1)

                bottomPanel
                    .frame(height: bottomHeight)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    private let bottomHeight: CGFloat = 220

    private var bottomPanel: some View {
        VStack(spacing: 14) {
            DisplayTitle(text: "POCKIT", size: 54)
            if web.loadError {
                Text(settings.t.loadFailed)
                    .font(Theme.text(15, .medium, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lilac)
                    .multilineTextAlignment(.center)
                Button(settings.t.retry) { web.loadHome() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.switchPink)
            } else {
                Text(settings.t.loading)
                    .font(Theme.text(15, .medium, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lilac)
                ProgressBar(value: max(0.06, web.progress))
                    .frame(width: 180, height: 6)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 18)
        .background(Theme.night.ignoresSafeArea(edges: .bottom))
    }
}

struct ProgressBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.nightDeep)
                Capsule().fill(Theme.switchPink)
                    .frame(width: geo.size.width * min(1, max(0, value)))
                    .animation(.easeOut(duration: 0.3), value: value)
            }
        }
        .accessibilityElement()
        .accessibilityValue("\(Int(value * 100))%")
    }
}
