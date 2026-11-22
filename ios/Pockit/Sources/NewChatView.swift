import SwiftUI
import UIKit

/// Conversación nueva con Marisol (tapa la página del proyecto de claude.ai).
/// Lo que escribís aquí se manda por la caja de escribir de claude.ai, y al mandarlo claude.ai abre la conversación.
struct NewChatView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var web: WebModel
    @State private var text = ""
    @State private var sending = false

    var body: some View {
        let t = settings.t
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.switchPink)
                Text(t.s("Conversación nueva con Marisol", "New chat with Marisol"))
                    .font(Theme.text(20, .semibold))
                    .foregroundStyle(.white)
                Text(t.s("Tus conversaciones viejas están en ☰ arriba a la izquierda.", "Your old chats are under ☰ at the top left."))
                    .font(Theme.text(13))
                    .foregroundStyle(Theme.lilac)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            Spacer()

            BubbleComposer(text: $text, sending: sending, onSend: send)
        }
        .background(Theme.night)
        .onChange(of: web.currentPath) { _, _ in
            if !web.isNewChat { sending = false; text = "" }
        }
        .onChange(of: web.sendProblem) { _, problem in if problem != nil { sending = false } }
    }

    private func send() {
        let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty, !sending else { return }
        sending = true
        web.send(msg)
        // Si a los 12 s claude.ai no abrió la conversación, se puede reintentar.
        Task {
            try? await Task.sleep(for: .seconds(12))
            if web.isNewChat { sending = false }
        }
    }
}
