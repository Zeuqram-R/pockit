import SwiftUI

enum ProgressSection: String { case collections, challenges, activities }

/// Progress (como el menú del juego): Collections, Challenges y Activities.
/// Collections: las categorías aparecen cuando reportás el primero de cada tipo.
/// Contador "N/??" y el total solo se muestra al completar la categoría.
struct CollectiblesView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @State private var adding = false
    @AppStorage("pockit.progressSection") private var section: ProgressSection = .collections

    var body: some View {
        let t = settings.t
        NavigationStack {
            List {
                LargeTitleRow(text: "PROGRESS")
                Section {
                    IconSegments(items: [
                        (ProgressSection.collections, "Collections", .asset("collections")),
                        (ProgressSection.challenges, "Challenges", .asset("challenges")),
                        (ProgressSection.activities, "Activities", .symbol("figure.run")),
                    ], selection: $section)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
                switch section {
                case .collections:
                Section {
                    HStack(spacing: 14) {
                        Image("TabColor_collections").resizable().scaledToFit().frame(width: 54, height: 54)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(store.collectiblesFound)")
                                .font(Theme.display(40)).foregroundStyle(.white)
                                .contentTransition(.numericText())
                            Text(t.s("encontrados", "found")).font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac)
                        }
                        Spacer()
                        let done = store.data.collectibles.filter(\.isComplete).count
                        if done > 0 {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(done)").font(Theme.display(28)).foregroundStyle(Theme.switchPink)
                                Text(t.s("completas", "complete")).font(Theme.text(12, relativeTo: .caption)).foregroundStyle(Theme.lilac)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .menuRow()
                }

                // Categorías generales (solo las que ya tienen algo desbloqueado), cada una con sus subcategorías.
                ForEach(store.collectibleGroups, id: \.name) { group in
                    Section {
                        ForEach(group.categories) { cat in
                            NavigationLink {
                                CollectibleCategoryView(categoryID: cat.id)
                            } label: {
                                CategoryRow(cat: cat, t: t)
                            }
                            .menuRow()
                        }
                    } header: {
                        HStack {
                            SectionTitle(text: group.name)
                            Spacer()
                            Text("\(group.categories.reduce(0) { $0 + $1.count })")
                                .font(Theme.display(17, weight: .semibold))
                                .foregroundStyle(Theme.switchPink)
                        }
                    }
                }

                Section {
                    // Lo que todavía no se ha descubierto.
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.square.dashed").font(.system(size: 22)).foregroundStyle(Theme.lilac.opacity(0.7)).frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("???").font(Theme.display(18, weight: .semibold)).foregroundStyle(Theme.lilac)
                            Text(store.data.collectibles.isEmpty
                                 ? t.s("Contale a Marisol cuando encontrés uno y su categoría aparece aquí.", "Tell Marisol when you find one and its category shows up here.")
                                 : t.s("Más categorías y subcategorías por descubrir", "More categories and subcategories to discover"))
                                .font(Theme.text(12, relativeTo: .caption)).foregroundStyle(Theme.lilac.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 4)
                    .menuRow()
                }
                case .challenges:
                    ChallengesSections()
                case .activities:
                    ActivitiesSections()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .fadingNavBar(title: "PROGRESS")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if section == .collections {
                        Button { adding = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 22)) }
                            .accessibilityLabel(t.s("Agregar a mano", "Add manually"))
                    }
                }
            }
            .sheet(isPresented: $adding) { CollectibleAddSheet().presentationDetents([.medium, .large]) }
        }
    }
}

private struct CategoryRow: View {
    let cat: CollectibleCategory
    let t: L10n

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cat.isComplete ? "checkmark.seal.fill" : "square.stack.3d.up.fill")
                .font(.system(size: 20)).foregroundStyle(Theme.switchPink).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(cat.name).font(Theme.text(16, .semibold)).foregroundStyle(.white)
                if cat.isComplete, let total = cat.total {
                    ProgressView(value: Double(cat.count), total: Double(total)).tint(Theme.switchPink)
                }
            }
            Spacer()
            Text(cat.isComplete ? "\(cat.count)/\(cat.total ?? cat.count)" : "\(cat.count)/??")
                .font(Theme.display(20, weight: .semibold))
                .foregroundStyle(cat.isComplete ? Theme.switchPink : .white)
        }
        .padding(.vertical, 4)
    }
}

struct CollectibleCategoryView: View {
    let categoryID: UUID
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        let t = settings.t
        let cat = store.data.collectibles.first { $0.id == categoryID }
        List {
            if let cat {
                Section {
                    if cat.items.isEmpty && cat.extraCount == 0 {
                        EmptyRow(symbol: "sparkles", text: t.s("Desbloqueada, pero todavía sin ninguno.", "Unlocked, but none found yet."))
                    }
                    ForEach(cat.items.sorted { $0.foundAt > $1.foundAt }) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(Theme.text(16)).foregroundStyle(.white)
                                if let v = item.variant { Text(v).font(Theme.text(12, .semibold, relativeTo: .caption)).foregroundStyle(Theme.switchPink) }
                            }
                            Spacer()
                            Text(Fmt.relative(item.foundAt, lang: settings.language))
                                .font(Theme.text(11, relativeTo: .caption2)).foregroundStyle(Theme.lilac)
                        }
                        .menuRow()
                        .swipeActions { Button(role: .destructive) { store.delete(item, in: cat) } label: { Label(t.s("Borrar", "Delete"), systemImage: "trash") } }
                    }
                    if cat.extraCount > 0 || !cat.items.isEmpty {
                        Stepper(value: Binding(get: { cat.extraCount }, set: { store.setExtraCount($0, in: cat) }), in: 0...999) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.s("Sin identificar: \(cat.extraCount)", "Unidentified: \(cat.extraCount)")).font(Theme.text(16)).foregroundStyle(.white)
                                Text(t.s("Los que el juego cuenta pero no dice cuáles.", "Ones the game counts but doesn't name."))
                                    .font(Theme.text(11, relativeTo: .caption2)).foregroundStyle(Theme.lilac)
                            }
                        }
                        .menuRow()
                    }
                } header: {
                    SectionTitle(text: (cat.group == cat.name ? "" : cat.group + " · ") + (cat.isComplete ? "\(cat.count)/\(cat.total ?? 0) " + t.s("Completa", "Complete") : "\(cat.count)/??"))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.menu.ignoresSafeArea())
        .navigationTitle((cat?.name ?? "").uppercased())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) { confirmDelete = true } label: { Label(t.s("Borrar subcategoría", "Delete subcategory"), systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .confirmationDialog(t.s("¿Borrar esta subcategoría y lo que tiene?", "Delete this subcategory and its items?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(t.s("Borrar", "Delete"), role: .destructive) { if let cat { store.delete(category: cat) }; dismiss() }
            Button(t.cancel, role: .cancel) {}
        }
    }
}

struct CollectibleAddSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @Environment(\.dismiss) private var dismiss
    @State private var group = ""
    @State private var category = ""
    @State private var item = ""
    @State private var variant = ""

    var body: some View {
        let t = settings.t
        let groups = Array(Set(CollectibleGroups.order + store.data.collectibles.map(\.group))).sorted {
            (CollectibleGroups.order.firstIndex(of: $0) ?? 99, $0) < (CollectibleGroups.order.firstIndex(of: $1) ?? 99, $1)
        }
        let cats = store.data.collectibles.filter { group.isEmpty || $0.group == group }
        NavigationStack {
            Form {
                Section {
                    chips(groups, selected: group) { group = $0; category = "" }
                    TextField(t.s("Categoría general", "Category"), text: $group).menuRow()
                } header: { SectionTitle(text: t.s("Categoría", "Category")) }
                Section {
                    if !cats.isEmpty { chips(cats.map(\.name), selected: category) { category = $0 } }
                    TextField(t.s("Subcategoría", "Subcategory"), text: $category).menuRow()
                } header: { SectionTitle(text: t.s("Subcategoría", "Subcategory")) }
                Section {
                    TextField(t.s("Cuál encontraste (vacío = solo desbloquear)", "Which one (empty = just unlock)"), text: $item).menuRow()
                    TextField(t.s("Variante (opcional)", "Variant (optional)"), text: $variant).menuRow()
                } footer: {
                    Text(t.s("Normalmente no hace falta: cuando le contás a Marisol, se anota solo.", "Usually not needed: when you tell Marisol, it's logged automatically."))
                        .font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac.opacity(0.85))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(t.s("Agregar", "Add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t.s("Agregar", "Add")) {
                        let g = group.trimmingCharacters(in: .whitespaces)
                        let c = category.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? g
                        if item.trimmingCharacters(in: .whitespaces).isEmpty {
                            store.unlockCategory(c, group: g)
                        } else {
                            store.addCollectible(category: c, item: item, total: nil, group: g, variant: variant)
                        }
                        dismiss()
                    }
                    .disabled(group.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationBackground(Theme.nightDeep)
    }

    private func chips(_ names: [String], selected: String, pick: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(names, id: \.self) { n in
                    Button(n) { pick(n) }
                        .font(Theme.text(13, .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(selected == n ? Theme.switchPink : Theme.purple))
                        .foregroundStyle(selected == n ? Theme.nightDeep : .white)
                        .buttonStyle(.plain)
                }
            }
        }
        .listRowBackground(Color.clear)
    }
}

/// Mapa: llega en la fase 4 (importar el mapa y poner pines sincronizados).
struct MapaView: View {
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        let t = settings.t
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image("TabColor_mapa").resizable().scaledToFit().frame(width: 120, height: 120)
                Text(t.s("PRÓXIMAMENTE", "COMING SOON")).font(Theme.display(30)).foregroundStyle(.white)
                Text(t.s("Aquí vas a importar tu mapa de Leonida y ponerle pines a tus lugares. Llega en la fase 4.",
                         "Here you'll import your Leonida map and pin your places. Coming in phase 4."))
                    .font(Theme.text(15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lilac)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(t.s("MAPA", "MAP"))
        }
    }
}


// MARK: - Challenges

struct ChallengesSections: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @State private var adding: ChallengeCategory?
    @State private var newName = ""

    var body: some View {
        let t = settings.t
        ForEach(store.data.challenges) { cat in
            Section {
                ForEach(cat.done, id: \.self) { name in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.switchPink)
                        Text(name).font(Theme.text(16)).foregroundStyle(.white)
                    }
                    .menuRow()
                    .swipeActions { Button(role: .destructive) { store.markChallenge(category: cat.name, item: name, done: false) } label: { Label(t.s("Quitar", "Remove"), systemImage: "xmark") } }
                }
                Button { newName = ""; adding = cat } label: {
                    Label(t.s("Marcar uno completado", "Mark one completed"), systemImage: "plus")
                        .font(Theme.text(14, .medium))
                }
                .menuRow()
            } header: {
                HStack {
                    SectionTitle(text: cat.name)
                    Spacer()
                    Text("\(cat.done.count)/\(cat.total)")
                        .font(Theme.display(17, weight: .semibold))
                        .foregroundStyle(cat.done.count >= cat.total ? Theme.switchPink : .white)
                }
            }
        }
        .alert(t.s("Reto completado", "Completed challenge"), isPresented: Binding(get: { adding != nil }, set: { if !$0 { adding = nil } })) {
            TextField(t.s("Nombre del reto", "Challenge name"), text: $newName)
            Button(t.cancel, role: .cancel) { adding = nil }
            Button(t.s("Marcar", "Mark")) { if let c = adding { store.markChallenge(category: c.name, item: newName) }; adding = nil }
        }
    }
}

// MARK: - Activities

struct ActivitiesSections: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore

    var body: some View {
        let t = settings.t
        ForEach(store.data.activities) { cat in
            Section {
                ForEach(cat.items) { item in
                    if item.discovered {
                        NavigationLink {
                            ActivityDetailView(categoryID: cat.id, itemID: item.id)
                        } label: {
                            ActivityRow(item: item)
                        }
                        .menuRow()
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "questionmark.square.dashed").foregroundStyle(Theme.lilac.opacity(0.6))
                            Text("???").font(Theme.display(16, weight: .semibold)).foregroundStyle(Theme.lilac.opacity(0.7))
                            Spacer()
                            Text(t.s("Sin descubrir", "Undiscovered")).font(Theme.text(11)).foregroundStyle(Theme.lilac.opacity(0.6))
                        }
                        .menuRow()
                    }
                }
            } header: {
                HStack {
                    SectionTitle(text: cat.name)
                    Spacer()
                    Text("\(cat.discoveredCount)/\(cat.items.count)")
                        .font(Theme.display(17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct ActivityRow: View {
    let item: ActivityItem
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name).font(Theme.text(15, .semibold)).foregroundStyle(.white).lineLimit(2)
                Spacer()
                if let m = item.medal, !m.isEmpty { MedalBadge(medal: m) }
                if item.check == true { Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.switchPink) }
            }
            if let s = item.stats.first(where: { $0.max != nil }) ?? item.stats.first {
                HStack(spacing: 8) {
                    Text(s.label).font(Theme.text(11)).foregroundStyle(Theme.lilac)
                    if let m = s.max, m > 0 {
                        ProgressView(value: Double(min(s.value, m)), total: Double(m)).tint(Theme.switchPink)
                        Text("\(s.value)/\(m)").font(Theme.text(11, .semibold)).foregroundStyle(.white)
                    } else {
                        Text("\(s.value)").font(Theme.text(11, .semibold)).foregroundStyle(.white)
                    }
                }
            } else if let b = item.best {
                Text(b).font(Theme.text(11)).foregroundStyle(Theme.lilac)
            }
        }
        .padding(.vertical, 2)
    }
}

struct MedalBadge: View {
    let medal: String
    var body: some View {
        let c: Color = medal.lowercased().hasPrefix("g") || medal.lowercased().hasPrefix("o") ? Theme.sunset
            : medal.lowercased().hasPrefix("s") || medal.lowercased().hasPrefix("p") ? Color(white: 0.85) : Theme.coral
        Image(systemName: "medal.fill").foregroundStyle(c)
    }
}

struct ActivityDetailView: View {
    let categoryID: UUID
    let itemID: UUID
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore

    private static let medals = ["", "Bronze", "Silver", "Gold"]

    var body: some View {
        let t = settings.t
        let cat = store.data.activities.first { $0.id == categoryID }
        let item = cat?.items.first { $0.id == itemID }
        List {
            if let cat, let item {
                if !item.stats.isEmpty {
                    Section {
                        ForEach(item.stats) { s in
                            Stepper(value: Binding(get: { s.value }, set: { v in
                                var it = item
                                if let i = it.stats.firstIndex(where: { $0.label == s.label }) { it.stats[i].value = max(0, v) }
                                store.updateActivity(it, in: cat)
                            }), in: 0...99_999) {
                                HStack {
                                    Text(s.label).font(Theme.text(15)).foregroundStyle(.white)
                                    Spacer()
                                    Text(s.max.map { "\(s.value)/\($0)" } ?? "\(s.value)").font(Theme.text(15, .semibold)).foregroundStyle(Theme.switchPink)
                                }
                            }
                            .menuRow()
                        }
                    } header: { SectionTitle(text: t.s("Avance", "Progress")) }
                }
                Section {
                    if let level = item.level {
                        LabeledContent(t.s("Nivel", "Level"), value: level).menuRow()
                    }
                    if item.best != nil {
                        HStack {
                            Text(t.s("Mejor", "Best")).font(Theme.text(15)).foregroundStyle(.white)
                            Spacer()
                            TextField("", text: Binding(get: { item.best ?? "" }, set: { var it = item; it.best = $0; store.updateActivity(it, in: cat) }))
                                .multilineTextAlignment(.trailing)
                                .font(Theme.text(15, .semibold))
                        }
                        .menuRow()
                    }
                    Picker(t.s("Medalla", "Medal"), selection: Binding(get: { item.medal ?? "" }, set: { var it = item; it.medal = $0.isEmpty ? nil : $0; store.updateActivity(it, in: cat) })) {
                        ForEach(Self.medals, id: \.self) { m in Text(m.isEmpty ? "—" : m).tag(m) }
                    }
                    .menuRow()
                    if let label = item.checkLabel {
                        Toggle(label, isOn: Binding(get: { item.check ?? false }, set: { var it = item; it.check = $0; store.updateActivity(it, in: cat) }))
                            .tint(Theme.switchPink)
                            .menuRow()
                    }
                } header: { SectionTitle(text: t.s("Récords", "Records")) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.menu.ignoresSafeArea())
        .navigationTitle((item?.name ?? "").uppercased())
        .navigationBarTitleDisplayMode(.inline)
    }
}
