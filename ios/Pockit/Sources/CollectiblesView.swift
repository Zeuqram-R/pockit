import SwiftUI

/// Collectibles: las categorías aparecen cuando reportás el primero de cada tipo.
/// Contador "N/??" y el total solo se muestra al completar la categoría.
struct CollectiblesView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @State private var adding = false

    var body: some View {
        let t = settings.t
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image("TabColor_collectibles").resizable().scaledToFit().frame(width: 54, height: 54)
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

                Section {
                    ForEach(store.data.collectibles) { cat in
                        NavigationLink {
                            CollectibleCategoryView(categoryID: cat.id)
                        } label: {
                            CategoryRow(cat: cat, t: t)
                        }
                        .menuRow()
                    }
                    // La siguiente categoría todavía no se sabe.
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.square.dashed").font(.system(size: 22)).foregroundStyle(Theme.lilac.opacity(0.7)).frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("???").font(Theme.display(18, weight: .semibold)).foregroundStyle(Theme.lilac)
                            Text(store.data.collectibles.isEmpty
                                 ? t.s("Contale a Marisol cuando encontrés uno y su categoría aparece aquí.", "Tell Marisol when you find one and its category shows up here.")
                                 : t.s("Más categorías por descubrir", "More categories to discover"))
                                .font(Theme.text(12, relativeTo: .caption)).foregroundStyle(Theme.lilac.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 4)
                    .menuRow()
                } header: {
                    SectionTitle(text: t.s("Categorías", "Categories"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle("COLLECTIBLES")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 22)) }
                        .accessibilityLabel(t.s("Agregar a mano", "Add manually"))
                }
            }
            .sheet(isPresented: $adding) { CollectibleAddSheet().presentationDetents([.medium]) }
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
                    ProgressView(value: Double(cat.items.count), total: Double(total)).tint(Theme.switchPink)
                }
            }
            Spacer()
            Text(cat.isComplete ? "\(cat.items.count)/\(cat.total ?? cat.items.count)" : "\(cat.items.count)/??")
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

    var body: some View {
        let t = settings.t
        let cat = store.data.collectibles.first { $0.id == categoryID }
        List {
            if let cat {
                Section {
                    ForEach(cat.items.sorted { $0.foundAt > $1.foundAt }) { item in
                        HStack {
                            Text(item.name).font(Theme.text(16)).foregroundStyle(.white)
                            Spacer()
                            Text(Fmt.relative(item.foundAt, lang: settings.language))
                                .font(Theme.text(11, relativeTo: .caption2)).foregroundStyle(Theme.lilac)
                        }
                        .menuRow()
                        .swipeActions { Button(role: .destructive) { store.delete(item, in: cat) } label: { Label(t.s("Borrar", "Delete"), systemImage: "trash") } }
                    }
                } header: {
                    SectionTitle(text: cat.isComplete ? "\(cat.items.count)/\(cat.total ?? 0) · " + t.s("Completa", "Complete") : "\(cat.items.count)/??")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.menu.ignoresSafeArea())
        .navigationTitle((cat?.name ?? "").uppercased())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CollectibleAddSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @Environment(\.dismiss) private var dismiss
    @State private var category = ""
    @State private var item = ""

    var body: some View {
        let t = settings.t
        NavigationStack {
            Form {
                Section {
                    TextField(t.s("Categoría", "Category"), text: $category).menuRow()
                    if !store.data.collectibles.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(store.data.collectibles) { c in
                                    Button(c.name) { category = c.name }
                                        .font(Theme.text(13, .semibold))
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Capsule().fill(category == c.name ? Theme.switchPink : Theme.purple))
                                        .foregroundStyle(.white)
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    TextField(t.s("Cuál encontraste", "Which one you found"), text: $item).menuRow()
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
                        store.addCollectible(category: category, item: item, total: nil)
                        dismiss()
                    }
                    .disabled(category.trimmingCharacters(in: .whitespaces).isEmpty || item.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationBackground(Theme.nightDeep)
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
