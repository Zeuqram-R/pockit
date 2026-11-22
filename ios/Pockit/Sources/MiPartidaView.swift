import SwiftUI

/// Mi Partida: se abre al tocar la cara de Marisol.
struct MiPartidaView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @EnvironmentObject private var state: PockitState
    @EnvironmentObject private var web: WebModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let t = settings.t
        let pct = max(0, state.progressPct)
        NavigationStack {
            List {
                LargeTitleRow(text: t.s("MI PARTIDA", "MY GAME"))
                Section {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(Theme.nightDeep.opacity(0.7), lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: CGFloat(pct) / 100)
                                .stroke(Theme.switchPink, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text(state.progressPct >= 0 ? "\(pct)%" : "—")
                                .font(Theme.display(28)).foregroundStyle(.white)
                        }
                        .frame(width: 96, height: 96)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.s("ÚLTIMA MISIÓN", "LAST MISSION")).font(Theme.display(13, weight: .semibold)).foregroundStyle(Theme.lilac)
                            Text(state.progressMission.isEmpty ? t.s("Todavía no la sé", "Not reported yet") : state.progressMission)
                                .font(Theme.text(18, .semibold)).foregroundStyle(.white)
                            if let last = store.data.missions.last {
                                Text(Fmt.relative(last.at, lang: settings.language)).font(Theme.text(12, relativeTo: .caption)).foregroundStyle(Theme.lilac.opacity(0.8))
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .menuRow()

                    Button {
                        askWhereWasI(t)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                            Text(t.s("¿Dónde me quedé?", "Where did I leave off?"))
                        }
                        .font(Theme.text(17, .semibold))
                        .foregroundStyle(Theme.nightDeep)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(Theme.switchPink))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }

                Section {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        Stat(symbol: "dollarsign.circle.fill", title: "Money", value: Fmt.money(store.currentMoney?.total ?? 0)) { go(.money) }
                        Stat(symbol: "square.stack.3d.up.fill", title: "Collectibles", value: "\(store.collectiblesFound)") { go(.collectibles) }
                        Stat(symbol: "checklist", title: t.s("Pendientes", "To-do"), value: "\(store.openPendientes.count)") { go(.pendientes) }
                        Stat(symbol: "flag.checkered", title: t.s("Misiones", "Missions"), value: "\(store.data.missions.count)") {}
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }

                Section {
                    if store.data.missions.isEmpty {
                        EmptyRow(symbol: "flag", text: t.s("Las misiones se anotan cuando mandás 📍 Progreso o Marisol las reporta.", "Missions are logged when you send 📍 Progress or Marisol reports them."))
                    }
                    ForEach(store.data.missions.reversed()) { m in
                        HStack {
                            Text(m.name).font(Theme.text(16)).foregroundStyle(.white)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                if let p = m.pct { Text("\(p)%").font(Theme.text(13, .semibold)).foregroundStyle(Theme.switchPink) }
                                Text(Fmt.relative(m.at, lang: settings.language)).font(Theme.text(11, relativeTo: .caption2)).foregroundStyle(Theme.lilac)
                            }
                        }
                        .menuRow()
                        .swipeActions { Button(role: .destructive) { store.delete(m) } label: { Label(t.s("Borrar", "Delete"), systemImage: "trash") } }
                    }
                } header: {
                    SectionTitle(text: t.s("Historial de misiones", "Mission history"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .fadingNavBar(title: t.s("MI PARTIDA", "MY GAME"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(t.done) { dismiss() } }
            }
        }
        .presentationBackground(Theme.nightDeep)
    }

    private func go(_ tab: PockitTab) {
        state.tab = tab
        dismiss()
    }

    private func askWhereWasI(_ t: L10n) {
        var lines: [String] = []
        if state.progressPct >= 0 { lines.append(t.s("Progreso: \(state.progressPct)%", "Progress: \(state.progressPct)%")) }
        if !state.progressMission.isEmpty { lines.append(t.s("Última misión: \(state.progressMission)", "Last mission: \(state.progressMission)")) }
        if let last = store.data.missions.last {
            lines.append(t.s("La anoté \(Fmt.relative(last.at, lang: .es))", "Logged \(Fmt.relative(last.at, lang: .en))"))
        }
        if let m = store.currentMoney {
            lines.append("Money: \(t.s("banco", "bank")) \(Fmt.money(m.bank)), BUCKME \(Fmt.money(m.app)), STASH \(Fmt.money(m.home))")
        }
        let open = store.openPendientes.prefix(5).map(\.text)
        if !open.isEmpty { lines.append(t.s("Pendientes abiertos: ", "Open to-dos: ") + open.joined(separator: "; ")) }
        let summary = lines.isEmpty ? "" : " (" + lines.joined(separator: " · ") + ")"
        let msg = t.s("¿Dónde me quedé?\(summary). Dame un resumen sin spoilers de dónde voy y qué me conviene hacer ahora.",
                      "Where did I leave off?\(summary). Give me a spoiler-free recap of where I am and what I should do next.")
        state.tab = .marisol
        dismiss()
        web.send(msg)
    }
}

private struct Stat: View {
    let symbol: String
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.switchPink)
                Text(title.uppercased()).font(Theme.display(13, weight: .semibold)).foregroundStyle(Theme.lilac)
                Text(value).font(Theme.text(20, .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.panel.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
