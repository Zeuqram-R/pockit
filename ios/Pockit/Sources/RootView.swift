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
    @State private var showChats = false
    @EnvironmentObject private var chats: ProjectChats
    @State private var showLoading = true

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    // El chat siempre vivo (la WebView no se recarga al cambiar de pestaña).
                    VStack(spacing: 0) {
                        TopBar(onSettings: { showSettings = true }, onAvatar: { showPartida = true }, onChats: { showChats = true })
                        QuickBar()
                        WebContainer(webView: web.webView)
                            // Conversación nueva: vista nativa encima de la página del proyecto.
                            .overlay {
                                if web.isNewChat { NewChatView() }
                            }
                            // En una conversación: caja de escribir nativa estilo iMessage.
                            .overlay(alignment: .bottom) {
                                if web.isChatPage && skin.chatActive { ChatComposerBar() }
                            }
                            // Deslizar desde el borde izquierdo abre el panel de conversaciones.
                            .overlay(alignment: .leading) {
                                Color.clear
                                    .frame(width: 16)
                                    .contentShape(Rectangle())
                                    .gesture(DragGesture(minimumDistance: 10).onEnded { v in
                                        if v.translation.width > 40 { showChats = true }
                                    })
                            }
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

            if state.tab == .marisol {
                ChatsDrawer(isOpen: $showChats)
                    .zIndex(1.5)
                    .allowsHitTesting(showChats)
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
                .environmentObject(chats)
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
            // Si nunca se guardó la última conversación, abrir la más reciente del panel.
            if UserDefaults.standard.string(forKey: WebModel.lastChatKey) == nil,
               let recent = chats.chats.first(where: { !$0.chatID.isEmpty }) {
                web.open(path: recent.path)
            }
            web.onTags = { items in state.handle(items: items) }
            web.onProjectChats = { items in chats.ingestFromProjectPage(items) }
            web.onChatVisited = { id, title in chats.visited(chatID: id, title: title) }
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
    let onChats: () -> Void
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var state: PockitState
    @State private var confirmSpoilers = false

    var body: some View {
        let t = settings.t
        // Como el encabezado de iMessage: botón a la izquierda, contacto al centro, botones a la derecha.
        ZStack(alignment: .top) {
            HStack(spacing: 10) {
                GlassCircleButton(systemName: "line.3.horizontal", label: t.s("Conversaciones", "Chats"), action: onChats)
                Spacer()
                GlassCircleButton(systemName: state.spoilersOn ? "eye.fill" : "eye.slash.fill",
                                  label: state.spoilersOn ? t.spoilersOn : t.spoilersOff,
                                  tint: state.spoilersOn ? Theme.sunset : .white) { confirmSpoilers = true }
                GlassCircleButton(systemName: "gearshape.fill", label: t.settings, action: onSettings)
            }
            .padding(.top, 10)

            Button(action: onAvatar) {
                VStack(spacing: 4) {
                    AvatarView(mood: state.mood, size: 58, spoilerDot: state.lastReplyHadSpoiler)
                    HStack(spacing: 3) {
                        Text("Marisol").font(Theme.text(15, .semibold, relativeTo: .subheadline))
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).opacity(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .background(Capsule().fill(Theme.nightDeep.opacity(0.35)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    Text(state.progressSummary ?? t.noProgressYet)
                        .font(Theme.text(11, .medium, relativeTo: .caption2))
                        .foregroundStyle(Theme.lilac)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t.s("Mi Partida", "My Game"))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
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

/// Botón redondo de vidrio (como los del encabezado de iMessage).
struct GlassCircleButton: View {
    let systemName: String
    let label: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ultraThinMaterial))
                .background(Circle().fill(Theme.nightDeep.opacity(0.35)))
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
