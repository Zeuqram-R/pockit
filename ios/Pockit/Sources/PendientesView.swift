import SwiftUI
import UIKit

/// Pendientes (los "Ojo, ya que andas por ahí…" de Marisol) y la Libreta de tips guardados.
struct PendientesView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @EnvironmentObject private var state: PockitState
    @EnvironmentObject private var web: WebModel

    enum Mode: String, CaseIterable, Identifiable { case pendientes, libreta; var id: String { rawValue } }
    @State private var mode: Mode = .pendientes
    @State private var query = ""
    @State private var showDone = false
    @State private var adding = false
    @State private var newText = ""
    @State private var editing: Nota?
    @State private var editText = ""

    var body: some View {
        let t = settings.t
        NavigationStack {
            List {
                Section {
                    Picker("", selection: $mode) {
                        Text(t.s("Pendientes", "To-do")).tag(Mode.pendientes)
                        Text(t.s("Libreta", "Notebook")).tag(Mode.libreta)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                if mode == .pendientes { pendientesSections(t) } else { libretaSection(t) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: t.s("Buscar", "Search"))
            .fadingNavBar()
            .navigationTitle(t.s("PENDIENTES", "TO-DO"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { newText = ""; adding = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 22)) }
                        .accessibilityLabel(t.s("Agregar", "Add"))
                }
            }
            .alert(mode == .pendientes ? t.s("Nuevo pendiente", "New to-do") : t.s("Nueva nota", "New note"), isPresented: $adding) {
                TextField(t.s("Escribí aquí", "Type here"), text: $newText)
                Button(t.cancel, role: .cancel) {}
                Button(t.s("Agregar", "Add")) {
                    if mode == .pendientes { store.addPendiente(newText) } else { store.addNota(newText) }
                }
            }
            .alert(t.s("Editar nota", "Edit note"), isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("", text: $editText)
                Button(t.cancel, role: .cancel) { editing = nil }
                Button(t.s("Guardar", "Save")) { if let n = editing { store.updateNota(n, text: editText) }; editing = nil }
            }
        }
    }

    private func matches(_ text: String) -> Bool {
        query.isEmpty || text.localizedCaseInsensitiveContains(query)
    }

    @ViewBuilder private func pendientesSections(_ t: L10n) -> some View {
        let open = store.openPendientes.filter { matches($0.text) }
        let done = store.donePendientes.filter { matches($0.text) }

        Section {
            if open.isEmpty {
                EmptyRow(symbol: "checklist", text: query.isEmpty
                         ? t.s("Nada pendiente. Cuando Marisol te diga \"Ojo, ya que andas por ahí…\", aparece aquí.",
                               "Nothing pending. When Marisol says \"Ojo, ya que andas por ahí…\", it shows up here.")
                         : t.s("No encontré nada.", "No matches."))
            }
            ForEach(open) { p in pendienteRow(p, t) }
        } header: {
            SectionTitle(text: t.s("Por hacer", "To do") + (open.isEmpty ? "" : " · \(open.count)"))
        }

        if !done.isEmpty {
            Section {
                if showDone || !query.isEmpty { ForEach(done) { p in pendienteRow(p, t) } }
            } header: {
                Button {
                    withAnimation { showDone.toggle() }
                } label: {
                    HStack {
                        SectionTitle(text: t.s("Hechos", "Done") + " · \(done.count)")
                        Spacer()
                        Image(systemName: showDone ? "chevron.up" : "chevron.down").foregroundStyle(Theme.lilac)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pendienteRow(_ p: Pendiente, _ t: L10n) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { store.toggle(p) }
            } label: {
                Image(systemName: p.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(p.done ? Theme.switchPink : Theme.lilac)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(p.done ? t.s("Marcar como pendiente", "Mark as not done") : t.s("Marcar como hecho", "Mark as done"))

            VStack(alignment: .leading, spacing: 3) {
                Text(p.text)
                    .font(Theme.text(16, relativeTo: .body))
                    .foregroundStyle(p.done ? Theme.lilac : .white)
                    .strikethrough(p.done, color: Theme.lilac)
                HStack(spacing: 6) {
                    if p.source == "marisol" { Text("Marisol").font(Theme.text(11, .semibold, relativeTo: .caption2)).foregroundStyle(Theme.switchPink) }
                    Text(Fmt.relative(p.createdAt, lang: settings.language))
                        .font(Theme.text(11, relativeTo: .caption2)).foregroundStyle(Theme.lilac.opacity(0.8))
                }
            }
        }
        .padding(.vertical, 4)
        .menuRow()
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { store.delete(p) } label: { Label(t.s("Borrar", "Delete"), systemImage: "trash") }
            Button { store.moveToLibreta(p) } label: { Label(t.s("A la libreta", "To notebook"), systemImage: "book") }.tint(Theme.purple)
        }
        .contextMenu {
            Button { ask(about: p.text, t) } label: { Label(t.s("Pregúntale a Marisol", "Ask Marisol"), systemImage: "bubble.left") }
            Button { UIPasteboard.general.string = p.text } label: { Label(t.s("Copiar", "Copy"), systemImage: "doc.on.doc") }
            Button { store.moveToLibreta(p) } label: { Label(t.s("Mover a la libreta", "Move to notebook"), systemImage: "book") }
        }
    }

    @ViewBuilder private func libretaSection(_ t: L10n) -> some View {
        let notas = store.data.libreta.filter { matches($0.text) }.sorted { $0.createdAt > $1.createdAt }
        Section {
            if notas.isEmpty {
                EmptyRow(symbol: "book", text: query.isEmpty
                         ? t.s("Tu libreta está vacía. Agregá tips con + o deslizá un pendiente pa' guardarlo aquí.",
                               "Your notebook is empty. Add tips with + or swipe a to-do to keep it here.")
                         : t.s("No encontré nada.", "No matches."))
            }
            ForEach(notas) { n in
                VStack(alignment: .leading, spacing: 3) {
                    Text(n.text).font(Theme.text(16, relativeTo: .body)).foregroundStyle(.white)
                    Text(Fmt.relative(n.createdAt, lang: settings.language))
                        .font(Theme.text(11, relativeTo: .caption2)).foregroundStyle(Theme.lilac.opacity(0.8))
                }
                .padding(.vertical, 4)
                .menuRow()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { store.delete(n) } label: { Label(t.s("Borrar", "Delete"), systemImage: "trash") }
                    Button { editText = n.text; editing = n } label: { Label(t.s("Editar", "Edit"), systemImage: "pencil") }.tint(Theme.purple)
                }
                .contextMenu {
                    Button { ask(about: n.text, t) } label: { Label(t.s("Pregúntale a Marisol", "Ask Marisol"), systemImage: "bubble.left") }
                    Button { UIPasteboard.general.string = n.text } label: { Label(t.s("Copiar", "Copy"), systemImage: "doc.on.doc") }
                }
            }
        } header: {
            SectionTitle(text: t.s("Tips guardados", "Saved tips") + (notas.isEmpty ? "" : " · \(notas.count)"))
        }
    }

    private func ask(about text: String, _ t: L10n) {
        state.tab = .marisol
        web.send(t.s("Sobre este tip: \"\(text)\". ¿Cómo lo hago desde donde voy?", "About this tip: \"\(text)\". How do I do it from where I am?"))
    }
}

/// Fila vacía con ícono y texto suave.
struct EmptyRow: View {
    let symbol: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(Theme.switchPink)
            Text(text).font(Theme.text(14, relativeTo: .subheadline)).foregroundStyle(Theme.lilac)
        }
        .padding(.vertical, 8)
        .menuRow()
    }
}
