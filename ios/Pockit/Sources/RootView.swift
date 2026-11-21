import SwiftUI
import WebKit
import UIKit

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var state: PockitState
    @EnvironmentObject private var skin: SkinManager
    @EnvironmentObject private var store: PockitStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var keyboard = KeyboardWatcher()
    @State private var showSettings = false
    @State private var showPartida = false
    @State private var showLoading = true

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    // El chat siempre vivo (la WebView no se recarga al cambiar de pestaña).
                    VStack(spacing: 0) {
                        TopBar(onSettings: { showSettings = true }, onAvatar: { showPartida = true })
                        QuickBar()
                        WebContainer(webView: web.webView)
                    }
                    .opacity(state.tab == .marisol ? 1 : 0)
                    .allowsHitTesting(state.tab == .marisol)
                    .accessibilityHidden(state.tab != .marisol)

                    switch state.tab {
                    case .marisol: EmptyView()
                    case .pendientes: PendientesView()
                    case .money: MoneyView()
                    case .collectibles: CollectiblesView()
                    case .mapa: MapaView()
                    }
                }
                .frame(maxHeight: .infinity)

                if !keyboard.visible {
                    PockitTabBar(selection: $state.tab, style: settings.tabIconStyle, t: settings.t)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: keyboard.visible)

            if let problem = web.sendProblem {
                SendProblemBanner(reason: problem) { web.sendProblem = nil }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            // Avisos apilados: uno arriba del otro, cada uno se desvanece a los 3 s.
            VStack(spacing: 8) {
                ForEach(store.notices) { n in
                    NoticeCard(notice: n) { store.dismissNotice(n.id) }
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, keyboard.visible ? 12 : 86)
            .allowsHitTesting(!store.notices.isEmpty)
            .zIndex(2)

            if showLoading {
                LoadingView()
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
        .animation(.easeOut(duration: 0.25), value: web.sendProblem)
        .animation(.easeInOut(duration: 0.4), value: store.notices)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(web)
                .environmentObject(state)
                .environmentObject(skin)
                .environmentObject(store)
        }
        .sheet(isPresented: $showPartida) {
            MiPartidaView()
                .environmentObject(settings)
                .environmentObject(web)
                .environmentObject(state)
                .environmentObject(store)
        }
        .onAppear {
            state.onEvent = { tag in store.ingest(tag) }
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
    let onAvatar: () -> Void
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var state: PockitState
    @State private var confirmSpoilers = false

    var body: some View {
        let t = settings.t
        HStack(spacing: 10) {
            Button(action: onAvatar) {
                AvatarView(mood: state.mood, size: 52, spoilerDot: state.lastReplyHadSpoiler)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t.s("Mi Partida", "My Game"))

            VStack(alignment: .leading, spacing: 1) {
                DisplayTitle(text: "MARISOL", size: 24)
                Text(state.progressSummary ?? t.noProgressYet)
                    .font(Theme.text(12, .medium, relativeTo: .caption))
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
                .font(Theme.text(12, .semibold, relativeTo: .caption))
                .foregroundStyle(state.spoilersOn ? Theme.nightDeep : .white)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(Capsule().fill(state.spoilersOn ? Theme.sunset : Theme.purple))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.spoilersOn ? t.spoilersOn : t.spoilersOff)

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
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

/// Tarjetita nativa: "Marisol anotó…".
struct NoticeCard: View {
    let notice: StoreNotice
    let onClose: () -> Void
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var state: PockitState

    var body: some View {
        Button {
            switch notice.emoji {
            case "🃏": state.tab = .collectibles
            case "📌": state.tab = .pendientes
            case "💰": state.tab = .money
            default: break
            }
            onClose()
        } label: {
            HStack(spacing: 10) {
                Text(notice.emoji).font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    Text(settings.t.s("MARISOL ANOTÓ", "MARISOL LOGGED")).font(Theme.display(12, weight: .semibold)).foregroundStyle(Theme.switchPink)
                    Text(notice.text).font(Theme.text(14, .medium, relativeTo: .subheadline)).foregroundStyle(.white).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
            .background(Capsule(style: .continuous).fill(Theme.nightDeep.opacity(0.6)))
            .overlay(Capsule(style: .continuous).stroke(Theme.switchPink.opacity(0.6), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 480)
        .padding(.horizontal, 20)
        .task {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(for: .seconds(3))
            onClose()
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
                .font(Theme.text(13, relativeTo: .footnote))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark").foregroundStyle(Theme.lilac).frame(width: 32, height: 32)
            }
            .accessibilityLabel("OK")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.nightDeep))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.violet, lineWidth: 1))
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
