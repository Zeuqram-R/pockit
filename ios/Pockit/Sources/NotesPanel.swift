import SwiftUI

/// Columna derecha en el iPad grande / Mac: la Libreta (tips de Marisol y tus notas) a mano mientras chateás.
struct NotesPanel: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @EnvironmentObject private var web: WebModel
    @State private var draft = ""
    @State private var query = ""

    var body: some View {
        let t = settings.t
        let notes = store.data.libreta.reversed().filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }
        VStack(alignment: .leading, spacing: 12) {
            Text(t.s("LIBRETA", "NOTEBOOK")).font(Theme.display(30)).foregroundStyle(.white)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.lilac.opacity(0.7))
                TextField(t.s("Buscar", "Search"), text: $query).font(Theme.text(14)).foregroundStyle(.white)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel.opacity(0.75)))
            HStack {
                TextField(t.s("Anotar algo…", "Jot something…"), text: $draft, axis: .vertical)
                    .lineLimit(1...3).font(Theme.text(14)).foregroundStyle(.white)
                    .onSubmit(add)
                Button(action: add) { Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.switchPink) }
                    .buttonStyle(.plain)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel.opacity(0.75)))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if notes.isEmpty {
                        Text(t.s("Los tips de Marisol y tus notas aparecen aquí.", "Marisol's tips and your notes show up here."))
                            .font(Theme.text(14)).foregroundStyle(Theme.lilac).padding(.top, 8)
                    }
                    ForEach(notes) { n in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(n.text).font(Theme.text(14)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                            Text(Fmt.relative(n.createdAt, lang: settings.language)).font(Theme.text(11)).foregroundStyle(Theme.lilac.opacity(0.7))
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel.opacity(0.75)))
                        .contextMenu {
                            Button { web.send(t.s("Sobre esto que tengo anotado: \"\(n.text)\". ¿Qué me recomendás? Sin spoilers.",
                                                  "About this note of mine: \"\(n.text)\". What do you recommend? No spoilers.")) } label: {
                                Label(t.s("Preguntarle a Marisol", "Ask Marisol"), systemImage: "bubble.left.fill")
                            }
                            Button { store.addPendiente(n.text) } label: { Label(t.s("Pasar a Pendientes", "Move to To-do"), systemImage: "checklist") }
                            Button(role: .destructive) { store.delete(n) } label: { Label(t.s("Borrar", "Delete"), systemImage: "trash") }
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .padding(18)
        .background(Theme.nightDeep.opacity(0.35).ignoresSafeArea())
    }

    private func add() {
        let s = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        store.addNota(s)
        draft = ""
    }
}
