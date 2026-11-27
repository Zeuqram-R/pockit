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
    @ObservedObject private var inbox = IntentInbox.shared

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    // El chat siempre vivo (la WebView no se recarga al cambiar de pestaña).
                    GeometryReader { geo in
                    let wide = UIDevice.current.userInterfaceIdiom != .phone && geo.size.width >= 900
                    HStack(spacing: 0) {
                    if wide {
                        TrackerSidebar()
                            .frame(width: 330)
                        Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea(edges: .bottom)
                    }
                    VStack(spacing: 0) {
                        TopBar(onSettings: { showSettings = true }, onAvatar: { showPartida = true }, onChats: { showChats = true })
                        QuickBar()
                        ChatColumn(webView: web.webView)
                            .overlay { if web.loadError && !web.hasLoadedOnce { OfflineChatCard() } }
                            .overlay(alignment: .top) {
                                if !web.online && web.hasLoadedOnce {
                                    Label(settings.t.s("Sin internet · Marisol responde cuando vuelva la conexión", "Offline · Marisol replies when you're back online"),
                                          systemImage: "wifi.slash")
                                        .font(Theme.text(13, .semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(Theme.coral.opacity(0.9)))
                                        .padding(.top, 8)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: web.online)
                            // El historial sigue detrás del teclado (como en iMessage); chat.js sube la caja.
                            .ignoresSafeArea(.keyboard, edges: .bottom)
                            // Conversación nueva: vista nativa encima de la página del proyecto.
                            .overlay {
                                if web.showsNewChat { NewChatView() }
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

                // 0.4.2: la barra ya no se quita del diseño cuando sale el teclado (eso estiraba el chat de golpe
                // y hacía brincar la caja de escribir). Solo se desvanece; queda escondida detrás del teclado.
                PockitTabBar(selection: $state.tab, style: settings.tabIconStyle, t: settings.t)
                    .opacity(keyboard.visible ? 0 : 1)
                    .offset(y: keyboard.visible ? 24 : 0)
                    .allowsHitTesting(!keyboard.visible)
                    .accessibilityHidden(keyboard.visible)
            }
            // 0.6.4: en el chat, la pantalla no se encoge con el teclado (si se encogía, la barra de abajo —aunque
            // invisible— quedaba entre el teclado y la burbuja). La caja la sube el skin justo encima del teclado.
            .ignoresSafeArea(.keyboard, edges: state.tab == .marisol ? .bottom : [])
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
            UsageMonitor.shared.start(); SyncManager.shared.attach(store: store, state: state)
            web.watchNetwork()
            // El mapa se va cargando por detrás unos segundos después de abrir, pa' que la pestaña abra de una.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { MapWeb.shared.start() }
            WidgetBridge.update(store: store, state: state, lang: settings.language)
            Task { await SyncManager.shared.sync() }
            // Si nunca se guardó la última conversación, abrir la más reciente del panel.
            if UserDefaults.standard.string(forKey: WebModel.lastChatKey) == nil,
               let recent = chats.chats.first(where: { !$0.chatID.isEmpty }) {
                web.open(path: recent.path)
            }
            web.onTags = { items in state.handle(items: items) }
            web.onProjectChats = { items in chats.ingestFromProjectPage(items) }
            web.onChatVisited = { id, title in chats.visited(chatID: id, title: title) }
            web.onChatMissing = { id in chats.missing(chatID: id) }
            web.setPrefix(state.prefix(lang: settings.language))
            skin.attach(web)
        }
        .onChange(of: settings.languageRaw) { _, _ in
            web.setPrefix(state.prefix(lang: settings.language))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { UsageMonitor.shared.refresh(); Task { await skin.refresh(); await SyncManager.shared.sync() }; Notifier.shared.becameActive(); deliverInbox() }
            if phase == .background { Notifier.shared.wentToBackground(streaming: web.isStreaming) }
        }
        .onChange(of: web.isStreaming) { _, on in
            Notifier.shared.streamingChanged(on, inBackground: scenePhase != .active, lang: settings.language)
            if !on { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { UsageMonitor.shared.refresh() } }
        }
        .onChange(of: inbox.pendingMessage) { _, _ in deliverInbox() }
        .onChange(of: store.data.updatedAt) { _, _ in WidgetBridge.update(store: store, state: state, lang: settings.language) }
        .onChange(of: state.mood) { _, _ in WidgetBridge.update(store: store, state: state, lang: settings.language) }
        .onChange(of: state.progressPct) { _, _ in WidgetBridge.update(store: store, state: state, lang: settings.language) }
        .onOpenURL { _ in state.tab = .marisol }
        .onChange(of: inbox.openMarisol) { _, on in if on { state.tab = .marisol; inbox.openMarisol = false } }
        .onChange(of: web.hasLoadedOnce) { _, _ in deliverInbox() }
        .task {
            // Mínimo de 1.2 s pa' que la pantalla de carga no parpadee.
            try? await Task.sleep(for: .seconds(1.2))
            // 0.6.1: sin internet ya no se queda trabada en la pantalla de carga: se abre la app igual
            // (mapa, tracker, pendientes funcionan) y el chat muestra el aviso.
            while !web.hasLoadedOnce && !web.loadError { try? await Task.sleep(for: .milliseconds(150)) }
            // 0.8.5: espera a que nuestra burbuja y el chat estén armados (antes se veía la caja gris de claude.ai un segundo)
            var waited = 0
            while !web.chatReady && !web.loadError && waited < 25 { try? await Task.sleep(for: .milliseconds(120)); waited += 1 }
            withAnimation(.easeOut(duration: 0.5)) { showLoading = false }
        }
    }

    /// Lo que llegó por Siri / Atajos: se manda a Marisol cuando el chat ya cargó.
    private func deliverInbox() {
        guard let msg = inbox.pendingMessage, web.hasLoadedOnce else { return }
        inbox.pendingMessage = nil
        state.tab = .marisol
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if web.showsNewChat { web.startNewChat(msg) } else { web.send(msg) }
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
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 8) {
                    GlassCircleButton(systemName: "line.3.horizontal", label: t.s("Conversaciones", "Chats"), action: onChats)
                    UsageRing()
                }
                .zIndex(5)
                Spacer()
                GlassCircleButton(systemName: state.spoilersOn ? "eye.fill" : "eye.slash.fill",
                                  label: state.spoilersOn ? t.spoilersOn : t.spoilersOff,
                                  tint: state.spoilersOn ? Theme.sunset : .white,
                                  assetName: (settings.tabIconStyle == .game ? "Glyph_spoiler_" : "Color_spoiler_") + (state.spoilersOn ? "on" : "off")) { confirmSpoilers = true }
                GlassCircleButton(systemName: "gearshape.fill", label: t.settings,
                                  assetName: settings.tabIconStyle == .game ? "Glyph_settings" : "Color_settings", action: onSettings)
            }
            .padding(.top, 10)

            Button(action: onAvatar) {
                VStack(spacing: 4) {
                    AvatarView(mood: state.mood, size: 58, spoilerDot: state.lastReplyHadSpoiler, typing: web.dotsDocked)
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
    /// Ícono propio (plantilla blanca) en vez del símbolo del sistema, p. ej. en "Estilo del juego".
    var assetName: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let assetName {
                    // los íconos "Color_" van con sus colores; los "Glyph_" se pintan del color del botón
                    Image(assetName).renderingMode(assetName.hasPrefix("Color_") ? .original : .template)
                        .resizable().scaledToFit().frame(width: assetName.hasPrefix("Color_") ? 28 : 24, height: assetName.hasPrefix("Color_") ? 28 : 24)
                } else {
                    Image(systemName: systemName).font(.system(size: 17, weight: .semibold))
                }
            }
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

/// El chat con ancho y zoom pa' que claude.ai siempre use su diseño de teléfono (ver WebModel.setZoom).
struct ChatColumn: View {
    let webView: WKWebView
    @EnvironmentObject private var web: WebModel
    var body: some View {
        GeometryReader { g in
            let isPhone = UIDevice.current.userInterfaceIdiom == .phone
            // claude.ai abre su barra lateral desde unos 640 px: la página se queda en 600 px de ancho.
            // Si sobra espacio a la derecha (iPad grande acostado / Mac), ahí va la Libreta.
            let W = g.size.width
            let panel: CGFloat = 330
            let showPanel = !isPhone && W >= 600 + panel + 10
            let area = showPanel ? W - panel - 1 : W
            let zoom: CGFloat = isPhone ? 1 : min(1.3, max(1, area / 600))
            let width = min(area, 600 * zoom)
            HStack(spacing: 0) {
                WebContainer(webView: webView)
                    .frame(width: width, height: g.size.height)
                    .frame(maxWidth: .infinity)
                if showPanel {
                    Rectangle().fill(Theme.line).frame(width: 1)
                    NotesPanel().frame(width: panel)
                }
            }
            .onAppear { web.setZoom(zoom) }
            .onChange(of: zoom) { _, z in web.setZoom(z) }
        }
    }
}

struct WebContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}


/// Chat sin internet: aviso + atajos a lo que sí funciona.
struct OfflineChatCard: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var state: PockitState
    var body: some View {
        let t = settings.t
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash").font(.system(size: 40, weight: .semibold)).foregroundStyle(Theme.lilac)
            Text(t.s("SIN INTERNET", "OFFLINE")).font(Theme.display(28)).foregroundStyle(.white)
            Text(t.s("Marisol necesita conexión pa' responder. Mientras tanto, el mapa (con lo que descargaste), tus pendientes, la libreta y el tracker funcionan normal desde las pestañas de abajo.",
                     "Marisol needs a connection to reply. Meanwhile the map (with what you downloaded), your to-dos, notebook and tracker work as usual."))
                .font(Theme.text(15)).foregroundStyle(Theme.lilac).multilineTextAlignment(.center).padding(.horizontal, 28)
            Button(t.retry) { web.loadHome() }.font(Theme.text(15, .semibold)).foregroundStyle(.white)
            Text(t.s("Se conecta solo cuando vuelva el internet.", "Reconnects on its own when you're back online."))
                .font(Theme.text(12)).foregroundStyle(Theme.lilac.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.night)
    }
}
