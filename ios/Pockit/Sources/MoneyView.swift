import SwiftUI
import Charts

/// Money: banco / app / casa, gráfica del total, historial y (cuando se desbloquea) propiedades y negocios.
struct MoneyView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore

    @State private var editing = false
    @State private var confirmUnlock = false
    @State private var addingProp = false

    var body: some View {
        let t = settings.t
        let current = store.currentMoney
        let previous = store.data.money.dropLast().last
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOTAL").font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.lilac)
                        Text(Fmt.money(current?.total ?? 0))
                            .font(Theme.display(44))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        if let current {
                            HStack(spacing: 6) {
                                if let previous { DeltaText(delta: current.total - previous.total) }
                                Text(Fmt.relative(current.at, lang: settings.language))
                                    .font(Theme.text(12, relativeTo: .caption)).foregroundStyle(Theme.lilac.opacity(0.8))
                            }
                        } else {
                            Text(t.s("Contale a Marisol cuánto tenés o tocá Actualizar.", "Tell Marisol how much you have or tap Update."))
                                .font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac)
                        }
                    }
                    .padding(.vertical, 6)
                    .menuRow()

                    HStack(spacing: 10) {
                        MoneyTile(symbol: "building.columns.fill", title: t.s("Banco", "Bank"), value: current?.bank, delta: previous.map { (current?.bank ?? 0) - $0.bank })
                        MoneyTile(symbol: "iphone", title: "BUCKME", value: current?.app, delta: previous.map { (current?.app ?? 0) - $0.app })
                        MoneyTile(symbol: "house.fill", title: "STASH", value: current?.home, delta: previous.map { (current?.home ?? 0) - $0.home })
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }

                if store.data.money.count >= 2 {
                    Section {
                        Chart(store.data.money) { s in
                            AreaMark(x: .value("Fecha", s.at), y: .value("Total", s.total))
                                .foregroundStyle(LinearGradient(colors: [Theme.switchPink.opacity(0.35), Theme.switchPink.opacity(0)], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.monotone)
                            LineMark(x: .value("Fecha", s.at), y: .value("Total", s.total))
                                .foregroundStyle(Theme.switchPink)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Fecha", s.at), y: .value("Total", s.total))
                                .foregroundStyle(.white)
                                .symbolSize(18)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { v in
                                AxisGridLine().foregroundStyle(Theme.line)
                                AxisValueLabel { if let n = v.as(Int.self) { Text(Self.short(n)).font(Theme.text(10)).foregroundStyle(Theme.lilac) } }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(Theme.text(10)).foregroundStyle(Theme.lilac)
                            }
                        }
                        .frame(height: 170)
                        .padding(.vertical, 8)
                        .menuRow()
                    } header: {
                        SectionTitle(text: t.s("Historial del total", "Total over time"))
                    }
                }

                if store.data.propiedadesUnlocked {
                    Section {
                        if store.data.propiedades.isEmpty {
                            EmptyRow(symbol: "building.2", text: t.s("Agregá tus propiedades y negocios con +.", "Add your properties and businesses with +."))
                        }
                        ForEach(store.data.propiedades) { p in
                            HStack(spacing: 12) {
                                Image(systemName: p.isBusiness ? "storefront.fill" : "house.lodge.fill")
                                    .font(.system(size: 18)).foregroundStyle(Theme.switchPink).frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(Theme.text(16, .medium)).foregroundStyle(.white)
                                    Text(p.note.isEmpty ? (p.isBusiness ? t.s("Negocio", "Business") : t.s("Propiedad", "Property")) : p.note)
                                        .font(Theme.text(12, relativeTo: .caption)).foregroundStyle(Theme.lilac)
                                }
                            }
                            .menuRow()
                            .swipeActions { Button(role: .destructive) { store.delete(p) } label: { Label(t.s("Borrar", "Delete"), systemImage: "trash") } }
                        }
                        Button { addingProp = true } label: {
                            Label(t.s("Agregar propiedad o negocio", "Add property or business"), systemImage: "plus")
                        }
                        .menuRow()
                    } header: {
                        SectionTitle(text: t.s("Propiedades y negocios", "Properties & businesses"))
                    }
                }

                if !store.data.money.isEmpty {
                    Section {
                        ForEach(Array(store.data.money.reversed().prefix(30))) { s in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Fmt.money(s.total)).font(Theme.text(16, .semibold)).foregroundStyle(.white)
                                    Text("\(t.s("Banco", "Bank")) \(Fmt.money(s.bank)) · BUCKME \(Fmt.money(s.app)) · STASH \(Fmt.money(s.home))")
                                        .font(Theme.text(11, relativeTo: .caption2)).foregroundStyle(Theme.lilac)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Fmt.relative(s.at, lang: settings.language)).font(Theme.text(11, relativeTo: .caption2)).foregroundStyle(Theme.lilac)
                                    if s.source == "marisol" { Text("Marisol").font(Theme.text(10, .semibold)).foregroundStyle(Theme.switchPink) }
                                }
                            }
                            .menuRow()
                            .swipeActions { Button(role: .destructive) { store.delete(s) } label: { Label(t.s("Borrar", "Delete"), systemImage: "trash") } }
                        }
                    } header: {
                        SectionTitle(text: t.s("Registros", "Entries"))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle("MONEY")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(t.s("Actualizar", "Update")) { editing = true }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if store.data.propiedadesUnlocked {
                            Button(t.s("Esconder propiedades y negocios", "Hide properties & businesses")) { store.setPropiedadesUnlocked(false) }
                        } else {
                            Button(t.s("Ya desbloqueé propiedades y negocios", "I've unlocked properties & businesses")) { confirmUnlock = true }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .confirmationDialog(t.s("¿Mostrar la sección de propiedades y negocios?", "Show the properties & businesses section?"), isPresented: $confirmUnlock, titleVisibility: .visible) {
                Button(t.s("Mostrar", "Show")) { withAnimation { store.setPropiedadesUnlocked(true) } }
                Button(t.cancel, role: .cancel) {}
            }
            .sheet(isPresented: $editing) { MoneyEditSheet().presentationDetents([.medium, .large]) }
            .sheet(isPresented: $addingProp) { PropiedadSheet().presentationDetents([.medium]) }
        }
    }

    static func short(_ n: Int) -> String {
        if abs(n) >= 1_000_000 { return String(format: "$%.1fM", Double(n) / 1_000_000) }
        if abs(n) >= 1_000 { return "$\(n / 1_000)k" }
        return "$\(n)"
    }
}

struct DeltaText: View {
    let delta: Int
    var body: some View {
        if delta != 0 {
            Text((delta > 0 ? "▲ " : "▼ ") + Fmt.money(abs(delta)))
                .font(Theme.text(12, .semibold, relativeTo: .caption))
                .foregroundStyle(delta > 0 ? Theme.teal : Theme.coral)
        }
    }
}

struct MoneyTile: View {
    let symbol: String
    let title: String
    let value: Int?
    let delta: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.switchPink)
            Text(title.uppercased()).font(Theme.display(13, weight: .semibold)).foregroundStyle(Theme.lilac)
            Text(value.map(Fmt.money) ?? "—")
                .font(Theme.text(16, .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let delta { DeltaText(delta: delta) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.panel.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct MoneyEditSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @Environment(\.dismiss) private var dismiss
    @State private var bank = ""
    @State private var app = ""
    @State private var home = ""

    var body: some View {
        let t = settings.t
        NavigationStack {
            Form {
                Section {
                    field(t.s("Banco", "Bank"), symbol: "building.columns.fill", text: $bank)
                    field("BUCKME", symbol: "iphone", text: $app)
                    field("STASH", symbol: "house.fill", text: $home)
                } header: {
                    SectionTitle(text: t.s("¿Cuánto tenés?", "How much do you have?"))
                } footer: {
                    Text(t.s("Lo que le contás a Marisol también se anota solo.", "What you tell Marisol is logged automatically too."))
                        .font(Theme.text(13, relativeTo: .footnote)).foregroundStyle(Theme.lilac.opacity(0.85))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(t.s("Actualizar", "Update"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t.s("Guardar", "Save")) {
                        let last = store.currentMoney
                        store.addMoney(MoneySnapshot(
                            bank: PockitStore.number(bank) ?? last?.bank ?? 0,
                            app: PockitStore.number(app) ?? last?.app ?? 0,
                            home: PockitStore.number(home) ?? last?.home ?? 0))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(Theme.nightDeep)
        .onAppear {
            if let c = store.currentMoney { bank = "\(c.bank)"; app = "\(c.app)"; home = "\(c.home)" }
        }
    }

    private func field(_ title: String, symbol: String, text: Binding<String>) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(.white)
            Spacer()
            TextField("$0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.text(17, .semibold))
                .frame(maxWidth: 160)
        }
        .menuRow()
    }
}

struct PropiedadSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isBusiness = false
    @State private var note = ""

    var body: some View {
        let t = settings.t
        NavigationStack {
            Form {
                Section {
                    TextField(t.s("Nombre", "Name"), text: $name).menuRow()
                    Toggle(t.s("Es un negocio", "It's a business"), isOn: $isBusiness).tint(Theme.switchPink).menuRow()
                    TextField(t.s("Nota (opcional)", "Note (optional)"), text: $note).menuRow()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(t.s("Nueva", "New"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t.s("Agregar", "Add")) {
                        store.addPropiedad(Propiedad(name: name.trimmingCharacters(in: .whitespaces), isBusiness: isBusiness, note: note))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationBackground(Theme.nightDeep)
    }
}
