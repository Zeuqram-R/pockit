import SwiftUI

/// Barra lateral del iPad y la Mac: el tracker siempre a la vista al lado del chat con Marisol.
struct TrackerSidebar: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PockitStore
    @EnvironmentObject private var state: PockitState
    @EnvironmentObject private var web: WebModel
    @ObservedObject private var inbox = IntentInbox.shared
    @State private var newPendiente = ""

    var body: some View {
        let t = settings.t
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(t.s("MI PARTIDA", "MY GAME")).font(Theme.display(30)).foregroundStyle(.white)

                // Progreso
                HStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(Theme.nightDeep, lineWidth: 8)
                        Circle().trim(from: 0, to: CGFloat(max(0, state.progressPct)) / 100)
                            .stroke(Theme.switchPink, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                        Text(state.progressPct >= 0 ? "\(state.progressPct)%" : "—").font(Theme.display(22)).foregroundStyle(.white)
                    }
                    .frame(width: 74, height: 74)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.s("ÚLTIMA MISIÓN", "LAST MISSION")).font(Theme.text(11, .semibold)).foregroundStyle(Theme.lilac.opacity(0.8))
                        Text(state.progressMission.isEmpty ? t.s("Mandale tu progreso a Marisol", "Send Marisol your progress") : state.progressMission)
                            .font(Theme.text(17, .semibold)).foregroundStyle(.white).lineLimit(2)
                    }
                }
                .card()

                // Plata
                VStack(alignment: .leading, spacing: 8) {
                    label(t.s("PLATA", "MONEY"), "TabColor_cash")
                    if let m = store.currentMoney {
                        Text(Fmt.money(m.total)).font(Theme.display(30)).foregroundStyle(.white)
                        HStack(spacing: 12) {
                            mini(t.s("Banco", "Bank"), m.bank)
                            mini("App", m.app)
                            mini(t.s("Casa", "Home"), m.home)
                        }
                    } else {
                        Text(t.s("Todavía sin datos", "No data yet")).font(Theme.text(14)).foregroundStyle(Theme.lilac)
                    }
                }
                .card()

                // Coleccionables
                HStack {
                    label(t.s("COLECCIONABLES", "COLLECTIBLES"), "TabColor_collections")
                    Spacer()
                    Text("\(store.collectiblesFound)").font(Theme.display(26)).foregroundStyle(.white)
                }
                .card()
                .onTapGesture { state.tab = .collectibles }

                // Pendientes
                VStack(alignment: .leading, spacing: 10) {
                    label(t.s("PENDIENTES", "TO-DO"), "TabColor_pendientes")
                    let open = store.data.pendientes.filter { !$0.done }.reversed().prefix(6)
                    if open.isEmpty {
                        Text(t.s("Nada pendiente 🌴", "Nothing pending 🌴")).font(Theme.text(14)).foregroundStyle(Theme.lilac)
                    }
                    ForEach(Array(open)) { p in
                        Button { withAnimation { store.toggle(p) } } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle").foregroundStyle(Theme.switchPink).padding(.top, 2)
                                Text(p.text).font(Theme.text(14)).foregroundStyle(.white).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        TextField(t.s("Agregar…", "Add…"), text: $newPendiente)
                            .font(Theme.text(14)).foregroundStyle(.white)
                            .onSubmit(add)
                        Button(action: add) { Image(systemName: "plus.circle.fill").foregroundStyle(Theme.switchPink) }
                            .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                .card()

                // Atajos
                VStack(spacing: 10) {
                    action("🎮 " + t.s("Terminé de jugar", "Done playing")) { inbox.showEndSession = true }
                    action("🧭 " + t.qWhatNow) { web.send(t.msgWhatNow) }
                    action("🗺️ " + t.s("Abrir el mapa", "Open the map")) { state.tab = .mapa }
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .background(Theme.nightDeep.opacity(0.35).ignoresSafeArea())
    }

    private func add() {
        let s = newPendiente.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        store.addPendiente(s)
        newPendiente = ""
    }

    private func label(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(icon).resizable().scaledToFit().frame(width: 22, height: 22)
            Text(text).font(Theme.text(12, .semibold)).foregroundStyle(Theme.lilac.opacity(0.85))
        }
    }

    private func mini(_ title: String, _ v: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(Theme.text(11)).foregroundStyle(Theme.lilac.opacity(0.75))
            Text(Fmt.money(v)).font(Theme.text(13, .semibold)).foregroundStyle(.white)
        }
    }

    private func action(_ title: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title).font(Theme.text(15, .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(Theme.purple))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func card() -> some View {
        self.padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel.opacity(0.75)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
