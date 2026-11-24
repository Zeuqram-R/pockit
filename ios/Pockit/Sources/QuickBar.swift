import SwiftUI
import UIKit

/// Fila de botones rápidos debajo de la barra superior.
struct QuickBar: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var state: PockitState
    @State private var showProgress = false
    @ObservedObject private var inbox = IntentInbox.shared

    @EnvironmentObject private var store: PockitStore

    /// Pide a Marisol una ruta de ~1 hora solo con lo desbloqueado, y la etiqueta pa' dibujarla en el mapa.
    private func routePrompt(_ t: L10n) -> String {
        let known = store.data.places.suffix(60).joined(separator: ", ")
        let es = "🛣️ Ruta del día: armame una ruta de más o menos 1 hora, solo con lugares y zonas que ya desbloqueé (nada de spoilers). Mezclá lo que valga la pena: actividades, plata, side missions, tiendas, fotos o atardeceres, y coleccionables que me falten solo como pista, nunca la ubicación exacta. Si no sabés dónde estoy, preguntame primero."
            + (known.isEmpty ? "" : " Lugares que ya tengo en el mapa: \(known).")
            + " Al final poné la ruta para el mapa en una línea: ⟦pockit route title=\"…\" stops=\"Lugar 1|Lugar 2|…\"⟧ con los nombres exactos de los lugares, en orden."
        let en = "🛣️ Day route: build me a route of about 1 hour using only places and areas I've already unlocked (no spoilers). Mix what's worth it: activities, money, side missions, shops, photos or sunsets, and collectibles I'm missing only as hints, never the exact location. If you don't know where I am, ask me first."
            + (known.isEmpty ? "" : " Places already on my map: \(known).")
            + " At the end put the route for the map on one line: ⟦pockit route title=\"…\" stops=\"Place 1|Place 2|…\"⟧ with the exact place names, in order."
        return t.s(es, en)
    }

    var body: some View {
        let t = settings.t
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("📍 " + t.qProgress, color: Theme.pink) { showProgress = true }
                chip(t.qWhatNow, color: Theme.coral) { web.send(t.msgWhatNow) }
                chip("🛣️ " + t.s("Ruta del día", "Day route"), color: Theme.sunset) { web.send(routePrompt(t)) }
                chip("🎮 " + t.s("Terminé", "Done playing"), color: Theme.teal) { inbox.showEndSession = true }
                // Solo aparecen cuando Marisol está dando pistas de un secreto.
                if state.hintsOpen {
                    chip(t.qHint, color: Theme.teal) { web.send(t.msgHint) }
                    chip(t.qTellMe, color: Theme.sunset) { web.send(t.msgTellMe) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .animation(.easeOut(duration: 0.2), value: state.hintsOpen)
        }
        .background(Theme.night)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .sheet(isPresented: $inbox.showEndSession) {
            SessionEndSheet()
                .environmentObject(settings)
                .environmentObject(web)
                .environmentObject(state)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showProgress) {
            ProgressSheet()
                .environmentObject(settings)
                .environmentObject(web)
                .environmentObject(state)
                .presentationDetents([.medium])
        }
    }

    private func chip(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(title)
                .font(Theme.text(15, .semibold, relativeTo: .subheadline))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Capsule().fill(color.opacity(0.18)))
                .overlay(Capsule().stroke(color, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

/// Mini formulario de 📍 Progreso: actualiza el tracker y le avisa a Marisol.
struct ProgressSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var state: PockitState
    @Environment(\.dismiss) private var dismiss

    @State private var pct: Double = 0
    @State private var mission = ""

    var body: some View {
        let t = settings.t
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Slider(value: $pct, in: 0...100, step: 1)
                            .tint(Theme.switchPink)
                        Text("\(Int(pct))%")
                            .font(Theme.text(17, .semibold, relativeTo: .headline).monospacedDigit())
                            .frame(width: 52, alignment: .trailing)
                    }
                    .menuRow()
                } header: {
                    SectionTitle(text: t.progressPct)
                }
                Section {
                    TextField(t.progressMissionPlaceholder, text: $mission)
                        .textInputAutocapitalization(.words)
                        .menuRow()
                } header: {
                    SectionTitle(text: t.progressMission)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle("📍 " + t.qProgress)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t.send) {
                        let m = mission.trimmingCharacters(in: .whitespaces)
                        state.progressPct = Int(pct)
                        if !m.isEmpty { state.progressMission = m }
                        // "📍 Progreso" va siempre en español: así lo reconocen las instrucciones de Marisol.
                        var text = "📍 Progreso: \(Int(pct))%"
                        if !m.isEmpty { text += " – \(m)" }
                        web.send(text)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationBackground(Theme.nightDeep)
        .onAppear {
            pct = Double(max(0, state.progressPct))
            mission = state.progressMission
        }
    }
}
