import SwiftUI

/// Una conversación del Project GTA VI.
struct ProjectChat: Identifiable, Hashable, Codable {
    var id: String { chatID.isEmpty ? "t:" + title : chatID }
    var chatID: String  // uuid de la conversación ("" si claude.ai no lo da en la lista)
    var title: String
    var when: String    // "Hace 2 minutos", tal como lo muestra claude.ai
    var lastSeen = Date()
    var path: String { "/chat/\(chatID)" }
}

/// Lista de conversaciones del Project GTA VI.
/// Sale de dos lados: lo que claude.ai muestra en "Recientes" del proyecto (lo lee chat.js en la pantalla de
/// conversación nueva) y las conversaciones que abrís o empezás dentro de Pockit.
@MainActor
final class ProjectChats: ObservableObject {
    @Published private(set) var chats: [ProjectChat] = []

    private static let cacheKey = "pockit.projectChats.v2"

    init() {
        if let raw = UserDefaults.standard.data(forKey: Self.cacheKey),
           let list = try? JSONDecoder().decode([ProjectChat].self, from: raw) {
            chats = list.map { var c = $0; c.title = Self.clean(c.title); return c }
        }
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(chats) { UserDefaults.standard.set(raw, forKey: Self.cacheKey) }
    }

    /// Lo que mandó chat.js desde la página del proyecto (en el orden de claude.ai: más reciente primero).
    /// Quita íconos de letra (caracteres privados) que claude.ai mete en los títulos.
    static func clean(_ t: String) -> String {
        let scalars = t.unicodeScalars.filter { !(0xE000...0xF8FF).contains($0.value) && $0.value != 0xFFFD && !(0x200B...0x200F).contains($0.value) }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespaces)
    }

    func ingestFromProjectPage(_ items: [[String: Any]]) {
        var merged: [ProjectChat] = []
        for item in items {
            let title = Self.clean(item["title"] as? String ?? "")
            guard !title.isEmpty else { continue }
            var id = item["id"] as? String ?? ""
            if id.isEmpty, let known = chats.first(where: { $0.title == title && !$0.chatID.isEmpty }) { id = known.chatID }
            merged.append(ProjectChat(chatID: id, title: title, when: item["when"] as? String ?? ""))
        }
        // Las que se abrieron en Pockit y claude.ai ya no enseña en "Recientes" se quedan al final.
        for old in chats where !merged.contains(where: { $0.title == old.title || (!old.chatID.isEmpty && $0.chatID == old.chatID) }) {
            merged.append(old)
        }
        // Sin repetidos (mismo id o mismo título).
        var seen = Set<String>()
        chats = merged.filter { c in
            let key = c.chatID.isEmpty ? "t:" + c.title : c.chatID
            let tkey = "t:" + c.title
            if seen.contains(key) || (c.chatID.isEmpty && seen.contains(tkey)) { return false }
            seen.insert(key); seen.insert(tkey)
            return true
        }
        save()
    }

    /// Cada vez que se abre una conversación en Pockit (todas son del proyecto: no hay otra forma de llegar).
    func visited(chatID: String, title: String?) {
        guard chatID.count >= 20 else { return }
        let clean = Self.clean(title ?? "")
            .replacingOccurrences(of: " - Claude", with: "")
            .replacingOccurrences(of: " | Claude", with: "")
            .trimmingCharacters(in: .whitespaces)
        let isPlaceholder = clean.isEmpty || clean == "Claude" || clean.lowercased().hasPrefix("new chat") || clean.lowercased().hasPrefix("nueva")
        if let i = chats.firstIndex(where: { $0.chatID == chatID }) {
            var c = chats.remove(at: i)
            if !isPlaceholder { c.title = clean }
            c.lastSeen = Date()
            chats.insert(c, at: 0)
        } else if let i = chats.firstIndex(where: { $0.chatID.isEmpty && !isPlaceholder && $0.title == clean }) {
            var c = chats.remove(at: i)
            c.chatID = chatID
            c.lastSeen = Date()
            chats.insert(c, at: 0)
        } else {
            chats.insert(ProjectChat(chatID: chatID, title: isPlaceholder ? "…" : clean, when: ""), at: 0)
        }
        save()
    }
}

/// Panel de conversaciones que sale desde la izquierda (como en la app de Claude).
struct ChatsDrawer: View {
    @Binding var isOpen: Bool
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var chats: ProjectChats
    @State private var query = ""
    @GestureState private var drag: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.84, 360)
            let offset: CGFloat = isOpen ? min(0, drag) : -width
            let dim: Double = isOpen ? 0.45 * Double(1 + offset / width) : 0
            ZStack(alignment: .leading) {
                Color.black.opacity(dim)
                    .ignoresSafeArea()
                    .onTapGesture { isOpen = false }
                    .allowsHitTesting(isOpen)

                panel(width: width)
                    .frame(width: width)
                    .offset(x: offset)
                    .gesture(
                        DragGesture()
                            .updating($drag) { v, s, _ in s = min(0, v.translation.width) }
                            .onEnded { v in if v.translation.width < -width * 0.3 || v.predictedEndTranslation.width < -width * 0.6 { isOpen = false } }
                    )
            }
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.86), value: isOpen)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.9), value: drag)
        }
    }

    private func panel(width: CGFloat) -> some View {
        let t = settings.t
        let list = chats.chats.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.s("CONVERSACIONES", "CHATS")).font(Theme.display(28)).foregroundStyle(.white)
                Text("Project GTA VI").font(Theme.text(13, .medium, relativeTo: .footnote)).foregroundStyle(Theme.lilac)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            Button {
                web.open(path: WebModel.projectURL.path)
                isOpen = false
            } label: {
                Label(t.s("Nueva conversación", "New chat"), systemImage: "square.and.pencil")
                    .font(Theme.text(16, .semibold))
                    .foregroundStyle(Theme.nightDeep)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule().fill(Theme.switchPink))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 14)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.lilac)
                TextField(t.s("Buscar", "Search"), text: $query)
                    .font(Theme.text(15))
                    .foregroundStyle(.white)
                    .submitLabel(.search)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.nightDeep.opacity(0.6)))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if list.isEmpty {
                        Text(query.isEmpty
                             ? t.s("Todavía no hay conversaciones. Se llena cuando abrís la pantalla de conversación nueva o hablás con Marisol.", "No chats yet. It fills in from the new-chat screen and as you talk to Marisol.")
                             : t.s("No encontré nada.", "No matches."))
                            .font(Theme.text(14)).foregroundStyle(Theme.lilac)
                            .padding(18)
                    }
                    ForEach(list) { chat in
                        let current = !chat.chatID.isEmpty && web.currentPath.hasPrefix(chat.path)
                        Button {
                            if !current {
                                if chat.chatID.isEmpty { web.openProjectChat(title: chat.title) } else { web.open(path: chat.path) }
                            }
                            isOpen = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chat.title).font(Theme.text(15, current ? .semibold : .regular)).foregroundStyle(.white).lineLimit(2)
                                if !chat.when.isEmpty {
                                    Text(chat.when).font(Theme.text(11, relativeTo: .caption2)).foregroundStyle(Theme.lilac.opacity(0.85))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(current ? Theme.switchPink.opacity(0.22) : Color.clear))
                            .overlay(alignment: .leading) {
                                if current { Capsule().fill(Theme.switchPink).frame(width: 3).padding(.vertical, 8) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.menu.ignoresSafeArea())
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea() }
        .shadow(color: .black.opacity(0.35), radius: 18, x: 6)
    }
}
