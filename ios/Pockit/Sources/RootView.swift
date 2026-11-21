import SwiftUI
import WebKit

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var state: PockitState
    @EnvironmentObject private var skin: SkinManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var showLoading = true

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(onSettings: { showSettings = true })
                QuickBar()
                WebContainer(webView: web.webView)
                    .ignoresSafeArea(.container, edges: .bottom)
            }

            if let problem = web.sendProblem {
                SendProblemBanner(reason: problem) { web.sendProblem = nil }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            if showLoading {
                LoadingView()
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
        .animation(.easeOut(duration: 0.25), value: web.sendProblem)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(web)
                .environmentObject(state)
                .environmentObject(skin)
        }
        .onAppear {
            web.onTags = { items in state.handle(items: items) }
            web.setPrefix(state.prefix(lang: settings.language))
            skin.attach(web)
        }
        .onChange(of: settings.languageRaw) { _, _ in
            web.setPrefix(state.prefix(lang: settings.language))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await skin.refresh() } }
        }
        .task {
            // Mínimo de 1.2 s pa' que la pantalla de carga no parpadee.
            try? await Task.sleep(for: .seconds(1.2))
            while !web.hasLoadedOnce { try? await Task.sleep(for: .milliseconds(150)) }
            withAnimation(.easeOut(duration: 0.5)) { showLoading = false }
        }
    }
}

/// Barra superior: cara de Marisol, progreso, switch de spoilers y ajustes.
struct TopBar: View {
    let onSettings: () -> Void
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var state: PockitState
    @State private var confirmSpoilers = false

    var body: some View {
        let t = settings.t
        HStack(spacing: 10) {
            AvatarView(mood: state.mood, size: 46, spoilerDot: state.lastReplyHadSpoiler)

            VStack(alignment: .leading, spacing: 1) {
                DisplayTitle(text: "MARISOL", size: 22)
                Text(state.progressSummary ?? t.noProgressYet)
                    .font(.caption)
                    .foregroundStyle(Theme.lilac)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                confirmSpoilers = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: state.spoilersOn ? "eye.fill" : "eye.slash.fill")
                    Text(state.spoilersOn ? t.spoilersOn : t.spoilersOff)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(state.spoilersOn ? Theme.night : Theme.cream)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(Capsule().fill(state.spoilersOn ? Theme.sunset : Theme.purple))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.spoilersOn ? t.spoilersOn : t.spoilersOff)

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.sunset)
                    .frame(width: 40, height: 44)
            }
            .accessibilityLabel(t.settings)
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Theme.night)
        .confirmationDialog(state.spoilersOn ? t.spoilersTurnOffQ : t.spoilersTurnOnQ,
                            isPresented: $confirmSpoilers, titleVisibility: .visible) {
            Button(state.spoilersOn ? t.spoilersTurnOff : t.spoilersTurnOn) {
                state.spoilersOn.toggle()
                // Los comandos van en español: así los reconocen las instrucciones de Marisol.
                web.send(state.spoilersOn ? "activa spoilers" : "desactiva spoilers")
            }
            Button(t.cancel, role: .cancel) {}
        }
    }
}

struct SendProblemBanner: View {
    let reason: String
    let onClose: () -> Void
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(Theme.sunset)
            Text(settings.t.sendFailed)
                .font(.footnote)
                .foregroundStyle(Theme.cream)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark").foregroundStyle(Theme.lilac).frame(width: 32, height: 32)
            }
            .accessibilityLabel("OK")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.nightDeep))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.purple, lineWidth: 1))
        .padding(.horizontal, 16)
        .task {
            try? await Task.sleep(for: .seconds(5))
            onClose()
        }
        .accessibilityHint(reason)
    }
}

struct WebContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
