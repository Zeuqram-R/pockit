import SwiftUI
import WebKit

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @State private var showSettings = false
    @State private var showLoading = true

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(onSettings: { showSettings = true })
                WebContainer(webView: web.webView)
                    .ignoresSafeArea(.container, edges: .bottom)
            }

            if showLoading {
                LoadingView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(web)
        }
        .task {
            // Mínimo de 1.2 s pa' que la pantalla de carga no parpadee.
            try? await Task.sleep(for: .seconds(1.2))
            while !web.hasLoadedOnce { try? await Task.sleep(for: .milliseconds(150)) }
            withAnimation(.easeOut(duration: 0.5)) { showLoading = false }
        }
    }
}

/// Barra superior de la fase 1: nombre de la app y botón de ajustes.
/// En la fase 2 aquí va el avatar de Marisol y el switch de spoilers.
struct TopBar: View {
    let onSettings: () -> Void
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack {
            DisplayTitle(text: "POCKIT", size: 26)
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.sunset)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(settings.t.settings)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Theme.night)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.purple.opacity(0.6)).frame(height: 1)
        }
    }
}

struct WebContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
