import SwiftUI

/// "Terminé de jugar": tocás lo que hiciste (sin escribir) y Marisol lo anota en el tracker.
struct SessionEndSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @EnvironmentObject private var state: PockitState
    @Environment(\.dismiss) private var dismiss
    @State private var picked: Set<String> = []
    @State private var time: String?
    @State private var note = ""

    private struct Opt: Identifiable { let id: String; let emoji: String; let es: String; let en: String }
    private let opts: [Opt] = [
        Opt(id: "missions", emoji: "📍", es: "Misiones", en: "Missions"),
        Opt(id: "collect", emoji: "🃏", es: "Coleccionables", en: "Collectibles"),
        Opt(id: "money", emoji: "💰", es: "Plata / negocios", en: "Money / business"),
        Opt(id: "explore", emoji: "🧭", es: "Exploré", en: "Explored"),
        Opt(id: "activities", emoji: "🎯", es: "Actividades", en: "Activities"),
        Opt(id: "challenges", emoji: "🏆", es: "Desafíos", en: "Challenges"),
        Opt(id: "bought", emoji: "🚗", es: "Compré algo", en: "Bought something"),
        Opt(id: "chill", emoji: "🌴", es: "Solo vacilé", en: "Just chilled")
    ]
    private let times = ["<1h", "1–2h", "2–4h", "4h+"]

    var body: some View {
        let t = settings.t
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(t.s("¿Qué hiciste hoy?", "What did you do today?")).font(Theme.display(24)).foregroundStyle(.white)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(opts) { o in
                            let on = picked.contains(o.id)
                            Button {
                                UISelectionFeedbackGenerator().selectionChanged()
                                if on { picked.remove(o.id) } else { picked.insert(o.id) }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(o.emoji).font(.system(size: 20))
                                    Text(t.s(o.es, o.en)).font(Theme.text(15, .semibold)).foregroundStyle(.white)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12).frame(height: 50)
                                .background(RoundedRectangle(cornerRadius: 14).fill(on ? Theme.purple : Theme.panel))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Theme.switchPink : Color.white.opacity(0.12), lineWidth: on ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(t.s("¿Cuánto jugaste?", "How long did you play?")).font(Theme.text(15, .semibold)).foregroundStyle(Theme.lilac)
                    HStack(spacing: 8) {
                        ForEach(times, id: \.self) { tm in
                            Button { time = time == tm ? nil : tm } label: {
                                Text(tm).font(Theme.text(14, .semibold)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 38)
                                    .background(Capsule().fill(time == tm ? Theme.purple : Theme.panel))
                                    .overlay(Capsule().stroke(time == tm ? Theme.switchPink : Color.white.opacity(0.12), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField(t.s("Algo más (opcional, podés dictarlo con el micrófono del teclado)", "Anything else (optional, you can dictate it)"), text: $note, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
                        .foregroundStyle(.white)
                    Button { send() } label: {
                        Text(t.s("Contale a Marisol", "Tell Marisol"))
                            .font(Theme.text(17, .semibold)).foregroundStyle(Theme.nightDeep)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Capsule().fill(Theme.switchPink))
                    }
                    .buttonStyle(.plain)
                    .disabled(picked.isEmpty && note.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(picked.isEmpty && note.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .background(Theme.menu.ignoresSafeArea())
            .navigationTitle(t.s("Terminé de jugar", "Done playing"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(t.cancel) { dismiss() } } }
        }
    }

    private func send() {
        let t = settings.t
        let list = opts.filter { picked.contains($0.id) }.map { t.s($0.es, $0.en) }.joined(separator: ", ")
        var msg = t.s("🎮 Terminé de jugar", "🎮 Done playing")
        if let time { msg += " (\(time))" }
        msg += "."
        if !list.isEmpty { msg += t.s(" Hoy hice: \(list).", " Today: \(list).") }
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { msg += " " + n }
        msg += t.s(" Haceme máximo 2 preguntas cortas pa' anotar lo que haga falta en mi tracker (progreso, plata, coleccionables) y después dame un mini resumen. Sin spoilers.",
                   " Ask me at most 2 short questions to log what's needed in my tracker (progress, money, collectibles), then give me a mini recap. No spoilers.")
        state.tab = .marisol
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if web.showsNewChat { web.startNewChat(msg) } else { web.send(msg) }
        }
    }
}
