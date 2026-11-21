import SwiftUI
import UIKit

/// Fila de botones rápidos debajo de la barra superior.
struct QuickBar: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var state: PockitState
    @State private var showProgress = false

    var body: some View {
        let t = settings.t
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("📍 " + t.qProgress, color: Theme.pink) { showProgress = true }
                chip(t.qWhatNow, color: Theme.coral) { web.send(t.msgWhatNow) }
                chip(t.qHint, color: Theme.teal) { web.send(t.msgHint) }
                chip(t.qTellMe, color: Theme.sunset) { web.send(t.msgTellMe) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Theme.night)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.purple.opacity(0.5)).frame(height: 1)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.cream)
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
                Section(t.progressPct) {
                    HStack {
                        Slider(value: $pct, in: 0...100, step: 1)
                        Text("\(Int(pct))%")
                            .font(.headline.monospacedDigit())
                            .frame(width: 52, alignment: .trailing)
                    }
                }
                Section(t.progressMission) {
                    TextField(t.progressMissionPlaceholder, text: $mission)
                        .textInputAutocapitalization(.words)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.night)
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
        .presentationBackground(Theme.night)
        .onAppear {
            pct = Double(max(0, state.progressPct))
            mission = state.progressMission
        }
    }
}
